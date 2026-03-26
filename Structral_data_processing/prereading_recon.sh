DATA_DIR=/Users/molin/Downloads/files/ds006169-2
export SUBJECTS_DIR=$DATA_DIR/prereading_fs_subjects

mkdir -p $SUBJECTS_DIR

cd $SUBJECTS_DIR

for subject in $DATA_DIR/sub-*; do

    subject=$(basename $subject)

    anatdir=$DATA_DIR/$subject/ses-03/anat

    t1file=$(find "$anatdir" -name "*T1w.nii.gz" | head -n 1)

    if [ -z "$t1file" ]; then
        echo "❌ No T1 found for $subject"
        continue
    fi

    echo "Found T1:"
    echo "$t1file"

    subjdir=$SUBJECTS_DIR/$subject

    if [ -d "$subjdir" ]; then
        echo "⚠️ $subject already processed"
        continue
    fi

    echo "Running recon-all..."

    recon-all -s "$subject" -i "$t1file" -all

    echo "--------------------------------"

done

