
#first suggestion by chatgpt
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

# example from my data

#2) Project volume t-maps → native surface (left and right hemispheres)
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


# let's try to visulise at this step
mris_convert \
  $SUBJECTS_DIR/fsaverage/surf/lh.inflated \
  $SUBJECTS_DIR/fsaverage/surf/lh.inflated.surf.gii
mris_convert \
  $SUBJECTS_DIR/fsaverage/surf/rh.inflated \
  $SUBJECTS_DIR/fsaverage/surf/rh.inflated.surf.gii
# also convert curvature to overlay
mris_convert \
  -c $SUBJECTS_DIR/fsaverage/surf/rh.curv \
  $SUBJECTS_DIR/fsaverage/surf/rh.inflated \
  $SUBJECTS_DIR/fsaverage/surf/rh.curv.func.gii

  mris_convert \
  -c $SUBJECTS_DIR/fsaverage/surf/lh.curv \
  $SUBJECTS_DIR/fsaverage/surf/lh.inflated \
  $SUBJECTS_DIR/fsaverage/surf/lh.curv.func.gii

# setting up endlessly ciftify stuff 
export CIFTIFY_WORKDIR=/Volumes/extreme/Cerens_files/fMRI/MoebiusProject/cluster_output/ciftify
export SUBJECTS_DIR=/Volumes/extreme/Cerens_files/fMRI/MoebiusProject/cluster_output/Freesurfer

ciftify_recon_all --surf-reg MSMSulc sub-ctrl001
ciftify_recon_all --subject-id sub-ctrl001 --surf-reg MSMSulc

export MSM_BIN=/Users/battal/fsl/bin/msm

# 05/08/2025
# open Rosetta terminal
arch -x86_64 zsh


# let's make ciftify_recon_all docker run
# basic idea
docker run -it --platform linux/amd64 \
    -v /Users/you/freesurfer:/opt/freesurfer/subjects \
    -v /Users/you/ciftify_output:/out \
    my_ciftify_workbench_image \
    ciftify_recon_all --verbose sub-ctrl001

# my example 
docker run --platform=linux/amd64 -it \
  -v /Volumes/extreme/Cerens_files/fMRI/MoebiusProject/cluster_output/Freesurfer:/opt/freesurfer/subjects \
  -v /Volumes/extreme/Cerens_files/fMRI/MoebiusProject/cluster_output/ciftify:/out \
  -v /Volumes/extreme/Cerens_files/fMRI/MoebiusProject/tmp_ciftify_workdir:/tmp/ciftify_workdir \
  -v /Volumes/extreme/Cerens_files/fMRI/MoebiusProject/cluster_output/Freesurfer/license.txt:/opt/freesurfer/license.txt \
  -e CIFTIFY_OUTPUT_DIR=/out \
  -e CIFTIFY_WORKDIR=/tmp/ciftify_workdir \
  -w /opt/freesurfer/subjects \
  --entrypoint /bin/bash \
  my_ciftify_workbench_image

  #   -v /Volumes/extreme/Cerens_files/fMRI/MoebiusProject/workbench:/opt/workbench \
 # Run this before launching ciftify:
 export PATH=/usr/local/bin:$PATH
 which msm
 # it should now output : /usr/local/bin/msm

#######
# where fs_LR 32k is
/Users/battal/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k


# converting func map into surface map of fs_LR space
wb_command -volume-to-surface-mapping tmp_peak_mask_5mm.nii.gz \
 ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.midthickness_orig.32k_fs_LR.surf.gii \
 tmp_peak_mask_5mm.R.func.gii \
 -ribbon-constrained  \
 ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.white_orig.32k_fs_LR.surf.gii \
 ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.pial_orig.32k_fs_LR.surf.gii

#now let's try with my functional image
# hand
wb_command -volume-to-surface-mapping \
  sub-ctrl001_task-somatotopy_space-T1w_desc-HandGtAll_p-0pt001_k-0_MC-none_spmT.nii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.midthickness_orig.32k_fs_LR.surf.gii \
  rh.sub-ctrl001.fs_LR_32k.hand0pt001_none.func.gii \
  -ribbon-constrained \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.white_orig.32k_fs_LR.surf.gii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.pial_orig.32k_fs_LR.surf.gii

wb_command -volume-to-surface-mapping \
  sub-ctrl001_task-somatotopy_space-T1w_desc-HandGtAll_p-0pt001_k-0_MC-none_spmT.nii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.midthickness_orig.32k_fs_LR.surf.gii \
  lh.sub-ctrl001.fs_LR_32k.hand0pt001_none.func.gii \
  -ribbon-constrained \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.white_orig.32k_fs_LR.surf.gii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.pial_orig.32k_fs_LR.surf.gii

  # let's try another spmT map 
  # 
  # 
  # forehead
  wb_command -volume-to-surface-mapping \
  sub-ctrl001_task-somatotopy_space-T1w_desc-ForeheadGtAll_p-0pt001_k-0_MC-none_spmT.nii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.midthickness_orig.32k_fs_LR.surf.gii \
  rh.sub-ctrl001.fs_LR_32k.forehead0pt001_none.func.gii \
  -ribbon-constrained \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.white_orig.32k_fs_LR.surf.gii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.pial_orig.32k_fs_LR.surf.gii

wb_command -volume-to-surface-mapping \
  sub-ctrl001_task-somatotopy_space-T1w_desc-ForeheadGtAll_p-0pt001_k-0_MC-none_spmT.nii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.midthickness_orig.32k_fs_LR.surf.gii \
  lh.sub-ctrl001.fs_LR_32k.forehead0pt001_none.func.gii \
  -ribbon-constrained \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.white_orig.32k_fs_LR.surf.gii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.pial_orig.32k_fs_LR.surf.gii

# lips
 wb_command -volume-to-surface-mapping \
  sub-ctrl001_task-somatotopy_space-T1w_desc-LipsGtAll_p-0pt001_k-0_MC-none_spmT.nii\
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.midthickness_orig.32k_fs_LR.surf.gii \
  rh.sub-ctrl001.fs_LR_32k.lips0pt001_none.func.gii \
  -ribbon-constrained \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.white_orig.32k_fs_LR.surf.gii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.pial_orig.32k_fs_LR.surf.gii

wb_command -volume-to-surface-mapping \
  sub-ctrl001_task-somatotopy_space-T1w_desc-LipsGtAll_p-0pt001_k-0_MC-none_spmT.nii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.midthickness_orig.32k_fs_LR.surf.gii \
  lh.sub-ctrl001.fs_LR_32k.lips0pt001_none.func.gii \
  -ribbon-constrained \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.white_orig.32k_fs_LR.surf.gii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.pial_orig.32k_fs_LR.surf.gii

# tongue
 wb_command -volume-to-surface-mapping \
  sub-ctrl001_task-somatotopy_space-T1w_desc-TongueGtAll_p-0pt001_k-0_MC-none_spmT.nii\
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.midthickness_orig.32k_fs_LR.surf.gii \
  rh.sub-ctrl001.fs_LR_32k.tongue0pt001_none.func.gii \
  -ribbon-constrained \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.white_orig.32k_fs_LR.surf.gii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.R.pial_orig.32k_fs_LR.surf.gii

wb_command -volume-to-surface-mapping \
  sub-ctrl001_task-somatotopy_space-T1w_desc-TongueGtAll_p-0pt001_k-0_MC-none_spmT.nii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.midthickness_orig.32k_fs_LR.surf.gii \
  lh.sub-ctrl001.fs_LR_32k.tongue0pt001_none.func.gii \
  -ribbon-constrained \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.white_orig.32k_fs_LR.surf.gii \
  ~/Documents/GitHub/CBIG/data/templates/surface/fs_LR_32k/fsaverage.L.pial_orig.32k_fs_LR.surf.gii

# try euclidean distance with two peaks (how to extract them?)
# next: make the feet contrast in the other PC (with Volume- extreme connected) - DONE
# it seems forehead in the left is not "mapped" well or goes out of ribbon-constrained
# wondering: if we can use something else than ribbon-constrained? 
# or when we do find the peak coordinate, maybe draw a sphere?

# for fsaverage surfaces, we need metric-sampling. but do we need ribbon-contrained? maybe it is better??

# for euclidean distance or any kind of analyses, we need .dscalar.nii files
wb_command -cifti-create-dense-scalar \
  sub-001_contrast.dscalar.nii \
  -left-metric  L.sub-001.fs_LR_32k.contrast.func.gii \
  -right-metric R.sub-001.fs_LR_32k.contrast.func.gii

#applied to my dataset
wb_command -cifti-create-dense-scalar \
    sub-ctrl001_fs_LR_32k_hand0pt001.dscalar.nii \
    -left-metric lh.sub-ctrl001.fs_LR_32k.hand0pt001_none.func.gii \
    -right-metric rh.sub-ctrl001.fs_LR_32k.hand0pt001_none.func.gii



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
makeROIs_GlassierAtlas.sh

# my functional data
data = '/Volumes/extreme/Cerens_files/fMRI/moebius_topo_analyses/outputs/derivatives/bidspm-stats/sub-ctrl001/task-somatotopy_space-T1w_FWHM-6'

#######################
# EXAMPLE to find the PEAK COORDINATE 
# Now let's find the max peaks within the ROIs
# doesn't work 
wb_command -cifti-find-extrema func.gii \
  -roi R_sensorimotor_union.func.gii \
  -most-positive peak.csv 

  