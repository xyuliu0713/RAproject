#!/bin/bash 
# in /Volumes/xyu/files/ds006169-2/script/test.sh

BASE_DIR="/Volumes/xyu/files/ds006169-2"
FS_BASE="/Volumes/xyu/files/ds006169-2"

export TMPDIR="${BASE_DIR}/tmp"
mkdir -p "$TMPDIR"

for sub_dir in "${BASE_DIR}"/sub-*; do
    sub=$(basename "${sub_dir}")
    echo "===== Processing ${sub} ====="

    for ses_dir in "${sub_dir}"/ses-*; do
        ses=$(basename "${ses_dir}")
        echo "---- Session: ${ses} ----"

        dwi_dir="${ses_dir}/dwi"
        anat_dir="${ses_dir}/anat"
        fmap_dir="${ses_dir}/fmap"

        if [ ! -d "$dwi_dir" ]; then
            echo "No DWI folder"
            continue
        fi

        cd "$dwi_dir" || exit

        dwi_nii=$(ls *_dir-AP_dwi.nii.gz 2>/dev/null)
        bvec=$(ls *_dir-AP_dwi.bvec 2>/dev/null)
        bval=$(ls *_dir-AP_dwi.bval 2>/dev/null)

        if [ -z "$dwi_nii" ]; then
            echo "No DWI found"
            continue
        fi

        # ========================
        # 1. Convert
        # ========================
        if [ ! -f "dwi.mif" ]; then
            echo "▶ Convert"
            mrconvert "$dwi_nii" dwi.mif -fslgrad "$bvec" "$bval" -force
        else
            echo "⏭ Skip convert"
        fi

        # ========================
        # 2. Denoise
        # ========================
        if [ ! -f "dwi_den.mif" ]; then
            echo "▶ Denoise"
            dwidenoise dwi.mif dwi_den.mif -noise noise.mif -force
        else
            echo "⏭ Skip denoise"
        fi

        # ========================
        # 3. Gibbs
        # ========================
        if [ ! -f "dwi_den_deg.mif" ]; then
            echo "▶ Gibbs correction"
            mrdegibbs dwi_den.mif dwi_den_deg.mif -force
        else
            echo "⏭ Skip Gibbs"
        fi

        # ========================
        # 4. b0 AP
        # ========================
        if [ ! -f "b0_AP.mif" ]; then
            echo "▶ Extract b0 AP"
            dwiextract dwi_den_deg.mif - -bzero | \
                mrmath - mean b0_AP.mif -axis 3 -force
        else
            echo "⏭ Skip b0 AP"
        fi

        # ========================
        # 5. PA fmap
        # ========================
        if [ ! -f "b0_PA.mif" ]; then
            if [ -d "$fmap_dir" ]; then
                cd "$fmap_dir" || exit
                pa_file=$(ls *_dir-PA_epi.nii.gz 2>/dev/null)

                if [ -n "$pa_file" ]; then
                    echo "▶ Convert PA"
                    mrconvert "$pa_file" b0_PA.mif -force
                    cp b0_PA.mif "$dwi_dir"
                else
                    echo "❌ No PA file"
                    continue
                fi
            else
                echo "❌ No fmap folder"
                continue
            fi
        else
            echo "⏭ Skip PA"
        fi

        cd "$dwi_dir" || exit

        # ========================
        # 6. Merge
        # ========================
        if [ ! -f "b0_pair.mif" ]; then
            echo "▶ Merge AP+PA"
            mrcat b0_AP.mif b0_PA.mif b0_pair.mif -axis 3 -force
        else
            echo "⏭ Skip merge"
        fi

        # ========================
        # 7. Preproc
        # ========================
        if [ ! -f "dwi_preproc.mif" ]; then
            echo "▶ dwifslpreproc"
            dwifslpreproc dwi_den_deg.mif dwi_preproc.mif \
                -pe_dir AP \
                -rpe_pair \
                -se_epi b0_pair.mif \
                -eddy_options " --slm=linear" \
                -force
        else
            echo "⏭ Skip preproc"
        fi

        # ========================
        # 8. Motion QC
        # ========================

        totalSlices=$(mrinfo dwi.mif | grep Dimensions | awk '{print $6 * $8}')
        totalOutliers=$(awk '{ for(i=1;i<=NF;i++)sum+=$i } END { print sum }' dwi_post_eddy.eddy_outlier_map)

        percent=$(echo "scale=5; ($totalOutliers / $totalSlices * 100)" | bc)
        echo "Outlier %: $percent" > percentageOutliers.txt


        # ========================
        # 9. Bias
        # ========================
        if [ ! -f "dwi_preproc_unbiased.mif" ]; then
            echo "▶ Bias correction"
            dwibiascorrect ants dwi_preproc.mif dwi_preproc_unbiased.mif \
                -bias bias.mif -force
        else
            echo "⏭ Skip bias"
        fi

        # ========================
        # 10. Mask
        # ========================
        if [ ! -f "mask.mif" ]; then
            echo "▶ Mask"
            dwi2mask dwi_preproc_unbiased.mif mask.mif -force
        else
            echo "⏭ Skip mask"
        fi

        # ========================
        # 11. Tensor
        # ========================
        if [ ! -f "dt.mif" ]; then
            echo "▶ dt"
            dwi2tensor dwi_preproc_unbiased.mif dt.mif \
                -mask mask.mif -force
        else
            echo "⏭ Skip dt"
        fi


        if [ ! -f "dt.mif" ]; then
            echo "▶ dt"
            dwi2tensor dwi_preproc_unbiased.mif dt.mif \
                -mask mask.mif -force
                
            tensor2metric dt.mif \
                -fa fa.mif \
                -adc md.mif \
                -force
                
        else
            echo "⏭ Skip dt"
        fi
      
        # ========================
        # 12. Response function
        # ========================
        if [ ! -f wm.txt ]; then
            echo "▶ Response function (dhollander)"

            dwi2response dhollander dwi_preproc.mif \
                wm.txt gm.txt csf.txt \
                -voxels voxels.mif \
                -force

            # 🔥 check
            if [ ! -s wm.txt ] || [ ! -s csf.txt ]; then
                echo "❌ response failed"
            fi
        fi
  

        # ========================
        # 13. FOD
        # ========================
        if [ ! -f "wmfod_norm.mif" ]; then
            echo "▶ FOD + normalization"
            dwi2fod msmt_csd dwi_preproc_unbiased.mif \
                -mask mask.mif \
                wm.txt wmfod.mif \
                gm.txt gmfod.mif \
                csf.txt csffod.mif \
                -force

        # sanity check
        for f in wmfod.mif gmfod.mif csffod.mif; do
            if [ ! -f "$f" ]; then
                echo "❌ missing $f"
            fi
        done

        # ========================
        # 14. Normalization
        # ========================
            mtnormalise \
                wmfod.mif wmfod_norm.mif \
                csffod.mif csffod_norm.mif \
                -mask mask.mif -force

        else
            echo "⏭ Skip FOD"
        fi

        # ========================
        # 15. FreeSurfer 检查
        # ========================
        FS_SUB="${sub}"

        case $ses in
            ses-01)
                FS_DIR="/Volumes/xyu/files/ds006169-2/infant_fs_subjects"
                ;;
            ses-02)
                FS_DIR="/Volumes/xyu/files/ds006169-2/toddler_fs_subjects"
                ;;
            ses-03)
                FS_DIR="/Volumes/xyu/files/ds006169-2/prereading_fs_subjects"
                ;;
            ses-04)
                FS_DIR="/Volumes/xyu/files/ds006169-2/beginreading_fs_subjects"
                ;;
            ses-05)
                FS_DIR="/Volumes/xyu/files/ds006169-2/emergereading_fs_subjects"
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
            echo "▶ Generating 5TT"

            T1=$(ls "${anat_dir}"/*T1w.nii.gz 2>/dev/null)

            if [ -z "$T1" ]; then
                echo "❌ No T1"
                continue
            fi

            5ttgen fsl "$T1" 5tt.mif -force
        else
            echo "⏭ Skip 5TT"
        fi

        if [ ! -f "gmwmi_seed.mif" ]; then
            echo "▶ GMWMI"
            5tt2gmwmi 5tt.mif gmwmi_seed.mif -force
        else
            echo "⏭ Skip GMWMI"
        fi

        echo "✔ Finished ${sub} ${ses}"

    done
done

echo "🎉 SCRIPT 1 DONE"

        # ========================
        # 18. SIFT2
        # ========================
        #if [ ! -f "sift2_weights.txt" ]; then
        #    tcksift2 tracks_2M.tck wmfod_norm.mif \
        #        sift2_weights.txt -force
        #fi
