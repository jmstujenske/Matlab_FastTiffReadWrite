# Package for managing large Tiffs in Matlab
Solution for dealing with large image stacks acquired for two photon calcium imaging.

![](https://github.com/jmstujenske/Matlab_FastTiffReadWrite/blob/main/Media/TiffViewer_scroll.gif)

Easily scroll through a 512x512x250,000 frame file, loaded in seconds.

![](https://github.com/jmstujenske/Matlab_FastTiffReadWrite/blob/main/Media/TiffViewer_ROI.png)

Then, quickly get time traces from custom drawn ROIs.


This is implemented in Matlab, and it includes great scripts for reading and writing uncompressed tiff files of all sizes.
Use **bigread4** for (relatively) quick reading and writing of tiff files into Matlab memory. Use **FastTiffSave** to save data from Matlab into a tiff stack quickly.
Then, use **memory_map_tiff** to read and write tiff files WITHOUT needing to hold the data in Matlab memory. This is *FAST*. You can load and manipulate a large file in *seconds*.
The **TiffViewer** allows for easily going through large tiffs, bin files, or matrices. It supports up to two colors and can get ROI time traces, mean images, and maximum projection images.
This loads things as fast as an ImageJ virtual stack, but with *MUCH FASTER* calculations.

# Further Information

## 1. Read / Write Functions:
 
bigread4.m -- reads standard and BigTiffs quickly; calls readtifftags.m

FastTiffSave.m -- saves standard and BigTiffs quickly; calls Fast_BigTiff_Write.m and Fast_Tiff_Write.m

Example usage:
imData=bigread4('C:\Users\Admin\Desktop\test.tif');
FastTiffSave(imData,'C:\Users\Admin\Desktop\test_copy.tif');

## 2. Memory mapping function:

memory_map_tiff -- memory map a tiff, to read quickly, like you could for a binary file
%Works for all tiffs saved by FastTiffSave, but will work for most other tiffs. Tiffs saved with Big-endian convention cannot be memory mapped, and an error will be thrown. A caveat is that the memory mapping can be done in two ways: as a large matrix (which has some advantages for certain manipulation of the data), or a structure with a single entry per frame. The matrix method will only work if the tiff tags are not embedded within the image data and the image data is written as one continuous chunk in the file. Functions like SaveasTiff, the builtin Tiff class, or standard Tiff libraries do not save the Tiffs this way, so you are limited to use the structure based method. This is not a problem with TiffViewer (see below).

Example usage:


_Example 1_

```Matlab
m = memory_map_tiff('test.tif',[],2);
channel1_frame1=m.Data(1).channel1;
```

_Example 2_

_Step 1: memory map the tif and get a projection_

```Matlab
m = memory_map_tiff('test.tif','matrix',2); #Note, the matrix data has the dimensions 1 and 2 swapped compared to image display due to how Tiff files are written.
mean_proj_twochannels=permute(mean(m.Data.allchans,3),[2 1 3]); #Mean Projection
```

_Step 2: extract the first channel from the memory mapped file and load into Matlab memory_

```Matlab
info = readtifftags('test.tif'); #Load tiff tags, quickly
tiff_height=info(1).ImageHeight;
allchannel1data=m.Data.allchans(:,1:tiff_height,:); 
```

## 3. Visualizing tiffs:

TiffViewer -- object class for viewing tiffs (like in ImageJ but much faster, images read virtually with memory mapping but not as slow to make projections like in ImageJ)

example usage:

tv=TiffViewer('test.tif'); %Figure will pop up to visualize the tiff

%Note, that this functions best if the tiff can be memory map-able as a structure (true of most tiffs written by other software and true of all tiffs written by FastTiffSave).



## Credits:

Reading based on bigread2 script by D. Peterka (modified by E. Pnevmatikakis, currently utilized in CaImAn package and others)


Writing based on solution by R. Harkes:
https://github.com/rharkes/Fast_Tiff_Write

Memory mapping uses innate Matlab functionality, and TiffViewer is custom written code built around memory mapping.


## More details:
This was written for use with large tiff stacks containing calcium imaging data but works for other applications.
Reading is optimized for uncompressed, grayscale tiff stacks. This improves on bigread2 by expanding functionality (e.g., tiffs can be written in tiles rather than just strips; deals with tiffs with tags stuck in between image data; will call builtin tiff class or bioformats plugin as a contingency for other tiff formats, though these are slower).
Further, I wrote a shortcut for tifftag reading, which assumes that tags don't change between tiffs, that provides a big speedup.

Writing is mostly a wrapper function utilizing the solution written by R. Harkes, which I extended to handle bigtiffs in 2020 (It seems that another independent modification came to basically the same solution, which I discovered when finally posting this to github).
Writing speed will NOT be strictly linear with file size. The writing slows down with increasing frame number. So, it is actually faster to save you data as multiple, smaller tiffs; however, subsequent analysis steps may become more problematic with this method. Please note that BigTiffs are not readable by many standard softwares that work with Tiffs, including certain Python packages.

Rough benchmarks (will depend on your hardware. SSD highly recommended):

512x512x50000 uint16 tiff stack should read in to Matlab memory in about 2 minutes with bigread4. Speed up is about 20% faster than bigread2.
(If tifftags are unevenly spaced as done by functions like saveastiff, may be the same speed as bigread2).

The same data should write to disk in about 2.5 minutes.

Reading and writing should be negligibly slower than for binary files, but with image data parameters saved.
If tiff files are saved with FastTiffSave, they can be memory mapped in Matlab using the memory_map_tiff.m function!

TiffViewer should be able to open the above tiff stack in about 5 seconds.

If RAM on your device is too low to hold all image data in memory at the same time and you want to write a tiff file, you can loop through holding chunks of the data in memory and directly use the
Fast_BigTiff_Write class to write in a loop. Look in the FastTiffSave code for how to use the class.

