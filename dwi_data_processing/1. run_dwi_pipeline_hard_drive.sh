#!/bin/bash

# ========================
# 🔧 CONFIG
# ========================
BASE_DIR="/Volumes/xyu/files/ds006169-2"
FS_BASE="/Volumes/xyu/files/ds006169-2"

MAX_JOBS=2   # ⚠️ 建议先用2（硬盘更稳）

# ========================
# 🚨 HARD DRIVE CHECK
# ========================
if [ ! -d "$BASE_DIR" ]; then
    echo "❌ HARD DRIVE NOT FOUND: $BASE_DIR"
    exit 1
fi

# ========================
# 🧠 FORCE TEMP TO HARD DRIVE
# ========================
export TMPDIR="${BASE_DIR}/tmp"
mkdir -p "$TMPDIR"

echo "🧠 TMPDIR = $TMPDIR"

# ========================
# 🔁 MAIN LOOP
# ========================
for sub_dir in "${BASE_DIR}"/sub-*; do

    sub=$(basename "$sub_dir")       # sub-01
    sub_num=${sub#sub-}              # 去掉前缀 "sub-"
    sub_num=$((10#$sub_num))         # 转成整数

    # 如果你想跳过 sub_num 小于 40 的
    if [ "$sub_num" -lt 40 ]; then
        continue
    fi

(
    set -e

    echo "▶ Start $sub"

    logfile="${sub_dir}/processing.log"
    exec > >(tee -a "$logfile") 2>&1

    start_time=$(date +%s)


    # ========================
    # LOOP SESSIONS
    # ========================
    for ses_dir in "${sub_dir}"/ses-*; do

        ses=$(basename "$ses_dir")
        echo "---- Session: $ses ----"

        dwi_dir="${ses_dir}/dwi"
        anat_dir="${ses_dir}/anat"
        fmap_dir="${ses_dir}/fmap"

        [ ! -d "$dwi_dir" ] && echo "No DWI, skip" && continue

        cd "$dwi_dir" || { echo "❌ Cannot enter $dwi_dir"; exit 1; }

        # ========================
        # ✅ SKIP IF DONE
        # ========================
        if [ -f "tracks_2M.tck" ]; then
            echo "✔ Already finished, skip session"
            continue
        fi

        # ========================
        # INPUT CHECK
        # ========================
        dwi_nii=$(ls *_dir-AP_dwi.nii.gz 2>/dev/null | head -n 1)
        bvec=$(ls *_dir-AP_dwi.bvec 2>/dev/null | head -n 1)
        bval=$(ls *_dir-AP_dwi.bval 2>/dev/null | head -n 1)

        [ -z "$dwi_nii" ] && echo "❌ No DWI" && continue

        echo "DWI: $dwi_nii"

        # ========================
        # PIPELINE (WITH CHECKPOINTS)
        # ========================

        [ ! -f dwi.mif ] && mrconvert "$dwi_nii" dwi.mif -fslgrad "$bvec" "$bval" -force

        [ ! -f dwi_den.mif ] && dwidenoise dwi.mif dwi_den.mif -noise noise.mif -force

        [ ! -f dwi_den_deg.mif ] && mrdegibbs dwi_den.mif dwi_den_deg.mif -force

        if [ ! -f b0_AP.mif ]; then
            dwiextract dwi_den_deg.mif - -bzero | \
            mrmath - mean b0_AP.mif -axis 3 -force
        fi

        # ===== fmap =====
        if [ ! -f b0_PA.mif ]; then
            [ ! -d "$fmap_dir" ] && echo "❌ No fmap" && continue
            pa_file=$(ls "$fmap_dir"/*_dir-PA_epi.nii.gz 2>/dev/null | head -n 1)
            [ -z "$pa_file" ] && echo "❌ No PA" && continue
            mrconvert "$pa_file" b0_PA.mif -force
        fi

        [ ! -f b0_pair.mif ] && mrcat b0_AP.mif b0_PA.mif b0_pair.mif -axis 3 -force

        if [ ! -f dwi_preproc.mif ]; then
            dwifslpreproc dwi_den_deg.mif dwi_preproc.mif \
                -pe_dir AP -rpe_pair -se_epi b0_pair.mif \
                -eddy_options " --slm=linear --data_is_shelled" \
                -force
        fi

        [ ! -f dwi_preproc_unbiased.mif ] && \
        dwibiascorrect ants dwi_preproc.mif dwi_preproc_unbiased.mif -force

        [ ! -f mask.mif ] && dwi2mask dwi_preproc_unbiased.mif mask.mif -force

        if [ ! -f fa.mif ]; then
            dwi2tensor dwi_preproc_unbiased.mif dt.mif -mask mask.mif -force
            tensor2metric dt.mif -fa fa.mif -adc md.mif -force
        fi

        if [ ! -f wmfod_norm.mif ]; then
            dwi2response dhollander dwi_preproc_unbiased.mif wm.txt gm.txt csf.txt -force

            dwi2fod msmt_csd dwi_preproc_unbiased.mif \
                wm.txt wmfod.mif gm.txt gmfod.mif csf.txt csffod.mif \
                -mask mask.mif -force

            mtnormalise wmfod.mif wmfod_norm.mif \
                csffod.mif csffod_norm.mif \
                -mask mask.mif -force
        fi

        # ========================
        # FreeSurfer
        # ========================
        case $ses in
            ses-01) FS_DIR="$FS_BASE/infant_fs_subjects" ;;
            ses-02) FS_DIR="$FS_BASE/toddler_fs_subjects" ;;
            ses-03) FS_DIR="$FS_BASE/prereading_fs_subjects" ;;
            ses-04) FS_DIR="$FS_BASE/beginreading_fs_subjects" ;;
            ses-05) FS_DIR="$FS_BASE/emergereading_fs_subjects" ;;
            *) echo "❌ Unknown session"; continue ;;
        esac

        [ ! -d "${FS_DIR}/${sub}" ] && echo "❌ No FS subject" && continue

        if [ ! -f 5tt.mif ]; then
            T1=$(find "$anat_dir" -name "*T1w.nii.gz" | head -n 1)
            [ -z "$T1" ] && echo "❌ No T1" && continue
            5ttgen fsl "$T1" 5tt.mif -force
        fi

        [ ! -f gmwmi_seed.mif ] && 5tt2gmwmi 5tt.mif gmwmi_seed.mif -force

        # ========================
        # Tractography
        # ========================
        if [ ! -f tracks_2M.tck ]; then
            tckgen wmfod_norm.mif tracks_2M.tck \
                -algorithm iFOD1 \
                -backtrack -crop_at_gmwmi \
                -seed_gmwmi gmwmi_seed.mif \
                -act 5tt.mif \
                -select 2000000 -force
        fi

        echo "✔ Finished $sub $ses"

    done

    end_time=$(date +%s)
    runtime=$((end_time - start_time))
    echo "⏱ Runtime for $sub: $runtime sec"

    echo "✔ DONE $sub"

) &

    # ========================
    # 🔁 JOB CONTROL
    # ========================
    while [ "$(jobs -r | wc -l)" -ge "$MAX_JOBS" ]; do
        sleep 5
    done

done

wait

echo "🎉 ALL DONE"