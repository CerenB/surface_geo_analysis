import os
import re
from glob import glob
import argparse
import subprocess
import numpy as np
import nibabel as nib

# Parse command-line arguments
parser = argparse.ArgumentParser(description="Average .func.gii maps using wb_command, preserving structure for Workbench.")
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

            # Use wb_command -metric-math for averaging
            var_args = []
            var_names = []
            for i, f in enumerate(files):
                var_name = chr(65 + i)  # A, B, C, ...
                var_args += ["-var", var_name, f]
                var_names.append(var_name)
            expr = "(" + "+".join(var_names) + f")/{len(var_names)}"

            subprocess.run(
                ["wb_command", "-metric-math", expr, avg_out] + var_args,
                check=True
            )
            print(f"Created (wb_command): {avg_out}")

            # Optionally, set -200 at any vertex that was zero in any input
            # (This step uses nibabel and may lose some metadata, but is optional)
            data_list = []
            for f in files:
                gii = nib.load(f)
                arr = gii.darrays[0].data
                data_list.append(arr)
            data_stack = np.vstack(data_list)
            zero_mask = np.any(data_stack == 0, axis=0)
            if np.any(zero_mask):
                avg_gii = nib.load(avg_out)
                avg_data = avg_gii.darrays[0].data.copy()
                avg_data[zero_mask] = -200
                new_gii = nib.gifti.GiftiImage(darrays=[nib.gifti.GiftiDataArray(avg_data.astype(np.float32))])
                nib.save(new_gii, avg_out)
                print(f"Set -200 at zero vertices in: {avg_out}")

# Subtraction: ctrl - mbs
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