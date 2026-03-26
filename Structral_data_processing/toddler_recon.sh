DATA_DIR=/Users/molin/Downloads/files/ds006169-2
export SUBJECTS_DIR=$DATA_DIR/toddler_fs_subjects

mkdir -p $SUBJECTS_DIR

tail -n +2 $DATA_DIR/participants_clean.tsv | awk -F'\t' '$2==1 {print $1 "\t" $4}' | \
while IFS=$'\t' read subject age
do

    rounded_age=$(printf "%.0f" "$age")

    echo "Processing $subject age $rounded_age"

    anatdir=$DATA_DIR/$subject/ses-02/anat

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

    mkdir -p "$subjdir"

    echo "Copying T1..."
    cp "$t1file" "$subjdir/mprage.nii.gz"

    echo "Running toddler_recon_all..."

    cd $SUBJECTS_DIR

    infant_recon_all --s "$subject" --age "$rounded_age" --inputfile "$t1file"

    echo "--------------------------------"

done

