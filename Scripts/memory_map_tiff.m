function [m,n_ch,info]=memory_map_tiff(filename,opt,n_ch,read_only,numFrames)
%m=memory_map_tiff(filename,opt,n_ch,read_only,numFrames)
%Memory map output of FastTiffSave
%
%Input:
%filename
%opt - 'channels' or 'matrix'
%channels splits up each frame per channel
%matrix concatenates the two channels into a large matrix
%
%n_ch - number of channels (default: found in imagedescription, else 1)
%
%read_only - optional; default: false;
%
%numFrames - optional; default: read from tifftags
%
%Output:
%m - memory map

if nargin<2 || isempty(opt)
    opt='channels';
end
if nargin<4 || isempty(read_only)
    read_only=false;
end


if nargin<5 || isempty(numFrames)
    info=readtifftags(filename);
    numFrames=length(info);
else
    info=readtifftags(filename,1);
end
  if isfield(info,'StripOffsets')
        offset_field='StripOffsets';
    elseif isfield(info,'TileOffsets')
        offset_field='TileOffsets';
    else
        error('Neither strip nor tile format.')
  end
offset=info(1).(offset_field)(1);
bd=info(1).BitsPerSample;
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
    if isfield(info,'Width')
        size_fields={'Width','Height'};
    elseif isfield(info,'ImageWidth')
        size_fields={'ImageWidth','ImageHeight'};
    else
        error('Size Tags not recognized.')
    end
    if nargin<3 || isempty(n_ch)
    if isfield(info,'ImageDescription')
    n_ch=str2double(char(info(1).ImageDescription(strfind(info(1).ImageDescription,'channels=')+9)));
    else
        n_ch=[];
    end
    end
    if isempty(n_ch) || isnan(n_ch);n_ch=1;end
    
    switch opt
        case 'channels'
        if isfield(info,'GapBetweenImages') && info(1).GapBetweenImages>0
            format_string=cell(n_ch*2,3);
            gap=info.GapBetweenImages;
        else
            format_string=cell(n_ch,3);
            gap=0;
        end
    count=0;
    for ch_rep=1:n_ch
        count=count+1;
        format_string(count,:)={form,[info(1).(size_fields{1}) info(1).(size_fields{2})],['channel',num2str(ch_rep)]};
        if gap>0
            count=count+1;
            format_string(count,:)={'uint8',gap,['gap',num2str(ch_rep)]};
        end
    end
        rep=numFrames/n_ch;
        case 'matrix'
            if isfield(info,'GapBetweenImages')
                if info(1).GapBetweenImages>0
                    error('Cannot matrix map with this file format. The data is not a continguous block.');
                end
            end
      format_string={form,[info(1).(size_fields{1}) info(1).(size_fields{2})*n_ch numFrames/n_ch],'allchans'};

        rep=1;
    end
        m = memmapfile(filename, 'Offset', offset, 'Format',format_string,'Writable',~read_only,'Repeat',rep);
