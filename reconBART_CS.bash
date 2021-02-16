#!/bin/bash

  # Performs recon on all slices using BART. Call with reconSlices BART/Slices xres rcxres
reconSlices () {
  for i in $(find $1 -maxdepth 1 -type d -name Slice_*) # Loop through slices
  do
     # Convert static k-space data to do coil sensitivity measurement with eSpirit
     bart nufft -i -P -t $i/traj_static $i/kdata_static $i/coil_img
     bart resize -c 0 $2 1 $2 $i/coil_img $i/coil_img2
     bart fft -u $(bart bitmask 0 1) $i/coil_img2 $i/ksp

     # Measure coil sensitivity maps with eSpirit
     bart ecalib -m1 $i/ksp $i/sens
     bart resize -c 0 $3 1 $3 $i/sens $i/sens2

     for ii in $(find $i -maxdepth 1 -type d -name *spokes) # Loop through temporal resolutions
     do
         echo ${ii}
         # Do parallel imaging compressed sensing reconstruction in BART
	       bart pics -R T:$(bart bitmask 10):0:$4 -R W:$(bart bitmask 0 1):0:$5 -e -i80 -u10 -S -t ${ii}/traj ${ii}/kdata $i/sens2 ${ii}/recon_img_CS
	       rm -f ${ii}/traj* ${ii}/kdata* # Remove what you don't need
     done
     rm -f $i/coil_img* $i/coil_img2* $i/ksp* $i/sens* $i/sens2* $i/*spokes/traj* $i/*spokes/kdata* # Remove what you don't need
  done
}

 reconPath="/data/data_mrcv/45_DATA_HUMANS/CHEST/STUDIES/2020_Realtime_CMR/AIC/reconScripts"
 baseDir=$1
 multislice=$2      #1 # this should be 0 or 1
 spokesPerFrame=$3   #"[20, 30]"
 tvLambda="0.008"
 waveletLamda="0.005"
 # Use pcvipr recon code to export data in BART format
 pcvipr_recon_binary -f $baseDir/ScanArchive*.h5 -ss_2D_multislice $multislice -export_bart

 # Grab PSD parameters of interest from data_header.txt
 xres=$(grep -m 1 xres $baseDir/data_header.txt)
 xres=${xres:5:3}
 nproj=$(grep -m 1 nproj $baseDir/data_header.txt)
 nproj=${nproj:5:7}
 nCoils=$(grep -m 1 numrecv $baseDir/data_header.txt)
 nCoils=${nCoils:8:1}
 nSlices=$(grep -m 1 rczres $baseDir/data_header.txt)
 nSlices=${nSlices:7:3}
 rcxres=$(grep -m 1 rcxres $baseDir/data_header.txt)
 rcxres=${rcxres:7:3}
 spokesPerSlice=$(($nproj / $nSlices))

 # Move data to BART folder for recon
 mkdir $baseDir/BART
 mv $baseDir/MRI_Raw_Bart* $baseDir/BART
 rm -f $baseDir/X_*.dat $baseDir/X_*.complex $baseDir/data_header.txt $baseDir/pcvipr_header.txt MAG.dat CD.dat comp_vd_1.dat comp_vd_2.dat comp_vd_3.dat ph_000_mag.dat ph_000_cd.dat ph_000_vd_1.dat ph_000_vd_2.dat ph_000_vd_3.dat

 # Divide data into individual slices using matlab function
 matlab_cmd="addpath('$reconPath'); divideSlices('$baseDir/BART', $nCoils, $nSlices, $xres, $spokesPerSlice, $spokesPerFrame); exit();"
 echo $rcxres
 echo $matlab_cmd
 matlab -nodesktop -nosplash -r "$matlab_cmd"

 # Run BART PI-CS Recon
 reconSlices $baseDir/BART/Slices $xres $rcxres $tvLambda $waveletLambda
