import os
import re
from glob import glob
import argparse
import numpy as np
import nibabel as nib

# Parse command-line arguments
parser = argparse.ArgumentParser(description="Average .func.gii maps, preserving zeros.")
parser.add_argument("TASK", help="Task name (used in file paths)")
parser.add_argument("MASK", help="Mask name (used in file names, e.g. sensorimotor_union)")
parser.add_argument("--dry-run", action="store_true", help="Only print which files would be averaged, do not run averaging")
args = parser.parse_args()
TASK = args.TASK
MASK = args.MASK
DRY_RUN = args.dry_run

OUTPUT_PATH = f"/Volumes/extreme/Cerens_files/fMRI/GlasserAtlas/Glasser_ROIs_sensorimotor/peakCoord/task-{TASK}/"
file_pattern = os.path.join(OUTPUT_PATH, f"tmp_sub-*_{MASK}_*.func.gii")

groups = ["ctrl", "mbs"]
hemis = ["L", "R"]
conditions = ["Hand", "Foot", "Forehead", "Lips", "Tongue"]


for group in groups:
    for hemi in hemis:
        for cond in conditions:
            files = []
            for fname in glob(file_pattern):
                m = re.match(
                    rf'tmp_(sub-[a-z]+[0-9]+)_([LR])_{re.escape(MASK)}_([A-Za-z]+)_(\d+)\.func\.gii',
                    os.path.basename(fname)
                )
                if m:
                    subject, h, condition, vertex = m.groups()
                    g = "ctrl" if "ctrl" in subject else "mbs"
                    if g == group and h == hemi and condition == cond:
                        files.append(fname)
            if len(files) == 0:
                continue

            print(f"\n[{group} | {cond} | {hemi} | {MASK}] Averaging the following files ({len(files)}):")
            for f in files:
                print(f"  {f}")

            avg_out = os.path.join(OUTPUT_PATH, f"{group}_{cond}_{hemi}_{MASK}_avg.func.gii")
            print(f"Would create: {avg_out}")

            if DRY_RUN:
                continue

            # Load all data
            data_list = []
            zero_indices = []
            for f in files:
                gii = nib.load(f)
                arr = gii.darrays[0].data
                data_list.append(arr)
                # Find the zero index for this subject
                zero_idx = np.where(arr == 0)[0]
                zero_indices.append(zero_idx)

            print(f"Zero indices for {cond}: {zero_indices}")
            data_stack = np.vstack(data_list)  # shape: (n_files, n_vertices)

            # Compute mean ignoring zeros
            with np.errstate(invalid='ignore'):
                data_stack_nan = np.where(data_stack == 0, np.nan, data_stack)
                avg = np.nanmean(data_stack_nan, axis=0)

            # Assign -200 to any vertex that was zero in any input
            zero_mask = np.any(data_stack == 0, axis=0)
            avg[zero_mask] = -200

            # Save as new func.gii
            new_gii = nib.gifti.GiftiImage(darrays=[nib.gifti.GiftiDataArray(avg.astype(np.float32))])
            nib.save(new_gii, avg_out)
            print(f"Created: {avg_out}")  

for hemi in hemis:
    for cond in conditions:
        ctrl_avg = os.path.join(OUTPUT_PATH, f"ctrl_{cond}_{hemi}_{MASK}_avg.func.gii")
        mbs_avg = os.path.join(OUTPUT_PATH, f"mbs_{cond}_{hemi}_{MASK}_avg.func.gii")
        out_diff = os.path.join(OUTPUT_PATH, f"ctrl_gt_mbs_{cond}_{hemi}_{MASK}_avg.func.gii")
        if os.path.exists(ctrl_avg) and os.path.exists(mbs_avg):
            ctrl_gii = nib.load(ctrl_avg)
            mbs_gii = nib.load(mbs_avg)
            ctrl_data = ctrl_gii.darrays[0].data
            mbs_data = mbs_gii.darrays[0].data

            # ctrl - mbs
            diff = ctrl_data - mbs_data
            new_gii = nib.gifti.GiftiImage(darrays=[nib.gifti.GiftiDataArray(diff.astype(np.float32))])
            nib.save(new_gii, out_diff)
            print(f"Created: {out_diff}")
        else:
            print(f"Missing file for subtraction: {ctrl_avg} or {mbs_avg}")