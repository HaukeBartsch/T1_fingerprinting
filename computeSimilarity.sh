#!/bin/bash
#
# compute the similarity of two T1-weighted brain scans
#    ./computeSimilarity.sh /home/abcdproj1/data/DAL_ABCD_HPT/raw/MRIRAW_G032_PhantomTravelingHuman001LIBR_20170627_20170627.151646_1/st002_ser0002 /home/abcdproj1/data/DAL_ABCD_HPT/raw/MRIRAW_G031_PhantomTravelingHuman001UCSD_20170821_20170821.170114_1/st001_ser0005/

if [ ! $# -eq "2" ]; then
    echo "usage: $0 <T1 DICOM directory 1> <T1 DICOM directory 2>"
    exit
fi

# temporary path
#tmp=`mktemp -d`
# keep the files together to not have to do the fsl stuff again and again
tmp=/tmp/T1_storage
if [ ! -d "${tmp}" ]; then
    mkdir "${tmp}"
fi
echo "Store all temporary results in ${tmp}..."

# provide two directories with DICOM files
T1_1d="$1"
T1_2d="$2"

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

T1_1d=`dcmdump +P "PatientID" "${T1_1}" | cut -d'[' -f2 | cut -d']' -f1`
T1_2d=`dcmdump +P "PatientID" "${T1_2}" | cut -d'[' -f2 | cut -d']' -f1`
date1=`dcmdump +P "StudyDate" "${T1_1}" | cut -d'[' -f2 | cut -d']' -f1`
date2=`dcmdump +P "StudyDate" "${T1_2}" | cut -d'[' -f2 | cut -d']' -f1`

T1_1d="${T1_1d}_${date1}"
T1_2d="${T1_2d}_${date2}"

# strip off everything after the last underscore (relationship number)
#family_1d="${T1_1d##*_}"
#family_2d="${T1_2d##*_}"
#rest_1d="${T1_1d%_*}"
#rest_2d="${T1_2d%_*}"
#group_1d="${rest_1d##*_}"
#group_2d="${rest_2d##*_}"
#T1_1d="${rest_1d%_*}"
#T1_2d="${rest_2d%_*}"

# don't run this pair if its already in the results.txt file

grep "$T1_1d,$T1_2d" results.txt > /dev/null
if [ "$?" == "0" ]; then
    # remove duplicates
    echo "skip, result is already available in output"
    exit
fi
# also remove the symmetric test
grep "$T1_2d,$T1_1d" results.txt > /dev/null
if [ "$?" == "0" ]; then
    # remove duplicates
    echo "skip, reverse test result is already available in output"
    exit
fi

# get a single DICOM file from the second directory
if [ ! -f ${tmp}/${T1_1d}_white_matter_label.nii.gz ]; then
    #mri_convert -i ${T1_1} -o "${tmp}/${T1_1d}.nii"
    dcm2niix -o "${tmp}/" -f "${T1_1d}" "${T1_1}"
fi
if [ ! -f ${tmp}/${T1_2d}_white_matter_label.nii.gz ]; then
    #mri_convert -i ${T1_2} -o "${tmp}/${T1_2d}.nii"
    dcm2niix -o "${tmp}/" -f "${T1_2d}" "${T1_2}"
fi

if [ ! -f ${tmp}/${T1_1d}_white_matter_label.nii.gz ]; then
    # /usr/pubsw/packages/fsl/fsl-5.0.2.2-centos6_64/bin/robustfov -i ${tmp}/${T1_1d}.nii -r ${tmp}/${T1_1d}_crop.nii
    docker run --rm -i -v ${tmp}:${tmp} fsl /bin/bash -c "robustfov -i ${tmp}/${T1_1d}.nii -r ${tmp}/${T1_1d}_crop.nii"
fi
if [ ! -f ${tmp}/${T1_2d}_white_matter_label.nii.gz ]; then
    #/usr/pubsw/packages/fsl/fsl-5.0.2.2-centos6_64/bin/robustfov -i ${tmp}/${T1_2d}.nii -r ${tmp}/${T1_2d}_crop.nii
    docker run --rm -i -v ${tmp}:${tmp} fsl /bin/bash -c "robustfov -i ${tmp}/${T1_2d}.nii -r ${tmp}/${T1_2d}_crop.nii"
fi

if [ ! -f ${tmp}/${T1_1d}_white_matter_label.nii.gz ]; then
    mkdir ${tmp}/${T1_1d}_fsl_anat/
fi
if [ ! -d "${tmp}/${T1_2d}_fsl_anat/" ]; then
    mkdir ${tmp}/${T1_2d}_fsl_anat/
fi
if [ ! -f ${tmp}/${T1_1d}_white_matter_label.nii.gz ]; then
    #fsl_anat --clobber -i ${tmp}/${T1_1d}_crop.nii.gz -o ${tmp}/${T1_1d}_fsl_anat/ &
    docker run --rm -i -v ${tmp}:${tmp} fsl /bin/bash -c "fsl_anat --clobber -i ${tmp}/${T1_1d}_crop.nii.gz -o ${tmp}/${T1_1d}_fsl_anat/"
fi
if [ ! -f ${tmp}/${T1_2d}_white_matter_label.nii.gz ]; then
    # fsl_anat --clobber -i ${tmp}/${T1_2d}_crop.nii.gz -o ${tmp}/${T1_2d}_fsl_anat/ &
    docker run --rm -i -v ${tmp}:${tmp} fsl /bin/bash -c "fsl_anat --clobber -i ${tmp}/${T1_2d}_crop.nii.gz -o ${tmp}/${T1_2d}_fsl_anat/"
fi
# wait

if [ ! -f ${tmp}/${T1_1d}_white_matter_label.nii.gz ]; then
    #fslmaths ${tmp}/${T1_1d}_fsl_anat/.anat/T1_fast_seg.nii.gz -thr 3 -uthr 3 -div 3 ${tmp}/${T1_1d}_white_matter_label.nii -odt int
    docker run --rm -i -v ${tmp}:${tmp} fsl /bin/bash -c "fslmaths ${tmp}/${T1_1d}_fsl_anat/.anat/T1_fast_seg.nii.gz -thr 3 -uthr 3 -div 3 ${tmp}/${T1_1d}_white_matter_label.nii -odt int"
fi
if [ ! -f ${tmp}/${T1_2d}_white_matter_label.nii.gz ]; then
    #fslmaths ${tmp}/${T1_2d}_fsl_anat/.anat/T1_fast_seg.nii.gz -thr 3 -uthr 3 -div 3 ${tmp}/${T1_2d}_white_matter_label.nii -odt int
    docker run --rm -i -v ${tmp}:${tmp} fsl /bin/bash -c "fslmaths ${tmp}/${T1_2d}_fsl_anat/.anat/T1_fast_seg.nii.gz -thr 3 -uthr 3 -div 3 ${tmp}/${T1_2d}_white_matter_label.nii -odt int"
fi

#flirt -in ${tmp}/${T1_2d}_white_matter_label.nii.gz -ref ${tmp}/${T1_1d}_white_matter_label.nii.gz -out ${tmp}/${T1_2d}_${T1_1d}_white_matter_label_res.nii -dof 6 -interp nearestneighbour
docker run --rm -i -v ${tmp}:${tmp} fsl /bin/bash -c "flirt -in ${tmp}/${T1_2d}_white_matter_label.nii.gz -ref ${tmp}/${T1_1d}_white_matter_label.nii.gz -out ${tmp}/${T1_2d}_${T1_1d}_white_matter_label_res.nii -dof 6 -interp nearestneighbour"

# compute the dice coefficient in the range of 0..1
# good overlap is > 0.7, excellent overlap is > 0.847
echo "Call now dice with : /home/hbartsch/src/T1_fingerprinting/dice.py ${tmp}/${T1_1d}_white_matter_label.nii.gz ${tmp}/${T1_2d}_${T1_1d}_white_matter_label_res.nii.gz"
#d=`/Users/hauke/src/T1_fingerprinting/dice.py ${tmp}/${T1_1d}_white_matter_label.nii.gz ${tmp}/${T1_2d}_${T1_1d}_white_matter_label_res.nii.gz`
d=`docker run --rm -i -v ${tmp}:${tmp} -v /Users/hauke/src/T1_fingerprinting/:/prog fsl /bin/bash -c "/prog/dice.py ${tmp}/${T1_1d}_white_matter_label.nii.gz ${tmp}/${T1_2d}_${T1_1d}_white_matter_label_res.nii.gz"`
echo "Write now results as : $T1_1d,$T1_2d,$d"
echo "$T1_1d,$T1_2d,$d" >> results.txt

# clean up
#/bin/rm -rf ${tmp}
