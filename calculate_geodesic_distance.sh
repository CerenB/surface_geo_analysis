#!/bin/bash

# Usage: ./calculate_geodesic_distance.sh <subject> <hemisphere> <mask_area> <vertex1> <vertex2>

SUBJECT="$1"
HEMI="$2"
MASK_AREA="$3"
vertex1="$4"
vertex2="$5"

# Check if all arguments are provided
if [ -z "$SUBJECT" ] || [ -z "$HEMI" ] || [ -z "$MASK_AREA" ] || [ -z "$vertex1" ] || [ -z "$vertex2" ]; then
  echo "Usage: $0 <subject> <hemisphere> <mask_area> <vertex1> <vertex2>"
  exit 1
fi

OUTPUT_PATH="/Volumes/extreme/Cerens_files/fMRI/GlasserAtlas/Glasser_ROIs_sensorimotor/peakCoord"

# Surface file
SURFACE_PATH="/Users/battal/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k"
if [[ "$HEMI" == "R" ]]; then
  SURF=$SURFACE_PATH/fsaverage.R.midthickness_orig.32k_fs_LR.surf.gii
else
  SURF=$SURFACE_PATH/fsaverage.L.midthickness_orig.32k_fs_LR.surf.gii
fi

# Calculate geodesic distance
wb_command -surface-geodesic-distance "$SURF" $vertex1 "$OUTPUT_PATH/geodesic_distance.func.gii"

# add python script to calculate the distance
# This will read the geodesic distance file and print the distance for vertex2
python3 <<EOF
import nibabel as nib
metric = nib.load('$OUTPUT_PATH/geodesic_distance.func.gii')
distances = metric.darrays[0].data
print(distances[$vertex2])
EOF

# next make this script with for loop, across different conditions and participant. or hemispheres
# analyse the feet spmT maps
# do another subject-ctrl002 and see all good. Then automate this script for all subjects and hemispheres
# and then make a python script to read the geodesic distance file and plot the distances 
# maybe then run stats on the distances
# and then plot the distances for each condition pairs (e.g. hand - feet, hand -lips, etc.)