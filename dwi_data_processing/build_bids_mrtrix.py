import os
import shutil
from glob import glob

SRC = "/Volumes/xyu/files/ds006169-2"
DEST = "/Volumes/xyu/ds006169/derivatives/mrtrix"

for sub in sorted(glob(os.path.join(SRC, "sub-*"))):
    sub_id = os.path.basename(sub)

    for ses in sorted(glob(os.path.join(sub, "ses-*"))):
        ses_id = os.path.basename(ses)

        dwi_dir = os.path.join(ses, "dwi")

        nii = os.path.join(dwi_dir, "dwi_preproc_unbiased.nii.gz")
        bval = os.path.join(dwi_dir, "dwi_preproc.bval")
        bvec = os.path.join(dwi_dir, "dwi_preproc.bvec")

        tck_files = glob(os.path.join(dwi_dir, "tracks*.tck"))
        b0 = os.path.join(dwi_dir, "b0_pair.nii.gz")
        bias = os.path.join(dwi_dir, "bias.nii.gz")
        mask = os.path.join(dwi_dir, "mask.nii.gz")

        if not (os.path.exists(nii) and os.path.exists(bval) and os.path.exists(bvec)):
            print(f"❌ Skipping {sub_id} {ses_id} (missing DWI)")
            continue

        print(f"✅ Processing {sub_id} {ses_id}")

        out_dwi = os.path.join(DEST, sub_id, ses_id, "dwi")
        out_anat = os.path.join(DEST, sub_id, ses_id, "anat")

        os.makedirs(out_dwi, exist_ok=True)
        os.makedirs(out_anat, exist_ok=True)

        # ---- DWI ----
        #shutil.copy(nii, os.path.join(
        #    out_dwi, f"{sub_id}_{ses_id}_desc-preproc_dwi.nii.gz"))

        #shutil.copy(bval, os.path.join(
        #    out_dwi, f"{sub_id}_{ses_id}_desc-preproc_dwi.bval"))

        #shutil.copy(bvec, os.path.join(
        #    out_dwi, f"{sub_id}_{ses_id}_desc-preproc_dwi.bvec"))

        # ---- tractography ----
        if tck_files:
            shutil.copy(tck_files[0], os.path.join(
                out_dwi, f"{sub_id}_{ses_id}_tractography.tck"))

        # ---- b0 ----
        if os.path.exists(b0):
            shutil.copy(b0, os.path.join(
                out_anat, f"{sub_id}_{ses_id}_desc-b0_dwi.nii.gz"))
            
       
        # anat: bias corrected image

        if os.path.exists(bias):

            shutil.copy(bias, os.path.join(

                out_anat, f"{sub_id}_{ses_id}_desc-t2BiascorrAcpc_dwi.nii.gz"))

      

        # anat: brain mask

        if os.path.exists(mask):

            shutil.copy(mask, os.path.join(

                out_anat, f"{sub_id}_{ses_id}_desc-t2BiasCorrAcpcResliced2dwi_mask.nii.gz"))  

        if not os.path.exists(mask):

            mask = os.path.join(dwi_dir, "mask.mif")      




# rm -rf /Volumes/xyu/ds006169/.pybids