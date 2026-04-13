MAX_JOBS=2   # 同时跑4个被试（根据CPU调）

job_count=0

BASE_DIR="/Users/molin/Downloads/files/ds006169-2"
# BASE_DIR="/Volumes/xyu/files/ds006169-2"
for sub_dir in "${BASE_DIR}"/sub-*; do
    sub=$(basename "${sub_dir}")

    sub_num=${sub#sub-}
    sub_num=$((10#$sub_num))

    #if [ "$sub_num" -lt 60 ]; then
    #    continue
    #fi
    while [ "$(jobs -r | wc -l)" -ge "$MAX_JOBS" ]; do
        sleep 5
    done

    (
        set -e
        echo "▶ Start $sub"
        
        echo "===== Processing ${sub} ====="

    # 遍历所有 session
    for ses_dir in "${sub_dir}"/ses-*; do
        ses=$(basename "${ses_dir}")
        echo "---- Session: ${ses} ----"

        dwi_dir="${ses_dir}/dwi"
        anat_dir="${ses_dir}/anat"
        fmap_dir="${ses_dir}/fmap"

        # ========================
        # 检查 DWI 文件
        # ========================
        if [ ! -d "$dwi_dir" ]; then
            echo "No DWI folder, skip"
            continue
        fi

        cd "$dwi_dir" || exit

        dwi_nii=$(ls *_dir-AP_dwi.nii.gz 2>/dev/null)
        bvec=$(ls *_dir-AP_dwi.bvec 2>/dev/null)
        bval=$(ls *_dir-AP_dwi.bval 2>/dev/null)

        if [ -z "$dwi_nii" ]; then
            echo "No AP DWI found, skip"
            continue
        fi

        echo "DWI file: $dwi_nii"

        # ========================
        # 1. Convert
        # ========================
        mrconvert "$dwi_nii" dwi.mif -fslgrad "$bvec" "$bval" -force

        # ========================
        # 2. Denoise
        # ========================
        dwidenoise dwi.mif dwi_den.mif -noise noise.mif -force
        mrcalc dwi.mif dwi_den.mif -subtract residual.mif -force

        # ========================
        # 3. Gibbs removal
        # ========================
        mrdegibbs dwi_den.mif dwi_den_deg.mif -force

        # ========================
        # 4. Extract b0 (AP)
        # ========================
        dwiextract dwi_den_deg.mif - -bzero | \
            mrmath - mean b0_AP.mif -axis 3 -force

        # ========================
        # 5. Convert PA fmap
        # ========================
        if [ -d "$fmap_dir" ]; then
            cd "$fmap_dir" || exit

            pa_file=$(ls *_dir-PA_epi.nii.gz 2>/dev/null)

            if [ -n "$pa_file" ]; then
                mrconvert "$pa_file" b0_PA.mif -force
                cp b0_PA.mif "$dwi_dir"
            else
                echo "No PA fmap found, skip session"
                continue
            fi
        else
            echo "No fmap folder, skip session"
            continue
        fi

        cd "$dwi_dir" || exit

        # ========================
        # 6. Merge AP + PA
        # ========================
        mrcat b0_AP.mif b0_PA.mif b0_pair.mif -axis 3 -force

        # ========================
        # 7. Preprocessing (TOPUP + EDDY)
        # ========================
        dwifslpreproc dwi_den_deg.mif dwi_preproc.mif \
            -nocleanup \
            -pe_dir AP \
            -rpe_pair \
            -se_epi b0_pair.mif \
            -eddy_options " --slm=linear --data_is_shelled" \
            -force

        # ========================
        # 8. Motion QC
        # ========================
        cd dwifslpreproc-tmp-* || exit

        totalSlices=$(mrinfo dwi.mif | grep Dimensions | awk '{print $6 * $8}')
        totalOutliers=$(awk '{ for(i=1;i<=NF;i++)sum+=$i } END { print sum }' dwi_post_eddy.eddy_outlier_map)

        percent=$(echo "scale=5; ($totalOutliers / $totalSlices * 100)" | bc)
        echo "Outlier %: $percent" > percentageOutliers.txt

        cd ..

        # ========================
        # 9. Bias correction
        # ========================
        dwibiascorrect ants dwi_preproc.mif dwi_preproc_unbiased.mif \
            -bias bias.mif -force

        # ========================
        # 10. Mask
        # ========================
        dwi2mask dwi_preproc_unbiased.mif mask.mif -force

        # ========================
        # 11. Tensor
        # ========================
        dwi2tensor dwi_preproc_unbiased.mif dt.mif \
            -mask mask.mif -force

        tensor2metric dt.mif \
            -fa fa.mif \
            -adc md.mif \
            -force

        # ========================
        # 12. Response function
        # ========================
        dwi2response dhollander dwi_preproc_unbiased.mif \
            wm.txt gm.txt csf.txt \
            -voxels voxels.mif -force

        # ========================
        # 13. FOD
        # ========================
        dwi2fod msmt_csd dwi_preproc_unbiased.mif \
            -mask mask.mif \
            wm.txt wmfod.mif \
            gm.txt gmfod.mif \
            csf.txt csffod.mif \
            -force

        # ========================
        # 14. Normalization
        # ========================
        mtnormalise \
            wmfod.mif wmfod_norm.mif \
            csffod.mif csffod_norm.mif \
            -mask mask.mif -force

        # ========================
        # 15. FreeSurfer 检查
        # ========================
        FS_SUB="${sub}"

        case $ses in
            ses-01)
                FS_DIR="/Users/molin/Downloads/ds006169-test/infant_fs_subjects"
                ;;
            ses-02)
                FS_DIR="/Users/molin/Downloads/ds006169-test/toddler_fs_subjects"
                ;;
            ses-03)
                FS_DIR="/Users/molin/Downloads/ds006169-test/prereading_fs_subjects"
                ;;
            ses-04)
                FS_DIR="/Users/molin/Downloads/ds006169-test/beginreading_fs_subjects"
                ;;
            ses-05)
                FS_DIR="/Users/molin/Downloads/ds006169-test/emergereading_fs_subjects"
                ;;
            *)
                echo "❌ Unknown session $ses, skip"
                continue
                ;;
        esac

        if [ ! -d "${FS_DIR}/${FS_SUB}" ]; then
            echo "❌ FreeSurfer subject not found: ${FS_DIR}/${FS_SUB}"
            continue
        else
            echo "✔ Found FreeSurfer: ${FS_SUB}"
        fi

        # ========================
        # 16. 5TT + GMWMI
        # ========================
        if [ ! -f "5tt.mif" ]; then
            echo "▶ Generating 5TT (FSL version)..."

            T1=$(find "$anat_dir" -maxdepth 1 -name "*T1w.nii.gz" | head -n 1)

            if [ -z "$T1" ]; then
                echo "❌ No T1 found, skip"
                continue
            fi

            5ttgen fsl "$T1" 5tt.mif -force
        fi

        if [ ! -f "gmwmi_seed.mif" ]; then
            5tt2gmwmi 5tt.mif gmwmi_seed.mif -force
        fi

        # ========================
        # 17. Tractography
        # ========================
        if [ ! -f "tracks_2M.tck" ]; then
            tckgen wmfod_norm.mif tracks_2M.tck -algorithm iFOD1 -info -backtrack -crop_at_gmwmi -seed_gmwmi gmwmi_seed.mif -act 5tt.mif -select 2000000 -force
        fi


        echo "✔ Finished ${sub} ${ses}"

    done
    echo "✔ Done $sub"
    ) &
done

wait
echo "🎉 ALL DONE"

        # ========================
        # 18. SIFT2
        # ========================
        #if [ ! -f "sift2_weights.txt" ]; then
        #    tcksift2 tracks_2M.tck wmfod_norm.mif \
        #        sift2_weights.txt -force
        #fi
        #    if [ "$sub_num" -lt 20 ]; then
        #continue
    #fi
