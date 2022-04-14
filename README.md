# Matlab_FastTiffReadWrite
 Functions to read tiffs and write tiffs quickly in matlab

Core functions:
bigread4.m -- reads standard and BigTiffs quickly; calls readtifftags.m
FastTiffSave.m -- saves standard and BigTiffs quickly; calls Fast_BigTiff_Write.m and Fast_Tiff_Write.m

Example usage:
imData=bigread4('C:\Users\Admin\Desktop\test.tif');
FastTiffSave(imData,'C:\Users\Admin\Desktop\test_copy.tif');

This should give ImageJ speeds for tiff reading and writing, if not quicker.

It's that simple!
All questions and comments to jms7008@med.cornell.edu