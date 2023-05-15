function tiff_cut(filename,cut_size,save_dir,n_ch,which_ch,min_size)
%tiff_cut(filename,cut_size,save_dir,n_ch,which_ch,min_size)
%
%Cuts a tiff so the # of frames per file is cut_size, with a minimum size of min_size for the last two files
%
%INPUT:
%filename = tif file path
%cut_size = number of image in each output file (default: 1000); note that this should be the # of frames desired * n_ch
%save_dir = where to save new tifs (default: folder containing filename)
%n_ch = how many channels in the tif file (default: 1)
%which_ch = which channel to cut out (default: 1)
%min_size = specify minimum size of the last file (default: 0)
%
%If min_size > 1, then the last two files will be cut such that min_size is
%achieved for each file. If min_size>cut_size/2, you will get an error.
%
%If you want to cut up a multi-color tif and keep all of the colors, then
%specify n_ch=1 and which_ch=1 (defaults) and make sure cut_size is t*2
%where t is the number of time points that you want
%
%OUTPUT:
%none = files
%
if nargin<6 || isempty(min_size)
    min_size=0;
end
if min_size>cut_size/2
    error('Min_size not possible to achieve if it is more than half of the cut_size');
end
[folder,file,~]=fileparts(filename);
if nargin<3 || isempty(save_dir)
    save_dir=folder;
end
if nargin<2 || isempty(cut_size)
    cut_size=1000;
end
if mod(cut_size,n_ch)>0
    cut_size=floor(cut_size/n_ch)*n_ch;
    disp('cut_size is not divisible by the number of channels, so it will be decreased.');
end
if nargin<4 || isempty(n_ch)
    info=readtifftags(tif_file);
    if isfield(info,'ImageDescription')
        n_ch=str2double(char(info(1).ImageDescription(strfind(info(1).ImageDescription,'channels=')+9)));
    else
        n_ch=1;
    end
end
if nargin<5 || isempty(which_ch)
    which_ch=1:n_ch;
end
if length(which_ch)==n_ch
    n_ch=1;
end
try
    [m,~,info]=memory_map_tiff(filename,'matrix',n_ch);
    memmap=true;
catch
    [temp,info]=bigread4(filename);
indices=[];
for ch_in=which_ch(:)'
    indices=cat(2,indices,which_ch(ch_in):n_ch:size(temp,3));
end
indices=sort(indices);
    m.Data.allchans=temp(:,:,indices);
    memmap=false;
    clear temp;
end
numFrames=size(m.Data.allchans,3);
cut_size=cut_size*length(which_ch);
n_block=ceil(numFrames/cut_size);
h=info(1).ImageHeight;
block_sizes=[cut_size*ones(1,n_block-1) mod(numFrames,cut_size)];
block_sizes(block_sizes==0)=cut_size; % if perfect divisor, last number should be the cut_size, not 0
if min_size>1
    missingframes=min_size-block_sizes(end);
    if missingframes>0
        block_sizes(end)=min_size;
        block_sizes(end-1)=block_sizes(end-1)-missingframes;
    end
end
end_frames=cumsum(block_sizes);
start_frames=[1 end_frames(1:end-1)+1];
for block_rep=1:n_block
%     ins=1+(block_rep-1)*cut_size:min(block_rep*cut_size,numFrames);
ins=start_frames(block_rep):end_frames(block_rep);
    if ~memmap || n_ch==1 || length(which_ch)==n_ch
        data=m.Data.allchans(:,:,ins);
    else
channel_in=[];
for ch_in=which_ch(:)'
channel_in=cat(2,channel_in,(1:h)+h*(which_ch(ch_in)-1));
end
channel_in=sort(channel_in);
        data=m.Data.allchans(:,channel_in,ins);
    end
    if memmap
        data=permute(data,[2 1 3]);
    end
    FastTiffSave(data,fullfile(save_dir,[file,'_',num2str(block_rep,'%.5d'),'.tif']));
end