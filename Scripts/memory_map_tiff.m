function [m,n_ch]=memory_map_tiff(filename,opt,n_ch,read_only)
%m=memory_map_tiff(filename,opt)
%Memory map output of FastTiffSave
%
%Input:
%filename
%opt - 'channels' or 'matrix'
%channels splits up each frame per channel
%matrix concatenates the two channels into a large matrix
%
%n_ch - number of channels (default: found in imagedescription, else 1)
%read_only - default: false;
%
%Output:
%m - memory map

if nargin<2 || isempty(opt)
    opt='channels';
end
if nargin<4 || isempty(read_only)
    read_only=false;
end
info=readtifftags(filename);
  if isfield(info,'StripOffsets')
        offset_field='StripOffsets';
    elseif isfield(info,'TileOffsets')
        offset_field='TileOffsets';
    else
        error('Neither strip nor tile format.')
  end
offset=info(1).(offset_field)(1);
bd=info(1).BitsPerSample;
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
        rep=length(info)/n_ch;
        case 'matrix'
            if isfield(info,'GapBetweenImages')
                if info(1).GapBetweenImages>0
                    error('Cannot matrix map with this file format. The data is not a continguous block.');
                end
            end
      format_string={form,[info(1).(size_fields{1}) info(1).(size_fields{2})*n_ch length(info)/n_ch],'allchans'};

rep=1;
    end
        m = memmapfile(filename, 'Offset', offset, 'Format',format_string,'Writable',~read_only,'Repeat',rep);
