#!/bin/bash

# what script does
# For each participant:
# Converts FreeSurfer surfaces (white, pial, midthickness, sphere.reg) to .surf.gii
# Computes vertex areas → area.white, area.pial, then averages them to create area.mid.shape.gii
# Runs wb_command -volume-to-surface-mapping
# Runs wb_command -metric-resample to fsaverage


#  how to run me in terminal
# chmod +x batch_surface_project_with_conversion.sh
# ./batch_surface_project_with_conversion.sh

# Base directories
SUBJECTS_DIR="/Volumes/extreme/Cerens_files/fMRI/MoebiusProject/cluster_output/Freesurfer"
FUNC_DIR="/Volumes/extreme/Cerens_files/fMRI/MoebiusProject/cluster_output/stats/task-somatotopy_space-T1w_FWHM-6"

# Participants
participants=(sub-ctrl{001..017} mbs-{001..007})

# Map suffixes
maps=(
  "desc-HandGtAll_p-0pt001_k-0"
  "desc-HandLtAll_p-0pt001_k-0"
  "desc-HandRtAll_p-0pt001_k-0"
  "desc-HandGtFoot_p-0pt001_k-0"
  "desc-HandGtFace_p-0pt001_k-0"
)

# Hemispheres
hems=(lh rh)

for subj in "${participants[@]}"; do
  echo "Processing ${subj}"
  subj_dir="${SUBJECTS_DIR}/${subj}/surf"

  for hemi in "${hems[@]}"; do
    echo "  ${hemi}: converting surfaces..."

    # Convert FreeSurfer surfaces to GIFTI
    mris_convert "${SUBJECTS_DIR}/${subj}/surf/${hemi}.white"       "${subj_dir}/${hemi}.white.surf.gii"
    mris_convert "${SUBJECTS_DIR}/${subj}/surf/${hemi}.pial"        "${subj_dir}/${hemi}.pial.surf.gii"
    mris_convert "${SUBJECTS_DIR}/${subj}/surf/${hemi}.sphere.reg"  "${subj_dir}/${hemi}.sphere.reg.surf.gii"

    # Create midthickness (midpoint between white and pial)
    wb_command -surface-average \
      "${subj_dir}/${hemi}.midthickness.surf.gii" \
      -surf "${subj_dir}/${hemi}.white.surf.gii" \
      -surf "${subj_dir}/${hemi}.pial.surf.gii"

    # Compute vertex area for white and pial
    wb_command -surface-vertex-areas "${subj_dir}/${hemi}.white.surf.gii" "${subj_dir}/${hemi}.area.white.shape.gii"
    wb_command -surface-vertex-areas "${subj_dir}/${hemi}.pial.surf.gii"  "${subj_dir}/${hemi}.area.pial.shape.gii"

    # Compute mid-area (average of white and pial)
    wb_command -metric-math "(a + b) / 2" \
      "${subj_dir}/${hemi}.area.mid.shape.gii" \
      -var a "${subj_dir}/${hemi}.area.white.shape.gii" \
      -var b "${subj_dir}/${hemi}.area.pial.shape.gii"

    # Now map functional data
    for map in "${maps[@]}"; do
      echo "    Mapping ${map}"

      vol_input="${FUNC_DIR}/${subj}_task-somatotopy_space-T1w_${map}_MC-none_spmT.nii"
      surf_func="${FUNC_DIR}/${hemi}.${subj}.T1w.${map}.func.gii"
      fsavg_func="${FUNC_DIR}/${hemi}.${subj}.fsaverage.${map}.func.gii"

      # fsaverage references
      fsavg_sphere="${SUBJECTS_DIR}/fsaverage/surf/${hemi}.sphere.reg.surf.gii"
      fsavg_area="${SUBJECTS_DIR}/fsaverage/surf/${hemi}.area.mid.shape.gii"

      # Volume to surface
      wb_command -volume-to-surface-mapping \
        "$vol_input" \
        "${subj_dir}/${hemi}.midthickness.surf.gii" \
        "$surf_func" \
        -ribbon-constrained \
        "${subj_dir}/${hemi}.white.surf.gii" \
        "${subj_dir}/${hemi}.pial.surf.gii"

      # Surface resample to fsaverage
      wb_command -metric-resample \
        "$surf_func" \
        "${subj_dir}/${hemi}.sphere.reg.surf.gii" \
        "$fsavg_sphere" \
        ADAP_BARY_AREA \
        "$fsavg_func" \
        -area-metrics \
        "${subj_dir}/${hemi}.area.mid.shape.gii" \
        "$fsavg_area"
    done
  done
done
