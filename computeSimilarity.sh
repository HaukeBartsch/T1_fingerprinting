#!/bin/bash
#
# compute the similarity between two T1w brain scans
#    ./computeSimilarity.sh /home/abcdproj1/data/DAL_ABCD_HPT/raw/MRIRAW_G032_PhantomTravelingHuman001LIBR_20170627_20170627.151646_1/st002_ser0002 /home/abcdproj1/data/DAL_ABCD_HPT/raw/MRIRAW_G031_PhantomTravelingHuman001UCSD_20170821_20170821.170114_1/st001_ser0005/

if [ ! $# -eq "4" ]; then
    echo "usage: $0 <T1 DICOM directory 1> <T1 DICOM directory 2> <groupID 1> <groupID 2>"
fi

# temporary path
tmp=`mktemp -d`    
    
# provide two directories with DICOM files
T1_1d="$1"
T1_2d="$2"
# strip off everything after the last underscore (relationship number)
family_1d="${T1_1d##*_}"
family_2d="${T1_2d##*_}"
rest_1d="${T1_1d%_*}"
rest_2d="${T1_2d%_*}"
group_1d="${rest_1d##*_}"
group_2d="${rest_2d##*_}"
T1_1d="${rest_1d%_*}"
T1_2d="${rest_2d%_*}"

# don't run this pair if its already in the results.txt file

grep "$T1_1d,$T1_2d" /home/hbartsch/src/T1_fingerprinting/resultsUnrelated.txt > /dev/null
if [ "$?" == "0" ]; then
   echo "skip, result is already available in output"
   exit
fi

# get a single DICOM file from the first directory
SAVEIF=$IFS
IFS=$'\n'
files=($(find "${T1_1d}" -print))
IFS=$SAVEIFS
tLen=${#files[@]}
for (( i=0; i<${tLen}; i++ )); do
    file="${files[$i]}"
    dcmftest "${file}" > /dev/null
    if [ "$?" == "0" ]; then
       T1_1="$file"
    fi 
done

# get a single DICOM file from the second directory
SAVEIF=$IFS
IFS=$'\n'
files=($(find ${T1_2d} -print))
IFS=$SAVEIFS
tLen=${#files[@]}
for (( i=0; i<${tLen}; i++ )); do
    file="${files[$i]}"
    dcmftest "${file}" > /dev/null
    if [ "$?" == "0" ]; then
       T1_2="$file"
    fi 
done

# get a single DICOM file from the second directory
mri_convert -i ${T1_1} -o ${tmp}/T1_1.nii
mri_convert -i ${T1_2} -o ${tmp}/T1_2.nii

/usr/pubsw/packages/fsl/fsl-5.0.2.2-centos6_64/bin/robustfov -i ${tmp}/T1_1.nii -r ${tmp}/T1_1_crop.nii
/usr/pubsw/packages/fsl/fsl-5.0.2.2-centos6_64/bin/robustfov -i ${tmp}/T1_2.nii -r ${tmp}/T1_2_crop.nii

mkdir ${tmp}/T1_1_fsl_anat/
mkdir ${tmp}/T1_2_fsl_anat/
fsl_anat --clobber -i ${tmp}/T1_1_crop.nii.gz -o ${tmp}/T1_1_fsl_anat/ &
fsl_anat --clobber -i ${tmp}/T1_2_crop.nii.gz -o ${tmp}/T1_2_fsl_anat/ &
wait

fslmaths ${tmp}/T1_1_fsl_anat/.anat/T1_fast_seg.nii.gz -thr 3 -uthr 3 -div 3 ${tmp}/T1_1_white_matter_label.nii -odt int
fslmaths ${tmp}/T1_2_fsl_anat/.anat/T1_fast_seg.nii.gz -thr 3 -uthr 3 -div 3 ${tmp}/T1_2_white_matter_label.nii -odt int

flirt -in ${tmp}/T1_2_white_matter_label.nii.gz -ref ${tmp}/T1_1_white_matter_label.nii.gz -out ${tmp}/T1_2_white_matter_label_res.nii -dof 6 -interp nearestneighbour

# compute the dice coefficient in the range of 0..1
# good overlap is > 0.7, excellent overlap is > 0.847
echo "Call now dice with : /home/hbartsch/src/T1_fingerprinting/dice.py ${tmp}/T1_1_white_matter_label.nii.gz ${tmp}/T1_2_white_matter_label_res.nii.gz"
d=`/home/hbartsch/src/T1_fingerprinting/dice.py ${tmp}/T1_1_white_matter_label.nii.gz ${tmp}/T1_2_white_matter_label_res.nii.gz`
echo "Write now results as : $T1_1d,$T1_2d,$d,$group_1d,$group_2d"
echo "$T1_1d,$T1_2d,$d,$group_1d,$group_2d,$family_1d,$family_2d" >> /home/hbartsch/src/T1_fingerprinting/resultsUnrelated.txt

# clean up
#/bin/rm -rf ${tmp}
