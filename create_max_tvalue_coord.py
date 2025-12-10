# usage python3 summarize_max_peaks.py left.csv right.csv
# Summarize maximum peaks from multiple CSV files
# This script reads multiple CSV files containing peak data, 
# extracts the maximum peak for each condition and mask area, and saves a summary to a new CSV file.

# python3 create_max_tvalue_coord.py area3a_3b_all_peaks_mid

import pandas as pd
import os
import re
import sys
import glob


def get_sub_group_hemi(filename):
    m = re.search(r'(sub-[^_]+)', filename)
    sub = m.group(1) if m else "unknown"
    group = sub.split('-')[1][:-3] if '-' in sub else "unknown"
    hemi = "L" if "_L_" in filename else ("R" if "_R_" in filename else "unknown")
    return sub, group, hemi

def process_peak_file(filepath):
    df = pd.read_csv(filepath)
    sub, group, hemi = get_sub_group_hemi(os.path.basename(filepath))
    results = []
    for cond in df['condition'].unique():
        cond_df = df[df['condition'] == cond]
        for mask in cond_df['mask'].unique():
            mask_df = cond_df[cond_df['mask'] == mask]
            peak_row = mask_df.loc[mask_df['tval'].idxmax()]
            results.append({
                'sub': sub,
                'group': group,
                'hemi': hemi,
                'condition': cond,
                'mask': mask,
                'vertex': int(peak_row['vertex']),
                'tval': peak_row['tval'],
                'x': peak_row['x'],
                'y': peak_row['y'],
                'z': peak_row['z']
            })
    return results

if __name__ == "__main__":
    # Usage: python create_max_tvalue_coord.py <TASK> [<pvalue>] <area_pattern> [--dry-run]
    if len(sys.argv) < 3:
        print("Usage: python create_max_tvalue_coord.py <TASK> [<pvalue>] <area_pattern> [--dry-run]")
        sys.exit(1)

    TASK = sys.argv[1]
    FOLDER = f"/Volumes/extreme/Cerens_files/fMRI/GlasserAtlas/Glasser_ROIs_sensorimotor/peakCoord/task-{TASK}/"

    # Default p-value if not given
    if len(sys.argv) == 3 or (len(sys.argv) > 3 and sys.argv[2].startswith("area")):
        pattern1 = "p-0pt001"
        pattern2 = sys.argv[2]
        arg_offset = 3
    else:
        pattern1 = sys.argv[2]
        pattern2 = sys.argv[3]
        arg_offset = 4

    dry_run = False
    if len(sys.argv) > arg_offset and sys.argv[arg_offset] == "--dry-run":
        dry_run = True

    search_pattern = os.path.join(FOLDER, f"sub*{pattern1}_*_{pattern2}.csv")
    files = glob.glob(search_pattern)
    output_path = os.path.join(FOLDER, f"max_tvalue_vertices_{pattern1}_{pattern2}.csv")

    if not files:
        print(f"No files found for pattern: {pattern1} and {pattern2} in {FOLDER}")
        sys.exit(1)

    print("Matched CSV files:")
    for f in files:
        print("  " + os.path.basename(f))
    print(f"Output file would be: {os.path.basename(output_path)}")

    if dry_run:
        print("Dry run mode: No files will be processed or written.")
        sys.exit(0)

    all_results = []
    for csv_file in files:
        if csv_file == output_path:
            continue  # Skip the output file itself
        all_results.extend(process_peak_file(csv_file))

    summary_df = pd.DataFrame(all_results)
    summary_df.to_csv(output_path, index=False)
    print(f"Saved summary to {output_path}")