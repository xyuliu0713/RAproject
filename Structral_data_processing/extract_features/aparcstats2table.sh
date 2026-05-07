#!/bin/bash 
# run in the terminal, and then run the python scripts to extract features,
# lastly run metrices_table

cd /Volumes/xyu/files/ds006169-2/structural_features/prereading

export FREESURFER_HOME=/Applications/freesurfer/8.1.0
source $FREESURFER_HOME/SetUpFreeSurfer.sh


SUBJECTS_DIR=/Volumes/xyu/ds006169-1/derivatives/freeserfer/prereading_fs_subjects
SUBJECTS_DIR=/Volumes/xyu/files/ds006169-2/derivatives
#infant_fs_subjects
#toddler_fs_subjects
#prereading_fs_subjects
#beginreading_fs_subjects
#emereading_fs_subjects

1.	Thickness:
aparcstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --hemi lh \
  --meas thickness \
  --skip \
  --tablefile lh_thickness.txt

  aparcstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --hemi rh \
  --meas thickness \
  --skip \
  --tablefile rh_thickness.tx

2.	surface area
aparcstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --hemi lh \
  --meas area \
  --skip \
  --tablefile lh_area.txt

  aparcstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --hemi rh \
  --meas area \
  --skip \
  --tablefile rh_area.txt

3.	gray matter volume
aparcstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --hemi lh \
  --meas volume \
  --skip \
  --tablefile lh_gmvolume.txt

4.	white matter volume
asegstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --meas volume \
  --common-segs \
  --skip \
  --tablefile wmvolume.txt

asegstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --meas volume \
  --stats wmparc.stats \
  --common-segs \
  --skip \
  --tablefile wmvolume1.txt

5.	curvature
aparcstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --hemi lh \
  --meas meancurv \
  --skip \
  --tablefile lh_curv.txt



for hm in lh rh; do
  for m in volume area thickness thicknessstd meancurv gauscurv foldind curvind; do
    aparcstats2table --subjectsfile=${1} --hemi $hm --meas $m --tablefile ${out_dir}/${hm}_${m}_aparc_stats.txt
  done
done