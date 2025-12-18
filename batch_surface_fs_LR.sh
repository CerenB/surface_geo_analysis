#!/bin/bash

# what script should do
# 
# Converts FreeSurfer surfaces to .surf.gii in fs_LR space
# Computes vertex areas → area.white, area.pial, then averages them to create area.mid.shape.gii
# Runs wb_command -volume-to-surface-mapping


#  how to run me in terminal
# chmod +x batch_surface_project_with_conversion.sh
# ./batch_surface_project_with_conversion.sh

# current directory
cd /Users/battal/Documents/GitHub/surface_geo_analysis/

# Base directories
SURF_DIR="CBIG/data/templates/surface/fs_LR_32k/"
TASK='somatotopy'  # 'somatotopy' or 'mototopy'

# Participants
# somatotopy 
# participants=(sub-ctrl{001..005} sub-ctrl{007..013} sub-ctrl{015..017} sub-mbs{001..007})
# sub-ctrl0014 is mototopy only
participants=(sub-ctrl{001..005} sub-ctrl{007..017} sub-mbs{001..007})



# STEP 1: Convert volumetric contrasts to surface
# call a function for converting all contrasts spmT.nii into func.gii
for subj in "${participants[@]}"; do
  ./convert_vol_to_surf.sh "$SURF_DIR" "$subj" "$TASK" "$pvalue"
done

# STEP 2: Create dsclar images from func.gii files
# chmod +x create_dsclar_images.sh - to make it executable from terminal - do this only once
#   ./create_dsclar_images.sh "$SURF_DIR" "$subj" "$TASK" --dry-run
# now let's create dsclar .nii images for analytic calculations
for subj in "${participants[@]}"; do
  ./create_dsclar_images.sh "$SURF_DIR" "$subj" "$TASK" "$pvalue"
done



# # STEP 3: Create ROIs for the glassier atlas areas 
# # # create the glassier mask ROIs
# # # first we need to extract the relevant labels from the label file
# # # then create the ROIs using the bash script makeROIs_GlassierAtlas.sh
# cd /Volumes/extreme/Cerens_files/fMRI/GlasserAtlas
# wb_command -cifti-label-export-table \
# Glasser_et_al_2016_HCP_MMP1.0_v6_RVVG/Q1-Q6_RelatedParcellation210/MNINonLinear/fsaverage_LR32k/Q1-Q6_RelatedParcellation210.CorticalAreasAndSubAreas_dil_Colors_210P_Orig.32k_fs_LR.dlabel.nii \
# 1 \
# label_list_CorticalAreasAndSubAreas.txt

# # grep -E "L_4_|L_3a_|L_3b_|L_2_|L_1_|R_4_|R_3a_|R_3b_|R_2_|R_1_" label_list_CorticalAreasAndSubAreas.txt
# grep -E "L_3a_|L_3b_|L_2_|L_1_|R_3a_|R_3b_|R_2_|R_1_" label_list_CorticalAreasAndSubAreas.txt

# # # now use the bash script for ROI making:
# cd /Users/battal/Documents/GitHub/surface_geo_analysis/
# bash makeROIs_GlassierAtlas.sh L "3a|3b|2|1"
# bash makeROIs_GlassierAtlas.sh R "3a|3b|2|1"


# STEP 4: Calculate peak coordinates within a given ROI across multiple functional maps
# and output all the vertices into a .csv file
# bash calculate_peakCoordinate.sh <subject> <hemisphere> <mask_area>

# define the p-value threshold
pvalue='p-0pt990' # e.g., p-0pt001, p-0pt990
echo $pvalue

# define the mask area
mask_area='sensorimotor_union' # e.g., area4, area3a_3b, area3a_3b_2_1, sensorimotor_union
echo $mask_area

# loop through all subjects and calculate the peak coordinates
# it does it by finding the contrast maps in the func folder and multiples it with the mask
# then write down all the peak coordinates in a .csv file
# then we will find the max t-value coordinate in the .csv file using a python script
# and write it down in a separate .csv file
for subj in "${participants[@]}"; do
  # for somatotopy'
  # bash calculate_peakCoordinate.sh "$subj" both "$mask_area" "$TASK" "$SURF_DIR" "$pvalue" --dry-run
  # for mototopy
  bash calculate_peakCoordinate.sh "$subj" both "$mask_area" "$TASK" "$SURF_DIR" "$pvalue"
done



# STEP 5: Find the max t-values in the region of interest/masks
# and output the max t-value coordinate into a .csv file
python3 create_max_tvalue_coord.py "$TASK" "$pvalue" "$mask_area"_all_peaks_mid


# STEP 6: Calculate geodesic distances between the peak coordinates
# for this step, we need to read the vertex across condition pairs and hemispheres
# then run the geodesic distance calculation
inputfile="max_tvalue_vertices_${pvalue}_${mask_area}_all_peaks_mid.csv"
echo $inputfile
python3 calculate_geodesic_distances_from_csv.py "$inputfile" "$TASK"





# r script to plot the distances
# read from the latest created .csv file: geodesic_distance_areas3a_3b.csv
Rscript plotGeoDist.R #- WIP


# r script to plot the t-values and the coordinates


# bash or py script for overlapping the .func.gii maps across participants
# and create a group map of overlapping vertices
python3 average_geodistance_func.py "$TASK" "$mask_area"
python3 average_geodistance_func.py --dry-run "$TASK" "$mask_area"

#it did not help to restructure it. still in wb_view, it asks for all the .func.gii to say L or R
# so consider going back to the previous version of the script
python3 average_geodistance_func_wb.py "$TASK" "$mask_area"


# BACK - 20/10/2025 
# to create Glassier rois for the volumetric data to run MVPA 

# # # CLEANUP: Delete incorrectly created surface files
# echo "Cleaning up old surface files..."
# for subj in "${participants[@]}"; do
#   surf_dir="/Volumes/extreme/Cerens_files/fMRI/MoebiusProject/cluster_output/Freesurfer/${subj}/surf"
#   if [[ -d "$surf_dir" ]]; then
#     rm -f "$surf_dir"/*.surf.gii 2>/dev/null
#     echo "  ✓ Cleaned ${subj}"
#   fi
# done

# create. surf.gii files to use them for surface to volumetric conversion of the ROIs 
# in subject space
echo "Creating native GIFTI surfaces..."
for subj in "${participants[@]}"; do
  bash create_native_surface_gii.sh "$subj"

done

# convert surface Glassier ROIs into subject specific volumetric ROIs
# participants=(sub-ctrl002)
echo "Converting surface ROIs to volumetric space..."
for subj in "${participants[@]}"; do
  bash convert_surf_roi_to_vol.sh "$subj"
done

# warp the native volumetric ROIs to MNI space
echo "Warping native volumetric ROIs to MNI space..."

# Interpolation options:
#   NearestNeighbor (default, label-safe)
#   BSpline          (smooth; will be re-binarized in the warp script)
WARP_INTERP="BSpline"  # change to NearestNeighbor or BSpline to test smooth interpolation

participants=(sub-ctrl{001..002} )

for subj in "${participants[@]}"; do
  bash warp_native_masks_to_mni.sh "$subj" "$WARP_INTERP"
done

# Example calls:
# bash warp_native_masks_to_mni.sh sub-ctrl001 NearestNeighbor
# bash warp_native_masks_to_mni.sh sub-ctrl001 BSpline

# test different interpolation methods for warping
bash test_interpolations.sh