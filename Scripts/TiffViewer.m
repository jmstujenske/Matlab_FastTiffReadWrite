classdef TiffViewer < handle
    %Class to view tiffs using memory mamping
    %Sample usage:
    %tv=TiffViewer('test.tif');
    %
    %GUI fill popup and has intuitive controls.
    %
    %Controls:
    %
    %Play / Pause button - plays videos starting at current frame
    %scroll - scroll through video frames
    %Current Frame input - type in frame that you want to navigate to
    %Set FPS - set video speed in frames per second
    %ROI ts - prompts to draw an ROI and then plots the t-series. Can take
    %a while for large ROI
    %Max P - Maximum projection with a little noise removal first
    %Mean P - Mean projection
    %
    %Projections are currently capped at taking 30 seconds max to avoid
    %stalling Matlab.
    %
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
            [folder,file,ext]=fileparts(filename);
            if strcmp(ext,'.tif') || strcmp(ext,'.tiff')
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
            else
                uneven_flag=0;
            end
            if ~uneven_flag
                obj.map_type='mem';
                
                switch ext
                    case {'.tif','.tiff'}
                obj.memmap = memory_map_tiff(filename,[],n_ch,true);
                            width=info(1).ImageWidth;
            height=info(1).ImageHeight;
                    case '.bin'
                        userinputs=inputdlg({'Specify frame size as a matrix:','Number of channels:','data format:'});
                        framesize=eval(userinputs{1});
                        n_ch=str2double(userinputs{2});
                        form=userinputs{3};

                        
                        count=0;
                        for ch_rep=1:n_ch
                            count=count+1;
                            format_string(count,:)={form,framesize,['channel',num2str(ch_rep)]};
                        end
                        obj.memmap = memmapfile(filename, 'Format',format_string,'Writable',false);
                                    width=framesize(2);
                        height=framesize(1);
                    otherwise
                        error('File extension not recognized');
                end
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
                    if exist('info','var')
                    if isfield(info,'GapBetweenImages') && info(1).GapBetweenImages==0
                        obj.n_ch=length(fieldnames(obj.memmap_data));
                    else
                        obj.n_ch=length(fieldnames(obj.memmap_data))/2;
                    end
                    else
                        obj.n_ch=n_ch;
                    end
                case 'file'
                    obj.n_ch=n_ch;
            end
            obj.numFrames=length(obj.memmap_data);
            for rep=1:obj.n_ch
                obj.ax{rep}=uiaxes('Units','normalized','Parent',obj.figure,'Position',[0+(rep-1)*.5 0 .5 .89],'XTick',[],'YTick',[]);
                set(obj.ax{rep},'XLim',[1 width],'YLim',[1 height]);
            end
            myslider(obj);
            data=guidata(obj.figure);
            data.CurrFrame=1;
            obj.fps=30;
            data.timer=timer('ExecutionMode','fixedRate','TimerFcn',{@play_vid,obj},'Period',max(round(1/obj.fps,3),.001));
            guidata(obj.figure,data);
            disp_frame(obj)
            maxval=0;
                        switch obj.map_type
                case 'mem'
                    for a=1:obj.n_ch
                    maxval=max(maxval,max(obj.memmap_data(data.CurrFrame).(['channel',num2str(a)]),[],'all'));
                    end
                            case 'file'
                                for a=1:obj.n_ch
                                obj.memmap_data=(data.CurrFrame-1)*obj.n_ch+a;
                                fseek(obj.memmap.fid,diff([ftell(obj.memmap.fid),obj.memmap.idx(obj.memmap_data)]),'cof');
                                data=fread(obj.memmap.fid,obj.memmap.data_size,obj.memmap.form);
                                data=reshape(data,obj.memmap.frame_size)';
                                maxval=max(maxval,max(data,[],'all'));
                                end
                        end
                        set(obj.ax{a},'CLim',[0 maxval]);
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
                        obj.memmap_data=(data.CurrFrame-1)*obj.n_ch+a;
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
data.h.maxp = uicontrol('style','pushbutton','units','normalized','position',[.8 .9 .1 .05],'String','Max P','callback',{@(hObject,event) mm_proj(hObject,event,tv,'max')});
data.h.meanp = uicontrol('style','pushbutton','units','normalized','position',[.9 .9 .1 .05],'String','Mean P','callback',{@(hObject,event) mm_proj(hObject,event,tv,'mean')});
data.h.ROI = uicontrol('style','pushbutton','units','normalized','position',[.75 .9 .05 .05],'String','ROI ts','callback',{@(hObject,event) ROI_select(hObject,event,tv)});

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
function ROI_select(hOject,event,tv)
data=guidata(tv.figure);
    ax=gca;
if ~isfield(data,'ROI_precalc')
data.ROI_precalc.frame_size=size(ax.Children.CData');
[data.ROI_precalc.x,data.ROI_precalc.y]=ind2sub(data.ROI_precalc.frame_size,1:prod(data.ROI_precalc.frame_size));
end
data.ROI=drawpolygon(ax);
set(tv.figure, 'pointer', 'watch');
drawnow;
pixels=inpolygon(data.ROI_precalc.x,data.ROI_precalc.y,data.ROI.Position(:,1),data.ROI.Position(:,2));
pixel_mask=zeros(data.ROI_precalc.frame_size);
pixel_mask(pixels)=1;
pixel_mask=logical(pixel_mask);
z_series=zeros(tv.n_ch,tv.numFrames);
    for b=1:tv.n_ch
        for t=1:tv.numFrames
    z_series(b,t)=nanmean(tv.memmap_data(t).(['channel',num2str(b)])(pixel_mask));
        end
    end
figure;
colors={'r','g'};
    for b=1:tv.n_ch
plot(z_series(b,:),'-','Color',colors{b},'LineWidth',.5);
hold on;
plot(movmean(z_series(b,:),5),'k-','LineWidth',2);
hold on;
    end
    xlim([1 tv.numFrames]);
    box off;set(gca,'TickDir','out');
    
    delete(data.ROI);
    set(tv.figure, 'pointer', 'arrow');

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
function mm_proj(hObject,event,tv,type)
figure;
max_time=20;
    set(tv.figure, 'pointer', 'watch');
drawnow;
switch tv.map_type
    case 'mem'
        for a=1:tv.n_ch
            tic;
            subplot(1,tv.n_ch,a)

            switch type
                case 'mean'
                    P=(double(tv.memmap_data(1).(['channel',num2str(a)])))/tv.numFrames;
                    for b=2:length(tv.memmap_data);
                        P=P+double(tv.memmap_data(b).(['channel',num2str(a)]))/tv.numFrames;
                        if mod(b,1000)==0
                            imagesc(P');axis off;drawnow;
                        end
                        if toc>max_time/2
                            disp(['Max time reached for channel ',num2str(a),'.']);
                            break;
                        end
                    end
                    imagesc(P');axis off;

                case 'max'
                    P=tv.memmap_data(1).(['channel',num2str(a)]);
                    subsamp=5;
                    [n m]=size(P,1:2);
                    P=zeros(size(P));
                    temp_frames=zeros(n,m,subsamp,class(P));
                    for b=1:subsamp:length(tv.memmap_data)-subsamp+1;
                        for c=1:subsamp
                            temp_frames(:,:,c)=tv.memmap_data(b+(c-1)).(['channel',num2str(a)]);
                        end
                        P=max(P,median(temp_frames,3));
                        if mod(b,1000)<subsamp
                            imagesc(P');axis off;drawnow;
                        end
                        if toc>max_time/2
                            disp(['Max time reached for channel ',num2str(a),'.']);

                            break;
                        end
                    end
                    imagesc(P');axis off;

            end
        end
    case 'file'
        warning('Could not memory map, so projection would take too long.');
end
disp('Projection Done.');
set(tv.figure, 'pointer', 'arrow');

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