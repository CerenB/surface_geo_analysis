# Extract peak vertices (by looking aty the t-value) and coordinates from a metric according to the surface file.
# Choice of surface file can change the coordinates. 
# 
import nibabel as nib
import numpy as np
import argparse
import os

parser = argparse.ArgumentParser(description="Extract peak vertices and coordinates from a metric and surface file.")
parser.add_argument("--metric", required=True, help="Path to .func.gii metric file")
parser.add_argument("--surface", required=True, help="Path to .surf.gii surface file")
parser.add_argument("--output", required=True, help="Path to output CSV file")
args = parser.parse_args()

# Load metric
metric = nib.load(args.metric)
tvals = metric.darrays[0].data

# Load surface for coordinates
surf = nib.load(args.surface)
coords = surf.darrays[0].data

# Find nonzero, non-NaN vertices
valid_idx = np.where((tvals != 0) & (~np.isnan(tvals)))[0]

# Prepare output: vertex, tval, x, y, z
out = np.column_stack((valid_idx, tvals[valid_idx], coords[valid_idx]))

# Sort by t-value (column 1) in descending order
out_sorted = out[out[:, 1].argsort()[::-1]]

# Save sorted CSV
if out_sorted.shape[0] > 0:
    np.savetxt(args.output, out_sorted, delimiter=",", header="vertex,tval,x,y,z", comments="", fmt=["%d", "%.6f", "%.6f", "%.6f", "%.6f"])
    print(f"Saved {len(valid_idx)} vertices to {args.output}")
else:
    np.savetxt(args.output, np.array([[0, 0, 0, 0, 0]]), delimiter=",", header="vertex,tval,x,y,z", comments="", fmt=["%d", "%.6f", "%.6f", "%.6f", "%.6f"])
    print(f"Saved 0 vertices to {args.output}")
    print("No peaks found in this metric.")