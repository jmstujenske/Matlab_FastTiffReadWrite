function [imData,info]=bigread4(path_to_file,sframe,num2read,info)
%[imData,info]=bigread4(path_to_file,sframe,num2read,info)
%
%Only requires location of file as input. Default is to read the full file.
%imData=bigread4(path_to_file)
%
%If a second input is given, it reads that many frames from the start:
%imData=bigread4(path_to_file,num2read)
%Equivalent to: imData=bigread4(path_to_file,1,num2read);
%
%Inputs:
%path_to_file = location of image stack
%sframe (optional) = first frame to read
%num2read (optional) = number of frames to read (NOT LAST FRAME NUMBER)
%info (optional) = output of imfinfo(path_to_file) or readtifftags(path_to_file)
%(Note this is NOT equivalent to info output of this script if a frame subset is selected.)
%
%Output:
%imData=NxMxT array of same precision as file
%info=TiffTags and other identifying information (only for specified
%frames)
%
%reads tiff files in Matlab bigger than 4GB, allows reading from sframe to
%sframe+num2read-1 frames of the tiff - in other words, you can read page 200-
%300 without rading in from page 1. Originally based on a partial solution posted on
%Matlab Central (http://www.mathworks.com/matlabcentral/answers/108021-matlab-only-opens-first-frame-of-multi-page-tiff-stack)
%Darcy Peterka 2014, v1.0
%Darcy Peterka 2014, v1.1
%Darcy Peterka 2016, v1.2(bugs to dp2403@columbia.edu)
%Eftychios Pnevmatikakis 2016, v1.3 (added hdf5 support)
%
%Joseph Stujenske 2020, v1.0 modified to make the reader faster, incorporated
%ImageJ .Tif support, and added option to pass in "info" which is a structure
%with tiff tags, i.e. the output of info = imfinfo(path_to_file);
%imfinfo was replaced as the primary script for getting tiff tags, with a
%faster script, readtifftags.
%Reading tiff tags is a relatively slow step for large image stacks, and it
%is sometimes desired to repeatedly read chunks of frames from the same stack,
%in which case I advise preloading info and passing it in as the fourth input.
%
%Joseph Stujenske 2020, v1.1, added better error handling, calling Tiff
%Class in the event that data is compressed or there is something atypical
%about the file. Editted readtifftags to allow for unevenly spaced tiff
%tags and to output info in a similar format to imfinfo.
%bigread4 can now handle unevenly spaced FIDs, though builtin Tiff class is likely
%comparable speed or faster... Would consider replacing uneven FID support with
%tiff class call in the future, but the Tiff class still fails with
%BigTiffs.
%
%Joseph Stujenske 2021, v1.2, added compatibility with Tiffs that use Tiles
%rather than strips.
%
if ~exist(path_to_file,'file')
    error(['File ',path_to_file,' not found.'])
end
[~,~,ext] = fileparts(path_to_file);
if nargin==2 && ~isempty(sframe)
    num2read=sframe;
    sframe=1;
end
if nargin<2 || isempty(sframe)
    sframe = 1;
    num2read=inf;
end
if strcmpi(ext,'.tiff') || strcmpi(ext,'.tif')
    
    %get image info
    if nargin<4
        info=[];
    end
    if isempty(info)
        try
            [info]=readtifftags(path_to_file,num2read+sframe-1);%This tif reader assumes that FID info is identical for every image.
            % bps=sum(info.(byte_field))/(info.(size_fields{2})*info.(size_fields{1}));
            % info.BitDepth=8^bps;
            numFrames=length(info);
        catch
            %%This is a slow step; if calling iteratively for the same file, allow for pre-loading info
            %%If we get to this point, the function is almost certainly going to
            %%fail, but let's give it a shot...
            info = imfinfo(path_to_file);
            blah=size(info);
            numFrames=blah(1);
        end
        providedinfo=false;
    else
        providedinfo=true;
        numFrames=length(info);
    end
    if isfield(info,'ImageDescription')
        if contains(path_to_file,'.ome')
            imd=char(info(1).ImageDescription(:)');
            nZ=regexp(imd,'SizeZ="(\d*)', 'tokens');
            nC=regexp(imd,'SizeC="(\d*)', 'tokens');
            nT=regexp(imd,'SizeT="(\d*)', 'tokens');
            totalimages=str2double(nZ{1}{1})*str2double(nC{1}{1})*str2double(nT{1}{1});
            if totalimages>length(info)
                disp('OME file that did not parse correctly. Will try to open with bioformats plugin as alternative.')
                if ~exist('bfopen.m','file')
                    error('Please install bioformats plugin: https://www.openmicroscopy.org/bio-formats/downloads/');
                end
                data=bfopen(path_to_file);
                imData=cat(3,data{1}{:,1});
                return;
            end
        elseif numFrames==1 && num2read~=1
            numFramesStr = regexp(info(1).ImageDescription, 'images=(\d*)', 'tokens');
            if ~isempty(numFramesStr)
                numFrames = max(numFrames,str2double(numFramesStr{1}{1}));
            else
                numFramesStr = regexp(info(1).ImageDescription, 'frames=(\d*)', 'tokens');
                if ~isempty(numFramesStr)
                    numFrames = max(numFrames,str2double(numFramesStr{1}{1}));
                end
            end
        end
    end
    if providedinfo
        info=info(sframe:num2read+sframe-1);
        sframe=1;
        numFrames=length(info);
        %     numFrames=blah(1);
    end
                fieldstoadd={'BitDepth','Width','Height'};
            fieldstomatch={'BitsPerSample','ImageWidth','ImageHeight'};
            for field_rep=1:3
                temp=num2cell(repmat(info(1).(fieldstomatch{field_rep}),numFrames,1),2);
                [info(1:numFrames).(fieldstoadd{field_rep})]=temp{:};
            end
    if nargin<3 || isempty(num2read) || isinf(num2read)
        num2read=numFrames;
    end
    if sframe<=0
        sframe=1;
    end
    if num2read<1
        num2read=1;
    end
    if sframe>numFrames
        %         sframe=numFrames;
        %         num2read=1;
        disp('Starting frame has to be less than number of total frames. Returning empty.');
        imData=[];info=[];
        return;
    end
    if (num2read+sframe<= numFrames+1)
        lastframe=num2read+sframe-1;
    else
        num2read=numFrames-sframe+1;
        lastframe=numFrames;
        disp('More frames requested than exist. Reading to end of the file.');
    end
    bd=info(1).BitDepth;
    bo=strcmp(info(1).ByteOrder,'big-endian');
    if isfield(info,'StripOffsets')
        offset_field='StripOffsets';
        off_type='strip';
    elseif isfield(info,'TileOffsets')
        offset_field='TileOffsets';
        off_type='tile';
    else
        error('Neither strip nor tile format.')
    end
    he=info(1).(offset_field)(1);
    %finds the offset of each strip in the movie.  Image does not have to have
    %uniform strips, but needs uniform bytes per strip/row.
    if isfield(info,'Width')
        size_fields={'Width','Height'};
    elseif isfield(info,'ImageWidth')
        size_fields={'ImageWidth','ImageHeight'};
    else
        error('Size Tags not recognized.')
    end
    if isfield(info,'StripByteCounts')
        byte_field='StripByteCounts';
    elseif isfield(info,'TileByteCounts')
        byte_field='TileByteCounts';
    else
        error('Byte counts not found.')
    end
    switch off_type
        case 'strip'
            he_w=info(1).(size_fields{1});
            he_h=info(1).(size_fields{2});
        case 'tile'
            t_per_w=ceil(info(1).(size_fields{1})/info(1).TileWidth);
            t_per_h=ceil(info(1).(size_fields{2})/info(1).TileLength);
            he_w=t_per_w*info(1).TileWidth;
            he_h=t_per_h*info(1).TileLength;
    end
    if isfield(info,'SampleFormat')
        sf = info(1).SampleFormat;
    else
        sf=1;
    end
    if sf==4
        error('Unknown data format.')
    end
    switch lower(sf)
        case {char("two's complement signed integer")}
            sf=2;
        case {'unsigned integer'}
            sf=1;
        case {'ieee floating point'}
            sf=3;
        case {'undefined data format'}
            error('Unknown data format.')
    end
    
    if (bd==64)
        switch sf
            case 3
                form='double';
            case 2
                form='int64';
            case 1
                form='uint64';
        end
        %         bps=8;
    elseif(bd==32)
        switch sf
            case 3
                form='single';
            case 2
                form='int32';
            case 1
                form='uint32';
        end
        %         bps=4;
    elseif (bd==16)
        switch sf
            case 1
                form='uint16';
            case 2
                form='int16';
        end
        %         bps=2;
    elseif (bd==8)
        switch sf
            case 1
                form='uint8';
            case 2
                form='int8';
        end
        %         bps=1;
    end
    if strcmpi(form,'double')
        imData=zeros(he_h,he_w,lastframe-sframe+1,'single');
        if(bo)
            formatline='ieee-be.l64';
        else
            formatline='ieee-le.l64';
        end
    else
        imData=zeros(he_h,he_w,lastframe-sframe+1,form);
        if(bo)
            formatline='ieee-be';
        else
            formatline='ieee-le';
        end
    end
    compressedfile=1;
    if isfield(info,'Compression') || isfield(info,'CompressionString')
        if isfield(info,'Compression')
            if ischar(info(1).Compression)
                if strcmpi(info(1).Compression,'uncompressed') || strcmpi(info(1).Compression,'nocompression')
                    compressedfile=0;
                end
            else
                if info(1).Compression==1
                    compressedfile=0;
                end
            end
        elseif isfield(info,'CompressionString')
            if strcmpi(info(1).CompressionString,'nocompression')
                compressedfile=0;
            end
        end
    else
        compressedfile=0;
    end
    fileprocessed=0;
    %     sframemsg = ['Reading from frame ',num2str(sframe),' to frame ',num2str(num2read+sframe-1),' of ',num2str(numFrames), ' total frames'];
    %     disp(sframemsg)
    if ~compressedfile
        fp = fopen(path_to_file ,'rb',formatline);
        %     try
        
        % Use low-level File I/O to read the file
        
        if ~isfield(info,'FileSize')
            fseek(fp,0,'eof');
            filesize = ftell(fp);
        else
            filesize=info.FileSize;
        end
        switch off_type
            case 'strip'
                he_step=[he_w he_h];
                n_steps=[];
            case 'tile'
                he_step=[he_w/t_per_w he_h/t_per_h];
                n_steps=[t_per_w t_per_h];
        end
        % The StripOffsets field provides the offset to the first strip. Based on
        % the INFO for this file, each image consists of 1 strip.
        %First let's test if the data is evenly spaced...
        if numFrames>2
            if length(info)>1
                if info(2).(offset_field)(1)-he==info(3).(offset_field)(1)-info(2).(offset_field)(1)
                    uneven_flag=0;
                else
                    uneven_flag=1;
                end
            else
                uneven_flag=0;%%probably imagej 'bigtiff' --let's assume even spacing;
            end
        else
            uneven_flag=2;
        end
        if ~uneven_flag
            if isfield(info,'GapBetweenImages')
                gapimages=max(0,info(1).GapBetweenImages);
            else
                %rare that we will need to calculate gap, but added this just in
                %case...
                if length(info)==1 %imagej bigtiff
                    gapimages=0;
                else
                    stripstarts=vertcat(info(1:end).(offset_field));
                    gapimages=nanmean(diff(stripstarts(:,1))-sum(info(1).(byte_field)));
                    if gapimages<0
                        gapimages=nanmean(diff(stripstarts(:,1))-(info(1).(byte_field)(1)));
                    end
                end
            end
        end
        if ~uneven_flag
            fseek(fp, he+(sframe-1)*(gapimages+sum(info(1).(byte_field))), 'bof');
            if gapimages~=0
                [imData,lastframe]=read_data(fp,sframe,lastframe,form,he_step,imData,gapimages,off_type,n_steps,'even');
            else
                try
                    %reading with memory map is faster if the data is all
                    %in one block
                    m=memory_map_tiff(path_to_file,'matrix',1,[],numFrames);
                    imData=m.Data.allchans(:,:,sframe:min(end,sframe+num2read-1));
                    imData=permute(imData,[2 1 3]);
                    return;
                catch
                    [imData,lastframe]=read_data(fp,sframe,lastframe,form,he_step,imData,gapimages,off_type,n_steps,'even');
                end
            end
            
            %         display('Finished reading images')
        else
            [imData,lastframe]=read_data(fp,sframe,lastframe,form,he_step,imData,[],off_type,n_steps,'uneven',info,offset_field);
            
        end
        fclose(fp);
        fileprocessed=1;
        if strncmp(off_type,'tile',4)
            imData=imData(1:info(1).(size_fields{2}),1:info(1).(size_fields{1}),:);
        end
    else
        disp('File compressed. Will use Tiff class.');
    end
    if ~fileprocessed
        %%This is a slower implementation using the built-in Matlab tiff class,
        %%but it is overall more robust and can handle compressed files, so
        %%this will be our first backup plan. About 50% slower for some types of
        %%files.
        %If Tiff class fails, will try bioformats plugin.
        disp('Opening failed. Trying internal tiff class.')
        if exist('fp','var');fclose(fp);end
        try
            tiff_file=Tiff(path_to_file,'r');
            closeTiff = onCleanup(@() close(tiff_file));
            setDirectory(tiff_file, 1);
            for cnt = sframe:lastframe-1
                imData(:,:,cnt) = read(tiff_file);
                nextDirectory(tiff_file);
            end
            imData(:,:,lastframe) = read(tiff_file);
        catch
            disp('File opening failed. Trying bioformats plugin.')
            imData=try_bio(path_to_file);
        end
    end
    if length(info)>lastframe
        info(lastframe+1:end)=[];
    end
    info(1:sframe-1)=[]; %remove tiff tags for frames that were not requested
elseif strcmpi(ext,'.hdf5') || strcmpi(ext,'.h5')
    info = h5info(path_to_file);
    dims = info.GroupHierarchy.Datasets.Dims;
    if nargin < 2
        sframe = 1;
    end
    if nargin < 3
        num2read = dims(end)-sframe+1;
    end
    num2read = min(num2read,dims(end)-sframe+1);
    imData = h5read(path_to_file,'/mov',[ones(1,length(dims)-1),sframe],[dims(1:end-1),num2read]);
else
    %     error('Unknown file extension. Only .tiff and .hdf5 files are currently supported');
    disp('Uknown file extension. This function only has support for .tiff and .hdf5 files. Will call bioformats plugin.')
    imData=try_bio(path_to_file);
end

function imData=try_bio(path_to_file)
if ~exist('bfopen.m','file')
    error('Please install bioformats plugin: https://www.openmicroscopy.org/bio-formats/downloads/');
end
data=bfopen(path_to_file);
imData=cat(3,data{1}{:,1});

function [imData,lastframe]=read_data(fp,sframe,lastframe,form,he_step,imData,gapimages,off_type,n_steps,opt,info,offset_field)
if nargin<10 || isempty(opt)
    opt='even';
    info=[];
end
size_format=size(imData,1:2);
for cnt = sframe:lastframe
    switch opt
        case 'even'
            imData(:,:,cnt-sframe+1)=read_frame(fp,he_step,off_type,form,size_format);
            if cnt~=lastframe
                fseek(fp,gapimages,'cof');
            end
        case 'uneven'
            temp_off=info(cnt).(offset_field);
            if ~isempty(temp_off)
                fseek(fp,info(cnt).(offset_field)(1),'bof');
                imData(:,:,cnt-sframe+1)=read_frame(fp,he_step,off_type,form,size_format);
            else
                lastframe=cnt;
            end
    end
end


function imData_next=read_frame(fp,he_step,off_type,form,size_format,n_steps)
switch off_type
    case 'strip'
        if strcmpi(form,'double')
            tmp1 = fread(fp, he_step, form)';
            imData_next=cast(tmp1,'single');
        else
            imData_next=fread(fp, he_step, ['*',form])';
        end
    case 'tile'
        for read_rep_h=1:n_steps(2)
            for read_rep_w=1:n_steps(1)
                if strcmpi(form,'double')
                    imData_next=zeros(size_format,'single');
                    
                    imData_next(1+(read_rep_h-1)*he_step(2):read_rep_h*he_step(2),1+(read_rep_w-1)*he_step(1):read_rep_w*he_step(1),cnt-sframe+1)=cast(fread(fp, he_step, form)','single');
                else
                    imData_next=zeros(size_format,form);
                    
                    imData_next(1+(read_rep_h-1)*he_step(2):read_rep_h*he_step(2),1+(read_rep_w-1)*he_step(1):read_rep_w*he_step(1),cnt-sframe+1)=fread(fp, he_step, ['*',form])';
                end
            end
        end
end