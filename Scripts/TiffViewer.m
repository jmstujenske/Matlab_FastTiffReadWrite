classdef TiffViewer < handle
    %Class to view tiffs using memory mamping
    
    properties
        filename
        figure
        n_ch
        numFrames
        memmap_data
        fps
        map_type
    end
    properties(Hidden = true)
        ax
        memmap
        listener
    end
    methods
        function obj = TiffViewer(filename,n_ch)
            if nargin<2
                n_ch=[];
            end
            info = readtifftags(filename);
            offset_field=get_offset_field(info);
            
            if length(info)>3
                if info(2).(offset_field)(1)-info(1).(offset_field)(1)==info(3).(offset_field)(1)-info(2).(offset_field)(1)
                    uneven_flag=0;
                else
                    uneven_flag=1;
                end
            else
                uneven_flag=1;
                warning('File cannot be memory mapped. Will read frames from file, which will be slow.');
            end
            if ~uneven_flag
                obj.map_type='mem';
            obj.memmap = memory_map_tiff(filename,[],n_ch,true);
            obj.memmap_data=obj.memmap.Data;
            else
                obj.map_type='file';
                obj.memmap = set_up_file(filename,info,n_ch);
                obj.memmap_data = 1;
            end
            scaleval=.6;
            obj.figure=figure('Units','normalized','Position',[.1 .1 scaleval scaleval],'AutoResizeChildren','off','CloseRequestFcn',@(x,event) closefcn(x,event,obj));
            switch obj.map_type
                case 'mem'
                    if isfield(info,'GapBetweenImages') && info(1).GapBetweenImages==0
                    obj.n_ch=length(fieldnames(obj.memmap_data));
                    else
                        obj.n_ch=length(fieldnames(obj.memmap_data))/2;
                    end
                case 'file'
                    obj.n_ch=map.n_ch;
            end
            obj.numFrames=length(info)/obj.n_ch;
            for rep=1:obj.n_ch
            obj.ax{rep}=uiaxes('Units','normalized','Parent',obj.figure,'Position',[0+(rep-1)*.5 0 .5 .89],'XTick',[],'YTick',[]);
            set(obj.ax{rep},'XLim',[1 info(1).ImageWidth],'YLim',[1 info(1).ImageHeight]);

            end
            myslider(obj);
            data=guidata(obj.figure);
            data.CurrFrame=1;
            obj.fps=30;
            data.timer=timer('ExecutionMode','fixedRate','TimerFcn',{@play_vid,obj},'Period',max(round(1/obj.fps,3),.001));
            guidata(obj.figure,data);
            disp_frame(obj)
        end
        
        function disp_frame(obj,frame)
            data=guidata(obj.figure);
            if data.CurrFrame>obj.numFrames
                data.CurrFrame=obj.numFrames;
%                 error('Current Frame above number of frames.');
            end
            if nargin<2 || isempty(frame)
                frame=min(max(data.CurrFrame,1),obj.numFrames);
            end
            for a=1:obj.n_ch
            switch obj.map_type
                case 'mem'
                    imagesc(obj.ax{a},obj.memmap_data(frame).(['channel',num2str(a)])');
                case 'file'
                    obj.memmap_data=(obj.CurrFrame-1)*n_ch+a;
                    fseek(obj.memmap.fid,diff([ftell(obj.memmap.fid),obj.memmap.idx(obj.memmap_data)]),'cof');
                    data=fread(obj.memmap.fid,obj.memmap.data_size,obj.memmap.form);
                    data=reshape(data,obj.memmap.frame_size)';
                    imagesc(data);
            end
            end
            guidata(obj.figure,data);
        end
    end
end

function myslider(tv)
data=guidata(tv.figure);
data.h.slide = uicontrol('style','slider','units','normalized','position',[0.05 .9 .5 .05],'Parent',tv.figure,'Max',tv.numFrames,'Min',1,'Value',1,'SliderStep',[1, 1] / (tv.numFrames - 1));
data.h.edit = uicontrol('style','edit','units','normalized','position',[.57 .9 .05 .05],'Parent',tv.figure,'Max',1,'Min',1,'String',num2str(1),'callback',{@(hObject, event) makeplot2(hObject, event,tv)});
data.h.play = uicontrol('style','pushbutton','units','normalized','position',[0 .9 .05 .05],'String','>','callback',{@(hObject,event) play_but_down(hObject,event,tv)});
data.h.setfps = uicontrol('style','pushbutton','units','normalized','position',[.65 .9 .1 .05],'String','Set FPS','callback',{@(hObject,event) fps_but_down(hObject,event,tv)});
guidata(tv.figure,data);
tv.listener=addlistener(data.h.slide,'ContinuousValueChange',@(hObject, event) makeplot(hObject, event,tv));
end

function makeplot(hObject,event,tv)
data=guidata(tv.figure);
data.CurrFrame=round(get(hObject,'Value'));
set(data.h.edit,'String',num2str(data.CurrFrame));
guidata(tv.figure,data);
disp_frame(tv);
end

function makeplot2(hObject,event,tv)
data=guidata(tv.figure);
curval=get(hObject,'String');
try
data.CurrFrame=max(min(round(str2double(get(hObject,'String'))),tv.numFrames),1);
hObject.String=num2str(data.CurrFrame);
catch
    hObject.String=curval;
    return;
end
set(data.h.slide,'Value',data.CurrFrame);
disp_frame(tv);
guidata(tv.figure,data);
end

function fps_but_down(hObject,event,tv)
answer=inputdlg('Input FPS for Video Playback');
tv.fps=str2double(answer{1});
end

function play_but_down(hObject,event,tv)
data=guidata(tv.figure);
if data.CurrFrame~=tv.numFrames
set(data.timer,'Period',max(round(1/tv.fps,3),.001),'TimerFcn',{@play_vid,tv});
start(data.timer);
guidata(tv.figure,data);
set(hObject,'callback',@(x,evt) stop_but_down(x,evt,tv));
set(hObject,'String','=');
end
end

function play_vid(hObject,event,tv)
data=guidata(tv.figure);
if data.CurrFrame~=tv.numFrames
data.CurrFrame=data.CurrFrame+1;
else
    stop(hObject);
    return;
end
data.h.slide.Value=data.CurrFrame;
data.h.edit.String=num2str(data.CurrFrame);
disp_frame(tv);
if data.CurrFrame==tv.numFrames
    stop(hObject);
end
guidata(tv.figure,data);
end

function stop_but_down(hObject,event,tv)
data=guidata(tv.figure);
stop(data.timer);
set(hObject,'callback',@(x,evt) play_but_down(x,evt,tv));
set(hObject,'String','>');
guidata(tv.figure,data);
end
function closefcn(obj,event,tv)
data=guidata(tv.figure);
delete(tv.listener)
stop(data.timer);
delete(obj);
delete(tv);
end
function map=set_up_file(filename,info,n_ch);
offset_field=get_offset_field(info);
map.idx=zeros(length(info),1);
for rep=1:length(map.idx)
map.idx(rep)=info(rep).(offset_field)(1);
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
        map.n_ch=str2double(char(info(1).ImageDescription(strfind(info(1).ImageDescription,'channels=')+9)));
        else
            map.n_ch=1;
        end
    else
        map.n_ch=n_ch;
    end
bd=info(1).BitsPerSample;
    if (bd==64)
        map.form='double';
        %         bps=8;
    elseif(bd==32)
        map.form='single';
        %         bps=4;
    elseif (bd==16)
        map.form='uint16';
        %         bps=2;
    elseif (bd==8)
        map.form='uint8';
        %         bps=1;
    end
    map.frame_size=[info(1).(size_fields{1}) info(1).(size_fields{2})];
    map.data_size=prod(map.frame_size);
    map.byte_size=map.data_size*bd/8;
    map.fid=fopen(filename,'r');
    fseek(map.fid,map.idx(1),'bof');
end
function offset_field=get_offset_field(info)
if isfield(info,'StripOffsets')
    offset_field='StripOffsets';
elseif isfield(info,'TileOffsets')
    offset_field='TileOffsets';
else
    error('Neither strip nor tile format.')
end
end