#!/bin/bash
# Warp subject-specific native Glasser ROI masks to MNI152NLin2009cAsym space
# Uses subject's T1w→MNI2009cAsym warp from fmriprep
# STEP 1: Read native T1w binary masks
# STEP 2: Apply subject's ANTs warp to MNI2009cAsym
# Default interpolation: NearestNeighbor (safe for labels)
# Optional: BSpline (smooth) then re-binarize after warp+mask
# Usage: bash warp_native_masks_to_mni.sh <subject_id> [interp]
#   interp: NearestNeighbor (default) | Linear | BSpline
# Example: bash warp_native_masks_to_mni.sh sub-ctrl001

set -e

subject="$1"
interp="${2:-NearestNeighbor}"

if [[ -z "$subject" ]]; then
  echo "Usage: bash warp_native_masks_to_mni.sh <subject_id> [interp]"
  echo "  interp: NearestNeighbor (default) | BSpline"
  echo "Example: bash warp_native_masks_to_mni.sh sub-ctrl001"
  exit 1
fi

# Normalize interp option for antsApplyTransforms
case "$interp" in
  NearestNeighbor|nn|nearest|NEAREST|Nearest)
    interp_flag="NearestNeighbor"
    method="nearest"
    do_binarize=0
    ;;
  Linear|linear|LINear)
    interp_flag="Linear"
    method="linear"
    do_binarize=1
    ;;
  BSpline|bspline|BSPLINE|BSpline[3])
    interp_flag="BSpline[3]"
    method="bspline"
    do_binarize=1
    ;;
  *)
    echo "ERROR: Unknown interp option: $interp"
    echo "       Use NearestNeighbor, Linear or BSpline"
    exit 1
    ;;
esac

# Determine session based on subject ID
case "$subject" in
  sub-ctrl003|sub-ctrl004|sub-ctrl005|sub-ctrl006|sub-ctrl007|sub-ctrl008|sub-ctrl009|sub-ctrl010|sub-ctrl011|sub-ctrl012|sub-ctrl014)
    session="ses-002"
    ;;
  sub-ctrl015)
    session="ses-003"
    ;;
  sub-mbs004|sub-mbs005|sub-mbs006|sub-mbs007)
    session="ses-002"
    ;;
  *)
    session="ses-001"
    ;;
esac

# Base directories
native_masks_dir="/Volumes/extreme/Cerens_files/fMRI/GlasserAtlas/Glasser_ROIs_sensorimotor/volumetric_ROIs/binary/${subject}"
fmriprep_anat_dir="/Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/fmriprep/${subject}/${session}/anat"
bidspm_anat_dir="/Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/bidspm-preproc/${subject}/${session}/anat"
output_dir_base="/Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/cosmoMvpa/roi/glasser/volumetric_MNI2009cAsym"

# Create output directory: base/method/subject
output_dir="$output_dir_base/$method/$subject"
mkdir -p "$output_dir"

# Reference volume in MNI2009cAsym space (from bidspm-preproc)
ref_mni="${bidspm_anat_dir}/${subject}_${session}_space-MNI152NLin2009cAsym_desc-preproc_T1w.nii"
# Brain mask in MNI2009cAsym space (from bidspm-preproc)
brain_mask="${bidspm_anat_dir}/${subject}_${session}_space-MNI152NLin2009cAsym_desc-brain_mask.nii"

# ANTs warp from T1w to MNI2009cAsym (from fmriprep)
warp_file="${fmriprep_anat_dir}/${subject}_${session}_from-T1w_to-MNI152NLin2009cAsym_mode-image_xfm.h5"

echo "Processing subject: ${subject} (${session})"
echo "Native masks: $native_masks_dir"
echo "Warp file: $warp_file"
echo "Reference: $ref_mni"
echo "Brain mask: $brain_mask"
echo "Interpolation: $interp_flag"
echo "Output directory: $output_dir"
echo "=========================================="

# Check inputs
if [[ ! -d "$native_masks_dir" ]]; then
  echo "ERROR: Native masks directory not found: $native_masks_dir"
  exit 1
fi

if [[ ! -f "$warp_file" ]]; then
  echo "ERROR: Warp file not found: $warp_file"
  exit 1
fi

if [[ ! -f "$ref_mni" ]]; then
  echo "ERROR: Reference volume not found: $ref_mni"
  exit 1
fi

if [[ ! -f "$brain_mask" ]]; then
  echo "ERROR: Brain mask not found: $brain_mask"
  exit 1
fi

# Get all binary mask files (.nii or .nii.gz)
mask_files=("$native_masks_dir"/*.nii)
if [[ ${#mask_files[@]} -eq 0 || ! -f "${mask_files[0]}" ]]; then
  mask_files=("$native_masks_dir"/*.nii.gz)
fi

if [[ ${#mask_files[@]} -eq 0 || ! -f "${mask_files[0]}" ]]; then
  echo "ERROR: No mask files found in $native_masks_dir"
  exit 1
fi

echo "Found ${#mask_files[@]} mask files"
echo "=========================================="

# Process each mask
for mask_file in "${mask_files[@]}"; do
  basename_mask=$(basename "$mask_file")
  
  # Define output filename
  output_mask="${output_dir}/${basename_mask}"
  
  echo "Warping: $basename_mask"
  echo "  Input:  $mask_file"
  echo "  Output: $output_mask"
  
  # Apply warp using antsApplyTransforms
  # -d 3: 3D image
  # -i: input (moving) image
  # -r: reference image
  # -t: transform (warp file)
  # -o: output image
  # -n: interpolation (NearestNeighbor or BSpline[3])
  antsApplyTransforms \
    -d 3 \
    -i "$mask_file" \
    -r "$ref_mni" \
    -t "$warp_file" \
    -o "$output_mask" \
    -n "$interp_flag"
  
  if [[ ! -f "$output_mask" ]]; then
    echo "  ✗ FAILED to warp mask"
    continue
  fi

  # Apply brain mask: zero outside-brain voxels, force char dtype, keep .nii
  FSLOUTPUTTYPE=NIFTI fslmaths "$output_mask" -mas "$brain_mask" "$output_mask" -odt char

  # If BSpline interpolation was used, re-binarize to clean label values
  if [[ $do_binarize -eq 1 ]]; then
    FSLOUTPUTTYPE=NIFTI fslmaths "$output_mask" -thr 0.5 -bin "$output_mask" -odt char
  fi
  
  # Report intensity range
  range=$(fslstats "$output_mask" -R 2>/dev/null || echo "0 0")
  echo "  ✓ Finalized (range: $range)"
  
done

echo ""
echo "=========================================="
echo "Warping complete!"
echo "Output directory: $output_dir"
echo "Folders use method/subject structure under:"
echo "  $output_dir_base/{nearest|linear|bspline}/$subject/"
ls -lh "$output_dir"/*.nii* 2>/dev/null || echo "No .nii files created"
