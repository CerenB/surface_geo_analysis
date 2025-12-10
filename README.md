# The pipeline 
Here the end goal is to calculate the geodesic distance.  

First we move from native space to either freesurfer or fs_LR spaces (volume to surface). 

Then we calculate the geodesic distance on the surface



# Volume to space conversions 

##  Working on fs_LR space: One main function
Here is the main function to be used for all the volume, ```spmT.nii``` files into surface files (```.func.gii```)
```bash
wb_command -volume-to-surface-mapping \
```

### The cortical mesh is in:
```/Users/battal/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k```

You better choose: ```fsaverage.L.midthickness_orig.32k_fs_LR.surf.gii```
It is better/ more accurate for the cortical distances.

### You will also need pial and white surf.gii from the same folder:
```bash
~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.white_orig.32k_fs_LR.surf.gii \
~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.pial_orig.32k_fs_LR.surf.gii
```

### the functional images are in :
```bash
FUNC_PATH="/Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/bidspm-stats/${SUBJECT}/task-somatotopy_space-T1w_FWHM-6"
```

Here you can change the task and the subject to loop through:
```bash
FUNC_PATH="/Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/bidspm-stats/${SUBJECT}/task-${TASK}_space-T1w_FWHM-6"
```
The output image will be in the surface:
```
rh.sub-ctrl001.fs_LR_32k.hand0pt001_none.func.gii
```

### the full conversion command to run for volume to surface mapping:

SUBJECT='sub-ctrl002'
```bash
cd /Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/bidspm-stats/$SUBJECT/task-somatotopy_space-T1w_FWHM-6
```

for Right hemisphere
```bash
wb_command -volume-to-surface-mapping \
  sub-ctrl001_task-somatotopy_space-T1w_desc-HandGtAll_p-0pt001_k-0_MC-none_spmT.nii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.midthickness_orig.32k_fs_LR.surf.gii \
  rh.sub-ctrl001.fs_LR_32k.hand0pt001_none.func.gii \
  -ribbon-constrained \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.white_orig.32k_fs_LR.surf.gii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.pial_orig.32k_fs_LR.surf.gii
```
for Left hemisphere
```bash
wb_command -volume-to-surface-mapping \
  sub-ctrl001_task-somatotopy_space-T1w_desc-HandGtAll_p-0pt001_k-0_MC-none_spmT.nii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.midthickness_orig.32k_fs_LR.surf.gii \
  lh.sub-ctrl001.fs_LR_32k.hand0pt001_none.func.gii \
  -ribbon-constrained \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.white_orig.32k_fs_LR.surf.gii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.pial_orig.32k_fs_LR.surf.gii
```

This will be repeated for every subject, every condition, every task. See below:
  ```bash
  FUNC_PATH="/Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/bidspm-stats/${SUBJECT}/task-${TASK}_space-T1w_FWHM-6"
  Condition={Hand, Lips, Tongue, Forehead, Feet}
  sub-${GROUP}${SUBJECT}_task-${TASK}$_space-T1w_desc-${TASK}GtAll_p-0pt001_k-0_MC-none_spmT.nii 
  
```
Hemisphere will also change: L/R
The surface meshes are constant. 
But hemisphere changes in L/R in the ```.surf.gii ```files, and the output file ```{l,r}.h.sub-ctrl...func.gii ```

### Various calculations
....

# Geodesic distance calculations
Steps are: 
1. Create dsclar .nii images for analytic calculations
2. Create (glassier atlas) masks to limit the analysis  in region of interest
3. Calculate the peak coordinates within a given ROI
4. Find the max t-values in the region of interest/masks
5. Geodesic distance between the two vertex
6. Run stats across groups


### 1. For euclidean distance or any kind of analyses, we need .dscalar.nii files

Here below is the idea of it, for each contrast, we need to give left and right hemisphere .func.gii files
And below that, you can see the function which goes through all the contrasts in the folder. 
```bash
wb_command -cifti-create-dense-scalar \
  sub-001_contrast.dscalar.nii \
  -left-metric  L.sub-001.fs_LR_32k.contrast.func.gii \
  -right-metric R.sub-001.fs_LR_32k.contrast.func.gii

#applied to my dataset
wb_command -cifti-create-dense-scalar \
    sub-ctrl001_fs_LR_32k_hand0pt001.dscalar.nii \
    -left-metric lh.sub-ctrl001.fs_LR_32k.hand0pt001_none.func.gii \
    -right-metric rh.sub-ctrl001.fs_LR_32k.hand0pt001_none.func.gii
```
  
 _The function or a script to automatize the process across different contrasts_
```bash
create_dscalar_images.sh
```

### 2. Create Glassier masks
Here we will use Glassier atlas to create binary masks. 
This is to limit the region of interest in the following analysis. 

```bash
# listing the name of regions/labels
wb_command -cifti-label-export-table \
  Glasser_et_al_2016_HCP_MMP1.0_v6_RVVG/Q1-Q6_RelatedValidation210/MNINonLinear/fsaverage_LR32k/Q1-Q6_RelatedParcellation210.CorticalAreasAndSubAreas_dil_Colors_210P_Orig.32k_fs_LR.dlabel.nii \
  1 \
  /dev/stdout

# or write down into text file
wb_command -cifti-label-export-table \
Glasser_et_al_2016_HCP_MMP1.0_v6_RVVG/Q1-Q6_RelatedParcellation210/MNINonLinear/fsaverage_LR32k/Q1-Q6_RelatedParcellation210.CorticalAreasAndSubAreas_dil_Colors_210P_Orig.32k_fs_LR.dlabel.nii \
1 \
label_list_CorticalAreasAndSubAreas.txt

grep -E "L_4_|L_3a_|L_3b_|L_2_|L_1_|R_4_|R_3a_|R_3b_|R_2_|R_1_" label_list_CorticalAreasAndSubAreas.txt

# now use the bash script for ROI making:
bash makeROIs_GlassierAtlas.sh L 3a|3b
# bash makeROIs_GlassierAtlas.sh R 4
```


### 3. Calculate the peak coordinates within a given ROI
Below function calculates peak coordinates within a given ROI across multiple functional maps, and output all the vertices into a .csv file
Later on (see the Step 4) we need to concetante these maps from L and R hemisphere and find the max value to be used in the distance calculation

```bash
bash calculate_peakCoordinate.sh "$subj" both area3a_3b "$TASK"
```
 It creates a .csv file for each hemisphere, under ```Glasser_ROI_sensorimotor/peakCoord``` folder

### 4. Find the max t-values in the region of interest/masks

Below script reads multiple CSV files containing peak data, 
extracts the maximum peak for each condition and mask area, and saves a summary to a new CSV file.
```bash
python3 create_max_tvalue_coord.py area3a_3b_all_peaks_mid
```

This is currently creating the ```max_tvalue_vertices_area3a_3b_all_peaks.csv``` file saved inside this folder:
```
/Volumes/extreme/Cerens_files/fMRI/GlasserAtlas/Glasser_ROIs_sensorimotor/peakCoord/
```
Then in the created .csv file, we have the vertices across conditions. 


| sub         | group | hemi | condition | mask      | vertex | tval      | x         | y         | z         |
|-------------|-------|------|-----------|-----------|--------|-----------|-----------|-----------|-----------|
| sub-ctrl001 | ctrl  | L    | hand      | area3a_3b | 7933   | 11.118555 | -43.895927| -21.762276| 54.993706 |
| sub-ctrl001 |ctrl   | L	 | tongue	 | area3a_3b | 8067	  | 11.482499 | -47.664478| -18.289211| 48.681252 |


### 5. Geodesic distance between the two vertex
Now we take these vertex coordiantes and calculate the distance. That gives a numeric output
```bash
(base) ➜  GitHub bash calculate_geodesic_distance.sh sub-ctrl001 L area3a_3b 7933 8067
9.2004175
```

_What is needed probably: create a function where for across subjects, each pair of the conditions, it gives 2 row of output_

### 6. Run stats across groups

_What is needed probably: create a function to plot in R matlab,python the results & run stats_


  
    
      


## Working on freesurfer/ fsaverage space - One main function
```bash
wb_command -volume-to-surface-mapping \
wb_command -metric-resample \
```

Here is an example call:
```bash
# 1. Project volume (T1w) to native surface
wb_command -volume-to-surface-mapping \
  spmT_0001.nii \
  $SUBJECTS_DIR/sub-XX/surf/lh.midthickness \
  sub-XX.L.native.func.gii \
  -ribbon-constrained \
  $SUBJECTS_DIR/sub-XX/surf/lh.white \
  $SUBJECTS_DIR/sub-XX/surf/lh.pial

# 2. Resample from native to fsaverage surface
wb_command -metric-resample \
  sub-XX.L.native.func.gii \
  $SUBJECTS_DIR/sub-XX/surf/lh.sphere.reg \
  $FREESURFER_HOME/subjects/fsaverage/surf/lh.sphere.reg \
  ADAP_BARY_AREA \
  sub-XX.L.fsaverage.func.gii \
  -area-metrics \
  $SUBJECTS_DIR/sub-XX/surf/lh.area.mid \
  $FREESURFER_HOME/subjects/fsaverage/surf/lh.area.mid
  ```

An example with an actual data:
```bash
# 1. Project volume t-maps → native surface (left and right hemispheres)
#Use wb_command -volume-to-surface-mapping with the ribbon constrained approach:
# native volume (spmT map) to native surface
wb_command -volume-to-surface-mapping \
  sub-ctrl001_task-somatotopy_space-T1w_desc-HandGtAll_p-0pt001_k-0_MC-none_spmT.nii \
  $SUBJECTS_DIR/sub-ctrl001/surf/lh.midthickness.surf.gii \
  lh.sub-ctrl001.T1w.hand0pt001_none.func.gii \
  -ribbon-constrained \
  $SUBJECTS_DIR/sub-ctrl001/surf/lh.white.surf.gii \
  $SUBJECTS_DIR/sub-ctrl001/surf/lh.pial.surf.gii

  # do the same for the right hemisphere
wb_command -volume-to-surface-mapping \
    sub-ctrl001_task-somatotopy_space-T1w_desc-HandGtAll_p-0pt001_k-0_MC-none_spmT.nii \
    $SUBJECTS_DIR/sub-ctrl001/surf/rh.midthickness.surf.gii \
    rh.sub-ctrl001.T1w.hand0pt001_none.func.gii \
    -ribbon-constrained \
    $SUBJECTS_DIR/sub-ctrl001/surf/rh.white.surf.gii \
    $SUBJECTS_DIR/sub-ctrl001/surf/rh.pial.surf.gii

# note: 
    # You need your native surfaces in GIFTI format (.surf.gii) for wb_command — you can convert them using FreeSurfer's mris_convert if needed.
    # sphere.reg files are missing
    mris_convert $SUBJECTS_DIR/fsaverage/surf/rh.sphere.reg rh.sphere.reg.surf.gii
    mris_convert $SUBJECTS_DIR/fsaverage/surf/lh.sphere.reg lh.sphere.reg.surf.gii

# now actual step 2 : converting the surface
# native surface to standard surface (fsaverage or fs_LR)
wb_command -metric-resample \
  lh.sub-ctrl001.T1w.hand0pt001_none.func.gii \
  $SUBJECTS_DIR/sub-ctrl001/surf/lh.sphere.reg.surf.gii \
  $SUBJECTS_DIR/fsaverage/surf/lh.sphere.reg.surf.gii \
  ADAP_BARY_AREA \
  lh.sub-ctrl001.fsaverage.hand0pt001_none.func.gii \
  -area-metrics \
  $SUBJECTS_DIR/sub-ctrl001/surf/lh.area.mid.shape.gii \
  $SUBJECTS_DIR/fsaverage/surf/lh.area.mid.shape.gii

  # now rh
  wb_command -metric-resample \
  rh.sub-ctrl001.T1w.hand0pt001_none.func.gii \
  $SUBJECTS_DIR/sub-ctrl001/surf/rh.sphere.reg.surf.gii \
  $SUBJECTS_DIR/fsaverage/surf/rh.sphere.reg.surf.gii \
  ADAP_BARY_AREA \
  rh.sub-ctrl001.fsaverage.hand0pt001_none.func.gii \
  -area-metrics \
  $SUBJECTS_DIR/sub-ctrl001/surf/rh.area.mid.shape.gii \
  $SUBJECTS_DIR/fsaverage/surf/rh.area.mid.shape.gii

####### there are always some input files are missing
# so let's start with converting all the necessary files
# Create GIFTI versions of subject surface files
mris_convert $SUBJECTS_DIR/sub-XXX/surf/lh.white      $SUBJECTS_DIR/sub-XXX/surf/lh.white.surf.gii
mris_convert $SUBJECTS_DIR/sub-XXX/surf/lh.pial       $SUBJECTS_DIR/sub-XXX/surf/lh.pial.surf.gii
mris_convert $SUBJECTS_DIR/sub-XXX/surf/lh.inflated   $SUBJECTS_DIR/sub-XXX/surf/lh.inflated.surf.gii
mris_convert $SUBJECTS_DIR/sub-XXX/surf/lh.sphere.reg $SUBJECTS_DIR/sub-XXX/surf/lh.sphere.reg.surf.gii
mris_convert $SUBJECTS_DIR/sub-XXX/surf/lh.midthickness $SUBJECTS_DIR/sub-XXX/surf/lh.midthickness.surf.gii

# compute  vertex area maps for white and pial
wb_command -surface-vertex-areas \
  $SUBJECTS_DIR/sub-XXX/surf/lh.white.surf.gii \
  $SUBJECTS_DIR/sub-XXX/surf/lh.area.white.shape.gii

wb_command -surface-vertex-areas \
  $SUBJECTS_DIR/sub-XXX/surf/lh.pial.surf.gii \
  $SUBJECTS_DIR/sub-XXX/surf/lh.area.pial.shape.gii

# compute average area (area.mid)
wb_command -metric-math "(a + b) / 2" \
  $SUBJECTS_DIR/sub-XXX/surf/lh.area.mid.shape.gii \
  -var a $SUBJECTS_DIR/sub-XXX/surf/lh.area.white.shape.gii \
  -var b $SUBJECTS_DIR/sub-XXX/surf/lh.area.pial.shape.gii

# applie example
wb_command -metric-math "(a+b) / 2" \
rh.area.mid.shape.gii \
-var a rh.area.white.shape.gii \
-var b rh.area.pial.shape.gii

# prepare fsaverafe surfaces
# Only if these files don't exist already
mris_convert $FREESURFER_HOME/subjects/fsaverage/surf/lh.midthickness \
  $FREESURFER_HOME/subjects/fsaverage/surf/lh.midthickness.surf.gii

wb_command -surface-vertex-areas \
  $FREESURFER_HOME/subjects/fsaverage/surf/lh.midthickness.surf.gii \
  $FREESURFER_HOME/subjects/fsaverage/surf/lh.area.mid.shape.gii

mris_convert $FREESURFER_HOME/subjects/fsaverage/surf/lh.sphere.reg \
  $FREESURFER_HOME/subjects/fsaverage/surf/lh.sphere.reg.surf.gii