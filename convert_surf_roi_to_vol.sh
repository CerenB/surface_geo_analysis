#!/bin/bash
# Convert Glasser ROIs from fs_LR template to subject native volume
# STEP 1: Resample from fs_LR template → subject's native surface
# STEP 2: Convert native surface ROIs → volumetric masks
# Usage: bash convert_surf_roi_to_vol.sh <subject_id>
# Example: bash convert_surf_roi_to_vol.sh sub-ctrl001

subject="$1"

# Base directories
glasser_roi_dir="/Volumes/extreme/Cerens_files/fMRI/GlasserAtlas/Glasser_ROIs_sensorimotor/combined_ROIs"
fs_LR_dir="/Users/battal/Documents/GitHub/surface_geo_analysis/CBIG/data/templates/surface/fs_LR_32k"
fs_dir="/Volumes/extreme/Cerens_files/fMRI/MoebiusProject/cluster_output/Freesurfer/${subject}"
vol_roi_base="/Volumes/extreme/Cerens_files/fMRI/GlasserAtlas/Glasser_ROIs_sensorimotor/volumetric_ROIs"

# Subject-specific output directory
vol_roi_output="${vol_roi_base}/${subject}"
temp_dir="${vol_roi_output}/temp"

# Create directories
mkdir -p "$vol_roi_output"
mkdir -p "$temp_dir"

# Reference volume
ref_volume_mgz="${fs_dir}/mri/T1.mgz"
ref_volume="${fs_dir}/mri/T1.nii.gz"

# Convert mgz to nii.gz if not already done
if [[ ! -f "$ref_volume" ]]; then
  echo "Converting T1.mgz to T1.nii.gz..."
  mri_convert "$ref_volume_mgz" "$ref_volume"
fi

# Check reference volume exists
if [[ ! -f "$ref_volume" ]]; then
  echo "Error: Reference volume not found: $ref_volume"
  exit 1
fi

# Define ROI areas - matching your mask_area options
roi_areas=("area4" "area3a_3b" "area3a_3b_2_1" "sensorimotor_union")

# Define hemispheres
hemispheres=("L" "R")

echo "Processing subject: ${subject}"
echo "Output directory: ${vol_roi_output}"
echo "========================================"

for hemi in "${hemispheres[@]}"; do
  
  [[ "$hemi" == "L" ]] && HEMI_FULL="lh" || HEMI_FULL="rh"
  
  echo "Processing ${hemi} hemisphere..."
  
  # Template surfaces (fs_LR 32k)
  template_sphere="${fs_LR_dir}/fsaverage.${hemi}.sphere.32k_fs_LR.surf.gii"
  template_midthickness="${fs_LR_dir}/fsaverage.${hemi}.midthickness_orig.32k_fs_LR.surf.gii"
  
  # Native surfaces (created by create_native_surface_gii.sh)
  # These should now be in scanner coordinates if created with --to-scanner
  native_sphere_gii="${fs_dir}/surf/${HEMI_FULL}.sphere.reg.surf.gii"
  native_white_gii="${fs_dir}/surf/${HEMI_FULL}.white.surf.gii"
  native_pial_gii="${fs_dir}/surf/${HEMI_FULL}.pial.T1.surf.gii"
  native_midthickness_gii="${fs_dir}/surf/${HEMI_FULL}.midthickness.surf.gii"
  
  # Check all required surfaces exist
  missing_surfaces=()
  for surf in "$template_sphere" "$template_midthickness" "$native_sphere_gii" "$native_white_gii" "$native_pial_gii" "$native_midthickness_gii"; do
    if [[ ! -f "$surf" ]]; then
      missing_surfaces+=("$(basename $surf)")
    fi
  done
  
  if [[ ${#missing_surfaces[@]} -gt 0 ]]; then
    echo "  Error: Missing surfaces for ${hemi}: ${missing_surfaces[*]}"
    echo "  Run create_native_surface_gii.sh first!"
    continue
  fi
  
  # Process each ROI area
  for roi_area in "${roi_areas[@]}"; do
    
    input_funcgii="${glasser_roi_dir}/${hemi}_${roi_area}.func.gii"
    
    if [[ ! -f "$input_funcgii" ]]; then
      echo "  ⚠ Warning: ROI file not found: ${hemi}_${roi_area}.func.gii"
      continue
    fi
    
    echo "  Processing ${roi_area}..."
    
    # STEP 1: Resample ROI from fs_LR template to subject's native surface
    native_roi="${temp_dir}/${hemi}_${roi_area}_native.func.gii"
    
    echo "    STEP 1: Resampling to native surface..."
    wb_command -metric-resample \
      "$input_funcgii" \
      "$template_sphere" \
      "$native_sphere_gii" \
      ADAP_BARY_AREA \
      "$native_roi" \
      -area-surfs \
      "$template_midthickness" \
      "$native_midthickness_gii"
    
    if [[ $? -ne 0 ]]; then
      echo "    ✗ Failed to resample ${roi_area}"
      continue
    fi
    

    # STEP 2: Convert native surface ROI to volume
    # Now using surfaces that are in scanner coordinates (created with --to-scanner)
    output_nii="${vol_roi_output}/${hemi}_${roi_area}.nii.gz"
    
    echo "    STEP 2: Converting to volume (using scanner-aligned surfaces)..."
    
    # Run the command and capture both stdout and stderr
    wb_output=$(wb_command -metric-to-volume-mapping \
      "$native_roi" \
      "$native_white_gii" \
      "$ref_volume" \
      "$output_nii" \
      -ribbon-constrained \
      "$native_white_gii" \
      "$native_pial_gii" 2>&1)
    
    wb_exit_code=$?
    
    # Filter out the harmless warning
    filtered_output=$(echo "$wb_output" | grep -v "WARNING: Failed to parse caret volume extension")
    
    # Print any other warnings/errors
    if [[ -n "$filtered_output" ]]; then
      echo "$filtered_output"
    fi
    
    # Check if output file was actually created
    if [[ -f "$output_nii" ]]; then
      echo "    ✓ Created: ${hemi}_${roi_area}.nii.gz (in subject T1 native space)"
    else
      echo "    ✗ Failed to convert ${roi_area} to volume"
      if [[ $wb_exit_code -ne 0 ]]; then
        echo "    wb_command exit code: $wb_exit_code"
      fi
    fi
    
  done
done