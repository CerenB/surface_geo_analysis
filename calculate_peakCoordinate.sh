
#!/bin/bash
# Calculate peak coordinates within a given ROI for multiple functional maps
# Usage: ./calculate_peakCoordinate.sh <subject> <hemisphere|both> <mask_area> <task> [--dry-run]
# Example: ./calculate_peakCoordinate.sh sub-ctrl001 both area3b somatotopy --dry-run

SUBJECT="$1"      # e.g., sub-ctrl001
HEMI="$2"         # R, L, or both
MASK_AREA="$3"    # e.g., area3b
TASK="$4"         # e.g., somatotopy
SURF_DIR="$5"    # e.g., CBIG/data/templates/surface/fs_LR_32k
pvalue="$6" # e.g., p-0pt001
DRYRUN=false

if [[ "$7" == "--dry-run" ]]; then
  DRYRUN=true
  echo "Running in DRY RUN mode: will only print actions, not run commands."
fi

if [ -z "$SUBJECT" ] || [ -z "$HEMI" ] || [ -z "$MASK_AREA" ]; then
  echo "Usage: $0 <subject> <hemisphere|both> <mask_area> <task> <pvalue> [--dry-run]"
  exit 1
fi

# ROI paths
ROI_PATH="/Volumes/extreme/Cerens_files/fMRI/GlasserAtlas/Glasser_ROIs_sensorimotor"
OUTPUT_PATH="$ROI_PATH/peakCoord/task-${TASK}"

FUNC_DIR="/Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/bidspm-stats/$SUBJECT/task-${TASK}_space-T1w_FWHM-6"

# Set hemispheres to process
if [[ "$HEMI" == "both" ]]; then
  hemis=(L R)
elif [[ "$HEMI" == "L" || "$HEMI" == "R" ]]; then
  hemis=("$HEMI")
else
  echo "ERROR: HEMI must be L, R, or both"
  exit 1
fi

for HEMI in "${hemis[@]}"; do
  ROI="$ROI_PATH/combined_ROIs/${HEMI}_${MASK_AREA}.func.gii"
  # Set HEMI_LC to lh or rh
  if [[ "$HEMI" == "L" ]]; then
    HEMI_LC="lh"
  else
    HEMI_LC="rh"
  fi

  # Surface file (matching space)
  if [[ "$HEMI" == "R" ]]; then
    SURF=$SURF_DIR/fsaverage.R.midthickness_orig.32k_fs_LR.surf.gii
  else
    SURF=$SURF_DIR/fsaverage.L.midthickness_orig.32k_fs_LR.surf.gii
  fi

  # Output CSV
  combined_peak_file=$OUTPUT_PATH/${SUBJECT}_fs_LR_${pvalue}_${HEMI}_${MASK_AREA}_all_peaks_mid.csv
  echo "mask,condition,vertex,tval,x,y,z" > "$combined_peak_file"

  # Check ROI file
  if [ ! -f "$ROI" ]; then
    echo "ERROR: ROI file not found: $ROI"
    continue
  fi

  # Check output directory
  if [ ! -d "$OUTPUT_PATH" ]; then
    mkdir -p "$OUTPUT_PATH"
  fi

  # Check surface file
  if [ ! -f "$SURF" ]; then
    echo "ERROR: Surface file not found: $SURF"
    continue
  fi

  # Dynamically find functional map files
  FUNC_FILES=()
  FUNC_KEYS=()
  for func_file in "$FUNC_DIR"/${HEMI_LC}_${SUBJECT}_fs-LR-32k_*_${pvalue}.func.gii; do
    [ -e "$func_file" ] || continue
    # Extract the contrast key (e.g., Forehead, Hand, etc.)
    key=$(basename "$func_file" | sed -n "s/.*fs-LR-32k_\([A-Za-z]*\)_${pvalue}\.func\.gii/\1/p")
    FUNC_FILES+=("$func_file")
    FUNC_KEYS+=("$key")
  done

  if [ ${#FUNC_FILES[@]} -eq 0 ]; then
    echo "No functional map files found in $FUNC_DIR for $SUBJECT $HEMI"
    continue
  fi

  # Check functional map files
  for i in "${!FUNC_KEYS[@]}"; do
    key=${FUNC_KEYS[$i]}
    func=${FUNC_FILES[$i]}
    if [ ! -f "$func" ]; then
      echo "WARNING: Functional map not found for $key: $func"
    else
      echo "Found $key functional map: $func"
    fi
  done

  # now let's loop through the functional maps
  for i in "${!FUNC_KEYS[@]}"; do
    key=${FUNC_KEYS[$i]}
    func=${FUNC_FILES[$i]}
    masked_file=$OUTPUT_PATH/${HEMI}_${SUBJECT}_fs-LR_${key}_${pvalue}_${MASK_AREA}masked.func.gii

    if [ "$DRYRUN" = true ]; then
      echo "Would process:"
      echo "  Functional map: $func"
      echo "  ROI:            $ROI"
      echo "  Surface:        $SURF"
      echo "  Output masked:  $masked_file"
      echo "  Temp peak file: $OUTPUT_PATH/temp_${key}_peak.csv"
      echo "  Combined CSV:   $combined_peak_file"
      continue
    fi

    wb_command -metric-math \
      "col0 * col1" \
      "$masked_file" \
      -var col0 "$func" \
      -var col1 "$ROI"

    temp_peak_file=$OUTPUT_PATH/temp_${key}_peak.csv
    python3 extract_peaks.py \
      --metric "$masked_file" \
      --surface "$SURF" \
      --output "$temp_peak_file"

    awk -v mask="$MASK_AREA" -v cond="$key" 'NR>1 {print mask "," cond "," $0}' "$temp_peak_file" >> "$combined_peak_file"
    rm "$temp_peak_file"
  done
done


# small check point to see what values are stored inside the masked image
# wb_command -file-information $OUTPUT_PATH/${SUBJECT}_fs_LR_p0pt001_${HEMI}_${MASK_AREA}masked_hand.func.gii


# # Calculate geodesic distance between two vertices
# wb_command -surface-geodesic-distance "$SURF" $vertex1 "$OUTPUT_PATH/geodesic_distance.func.gii"


# ##### WIP ########
# # Extract peaks from the functional maps - not sure if needed anymore

# # Extract vertex index
# v1=$(tail -n +2 L_hand_peak.csv | cut -d',' -f1)
# v2=$(tail -n +2 L_tongue_peak.csv | cut -d',' -f1)

# # Get coordinates (x y z)
# coord1=$(wb_command -surface-coordinates $SURF | awk -v v=$v1 'NR==v+1')
# coord2=$(wb_command -surface-coordinates $SURF | awk -v v=$v2 'NR==v+1')

# # Break coordinates into components
# x1=$(echo $coord1 | awk '{print $1}')
# y1=$(echo $coord1 | awk '{print $2}')
# z1=$(echo $coord1 | awk '{print $3}')

# x2=$(echo $coord2 | awk '{print $1}')
# y2=$(echo $coord2 | awk '{print $2}')
# z2=$(echo $coord2 | awk '{print $3}')

# # Calculate
# dist=$(echo "scale=6; sqrt( ($x1-$x2)^2 + ($y1-$y2)^2 + ($z1-$z2)^2 )" | bc -l)
# echo "Euclidean distance: $dist mm"