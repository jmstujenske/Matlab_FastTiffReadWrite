classdef TiffViewer < handle
    %Class to view tiffs using memory mamping
    
    properties
        filename
        figure
        n_ch
        numFrames
        memmap_data
        fps
    end
    properties(Hidden = true)
        ax
        memmap
        listener
    end
    methods
        function obj = TiffViewer(filename)
            obj.memmap = memory_map_tiff(filename,[],[],true);
            obj.memmap_data=obj.memmap.Data;
            scaleval=.6;
            obj.figure=figure('Units','normalized','Position',[.1 .1 scaleval scaleval],'AutoResizeChildren','off','CloseRequestFcn',@(x,event) closefcn(x,event,obj));
            obj.n_ch=length(fieldnames(obj.memmap_data));
            info = readtifftags(filename);
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
                error('Current Frame above number of frames.');
            end
            if nargin<2 || isempty(frame)
                frame=data.CurrFrame;
            end
            for a=1:obj.n_ch
            imagesc(obj.ax{a},obj.memmap_data(frame).(['channel',num2str(a)])');
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