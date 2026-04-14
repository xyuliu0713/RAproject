#!/bin/bash in /Volumes/xyu/files/ds006169-2/script/test4.sh

BASE_DIR="/Volumes/xyu/files/ds006169-2"

export TMPDIR="${BASE_DIR}/tmp"
mkdir -p "$TMPDIR"

for sub_dir in "${BASE_DIR}"/sub-*; do
    sub=$(basename "${sub_dir}")
    echo "===== Tractography ${sub} ====="

    for ses_dir in "${sub_dir}"/ses-*; do
        ses=$(basename "${ses_dir}")
        echo "---- Session: ${ses} ----"

        dwi_dir="${ses_dir}/dwi"

        if [ ! -d "$dwi_dir" ]; then
            continue
        fi

        cd "$dwi_dir" || exit

        # ========================
        # 🔍 输入文件检查（只检查，不算 step）
        # ========================
        missing=0

        for f in wmfod_norm.mif 5tt.mif gmwmi_seed.mif; do
            if [ ! -f "$f" ]; then
                echo "❌ Missing $f"
                missing=1
            fi
        done

        if [ $missing -eq 1 ]; then
            echo "⏭ Skip session (missing inputs)"
            continue
        fi

        # ========================
        # 17. Tractography
        # ========================
        if [ -s "tracks_2M.tck" ]; then
            echo "⏭ Skip tractography (tracks exist)"
        else
            echo "▶ Running tractography..."

            tckgen wmfod_norm.mif tracks_2M.tck \
                -algorithm iFOD1 \
                -backtrack \
                -crop_at_gmwmi \
                -seed_gmwmi gmwmi_seed.mif \
                -act 5tt.mif \
                -select 2000000 \
                -force

            # ✅ 更安全：标记完成
            touch .tractography_done
        fi

        echo "✔ Finished tractography ${sub} ${ses}"

    done
done

echo "🎉 SCRIPT 2 DONE"
