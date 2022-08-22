# Matlab_FastTiffReadWrite
 Functions to read tiffs and write tiffs quickly in matlab
 J.M. Stujenske

1.Read / Write Functions:
bigread4.m -- reads standard and BigTiffs quickly; calls readtifftags.m

FastTiffSave.m -- saves standard and BigTiffs quickly; calls Fast_BigTiff_Write.m and Fast_Tiff_Write.m

Example usage:
imData=bigread4('C:\Users\Admin\Desktop\test.tif');
FastTiffSave(imData,'C:\Users\Admin\Desktop\test_copy.tif');

2. Memory mapping function
memory_map_tiff -- memory map a tif saved by FastTiffSave, to read quickly, like you could for a binary file
%May work for other tiffs, but notably does not work for tiffs saved with saveastiff or the Tiff class

Example usage:
m = memory_map_tiff('test.tif',[],2);
channel1_frame1=m.Data(1).channel1;
m = memory_map_tiff('test.tif','matrix',2);
info = readtifftags;
tiff_height=info(1).ImageHeight;
allchannel1data=m.Data.allchans(:,1:tiff_height,:);

3. Visualizing tiffs
TiffViewer -- object class for viewing tiffs (like in ImageJ but much faster, images read virtually with memory mapping but not slow like in ImageJ)

example usage:
tv=TiffViewer('test.tif'); %Figure will pop up to visual the tif
%Note, that this requires the tif to be memory map-able

Explanation:
Reading based on script by D. Peterka (modified by E. Pnevmatikakis, currently utilized in CaImAn package and others)

Writing based on solution by R. Harkes:
https://github.com/rharkes/Fast_Tiff_Write

This should give ImageJ speeds for tiff reading and writing, if not quicker.

More details:
This was written for use with large tiff stacks containing calcium imaging data but works for other applications.
Reading is optimized for uncompressed, grayscale tiff stacks. This improves on bigread2 by expanding functionality (e.g., tiffs can be written in tiles rather than just strips; deals with tiffs with tags stuck in between image data; will call builtin tiff class or bioformats plugin as a contingency for other tiff formats, though these are slower).
Further, I wrote a shortcut for tifftag reading, which assumes that tags don't change between tiffs, that provides a big speedup if the tags are evenly spaced.

Writing is mostly a wrapper function utilizing the solution written by R. Harkes, which I extended to handle bigtiffs in 2020 (It seems that another independent modification came to basically the same solution, which I discovered when finally posting this to github).
Writing speed will NOT be strictly linear with file size. The writing slows down with increasing frame number.

Rough benchmarks (will depend on your hardware. SSD highly recommended):

512x512x50000 uint16 tiff stack should read in about 2 minutes. Speed up is about 20% faster than bigread2.
(If tifftags are unevenly spaced as done by functions like saveastiff, may be slower and the same speed as bigread2).

The same data should write to disk in about 2.5 minutes.

Reading and writing should only be slightly slower than for binary files.
If tiff files are saved with FastTiffSave, they can be memory mapped in Matlab using the memory_map_tiff.m function!

If RAM on your device is too low to hold all image data in memory at the same time, you can load in chunks and directly use the
Fast_BigTiff_Write class to write in a loop.

All questions and comments to jms7008@med.cornell.edu
