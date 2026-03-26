BASE_DIR="/Users/molin/Downloads/files/ds006169-2"

# 遍历所有被试
for sub_dir in ${BASE_DIR}/sub-*; do
    sub=$(basename ${sub_dir})
    echo "===== Processing ${sub} ====="

    # 遍历所有 session（不固定）
    for ses_dir in ${sub_dir}/ses-*; do
        ses=$(basename ${ses_dir})
        echo "---- Session: ${ses} ----"

        dwi_dir="${ses_dir}/dwi"
        fmap_dir="${ses_dir}/fmap"

        # 如果没有 dwi 就跳过
        if [ ! -d "${dwi_dir}" ]; then
            echo "No DWI folder, skip"
            continue
        fi

        cd ${dwi_dir}

        # 找 AP DWI 文件（自动匹配）
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
        mrconvert $dwi_nii dwi.mif -fslgrad $bvec $bval

        # ========================
        # 2. Denoise
        # ========================
        dwidenoise dwi.mif dwi_den.mif -noise noise.mif

        mrcalc dwi.mif dwi_den.mif -subtract residual.mif

        # ========================
        # 3. Gibbs removal
        # ========================
        mrdegibbs dwi_den.mif dwi_den_deg.mif

        # ========================
        # 4. Extract b0 (AP)
        # ========================
        dwiextract dwi_den_deg.mif - -bzero | mrmath - mean b0_AP.mif -axis 3

        # ========================
        # 5. Convert PA fmap
        # ========================
        if [ -d "${fmap_dir}" ]; then
            cd ${fmap_dir}
            pa_file=$(ls *_dir-PA_epi.nii.gz 2>/dev/null)

            if [ -n "$pa_file" ]; then
                mrconvert $pa_file b0_PA.mif

                cp b0_PA.mif ${dwi_dir}
            else
                echo "No PA fmap found, skip session"
                continue
            fi
        else
            echo "No fmap folder, skip session"
            continue
        fi

        cd ${dwi_dir}

        # ========================
        # 6. Merge AP + PA
        # ========================
        mrcat b0_AP.mif b0_PA.mif b0_pair.mif -axis 3

        # ========================
        # 7. Preprocessing (TOPUP + EDDY)
        # ========================
        dwifslpreproc dwi.mif dwi_preproc.mif \
            -nocleanup \
            -pe_dir AP \
            -rpe_pair \
            -se_epi b0_pair.mif \
            -eddy_options " --slm=linear --data_is_shelled"

        # ========================
        # 8. Motion QC
        # ========================
        cd dwifslpreproc-tmp-*

        totalSlices=$(mrinfo dwi.mif | grep Dimensions | awk '{print $6 * $8}')
        totalOutliers=$(awk '{ for(i=1;i<=NF;i++)sum+=$i } END { print sum }' dwi_post_eddy.eddy_outlier_map)

        percent=$(echo "scale=5; ($totalOutliers / $totalSlices * 100)" | bc)

        echo "Outlier %: $percent"
        echo $percent > percentageOutliers.txt

        cd ..

        # ========================
        # 9. Bias correction
        # ========================
        dwibiascorrect ants dwi_preproc.mif dwi_preproc_unbiased.mif -bias bias.mif

        # ========================
        # 10. Mask
        # ========================
        dwi2mask dwi_preproc_unbiased.mif mask.mif

        # ========================
        # 11. Tensor
        # ========================
        dwi2tensor dwi_preproc_unbiased.mif dt.mif -mask mask.mif

        tensor2metric dt.mif -fa fa.mif -md md.mif

        # ========================
        # 12. Response function
        # ========================
        dwi2response dhollander dwi_preproc_unbiased.mif wm.txt gm.txt csf.txt -voxels voxels.mif

        # ========================
        # 13. FOD
        # ========================
        dwi2fod msmt_csd dwi_preproc_unbiased.mif \
            -mask mask.mif \
            wm.txt wmfod.mif \
            gm.txt gmfod.mif \
            csf.txt csffod.mif

        # ========================
        # 14. Normalization
        # ========================
        mtnormalise \
            wmfod.mif wmfod_norm.mif \
            gmfod.mif gmfod_norm.mif \
            csffod.mif csffod_norm.mif \
            -mask mask.mif

        echo "✔ Finished ${sub} ${ses}"
    done
done
