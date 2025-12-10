#!/bin/bash
# what script does:

# Converts FreeSurfer surfaces (white, pial, midthickness, sphere.reg) to .surf.gii
# how to run me in terminal:
# Usage: convert_vol_to_surf.sh SURF_DIR SUBJECT TASK

SURF_DIR="$1"
SUBJECT="$2"
TASK="$3" # e.g., somatotopy
pvalue="$4" # e.g.'p-0pt001'

FUNC_DIR="/Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/bidspm-stats/$SUBJECT/task-${TASK}_space-T1w_FWHM-6"

fsLR_R_midthickness="$SURF_DIR/fsaverage.R.midthickness_orig.32k_fs_LR.surf.gii"
fsLR_L_midthickness="$SURF_DIR/fsaverage.L.midthickness_orig.32k_fs_LR.surf.gii"
fsLR_R_white="$SURF_DIR/fsaverage.R.white_orig.32k_fs_LR.surf.gii"
fsLR_L_white="$SURF_DIR/fsaverage.L.white_orig.32k_fs_LR.surf.gii"
fsLR_R_pial="$SURF_DIR/fsaverage.R.pial_orig.32k_fs_LR.surf.gii"
fsLR_L_pial="$SURF_DIR/fsaverage.L.pial_orig.32k_fs_LR.surf.gii"

# Contrast Map suffixes
pattern=$pvalue'_k-0_MC-none_spmT.nii'

found_any_file=false
for file in $FUNC_DIR/${SUBJECT}_task-*"_desc-"*"$pattern"; do
  [ -e "$file" ] || continue
  found_any_file=true
  echo "processing subject: $SUBJECT and task: $TASK"
  echo


  # Extract the task part
  filename=$(basename "$file")
  task_in_file=$(echo "$filename" | sed -n 's/^sub-[^_]*_task-\([^_]*\).*_desc-.*/\1/p')

  # If you want to match any task that starts with $TASK:
  if [[ "$task_in_file" == "$TASK"* ]]; then
    echo "Found $file"
    echo 
    # subject=$(echo "$filename" | sed -n 's/^sub-\([^_]*\)_.*$/\1/p')
    contrast=$(echo "$filename" | sed -n "s/.*desc-\([A-Za-z]*\)Gt.*_${pvalue}.*/\1/p")
    surf_R_func="$FUNC_DIR/rh_${SUBJECT}_fs-LR-32k_${contrast}_${pvalue}.func.gii"
    surf_L_func="$FUNC_DIR/lh_${SUBJECT}_fs-LR-32k_${contrast}_${pvalue}.func.gii"

    # Right hemisphere
    wb_command -volume-to-surface-mapping \
      "$file" \
      "$fsLR_R_midthickness" \
      "$surf_R_func" \
      -ribbon-constrained \
      "$fsLR_R_white" \
      "$fsLR_R_pial"

    # Left hemisphere
    wb_command -volume-to-surface-mapping \
      "$file" \
      "$fsLR_L_midthickness" \
      "$surf_L_func" \
      -ribbon-constrained \
      "$fsLR_L_white" \
      "$fsLR_L_pial"
  else
    echo "Skipping $file: task does not match $TASK"
    continue
  fi
done

if [ "$found_any_file" = false ]; then
  echo "No files found matching pattern: $FUNC_DIR/${SUBJECT}_task-*\"_desc-\"*$pattern"
fi

# Hemispheres
# hems=(lh rh)

# for subj in "${participants[@]}"; do
#   echo "Processing ${subj}"
#   subj_dir="${SUBJECTS_DIR}/${subj}/surf"

#   for hemi in "${hems[@]}"; do
#     echo "  ${hemi}: converting surfaces..."

#     # Convert FreeSurfer surfaces to GIFTI
#     mris_convert "${SUBJECTS_DIR}/${subj}/surf/${hemi}.white"       "${subj_dir}/${hemi}.white.surf.gii"
#     mris_convert "${SUBJECTS_DIR}/${subj}/surf/${hemi}.pial"        "${subj_dir}/${hemi}.pial.surf.gii"
#     mris_convert "${SUBJECTS_DIR}/${subj}/surf/${hemi}.sphere.reg"  "${subj_dir}/${hemi}.sphere.reg.surf.gii"

#     # Create midthickness (midpoint between white and pial)
#     wb_command -surface-average \
#       "${subj_dir}/${hemi}.midthickness.surf.gii" \
#       -surf "${subj_dir}/${hemi}.white.surf.gii" \
#       -surf "${subj_dir}/${hemi}.pial.surf.gii"

#     # Compute vertex area for white and pial
#     wb_command -surface-vertex-areas "${subj_dir}/${hemi}.white.surf.gii" "${subj_dir}/${hemi}.area.white.shape.gii"
#     wb_command -surface-vertex-areas "${subj_dir}/${hemi}.pial.surf.gii"  "${subj_dir}/${hemi}.area.pial.shape.gii"

#     # Compute mid-area (average of white and pial)
#     wb_command -metric-math "(a + b) / 2" \
#       "${subj_dir}/${hemi}.area.mid.shape.gii" \
#       -var a "${subj_dir}/${hemi}.area.white.shape.gii" \
#       -var b "${subj_dir}/${hemi}.area.pial.shape.gii"

#     # Now map functional data
#     for map in "${maps[@]}"; do
#       echo "    Mapping ${map}"

#       vol_input="${FUNC_DIR}/${subj}_task-somatotopy_space-T1w_${map}_MC-none_spmT.nii"
#       surf_func="${FUNC_DIR}/${hemi}.${subj}.T1w.${map}.func.gii"
#       fsavg_func="${FUNC_DIR}/${hemi}.${subj}.fsaverage.${map}.func.gii"

#       # fsaverage references
#       fsavg_sphere="${SUBJECTS_DIR}/fsaverage/surf/${hemi}.sphere.reg.surf.gii"
#       fsavg_area="${SUBJECTS_DIR}/fsaverage/surf/${hemi}.area.mid.shape.gii"

#       # Volume to surface
#       wb_command -volume-to-surface-mapping \
#         "$vol_input" \
#         "${subj_dir}/${hemi}.midthickness.surf.gii" \
#         "$surf_func" \
#         -ribbon-constrained \
#         "${subj_dir}/${hemi}.white.surf.gii" \
#         "${subj_dir}/${hemi}.pial.surf.gii"


#     done
#   done
# done