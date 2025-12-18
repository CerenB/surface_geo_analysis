#!/bin/bash
# Test different ANTs interpolation methods for sub-ctrl001
# Creates three versions: NearestNeighbor, Linear, BSpline[3]

set -e

subject="sub-ctrl001"
session="ses-001"

# Base directories
native_masks_dir="/Volumes/extreme 1/Cerens_files/fMRI/GlasserAtlas/Glasser_ROIs_sensorimotor/volumetric_ROIs/binary/${subject}"
fmriprep_anat_dir="/Volumes/extreme 1/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/fmriprep/${subject}/${session}/anat"
bidspm_anat_dir="/Volumes/extreme 1/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/bidspm-preproc/${subject}/${session}/anat"
base_output_dir="/Volumes/extreme 1/Cerens_files/fMRI/GlasserAtlas/Glasser_ROIs_sensorimotor/volumetric_MNI2009cAsym_test"

# Reference and warp
ref_mni="${bidspm_anat_dir}/${subject}_${session}_space-MNI152NLin2009cAsym_desc-preproc_T1w.nii"
warp_file="${fmriprep_anat_dir}/${subject}_${session}_from-T1w_to-MNI152NLin2009cAsym_mode-image_xfm.h5"
brain_mask="${bidspm_anat_dir}/${subject}_${session}_space-MNI152NLin2009cAsym_desc-brain_mask.nii"

# Check inputs
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

# Interpolation methods to test
methods=("nearest" "linear" "bspline")
interp_flags=("NearestNeighbor" "Linear" "BSpline[3]")

echo "Testing interpolation methods for ${subject}"
echo "=========================================="

# Get mask files
mask_files=("$native_masks_dir"/*.nii)
if [[ ${#mask_files[@]} -eq 0 || ! -f "${mask_files[0]}" ]]; then
  mask_files=("$native_masks_dir"/*.nii.gz)
fi

if [[ ${#mask_files[@]} -eq 0 || ! -f "${mask_files[0]}" ]]; then
  echo "ERROR: No mask files found in $native_masks_dir"
  exit 1
fi

echo "Found ${#mask_files[@]} mask files"
echo ""

# Process each interpolation method
for i in "${!methods[@]}"; do
  method_name="${methods[$i]}"
  interp_flag="${interp_flags[$i]}"
  output_dir="${base_output_dir}/${method_name}/${subject}"
  
  mkdir -p "$output_dir"
  
  echo "Method: ${method_name} (${interp_flag})"
  echo "Output: $output_dir"
  echo "----------------------------------------"
  
  for mask_file in "${mask_files[@]}"; do
    basename_mask=$(basename "$mask_file")
    output_mask="${output_dir}/${basename_mask}"
    
    echo "  Warping: $basename_mask"
    
    antsApplyTransforms \
      -d 3 \
      -i "$mask_file" \
      -r "$ref_mni" \
      -t "$warp_file" \
      -o "$output_mask" \
      -n "$interp_flag" 2>&1 | grep -v "^$" || true
    
    if [[ -f "$output_mask" ]]; then
      # Get intensity range
      range=$(fslstats "$output_mask" -R)
      echo "    ✓ Created (range: $range)"
      
      # For Linear and BSpline, binarize in-place (overwrite output)
      if [[ "$method_name" != "nearest" ]]; then
        base_name="${output_mask%.nii.gz}"
        base_name="${base_name%.nii}"
        tmp_bin="${base_name}_tmpbin"
        # Force uncompressed NIfTI and overwrite original with binary
        FSLOUTPUTTYPE=NIFTI fslmaths "$output_mask" -thr 0.5 -bin "$tmp_bin" -odt char
        if [[ -f "${tmp_bin}.nii" ]]; then
          mv "${tmp_bin}.nii" "$output_mask"
        elif [[ -f "${tmp_bin}.nii.gz" ]]; then
          gunzip -f "${tmp_bin}.nii.gz"
          mv "${tmp_bin}.nii" "$output_mask"
        fi
        binary_range=$(fslstats "$output_mask" -R 2>/dev/null || echo "0 0")
        echo "    ✓ Binarized in-place (range: $binary_range)"
      fi

      # Apply brain mask to zero voxels outside the brain
      FSLOUTPUTTYPE=NIFTI fslmaths "$output_mask" -mas "$brain_mask" "$output_mask" -odt char
      masked_range=$(fslstats "$output_mask" -R 2>/dev/null || echo "0 0")
      echo "    ✓ Brain-masked (range: $masked_range)"
    else
      echo "    ✗ FAILED"
    fi
  done
  
  echo ""
done

echo "=========================================="
echo "Test complete!"
echo "Compare outputs in:"
echo "  ${base_output_dir}/nearest/${subject}/"
echo "  ${base_output_dir}/linear/${subject}/"
echo "  ${base_output_dir}/bspline/${subject}/"
echo ""
echo "Cleaning up .nii.gz files..."
find "${base_output_dir}" -name "*.nii.gz" -delete
echo "✓ Deleted all .nii.gz files"
