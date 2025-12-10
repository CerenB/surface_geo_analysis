import pandas as pd
import subprocess
import nibabel as nib
import os
import itertools
import sys
import re

SURFACE_PATH = "/Users/battal/Documents/GitHub/surface_geo_analysis/CBIG/data/templates/surface/fs_LR_32k"

def get_surface_file(hemi):
    if hemi == "R":
        return os.path.join(SURFACE_PATH, "fsaverage.R.midthickness_orig.32k_fs_LR.surf.gii")
    else:
        return os.path.join(SURFACE_PATH, "fsaverage.L.midthickness_orig.32k_fs_LR.surf.gii")

def calc_geodesic_distance(surf_file, vertex1, vertex2, tmp_out):
    subprocess.run([
        "wb_command", "-surface-geodesic-distance",
        surf_file, str(vertex1), tmp_out
    ], check=True)
    metric = nib.load(tmp_out)
    distances = metric.darrays[0].data
    return float(distances[vertex2])

def extract_pvalue_area_from_filename(filename):
    # Matches e.g. p-0pt990_area4 or p-0pt001_area3a_3b_2_1
    m = re.search(r'(p-0pt[0-9]+(?:_[a-zA-Z0-9_]+)*)_all_peaks_mid\.csv', filename)
    if m:
        return m.group(1)
    else:
        return "unknown"

def main():
    if len(sys.argv) < 3:
        print("Usage: python calculate_geodesic_distances_from_csv.py <input_csv_filename> <TASK>")
        sys.exit(1)
    input_csv_filename = sys.argv[1]
    TASK = sys.argv[-1]  # Always take the last argument as TASK

    OUTPUT_PATH = f"/Volumes/extreme/Cerens_files/fMRI/GlasserAtlas/Glasser_ROIs_sensorimotor/peakCoord/task-{TASK}/"
    input_csv = os.path.join(OUTPUT_PATH, input_csv_filename)
    
    pval_area = extract_pvalue_area_from_filename(os.path.basename(input_csv))
    output_csv = os.path.join(OUTPUT_PATH, f"geodesic_distance_{pval_area}.csv")

    df = pd.read_csv(input_csv)
    print("Unique conditions in CSV:", df['condition'].unique())
    results = []

    for (sub, group, hemi, mask), group_df in df.groupby(["sub", "group", "hemi", "mask"]):
        cond_verts = group_df.set_index("condition")["vertex"].to_dict()
        print(f"{sub} {group} {hemi} {mask} cond_verts: {cond_verts}")
        conds = list(cond_verts.keys())
        for cond1, cond2 in itertools.combinations(conds, 2):
            v1 = int(cond_verts[cond1])
            v2 = int(cond_verts[cond2])
            surf_file = get_surface_file(hemi)
            tmp_metric = os.path.join(OUTPUT_PATH, f"tmp_{sub}_{hemi}_{mask}_{cond1}_{v1}.func.gii")
            skip = 1 if v1 == 0 or v2 == 0 else 0
            dist = None
            if not skip:
                try:
                    dist = calc_geodesic_distance(surf_file, v1, v2, tmp_metric)
                except Exception as e:
                    print(f"Error for {sub} {hemi} {mask} {cond1}-{cond2}: {e}")
            results.append({
                "sub": sub,
                "group": group,
                "hemi": hemi,
                "mask": mask,
                "pairs": f"{cond1}-{cond2}",
                "vertex1": v1,
                "vertex2": v2,
                "geodesic_distance": dist,
                "skip": skip
            })
            # if os.path.exists(tmp_metric):
            #     os.remove(tmp_metric)
                # After the pairwise combinations loop
        for cond, v in cond_verts.items():
            surf_file = get_surface_file(hemi)
            tmp_metric = os.path.join(OUTPUT_PATH, f"tmp_{sub}_{hemi}_{mask}_{cond}_{v}.func.gii")
            if not os.path.exists(tmp_metric) and v != 0:
                try:
                    # Compute geodesic distance from this vertex to all others (output is tmp_metric)
                    subprocess.run([
                        "wb_command", "-surface-geodesic-distance",
                        surf_file, str(v), tmp_metric
                    ], check=True)
                    print(f"Created single-peak metric: {tmp_metric}")
                except Exception as e:
                    print(f"Error creating single-peak metric for {sub} {hemi} {mask} {cond}: {e}")
    out_df = pd.DataFrame(results)
    out_df.to_csv(output_csv, index=False)
    print(f"Saved geodesic distances to {output_csv}")

if __name__ == "__main__":
    main()