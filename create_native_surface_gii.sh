#!/bin/bash
# Create GIFTI surface files from FreeSurfer native surfaces
# This needs to be run once per subject before ROI conversion
# Usage: bash create_native_surfaces_gii.sh <subject_id>
# Example: bash create_native_surfaces_gii.sh sub-ctrl001

subject="$1"

# FreeSurfer directory
fs_dir="/Volumes/extreme/Cerens_files/fMRI/MoebiusProject/cluster_output/Freesurfer/${subject}"

# Check if subject directory exists
if [[ ! -d "$fs_dir" ]]; then
  echo "Error: FreeSurfer directory not found for ${subject}"
  exit 1
fi

echo "Creating GIFTI surfaces for: ${subject}"
echo "========================================"

# Process both hemispheres
for hemi in lh rh; do
  
  echo "Processing ${hemi}..."
  
  # Define FreeSurfer surface files
  fs_sphere="${fs_dir}/surf/${hemi}.sphere.reg"
  fs_white="${fs_dir}/surf/${hemi}.white"
  fs_pial="${fs_dir}/surf/${hemi}.pial.T1"
  
  # Define output GIFTI files
  gii_sphere="${fs_dir}/surf/${hemi}.sphere.reg.surf.gii"
  gii_white="${fs_dir}/surf/${hemi}.white.surf.gii"
  gii_pial="${fs_dir}/surf/${hemi}.pial.T1.surf.gii"
  gii_midthickness="${fs_dir}/surf/${hemi}.midthickness.surf.gii"
  
  # Check if FreeSurfer surfaces exist
  if [[ ! -f "$fs_sphere" ]] || [[ ! -f "$fs_white" ]] || [[ ! -f "$fs_pial" ]]; then
    echo "  Error: Required FreeSurfer surfaces not found for ${hemi}"
    continue
  fi
  
  # Convert sphere.reg to GIFTI (no --to-scanner needed for sphere)
  if [[ ! -f "$gii_sphere" ]]; then
    echo "  Converting ${hemi}.sphere.reg to GIFTI..."
    mris_convert "$fs_sphere" "$gii_sphere"
    [[ $? -eq 0 ]] && echo "    ✓ Created ${hemi}.sphere.reg.surf.gii" || echo "    ✗ Failed"
  else
    echo "  ✓ ${hemi}.sphere.reg.surf.gii already exists"
  fi
  
  # Convert white surface to GIFTI with --to-scanner flag
  if [[ ! -f "$gii_white" ]]; then
    echo "  Converting ${hemi}.white to GIFTI (scanner coordinates)..."
    mris_convert --to-scanner "$fs_white" "$gii_white"
    [[ $? -eq 0 ]] && echo "    ✓ Created ${hemi}.white.surf.gii" || echo "    ✗ Failed"
  else
    echo "  ✓ ${hemi}.white.surf.gii already exists"
  fi
  
  # Convert pial surface to GIFTI with --to-scanner flag
  if [[ ! -f "$gii_pial" ]]; then
    echo "  Converting ${hemi}.pial.T1 to GIFTI (scanner coordinates)..."
    mris_convert --to-scanner "$fs_pial" "$gii_pial"
    [[ $? -eq 0 ]] && echo "    ✓ Created ${hemi}.pial.T1.surf.gii" || echo "    ✗ Failed"
  else
    echo "  ✓ ${hemi}.pial.T1.surf.gii already exists"
  fi
  
  # Create midthickness surface (average of white and pial)
  if [[ ! -f "$gii_midthickness" ]]; then
    if [[ -f "$gii_white" ]] && [[ -f "$gii_pial" ]]; then
      echo "  Creating midthickness surface..."
      wb_command -surface-average "$gii_midthickness" \
        -surf "$gii_white" \
        -surf "$gii_pial"
      [[ $? -eq 0 ]] && echo "    ✓ Created ${hemi}.midthickness.surf.gii" || echo "    ✗ Failed"
    else
      echo "    ⚠ Cannot create midthickness: white or pial GIFTI missing"
    fi
  else
    echo "  ✓ ${hemi}.midthickness.surf.gii already exists"
  fi
  
done

echo "========================================"
echo "Completed: ${subject}"
echo ""
echo "NOTE: Surfaces created in scanner RAS coordinates (aligned with T1 volume)"