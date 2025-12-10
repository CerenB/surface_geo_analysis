#!/bin/bash
# Script to create ROIs from Glasser atlas based on specified area labels
# Usage: ./makeROIs_GlassierAtlas.sh <hemisphere> <area_label>
# Example: ./makeROIs_GlassierAtlas.sh L "3a|3b"

# how to use:
# bash makeROIs_GlassierAtlas.sh L 3a|3b
# bash makeROIs_GlassierAtlas.sh R 4


path_glasser_path="/Volumes/extreme/Cerens_files/fMRI/GlasserAtlas"
parcels="$path_glasser_path/Glasser_et_al_2016_HCP_MMP1.0_v6_RVVG/Q1-Q6_RelatedParcellation210/MNINonLinear/fsaverage_LR32k/Q1-Q6_RelatedParcellation210.CorticalAreasAndSubAreas_dil_Colors_210P_Orig.32k_fs_LR.dlabel.nii"

parcel_output="$path_glasser_path/Glasser_ROIs_sensorimotor/parcels"
outdir="$path_glasser_path/Glasser_ROIs_sensorimotor/combined_ROIs"
label_file="$path_glasser_path/label_list_CorticalAreasAndSubAreas.txt"

mkdir -p "$outdir"

HEMI="$1"           # L or R
area_label="$2"     # e.g., "3", "3a", "3b", "4", "3a|3b"

if [[ "$HEMI" == "L" ]]; then
  CORTEX="LEFT"
elif [[ "$HEMI" == "R" ]]; then
  CORTEX="RIGHT"
else
  echo "ERROR: HEMI must be L or R"
  exit 1
fi


# If area_label contains a pipe (|), use it directly for regex, else match all sub-areas if just a number
if [[ "$area_label" =~ \| ]]; then
  pattern="^${HEMI}_(${area_label})_"
elif [[ "$area_label" =~ ^[0-9]+$ ]]; then
  pattern="^${HEMI}_${area_label}[a-z]?_"   # matches 3, 3a, 3b, etc.
else
  pattern="^${HEMI}_${area_label}_"
fi

# Create output roi name to save
ROI_NAME="area${area_label}"
ROI_NAME="${ROI_NAME//|/_}"   # Replace | with _ if present

# Create output directory for parcels if it doesn't exist
labels=($(grep -E "$pattern" "$label_file" | cut -d' ' -f1))

for label in "${labels[@]}"; do
  if [ -f "$parcel_output/${label}.dscalar.nii" ]; then
    echo "File $parcel_output/${label}.dscalar.nii exists, skipping creation."
  else
    echo "Extracting ROI: $label"
    wb_command -cifti-label-to-roi "$parcels" \
      "$parcel_output/${label}.dscalar.nii" \
      -map 1 \
      -name "$label"
  fi
done

# Convert dscalar files to func.gii for each hemisphere
echo "Converting ${HEMI} hemisphere dscalar files to func.gii..."
for dscalar in "$parcel_output/${HEMI}"_*.dscalar.nii; do
  base=$(basename "$dscalar")
  if [[ $base =~ $pattern ]]; then
    roi_name="${base%.dscalar.nii}"
    if [ -f "$parcel_output/${roi_name}.func.gii" ]; then
      echo "File $parcel_output/${roi_name}.func.gii exists, skipping conversion."
    else
      echo "Processing $roi_name"
      wb_command -cifti-separate "$dscalar" -metric "CORTEX_${CORTEX}" "$parcel_output/${roi_name}.func.gii" COLUMN
    fi
  else
    echo "Skipping $base (does not match pattern)"
  fi
done

# Prepare lists for hemisphere-specific func.gii files ONLY (matching the same pattern)
metric_files=()
vars=()
expr_parts=()

index=0
for func in "$parcel_output/${HEMI}"_*.func.gii; do
  base=$(basename "$func")
  if [[ $base =~ $pattern ]]; then
    metric_files+=("$func")
    vars+=("-var" "col$index" "$func")
    expr_parts+=("col$index")
    ((index++))
  else
    echo "Skipping $base (does not match pattern)"
  fi
done

if [ $index -eq 0 ]; then
  echo "No .func.gii files found for hemisphere $HEMI to merge. Exiting."
  exit 1
fi

sum_expr=$(IFS=+ ; echo "${expr_parts[*]}")

echo "Combining all ${HEMI} hemisphere func.gii files into a binary union mask..."

wb_command -metric-math "min(1, $sum_expr)" \
  "$outdir/${HEMI}_${ROI_NAME}.func.gii" \
  "${vars[@]}"



###### NEED WORK FOR THE PATHS BUT VISUALISATION
# wb_view \
#  -surface Glasser_et_al_2016_HCP_MMP1.0_v6_RVVG/Q1-Q6_RelatedParcellation210/MNINonLinear/fsaverage_LR32k/fsaverage.L.inflated.32k_fs_LR.surf.gii \
# -surface Glasser_et_al_2016_HCP_MMP1.0_v6_RVVG/Q1-Q6_RelatedParcellation210/MNINonLinear/fsaverage_LR32k/fsaverage.R.inflated.32k_fs_LR.surf.gii \
#  -surface Glasser_et_al_2016_HCP_MMP1.0_v6_RVVG/Q1-Q6_RelatedParcellation210/MNINonLinear/fsaverage_LR32k/fsaverage.L.super_inflated.32k_fs_LR.surf.gii \
#  -surface Glasser_et_al_2016_HCP_MMP1.0_v6_RVVG/Q1-Q6_RelatedParcellation210/MNINonLinear/fsaverage_LR32k/fsaverage.R.super_inflated.32k_fs_LR.surf.gii \
#  -label Glasser_et_al_2016_HCP_MMP1.0_v6_RVVG/Q1-Q6_RelatedParcellation210/MNINonLinear/fsaverage_LR32k/Q1-Q6_RelatedParcellation210.CorticalAreasAndSubAreas_dil_Colors_210P_Orig.32k_fs_LR.dlabel.nii \
#  -metric ./Glasser_ROIs_sensorimotor/L_sensorimotor_union.func.gii \
#  -metric ./Glasser_ROIs_sensorimotor/R_sensorimotor_union.func.gii