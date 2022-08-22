classdef TiffViewer < handle
    %Class to view tiffs using memory mamping
    
    properties
        filename
        memmap
        figure
        n_ch
        numFrames
        memmap_data
        ax
    end
    
    methods
        function obj = TiffViewer(filename)
            obj.memmap = memory_map_tiff(filename);
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
            data.CurrFrame=1;
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
h.slide = uicontrol('style','slider','units','normalized','position',[0 .9 .5 .05],'Parent',tv.figure,'Max',tv.numFrames,'Min',1,'Value',1,'SliderStep',[1, 1] / (tv.numFrames - 1));
h.edit = uicontrol('style','edit','units','normalized','position',[.52 .9 .05 .05],'Parent',tv.figure,'Max',1,'Min',1,'String',num2str(1),'callback',{@(hObject, event) makeplot2(hObject, event,h.slide,tv)});
addlistener(h.slide,'ContinuousValueChange',@(hObject, event) makeplot(hObject, event,h.edit,tv));
end

function makeplot(hObject,event,hedit,tv)
data=guidata(tv.figure);
data.CurrFrame=round(get(hObject,'Value'));
set(hedit,'String',num2str(data.CurrFrame));
disp_frame(tv);
guidata(tv.figure,data);
end

function makeplot2(hObject,event,hslide,tv)
data=guidata(tv.figure);
curval=get(hObject,'String');
try
data.CurrFrame=max(min(round(str2double(get(hObject,'String'))),tv.numFrames),1);
hObject.String=num2str(data.CurrFrame);
catch
    hObject.String=curval;
    return;
end
set(hslide,'Value',data.CurrFrame);
disp_frame(tv);
guidata(tv.figure,data);
end

function closefcn(obj,event,tv)
delete(tv);
delete(obj);
end