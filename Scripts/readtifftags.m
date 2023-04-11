function [info,n_tifs]=readtifftags(path_to_file,lasttag)
% Adapted from tiff_read_header, Written by D.Kroon 31-05-2012 (see
% copyright and license information below).
% Reads Tiff Headers for regular or Big Tiffs
% Assumes that all Tiffs have same header and does a fast method to figure
% out the number of frames
%
% Copyright (c) 2012, Dirk-Jan Kroon
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
% 
% * Redistributions of source code must retain the above copyright notice, this
%   list of conditions and the following disclaimer.
% 
% * Redistributions in binary form must reproduce the above copyright notice,
%   this list of conditions and the following disclaimer in the documentation
%   and/or other materials provided with the distribution
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
% FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
% DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
% CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
% OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
if nargin<2 || isempty(lasttag)
    lasttag=inf;
end
global FILESIZE BYTEORDER
fp = fopen(path_to_file ,'r','l');
fseek(fp,0,'eof');
FILESIZE = ftell(fp);
% Get the ByteOrder
fseek(fp,0,'bof');
ByteOrder= fread(fp,2,'char=>char')';
fclose(fp);
switch(ByteOrder)
    case 'II'
        fp = fopen(path_to_file,'r','l');
        BYTEORDER='little-endian';
    case 'MM'
        fp = fopen(path_to_file,'r','b');
        BYTEORDER='big-endian';
    otherwise
        fp = fopen(path_to_file,'r','l');
        BYTEORDER='little-endian';
end
i=1;
Dic{i}='254,NewSubfileType'; i=i+1;
Dic{i}='255,SubfileType'; i=i+1;
Dic{i}='256,ImageWidth'; i=i+1;
Dic{i}='257,ImageHeight'; i=i+1;
Dic{i}='258,BitsPerSample'; i=i+1;
Dic{i}='259,Compression'; i=i+1;
Dic{i}='262,PhotometricInterpretation'; i=i+1;
Dic{i}='263,Treshholding'; i=i+1;
Dic{i}='264,CellWidth'; i=i+1;
Dic{i}='265,CellLength'; i=i+1;
Dic{i}='266,FillOrder'; i=i+1;
Dic{i}='269,DocumentName'; i=i+1;
Dic{i}='270,ImageDescription'; i=i+1;
Dic{i}='271,Make'; i=i+1;
Dic{i}='272,Model'; i=i+1;
Dic{i}='273,StripOffsets'; i=i+1;
Dic{i}='274,Orientation'; i=i+1;
Dic{i}='277,SamplesPerPixel'; i=i+1;
Dic{i}='278,RowsPerStrip'; i=i+1;
Dic{i}='279,StripByteCounts'; i=i+1;
Dic{i}='280,MinSampleValue'; i=i+1;
Dic{i}='281,MaxSampleValue'; i=i+1;
Dic{i}='282,Xresolution'; i=i+1;
Dic{i}='283,Yresolution'; i=i+1;
Dic{i}='284,PlanarConfiguration'; i=i+1;
Dic{i}='285,PageName'; i=i+1;
Dic{i}='286,XPosition'; i=i+1;
Dic{i}='287,YPosition'; i=i+1;
Dic{i}='288,FreeOffsets'; i=i+1;
Dic{i}='289,FreeByteCounts'; i=i+1;
Dic{i}='290,GrayResponseUnit'; i=i+1;
Dic{i}='291,GrayResponseCurve'; i=i+1;
Dic{i}='292,T4Options'; i=i+1;
Dic{i}='293,T6Options'; i=i+1;
Dic{i}='296,ResolutionUnit'; i=i+1;
Dic{i}='297,PageNumber'; i=i+1;
Dic{i}='301,TransferFunction'; i=i+1;
Dic{i}='305,Software'; i=i+1;
Dic{i}='306,DateTime'; i=i+1;
Dic{i}='315,Artist'; i=i+1;
Dic{i}='316,HostComputer'; i=i+1;
Dic{i}='317,Predictor'; i=i+1;
Dic{i}='318,ColorImageType'; i=i+1;
Dic{i}='319,ColorList'; i=i+1;
Dic{i}='320,Colormap'; i=i+1;
Dic{i}='321,HalftoneHints'; i=i+1;
Dic{i}='322,TileWidth'; i=i+1;
Dic{i}='323,TileLength'; i=i+1;
Dic{i}='324,TileOffsets'; i=i+1;
Dic{i}='325,TileByteCounts'; i=i+1;
Dic{i}='326,BadFaxLines'; i=i+1;
Dic{i}='330,SubIFDs'; i=i+1;
Dic{i}='332,InkSet'; i=i+1;
Dic{i}='333,InkNames'; i=i+1;
Dic{i}='334,NumberOfInks'; i=i+1;
Dic{i}='336,DotRange'; i=i+1;
Dic{i}='337,TargetPrinter'; i=i+1;
Dic{i}='338,ExtraSamples'; i=i+1;
Dic{i}='339,SampleFormat'; i=i+1;
Dic{i}='340,SMinSampleValue'; i=i+1;
Dic{i}='341,SMaxSampleValue'; i=i+1;
Dic{i}='342,TransferRange'; i=i+1;
Dic{i}='343,ClipPath'; i=i+1;
Dic{i}='33432,Copyright'; i=i+1;
% Split the Dictonary in Tag-ID and Tag-Name-list
TagId=zeros(1,length(Dic));
TagName=cell(1,length(Dic));
for j=1:length(Dic)
    bytes=uint8(Dic{j});
    bytes(bytes==32)=[];
    n=find(bytes==44);
    TagId(j)=str2double(char(bytes(1:n(1)-1)));
    TagName{j}=char(bytes(n(1)+1:end));
end
%%get tiftags
fseek(fp,2,'bof');
version= fread(fp,1,'uint16=>uint16');
% Get Position of the first Header (image file directory)

% if ~imagejflag
if version==42
    firstfp = fread(fp,1,'uint32=>uint32');
    [info,NextIFD]=readIFD_42(fp,firstfp,TagId,TagName);
else
    fseek(fp,8,'bof');
    firstfp = fread(fp,1,'uint64=>uint64');
    [info,NextIFD]=readIFD_43(fp,firstfp,TagId,TagName);
end
if version==42
    form='*uint32';
    spacer=4;
elseif version==43
    form='*uint64';
    spacer=8;
end
current_pos=ftell(fp);
% sizeofeachentry=current_pos-firstfp-spacer;
n_tifs=1;
done_flag=0;
fp_off_new=NextIFD;
numtocheck=3;
if NextIFD~=0 && lasttag~=1
    buff_foff=[firstfp NextIFD zeros(1,numtocheck)];
    %     fseek(fp,NextIFD,'bof');
    for a=1:numtocheck
        fp_off=fp_off_new;
        n_tifs=n_tifs+1;
        if version==42
            [info(n_tifs),fp_off_new]=readIFD_42(fp,fp_off,TagId,TagName,info(1));
        elseif version==43
            [info(n_tifs),fp_off_new]=readIFD_43(fp,fp_off,TagId,TagName,info(1)); %%read this way just in case it is a short tiff and uneven FIDs, even though slightly slower
        end
        % info(n_tifs)=info(1);
        % info(n_tifs).StripOffsets=info_new.StripOffsets;
        if fp_off_new==0 || n_tifs>1e5
            done_flag=1;%reallyshorttiff
            buff_foff(n_tifs+1:end)=[];
            break
            
        elseif n_tifs==lasttag
            done_flag=1;%small number of frames requested
            buff_foff(n_tifs+1:end)=[];
            break
        else
            buff_foff(n_tifs+1)=fp_off_new;
            % fseek(fp,fp_off-ftell(fp),'cof');
        end
    end
    current_pos=ftell(fp);
    sizeofeachentry=current_pos-fp_off-spacer;
    if ~done_flag
        if isfield(info,'TileOffsets')
            offset_field='TileOffsets';
        elseif isfield(info,'StripOffsets')
            offset_field='StripOffsets';
        else
            error('Unrecognized offset format.');
        end
        fid_spacer=fp_off_new-ftell(fp);
        
        db=diff(buff_foff);
        
        try
            data_size=sum(info(1).StripByteCounts);
        catch
            
            data_size=info(1).ImageHeight*info(1).ImageWidth*sum(info(1).BitsPerSample)/8;
        end
        %%%check for logical arrangement of files: fid first, first interleaved, or
        %%%fid end.
        
        if all(db(2:end)==db(1))
            if db(2)>=data_size-1 %interleaved
                
                info(1).GapBetweenImages=double(db(2))-double(data_size);
                lowerlimit_frames=double(floor((FILESIZE-firstfp)/db(1)));
                lowerlimit_loc=NextIFD+double(db(2))*(lowerlimit_frames-2);
                n_tifs=lowerlimit_frames-1;
                fseek(fp,lowerlimit_loc,'bof');
            else %either all at the beginning or the end
                current_pos=ftell(fp);
                if version==42
                    [info2]=readIFD_42(fp,NextIFD,TagId,TagName);
                else
                    [info2]=readIFD_43(fp,NextIFD,TagId,TagName);
                end
                
                    info(1).GapBetweenImages=max(0,info2.(offset_field)(1)-info(1).(offset_field)(1)-data_size);
                    info(2).GapBetweenImages=info(1).GapBetweenImages;
                fseek(fp,fp_off_new,'bof');
            end
            %%can do this because even spacing:
            while 1
                n_tifs=n_tifs+1;
                fseek(fp,sizeofeachentry,'cof');
                fp_off=fread(fp,1,form);
                if isempty(fp_off)
                    warning('Tif tags are incomplete.');
				break
                end
                if  fp_off==0 || n_tifs==lasttag || fp_off<ftell(fp)
                    break
                else
                    fseek(fp,fid_spacer,'cof');
                end
            end
            mattoassign=info(2).(offset_field)(:)';
            len_offs=length(info(2).(offset_field));
            n_tifs=min(lasttag,n_tifs);
            info(2).GapBetweenImages=info(1).GapBetweenImages;
            info_old=info(1);
            info=repmat(info(2),n_tifs,1);
            info(1).(offset_field)=info_old.(offset_field);
            temp=mat2cell(repmat(mattoassign,n_tifs-1,1)+cumsum([0;repmat(double(data_size+info(1).GapBetweenImages),n_tifs-2,1)]),ones(1,n_tifs-1),len_offs);
            [info(2:n_tifs).(offset_field)]=temp{:};
        else
%             disp('Reading Tiff Info with unevenly spaced FIDs. This may take a while.')
            %%FIDS are uneven.
            %%Have to work harder here. This happens sometimes for tiffs written by
            %%imwrite...
            %     error('FIDs are not equally spaced.')
            preassign=min(200000,lasttag); %%largest number of frames you expect
            info(n_tifs+1:preassign)=info(1);
            fp_off=fp_off_new;
                while 1
                    n_tifs=n_tifs+1;
                    if version==42
                    [info(n_tifs),fp_off]=readIFD_42(fp,fp_off,TagId,TagName,info(1)); %%read this way just in case it is a short tiff and uneven FIDs, even though slightly slower
                    else
                    [info(n_tifs),fp_off]=readIFD_43(fp,fp_off,TagId,TagName,info(1));
                    end
                    if fp_off==0 || n_tifs>1e5 || n_tifs==lasttag
                        done_flag=1;
                        info(n_tifs+1:end)=[];%%delete the unnecessary pre-allocated info
                        if isempty(info(n_tifs).(offset_field))
                                info(end)=[];
                                n_tifs=n_tifs-1;
                        end
                        break
                    else
                        buff_foff(n_tifs+1)=fp_off;
                        fseek(fp,fp_off,'bof');
                    end
                end
                if length(info)>=3
                    check_even_images=[];
                    for im_rep=1:min(5,length(info))
                        check_even_images=[check_even_images info(im_rep).(offset_field)(1)];
                    end
                    db=diff(check_even_images);
                    if all(db(1)==db)
                        gap=db(1)-sum(info(1).StripByteCounts);
                        for rep=1:length(info)
                        info(rep).GapBetweenImages=gap;
                        end
                    end
                end
        end
        
        
    end
end

fclose(fp);

function [TiffInfo,NextIFD]=readIFD_42(fp,PositionIFD,TagId,TagName,previousinfo)
if nargin>4
    TiffInfo=previousinfo;
    fieldnames=fields(TiffInfo);
    for field_rep=1:length(fieldnames)
        TiffInfo.(fieldnames{field_rep})=[];
    end
else
    TiffInfo=struct();
end
global FILESIZE BYTEORDER
% Get number of Tags
fseek(fp,double(PositionIFD),'bof');
IfdLength=fread(fp,1,'uint16=>uint16');
% TiffInfo=struct();
TiffInfo.FileSize=FILESIZE;
TiffInfo.ByteOrder=BYTEORDER;
for j=1:IfdLength
    TagCode=fread(fp,1,'uint16=>uint16');
    TagType=fread(fp,1,'uint16=>uint16')';
    TagLength=fread(fp,1,'uint32=>uint32');
    
    switch(TagType)
        case 1 %byte
            nbyte=TagLength*1;
        case 2 % ASCII
            nbyte=TagLength*1;
        case 3 % Word
            nbyte=TagLength*2;
        case 4 % DWord - Uword
            nbyte=TagLength*4;
        case 5 % Rational (2 dwords, numerator and denominator)
            nbyte=TagLength*2*4;
        case 6 % 8-bit signed (twos-complement) integer.
            nbyte=TagLength;
        case 7 % A 8-bit byte undefined
            nbyte=TagLength*1;
        case 8 % 16-bit (2-byte) signed (twos-complement) integer.
            nbyte=TagLength*2;
        case 9 % A 32 bit(4-byte) signed (twos-complement) integer
            nbyte=TagLength*4;
        case 10 % Two SLONGs, numerator/denominator
            nbyte=TagLength*8;
        case 11 % Single precision (4-byte) IEEE format
            nbyte=TagLength*4;
        case 12 % Double precision (8-byte) IEEE format
            nbyte=TagLength*8;
        case 13 % uint32??
            nbyte=TagLength*4;
        otherwise
            error('Unknown Tag Type')
    end
    
    % If more bytes than 4, the data is stored
    % elsewhere in the file
    if(nbyte>4)
        TagDataOffset=fread(fp,1,'uint32=>uint32');
        cPos=ftell(fp);
        fseek(fp,double(TagDataOffset),'bof');
    end
    
    switch(TagType)
        case 1 %byte
            TagValue=fread(fp,TagLength,'uint8=>double');
        case 2 % ASCII
            TagValue=fread(fp,TagLength,'uint8=>uint8')';
            if(TagValue(end)==0), TagValue=TagValue(1:end-1); end
            TagValue=char(TagValue);
        case 3 % Word
            TagValue=fread(fp,TagLength,'uint16=>double');
        case 4 % DWord - Uword
            TagValue=fread(fp,TagLength,'uint32=>double');
        case 5 % Rational (2 dwords, numerator and denominator)
            TagValue=double(fread(fp,TagLength*2,'uint32=>double'));
            TagValue=TagValue(1:2:end)/TagValue(2:2:end);
        case 6 % An 8-bit (2-byte) signed (twos-complement) integer.
            TagValue=fread(fp,TagLength,'int8=>double');
        case 7 % A 8-bit byte undefined
            TagValue=fread(fp,TagLength,'uint8=>double');
        case 8 % 16-bit (2-byte) signed (twos-complement) integer.
            TagValue=fread(fp,TagLength,'int16=>double');
        case 9 % A 32 bit(4-byte) signed (twos-complement) integer
            TagValue=fread(fp,TagLength,'int32=>double');
        case 10 % Two SLONGs, numerator/denominator
            TagValue=double(fread(fp,TagLength*2,'int32=>double'));
            TagValue=TagValue(1:2:end)/TagValue(2:2:end);
        case 11 % Single precision (4-byte) IEEE format
            TagValue=fread(fp,TagLength,'single=>single');
        case 12 % Double precision (8-byte) IEEE format
            TagValue=fread(fp,TagLength,'double=>double');
        case 13
            TagValue=fread(fp,TagLength,'uint32=>double');
        otherwise
    end
    
    % If the data is less than 4 bytes it is zero padded
    % to 4 bytes
    if(nbyte<4)
        cPos=ftell(fp);
        fseek(fp,cPos+(4-nbyte),'bof');
    end
    
    % Go back from data position to tag positon
    if(nbyte>4)
        fseek(fp,cPos,'bof');
    end
    
    % Store Tag value in Struct will all tag-info
    n=find(TagId==TagCode);
    if(isempty(n))
        TiffInfo.( ['private_' num2str(TagCode)])=TagValue;
    else
        TName=TagName{n(1)};
        TiffInfo.(TName)=TagValue;
        
        % PhotometricInterpretation
        if(TagCode==262)
            switch(TagValue)
                case 0
                    TiffInfo.([TName 'String'])='GrayScaleWhite';
                case 1
                    TiffInfo.([TName 'String'])='GrayScaleBlack';
                case 2
                    TiffInfo.([TName 'String'])='RGB';
                case 3
                    TiffInfo.([TName 'String'])='PaletteColor';
                case 4
                    TiffInfo.([TName 'String'])='TransparencyMask';
                otherwise
                    TiffInfo.([TName 'String'])='Unknown';
            end
        end
        
        % Compression
        if(TagCode==259)
            switch(TagValue)
                case 1
                    TiffInfo.([TName 'String'])='NoCompression';
                case 2
                    TiffInfo.([TName 'String'])='Modified-Huffman-CCITT-Group3';
                case 3
                    TiffInfo.([TName 'String'])='Facsimile-compatible-CCITT-Group3';
                case 4
                    TiffInfo.([TName 'String'])='Facsimile-compatible-CCITT-Group4';
                case 5
                    TiffInfo.([TName 'String'])='LWZ';
                case 7
                    TiffInfo.([TName 'String'])='JPEG';
                case 8
                    TiffInfo.([TName 'String'])='ZIP';
                case 32773
                    TiffInfo.([TName 'String'])='PackBits';
                otherwise
                    TiffInfo.([TName 'String'])='Unknown';
            end
        end
    end
end
NextIFD=fread(fp,1,'uint32=>uint32');

function [TiffInfo,NextIFD]=readIFD_43(fp,PositionIFD,TagId,TagName,previousinfo)

if nargin>4
    TiffInfo=previousinfo;
    fieldnames=fields(TiffInfo);
    for field_rep=1:length(fieldnames)
        TiffInfo.(fieldnames{field_rep})=[];
    end
else
    TiffInfo=struct();
    
end
global FILESIZE BYTEORDER
% Get number of Tags
fseek(fp,double(PositionIFD),'bof');
IfdLength=fread(fp,1,'uint64=>uint64');
TiffInfo.FileSize=FILESIZE;
TiffInfo.ByteOrder=BYTEORDER;
% Read all Tags
for j=1:IfdLength
    TagCode=fread(fp,1,'uint16=>uint16');
    TagType=fread(fp,1,'uint16=>uint16')';
    TagLength=fread(fp,1,'uint64=>uint64');
    
    switch(TagType)
        case 1 %byte
            nbyte=TagLength*1;
        case 2 % ASCII
            nbyte=TagLength*1;
        case 3 % Word
            nbyte=TagLength*2;
        case 4 % DWord - Uword
            nbyte=TagLength*4;
        case 5 % Rational (2 dwords, numerator and denominator)
            nbyte=TagLength*2*4;
        case 6 % 8-bit signed (twos-complement) integer.
            nbyte=TagLength;
        case 7 % A 8-bit byte undefined
            nbyte=TagLength*1;
        case 8 % 16-bit (2-byte) signed (twos-complement) integer.
            nbyte=TagLength*2;
        case 9 % A 32 bit(4-byte) signed (twos-complement) integer
            nbyte=TagLength*4;
        case 10 % Two SLONGs, numerator/denominator
            nbyte=TagLength*8;
        case 11 % Single precision (4-byte) IEEE format
            nbyte=TagLength*4;
        case 12 % Double precision (8-byte) IEEE format
            nbyte=TagLength*8;
        case 13 % uint32??
            nbyte=TagLength*4;
        case 16
            nbyte=TagLength*8;
        case 17
            nbyte=TagLength*8;
        case 18
            nbyte=TagLength*8;
        otherwise
    end
    
    % If more bytes than 4, the data is stored
    % elsewhere in the file
    if(nbyte>8)
        TagDataOffset=fread(fp,1,'uint64=>uint64');
        cPos=ftell(fp);
        fseek(fp,double(TagDataOffset),'bof');
    end
    
    switch(TagType)
        case 1 %byte
            TagValue=fread(fp,TagLength,'uint8=>uint8');
        case 2 % ASCII
            TagValue=fread(fp,TagLength,'uint8=>uint8')';
            if(TagValue(end)==0), TagValue=TagValue(1:end-1); end
            TagValue=char(TagValue);
        case 3 % Word
            TagValue=fread(fp,TagLength,'uint16=>uint16');
        case 4 % DWord - Uword
            TagValue=fread(fp,TagLength,'uint32=>uint32');
        case 5 % Rational (2 dwords, numerator and denominator)
            TagValue=double(fread(fp,TagLength*2,'uint32=>uint32'));
            TagValue=TagValue(1:2:end)/TagValue(2:2:end);
        case 6 % An 8-bit (2-byte) signed (twos-complement) integer.
            TagValue=fread(fp,TagLength,'int8=>int8');
        case 7 % A 8-bit byte undefined
            TagValue=fread(fp,TagLength,'uint8=>uint8');
        case 8 % 16-bit (2-byte) signed (twos-complement) integer.
            TagValue=fread(fp,TagLength,'int16=>int16');
        case 9 % A 32 bit(4-byte) signed (twos-complement) integer
            TagValue=fread(fp,TagLength,'int32=>int32');
        case 10 % Two SLONGs, numerator/denominator
            TagValue=double(fread(fp,TagLength*2,'int32=>int32'));
            TagValue=TagValue(1:2:end)/TagValue(2:2:end);
        case 11 % Single precision (4-byte) IEEE format
            TagValue=fread(fp,TagLength,'single=>single');
        case 12 % Double precision (8-byte) IEEE format
            TagValue=fread(fp,TagLength,'double=>double');
        case 13
            TagValue=fread(fp,TagLength,'uint32=>uint32');
        case 16
            TagValue=fread(fp,TagLength,'uint64=>uint64');
        case 17
            TagValue=fread(fp,TagLength,'int64=>int64');
        case 18
            TagValue=fread(fp,TagLength,'uint64=>uint64');
        otherwise
    end
    
    % If the data is less than 8 bytes it is zero padded
    % to 8 bytes
    if(nbyte<8)
        cPos=ftell(fp);
        fseek(fp,cPos+(8-nbyte),'bof');
    end
    
    % Go back from data position to tag positon
    if(nbyte>8)
        fseek(fp,cPos,'bof');
    end
    
    % Store Tag value in Struct with all tag-info
    n=find(TagId==TagCode);
    if(isempty(n))
        TiffInfo.( ['private_' num2str(TagCode)])=double(TagValue);
    else
        TName=TagName{n(1)};
        if ~ischar(TagValue)
            TagValue=double(TagValue);
        end
        TiffInfo.(TName)=TagValue;
        % PhotometricInterpretation
        if(TagCode==262)
            switch(TagValue)
                case 0
                    TiffInfo.([TName 'String'])='GrayScaleWhite';
                case 1
                    TiffInfo.([TName 'String'])='GrayScaleBlack';
                case 2
                    TiffInfo.([TName 'String'])='RGB';
                case 3
                    TiffInfo.([TName 'String'])='PaletteColor';
                case 4
                    TiffInfo.([TName 'String'])='TransparencyMask';
                otherwise
                    TiffInfo.([TName 'String'])='Unknown';
            end
        end
        
        % Compression
        if(TagCode==259)
            switch(TagValue)
                case 1
                    TiffInfo.([TName 'String'])='NoCompression';
                case 2
                    TiffInfo.([TName 'String'])='Modified-Huffman-CCITT-Group3';
                case 3
                    TiffInfo.([TName 'String'])='Facsimile-compatible-CCITT-Group3';
                case 4
                    TiffInfo.([TName 'String'])='Facsimile-compatible-CCITT-Group4';
                case 5
                    TiffInfo.([TName 'String'])='LWZ';
                case 7
                    TiffInfo.([TName 'String'])='JPEG';
                case 8
                    TiffInfo.([TName 'String'])='ZIP';
                case 32773
                    TiffInfo.([TName 'String'])='PackBits';
                otherwise
                    TiffInfo.([TName 'String'])='Unknown';
            end
        end
    end
end
NextIFD=fread(fp,1,'uint64=>uint64');