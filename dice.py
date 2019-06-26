#!/usr/local/fsl/bin/fslpython

# As recommended by Zijdenbos et al (15) in the literature of image validation an good overlap occurs when DSC >0.700, or equivalently, logit(DSC) >0.847. Based on the analysis of the kappa statistic, an excellent agreement occurs when k >0.75, as recommended by Fleiss (14).

import os.path as op
import sys
import time
import numpy as np
import fsl.data.image as fslimage
import nibabel as nib
import argparse
import math

#   ./dice.py T1_1_fsl_anat/.anat/white_matter_label.nii.gz T1_2_fsl_anat/.anat/white_matter_label_res.nii.gz 
parser = argparse.ArgumentParser(description='Compute DICE coefficient of two files. Excellent correspondence is a value returned of >0.75.')
parser.add_argument('images', metavar='I', type=str, nargs='+',
                   help='a filename')
parser.add_argument('--logit', default=0,
                    help='return the logit of the dice/(1-dice), a value that is -infty..+infty')


args = parser.parse_args()
if len(args.images) != 2:
    print("Error: two images are required")
    sys.exit(-1)
logit = False
if args.logit == "1":
    logit = True

im1 = nib.load(args.images[0])
im2 = nib.load(args.images[1])

# make data 1d
im1 = im1.get_fdata()
s1  = np.prod(im1.shape)
im1 = np.reshape(im1, s1)

im2 = im2.get_fdata()
s2  = np.prod(im2.shape)
im2 = np.reshape(im2, s2)

im1 = im1.astype(np.bool)
im2 = im2.astype(np.bool)

if im1.shape != im2.shape:
    raise ValueError("Shape mismatch: im1 and im2 must have the same shape.")

empty_score = 1.0
im_sum = im1.sum() + im2.sum()
if im_sum == 0:
    print(empty_score)
else:

    # Compute Dice coefficient
    intersection = np.logical_and(im1, im2)

    dice = 2. * intersection.sum() / im_sum
    logit_dice = math.log(dice/(1-dice))
    if not logit:
        print(dice)
    else:
        print(logit_dice)
