## T1 fingerprinting

Testing some simply ideas on how to do a T1 fingerprinting for longitudinal brains.

### Idea 1

Calculate the white matter mask after registration of the two brain images. Do a dice score of the white matter mask (twice the number of elements in common to both sets divided by the sum of the number of elements in each set).


Using the traveling phantom scans:

```
bash
T1_1=/home/abcdproj1/data/DAL_ABCD_HPT/raw/MRIRAW_G032_PhantomTravelingHuman001LIBR_20170627_20170627.151646_1/st002_ser0002/im0001.dcm
T1_2=/home/abcdproj1/data/DAL_ABCD_HPT/raw/MRIRAW_G031_PhantomTravelingHuman001UCSD_20170821_20170821.170114_1/st001_ser0005/im0001.dcm
```

Convert DICOM files to nii for processing:
```
mri_convert -i $T1_1 -o T1_1.nii
mri_convert -i $T1_2 -o T1_2.nii
```

Try to remove the neck to make bet2/fast work better
```
/usr/pubsw/packages/fsl/fsl-5.0.2.2-centos6_64/bin/robustfov -i T1_1.nii -r T1_1_crop.nii
/usr/pubsw/packages/fsl/fsl-5.0.2.2-centos6_64/bin/robustfov -i T1_2.nii -r T1_2_crop.nii
```

```
mkdir T1_1_fsl_anat/
fsl_anat --clobber -i T1_1_crop.nii.gz -o T1_1_fsl_anat/
mkdir T1_2_fsl_anat/
fsl_anat --clobber -i T1_2_crop.nii.gz -o T1_2_fsl_anat/
```
The segmented white matter is in (label 3):
```
tkmedit -f .anat/T1_biascorr.nii.gz -aux .anat/T1_fast_seg.nii.gz
```
To extract that label we can use fslmath
```
fslmaths T1_fast_seg.nii.gz -thr 3 -uthr 3 -div 3 white_matter_label.nii -odt int
```
Now make the two white matter labels have the same size
```
flirt -in white_matter_label.nii.gz -ref ../../T1_1_fsl_anat/.anat/white_matter_label.nii.gz -out white_matter_label_res.nii -dof 6 -interp nearestneighbour
```
Now display the two labels
```
tkmedit -f white_matter_label_res.nii.gz -aux ../../T1_1_fsl_anat/.anat/white_matter_label.nii.gz
```

Now compute the dice coefficient using a small fsl python program:




#Or just run fast directly...
#```
#fast -o T1_2_fast T1_2_crop.nii.gz
#```

