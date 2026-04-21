#!/bin/bash 
# run in the terminal, and then run the python scripts to extract features

cd /Users/molin/Downloads/files/ds006169-2/structural_data_features

export FREESURFER_HOME=/Applications/freesurfer/8.1.0
source $FREESURFER_HOME/SetUpFreeSurfer.sh

# SUBJECTS_DIR=/Users/molin/Downloads/ds006169-test/infant_fs_subjects

SUBJECTS_DIR=/Users/molin/Downloads/files/ds006169-2/emereading_fs_subjects
#toddler_fs_subjects
#prereading_fs_subjects
#beginreading_fs_subjects
#emereading_fs_subjects

1.	Thickness:
aparcstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --hemi lh \
  --meas thickness \
  --tablefile lh_thickness.txt

2.	surface area
aparcstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --hemi lh \
  --meas area \
  --tablefile lh_area.txt

3.	gray matter volume
aparcstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --hemi lh \
  --meas volume \
  --tablefile lh_volume.txt

4.	white matter volume
  asegstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --hemi lh \
  --meas volume \
  --tablefile aseg_volume.txt

5.	curvature
aparcstats2table \
  --subjects $(ls $SUBJECTS_DIR | grep '^sub') \
  --hemi lh \
  --meas meancurv \
  --tablefile lh_curv.txt
