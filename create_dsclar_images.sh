#!/bin/bash
# what script does:

# Converts FreeSurfer surfaces (white, pial, midthickness, sphere.reg) to .surf.gii
# how to run me in terminal:
# Usage: create_dsclar_images.sh.sh SURF_DIR SUBJECT TASK [--dry-run]
# ./create_dsclar_images.sh.sh SURF_DIR SUBJECT TASK --dry-run

SURF_DIR="$1"
SUBJECT="$2"
TASK="$3" # e.g., somatotopy
DRYRUN=false
pvalue="$4" # e.g., p-0pt001

if [[ "$4" == "--dry-run" ]]; then
  DRYRUN=true
  echo "Running in DRY RUN mode: will only print actions, not run wb_command."
fi

FUNC_DIR="/Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/bidspm-stats/$SUBJECT/task-${TASK}_space-T1w_FWHM-6"

pattern=$pvalue'.func.gii'

found_any_file=false
for left_func_img in "$FUNC_DIR"/lh_${SUBJECT}_fs-LR-32k_*"$pattern"; do
  [ -e "$left_func_img" ] || continue
  found_any_file=true
  filename=$(basename "$left_func_img")
  contrast=$(echo "$filename" | sed -n "s/^lh_${SUBJECT}_fs-LR-32k_\([A-Za-z]*\)_${pvalue}.func.gii$/\1/p")
  if [ -z "$contrast" ]; then
    echo "Could not extract contrast from $filename, skipping."
    continue
  fi
  right_func_img="$FUNC_DIR/rh_${SUBJECT}_fs-LR-32k_${contrast}_${pvalue}.func.gii"
  output_dscalar="$FUNC_DIR/${SUBJECT}_fs-LR-32k_${contrast}_${pvalue}.dscalar.nii"

  if [ -e "$right_func_img" ]; then
    echo "Would create dscalar for $contrast:"
    echo "  Left:  $(basename "$left_func_img")"
    echo "  Right: $(basename "$right_func_img")"
    echo "  Out:   $(basename "$output_dscalar")"
    if [ "$DRYRUN" = false ]; then
      wb_command -cifti-create-dense-scalar \
        "$output_dscalar" \
        -left-metric "$left_func_img" \
        -right-metric "$right_func_img"
    fi
  else
    echo "Missing right hemisphere file for $contrast, skipping."
  fi
done

if [ "$found_any_file" = false ]; then
  echo "No left hemisphere files found matching pattern: $FUNC_DIR/lh_${SUBJECT}_fs-LR-32k_*${pattern}"
fi




