function [imData,info]=bigread4(path_to_file,sframe,num2read,info,known_gap)
%[imData,info]=bigread4(path_to_file,sframe,num2read,info,known_gap)
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
%known_gap (optional) = gap between images in bytes (if known; this is really
%only available as an option in case the automatic calculation makes an
%error, which shouldn't happen).
%
%Output:
%imData=NxMxT array of same precision as file
%info=TiffTags and other identifying information (only for specified
%frames)
%
%Modification of bigread2, originally written by D. Peterka, and provided
%in CaImAn package under GNU license:
%https://github.com/flatironinstitute/CaImAn-MATLAB
% This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.
%
%Originally based on a partial solution posted on
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
    if nargin<4 || isempty(info)
        try
            [info]=readtifftags(path_to_file,num2read+sframe-1);%This tif reader assumes that FID info is identical for every image.
            % bps=sum(info.(byte_field))/(info.(size_fields{2})*info.(size_fields{1}));
            % info.BitDepth=8^bps;
            numFrames=length(info);
            fieldstoadd={'BitDepth','Width','Height'};
            fieldstomatch={'BitsPerSample','ImageWidth','ImageHeight'};
            for field_rep=1:3
                temp=num2cell(repmat(info(1).(fieldstomatch{field_rep}),numFrames,1),2);
                [info(1:numFrames).(fieldstoadd{field_rep})]=temp{:};
            end
        catch
            %%This is a slow step; if calling iteratively for the same file, allow for pre-loading info
            %%If we get to this point, the function is almost certainly going to
            %%fail, but let's give it a shot...
            info = imfinfo(path_to_file);
            blah=size(info);
            numFrames=blah(1);
        end
    else
        info=info(1:num2read+sframe-1);
        numFrames=length(info);
        %     numFrames=blah(1);
    end
    %deal with ImageJ BigTiff files:
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
        elseif numFrames==1 && num2read~=1 %ImageJ format
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
        sframe=numFrames;
        num2read=1;
        disp('Starting frame has to be less than number of total frames. Will read the last frame.');
    end
    if (num2read+sframe<= numFrames+1)
        lastframe=num2read+sframe-1;
    else
        num2read=numFrames-sframe+1;%currently this definition is not necessary, but want to forestall potential future issues by defining this correctly
        lastframe=numFrames;
        disp('Hmmm...just reading from starting frame until the end');
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
    if (bd==64)
        form='double';
        %         bps=8;
    elseif(bd==32)
        form='single';
        %         bps=4;
    elseif (bd==16)
        form='uint16';
        %         bps=2;
    elseif (bd==8)
        form='uint8';
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
                if strcmp(info(1).Compression,'Uncompressed')
                    compressedfile=0;
                end
            else
                if info(1).Compression==1
                    compressedfile=0;
                end
            end
        elseif isfield(info,'CompressionString')
            if strcmp(info(1).CompressionString,'NoCompression')
                compressedfile=0;
            end
        end
    else
        compressedfile=0;
    end
    fileprocessed=0;
    %     sframemsg = ['Reading from frame ',num2str(sframe),' to frame ',num2str(num2read+sframe-1),' of ',num2str(numFrames), ' total frames'];
    %     disp(sframemsg)
    if  ~compressedfile
        fp = fopen(path_to_file ,'rb',formatline);
        %     try

        % Use low-level File I/O to read the file

%         if ~isfield(info,'FileSize')
%             fseek(fp,0,'eof');
%             filesize = ftell(fp);
%         else
%             filesize=info.FileSize;
%         end
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
                uneven_flag=0;%%probably imagej file--let's assume even spacing;
            end
        else
            uneven_flag=2;
        end
        if ~uneven_flag
            if nargin<5 || isempty(known_gap)
                if isfield(info,'GapBetweenImages')
                    gapimages=max(0,info(1).GapBetweenImages);

                else
                    %rare that we will need to calculate gap, but added this just in
                    %case...
                    stripstarts=vertcat(info(1:end).(offset_field));
                    gapimages=nanmean(diff(stripstarts(:,1))-sum(info(1).(byte_field)));
                    if gapimages<0
                        gapimages=nanmean(diff(stripstarts(:,1))-(info(1).(byte_field)(1)));
                    end

                end
                if gapimages~=0
                    disp(['Gap Between Images Detected: ',num2str(gapimages),' Bytes'])
                end
            else
                gapimages=known_gap;
                disp(['Using Known Gap Between Images Detected: ',num2str(gapimages),' Bytes'])
            end
        else
            if uneven_flag==1
                disp('Data Unevenly Spaced. Tiff reading with Tiff class may be faster, but we will give it a go anyway...')
            end
            if nargin>4
                disp('Ignoring gap between images because it is not relevant.')
            end
        end

        %go to start of first strip
        switch off_type
            case 'strip'
                he_step=[he_w he_h];
            case 'tile'
                he_step=[he_w/t_per_w he_h/t_per_h];
                n_steps=[t_per_w t_per_h];
        end
        if ~uneven_flag
            fseek(fp, he+(sframe-1)*(gapimages+sum(info(1).(byte_field))), 'bof');
            if gapimages~=0

                if strcmpi(form,'uint16') || strcmpi(form,'uint8') || strcmpi(form,'single')
                    form=['*',form];
                    for cnt = sframe:lastframe
                        switch off_type
                            case 'strip'
                                imData(:,:,cnt-sframe+1)=fread(fp, he_step, form)';
                            case 'tile'
                                for read_rep_h=1:n_steps(2)
                                    for read_rep_w=1:n_steps(1)

                                        imData(1+(read_rep_h-1)*he_step(2):read_rep_h*he_step(2),1+(read_rep_w-1)*he_step(1):read_rep_w*he_step(1),cnt-sframe+1)=fread(fp, he_step, form)';
                                    end
                                end
                        end
                        if cnt~=lastframe
                            fseek(fp,gapimages,'cof');
                        end
                    end
                    %             imData(:,:,lastframe-sframe+1)=fread(fp, he_step, form)';

                elseif strcmpi(form,'double')
                    for cnt = sframe:lastframe
                        tmp1 = fread(fp, he_step, form)';
                        imData(:,:,cnt-sframe+1)=cast(tmp1,'single');
                        if cnt~=lastframe
                            fseek(fp,gapimages,'cof');
                        end
                    end
                    %                     tmp1 = fread(fp, he_step, form)';
                    %                     imData(:,:,lastframe-sframe+1)=cast(tmp1,'single');
                end
            else
                %Could read all of the information at once, but this turned out to
                %be slower and likely to give memory error for double data:
                %         he_step=[he_w*he_h*(lastframe-sframe+1)];
                %             if strcmpi(form,'uint16') || strcmpi(form,'uint8') || strcmpi(form,'single')
                %                 imData(:) = fread(fp, he_step, ['*',form]);
                % %                 imData(:)=cast(tmp1,form);
                % imData=permute(imData,[2 1 3]);
                %         elseif strcmpi(form,'double')
                %                     tmp1 = fread(fp, he_step, [form]);
                % %                     imData(:)=cast(tmp1,'single');
                % imData=permute(imData,[2 1 3]);
                %     end
                %         he_step=[he_w he_h];
                if strcmpi(form,'uint16') || strcmpi(form,'uint8') || strcmpi(form,'single')
                    form=['*',form];
                    %             for cnt = sframe:lastframe
                    %                 imData(:,:,cnt-sframe+1)=fread(fp, he_step, form)';
                    %             end
                    for cnt = sframe:lastframe
                        switch off_type
                            case 'strip'
                                imData(:,:,cnt-sframe+1)=fread(fp, he_step, form)';
                                fseek(fp,gapimages,'cof');
                            case 'tile'
                                for read_rep_h=1:n_steps(2)
                                    for read_rep_w=1:n_steps(1)

                                        imData(1+(read_rep_h-1)*he_step(2):read_rep_h*he_step(2),1+(read_rep_w-1)*he_step(1):read_rep_w*he_step(1),cnt-sframe+1)=fread(fp, he_step, form)';
                                    end
                                end
                        end
                    end
                elseif strcmpi(form,'double')
                    for cnt = sframe:lastframe
                        switch off_type
                            case 'strip'
                                tmp1 = fread(fp, he_step, form)';
                                imData(:,:,cnt-sframe+1)=cast(tmp1,'single');
                            case 'tile'
                                for read_rep_h=1:n_steps(2)
                                    for read_rep_w=1:n_steps(1)

                                        tmp1=fread(fp, he_step, form)';
                                        imData(1+(read_rep_h-1)*he_step(2):read_rep_h*he_step(2),1+(read_rep_w-1)*he_step(1):read_rep_w*he_step(1),cnt-sframe+1)=cast(tmp1,'single');
                                    end
                                end
                        end
                    end

                end
            end
            fclose(fp);
            %         display('Finished reading images')
        else
            %         he_step=[he_w he_h];
            if strcmpi(form,'uint16') || strcmpi(form,'uint8') || strcmpi(form,'single')
                form=['*',form];
                for cnt = sframe:lastframe
                    temp_off=info(cnt).(offset_field);
                    if ~isempty(temp_off)
                        fseek(fp,info(cnt).(offset_field)(1),'bof');
                        %                 imData(:,:,cnt-sframe+1)=fread(fp, he_step, form)';
                        switch off_type
                            case 'strip'
                                imData(:,:,cnt-sframe+1)=fread(fp, he_step, form)';
                            case 'tile'
                                for read_rep_h=1:n_steps(2)
                                    for read_rep_w=1:n_steps(1)

                                        imData(1+(read_rep_h-1)*he_step(2):read_rep_h*he_step(2),1+(read_rep_w-1)*he_step(1):read_rep_w*he_step(1),cnt-sframe+1)=fread(fp, he_step, form)';
                                    end
                                end
                        end
                    else
                        lastframe=cnt;
                    end
                end
            elseif strcmpi(form,'double')
                for cnt = sframe:lastframe
                    temp_off=info(cnt).(offset_field);
                    if ~isempty(temp_off)
                        switch off_type
                            case 'strip'
                                fseek(fp,info(cnt).(offset_field)(1),'bof');
                                tmp1 = fread(fp, he_step, form)';
                                imData(:,:,cnt-sframe+1)=cast(tmp1,'single');
                            case 'tile'
                                for read_rep_h=1:n_steps(2)
                                    for read_rep_w=1:n_steps(1)

                                        tmp1=fread(fp, he_step, form)';
                                        imData(1+(read_rep_h-1)*he_step(2):read_rep_h*he_step(2),1+(read_rep_w-1)*he_step(1):read_rep_w*he_step(1),cnt-sframe+1)=cast(tmp1,'single');
                                    end
                                end
                        end
                    else
                        lastframe=cnt;
                    end
                end
            end
            fclose(fp);
        end
        fileprocessed=1;
        if strncmp(off_type,'tile',4)
            imData=imData(1:info(1).(size_fields{2}),1:info(1).(size_fields{1}),:);
        end
        %     catch
        %         disp('Something went wrong. Will use Tiff class.');
        %     end
    else
        disp('File compressed. Will use Tiff class.');
    end
    if ~fileprocessed
        %%This is a slower implementation using the built-in Matlab tiff class,
        %%but it is overall more robust and can handle compressed files, so
        %%this will be our first backup plan. About 50% slower for some types of
        %%files.
        %If Tiff class fails, will try bioformats plugin.
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
            disp('File opening failed for unknown reasons. Will try to open with bioformats plugin as alternative.')
            if ~exist('bfopen.m','file')
                error('Please install bioformats plugin: https://www.openmicroscopy.org/bio-formats/downloads/');
            end
            data=bfopen(path_to_file);
            imData=cat(3,data{1}{:,1});
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
    if ~exist('bfopen.m','file')
        error('Please install bioformats plugin: https://www.openmicroscopy.org/bio-formats/downloads/');
    end
    data=bfopen(path_to_file);
    imData=cat(3,data{1}{:,1});
end
