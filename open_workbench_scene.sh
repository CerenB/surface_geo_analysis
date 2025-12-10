#!/bin/bash
# Open Workbench with surface and functional maps
# Usage: bash open_workbench_scene.sh

# Paths
SURF_DIR="$HOME/Documents/GitHub/surface_geo_analysis/CBIG/data/templates/surface/fs_LR_32k"
FUNC_DIR="/Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/bidspm-stats/sub-ctrl001/task-mototopy_space-T1w_FWHM-6"

# Surface files
L_MIDTHICKNESS="$SURF_DIR/fsaverage.L.midthickness_orig.32k_fs_LR.surf.gii"
R_MIDTHICKNESS="$SURF_DIR/fsaverage.R.midthickness_orig.32k_fs_LR.surf.gii"

# Functional maps
L_FUNC_1="$FUNC_DIR/lh_sub-ctrl001_fs-LR-32k_Tongue_p-0pt001.func.gii"
L_FUNC_2="$FUNC_DIR/lh_sub-ctrl001_fs-LR-32k_Tongue_p-0pt990.func.gii"
R_FUNC_1="$FUNC_DIR/rh_sub-ctrl001_fs-LR-32k_Tongue_p-0pt001.func.gii"
R_FUNC_2="$FUNC_DIR/rh_sub-ctrl001_fs-LR-32k_Tongue_p-0pt990.func.gii"

# Check if files exist
for file in "$L_MIDTHICKNESS" "$R_MIDTHICKNESS" "$L_FUNC_1" "$L_FUNC_2" "$R_FUNC_1" "$R_FUNC_2"; do
  if [ ! -f "$file" ]; then
    echo "ERROR: File not found: $file"
    exit 1
  fi
done

# Open Workbench with the surface and functional maps
# The -surface-load-secondary loads functional data onto the surface
wb_view \
  "$L_MIDTHICKNESS" \
  "$L_FUNC_1" \
  "$L_FUNC_2" \
  "$R_MIDTHICKNESS" \
  "$R_FUNC_1" \
  "$R_FUNC_2" &

echo "Workbench opened in the background"

# Alternative: Load all on left hemisphere only
# wb_view \
#   "$L_MIDTHICKNESS" \
#   "$L_FUNC_1" \
#   "$L_FUNC_2"
