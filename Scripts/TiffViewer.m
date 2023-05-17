classdef TiffViewer < handle
    %Class to view tiffs using memory mapping
    %tv=TiffViewer(input,n_ch);
    %
    %input = .tif file path, .bin file path, or matrix
    %
    %n_ch = number of channels in the file (default behavior: will try to
    %determine from the file, if possible; if not, 1).
    %
    %GUI will popup and has intuitive controls.
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
        memmap_matrix_data
        fps
        map_type
        max_time=20;
        type
    end
    properties(Hidden = true)
        ax
        memmap
        memmap_matrix
        listener
    end
    methods
        function obj = TiffViewer(filename,n_ch)
            if nargin<2
                n_ch=[];
            end
            if nargin<1 || isempty(filename)
                filename=uigetfile({'*.tif;*.tiff'});
                if isempty(n_ch)
                    userinputs=inputdlg({'Number of channels:'});
                    n_ch=str2double(userinputs{1});
                end
            end
            if ischar(filename)
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
                        uneven_flag=0;
                        %                 warning('File cannot be memory mapped. Will read frames from file, which will be slow.');
                    end
                else
                    uneven_flag=0;
                end
                if ~uneven_flag || strcmp(ext,'.bin')
                    obj.map_type='mem';

                    switch ext
                        case {'.tif','.tiff'}
                            obj.memmap = memory_map_tiff(filename,[],n_ch,true);
                            if isfield(info,'GapBetweenImages') && info(1).GapBetweenImages==0
                                obj.memmap_matrix = memory_map_tiff(filename,'matrix',n_ch,true);
                                obj.memmap_matrix_data = obj.memmap_matrix.Data.allchans;
                            end
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
                            obj.memmap_matrix = memmapfile(filename,'Format',{form,[framesize length(obj.memmap.Data)],'allchans'},'Writable',false);
                            obj.memmap_matrix_data = obj.memmap_matrix.Data.allchans;
                            obj.type='binary';
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
            elseif isnumeric(filename)
                if isempty(n_ch)
                    n_ch=1;
                end
                filename=permute(filename,[2 1 3]);
                [height width numFrames]=size(filename);

                data=[];
                ch_names=cell(1,n_ch);
                for ch_rep=1:n_ch
                    data=cat(2,data,squeeze((mat2cell(filename(:,:,ch_rep:n_ch:end),height,width,ones(size(filename,3)/n_ch,1)))));
                    ch_names(ch_rep)={['channel',num2str(ch_rep)]};
                end
                obj.memmap_data=cell2struct(data,ch_names,2)';
                obj.map_type='mem';
                file='matrix';
                ext=[];
            else
                error('Input type not recognized.')
            end
            scaleval=.6;
            obj.figure=figure('Units','normalized','Position',[.1 .1 scaleval scaleval],'AutoResizeChildren','off','CloseRequestFcn',@(x,event) closefcn(x,event,obj),'Name',[file,ext],'NumberTitle','off');
            switch obj.map_type
                case 'mem'
                    if exist('info','var')
                        if isfield(info,'GapBetweenImages') && info(1).GapBetweenImages==0
                            obj.n_ch=length(fieldnames(obj.memmap_data));
                        elseif length(info)>2
                            obj.n_ch=length(fieldnames(obj.memmap_data))/2;
                        else
                            obj.n_ch=length(fieldnames(obj.memmap_data));
                        end
                    else
                        obj.n_ch=n_ch;
                    end
                case 'file'
                    obj.n_ch=n_ch;
            end
            obj.numFrames=length(obj.memmap_data);
            for rep=1:obj.n_ch
                obj.ax{rep}=axes('Units','normalized','Parent',obj.figure,'Position',[0+(rep-1)*.5 0 .5 .89],'XTick',[],'YTick',[]);
                set(obj.ax{rep},'XLim',[1 width],'YLim',[1 height]);
            end
            linkaxes(cat(1,obj.ax{:}));
            myslider(obj);
            data=guidata(obj.figure);
            data.increment=1;
            data.CurrFrame=1;
            obj.fps=30;
            data.timer=timer('ExecutionMode','fixedRate','TimerFcn',{@play_vid,obj},'Period',max(round(1/obj.fps,3),.001));
            guidata(obj.figure,data);
            disp_frame(obj,[],1);
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

        function disp_frame(obj,frame,opt)
            if nargin<3 || isempty(opt)
                opt=0;
            end
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
                        if opt==0
                            if strcmp(obj.type,'binary')
                                set(obj.ax{a}.Children,'CData',obj.memmap_data(frame).(['channel',num2str(a)]));
                            else
                            set(obj.ax{a}.Children,'CData',obj.memmap_data(frame).(['channel',num2str(a)])');
                            end
                            %                         set(obj.ax{a},'XTick',[],'YTick',[])
                        else
                            if strcmp(obj.type,'binary')
                                                            imagesc(obj.ax{a},obj.memmap_data(frame).(['channel',num2str(a)]));

                            else
                                                            imagesc(obj.ax{a},obj.memmap_data(frame).(['channel',num2str(a)])');

                            end
                            set(obj.ax{a},'XTick',[],'YTick',[])
                            colormap('gray');
                        end
                    case 'file'
                        obj.memmap_data=(data.CurrFrame-1)*obj.n_ch+a;
                        fseek(obj.memmap.fid,diff([ftell(obj.memmap.fid),obj.memmap.idx(obj.memmap_data)]),'cof');
                        data=fread(obj.memmap.fid,obj.memmap.data_size,obj.memmap.form);
                        data=reshape(data,obj.memmap.frame_size)';
                        if opt==0
                            set(obj.ax{a}.Children,'CData',data');
                            %                         set(obj.ax{a},'XTick',[],'YTick',[])
                        else
                            imagesc(obj.ax{a},data');
                            set(obj.ax{a},'XTick',[],'YTick',[])
                        end
                end
            end
            guidata(obj.figure,data);
        end
        function allimages=mm_proj(obj,type)
            allimages=mm_proj([],[],obj,type);
        end
    end
end

function myslider(tv)
data=guidata(tv.figure);
data.h.slide = uicontrol('style','slider','units','normalized','position',[0.05 .92 .5 .05],'Parent',tv.figure,'Max',tv.numFrames,'Min',1,'Value',1,'SliderStep',[1, 1] / (max(tv.numFrames,2) - 1));
data.h.edit = uicontrol('style','edit','units','normalized','position',[.57 .92 .05 .05],'Parent',tv.figure,'Max',1,'Min',1,'String',num2str(1),'callback',{@(hObject, event) makeplot2(hObject, event,tv)});
data.h.play = uicontrol('style','pushbutton','units','normalized','position',[0 .92 .05 .05],'String','>','callback',{@(hObject,event) play_but_down(hObject,event,tv)});
data.h.setfps = uicontrol('style','pushbutton','units','normalized','position',[.65 .92 .1 .05],'String','Set FPS','callback',{@(hObject,event) fps_but_down(hObject,event,tv)});
data.h.maxp = uicontrol('style','pushbutton','units','normalized','position',[.8 .92 .1 .05],'String','Max P','callback',{@(hObject,event) mm_proj(hObject,event,tv,'max')});
data.h.meanp = uicontrol('style','pushbutton','units','normalized','position',[.9 .92 .1 .05],'String','Mean P','callback',{@(hObject,event) mm_proj(hObject,event,tv,'mean')});
data.h.ROI = uicontrol('style','pushbutton','units','normalized','position',[.75 .92 .05 .05],'String','ROI ts','callback',{@(hObject,event) ROI_select(hObject,event,tv)});
if tv.numFrames==1
    data.h.slide.Visible=false;
    data.h.play.Visible=false;
    data.h.setfps.Visible=false;
end
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
    if strcmp(tv.type,'binary')
         data.ROI_precalc.frame_size=size(ax.Children.CData);
             [data.ROI_precalc.y,data.ROI_precalc.x]=ind2sub(data.ROI_precalc.frame_size,1:prod(data.ROI_precalc.frame_size));

    else
        data.ROI_precalc.frame_size=size(ax.Children.CData');
            [data.ROI_precalc.x,data.ROI_precalc.y]=ind2sub(data.ROI_precalc.frame_size,1:prod(data.ROI_precalc.frame_size));

    end
end
data.ROI=drawpolygon(ax);
set(tv.figure, 'pointer', 'watch');

drawnow;
pixels=inpolygon(data.ROI_precalc.x,data.ROI_precalc.y,data.ROI.Position(:,1),data.ROI.Position(:,2));
pixel_mask=zeros(data.ROI_precalc.frame_size);
pixel_mask(pixels)=1;
pixel_mask=logical(pixel_mask);
z_series=zeros(tv.n_ch,tv.numFrames);
if isempty(tv.memmap_matrix_data)
    for b=1:tv.n_ch
        for t=1:tv.numFrames
            z_series(b,t)=nanmean(tv.memmap_data(t).(['channel',num2str(b)])(pixel_mask));
        end
    end
else
    for b=1:tv.n_ch
        ins=find(pixel_mask(:));
        z_series(b,:)=mean(tv.memmap_matrix_data(ins+(b-1)*numel(pixel_mask)+(0:tv.numFrames-1)*numel(pixel_mask)*tv.n_ch),1);
    end
end
f_out=figure;
set(f_out, 'pointer', 'watch');
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
set(f_out, 'pointer', 'arrow');

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
guidata(tv.figure,data);
disp_frame(tv);
end

function fps_but_down(hObject,event,tv)
data=guidata(tv.figure);
answer=inputdlg('Input FPS for Video Playback');
tv.fps=str2double(answer{1});
guidata(tv.figure,data);

end
function allimages=mm_proj(~,~,tv,type)
color_name={'Red','Green','Blue'};
f_out=figure;
max_time=tv.max_time;
set(tv.figure, 'pointer', 'watch');
set(f_out, 'pointer', 'watch');

drawnow;
if tv.n_ch>1
    n_subplots=tv.n_ch+1;
else
    n_subplots=tv.n_ch;
end
sub_handle_popup=zeros(1,n_subplots);
P=cell(1,tv.n_ch);
switch tv.map_type
    case 'mem'
        for a=1:tv.n_ch
            tic;
            sub_handle_popup(a)=subplot(1,n_subplots,a);
            switch type
                case 'mean'
                    if isempty(tv.memmap_matrix_data)
                        P{a}=(double(tv.memmap_data(1).(['channel',num2str(a)])))/tv.numFrames;
                        for b=2:length(tv.memmap_data)
                            P{a}=imadd(P{a},double(tv.memmap_data(b).(['channel',num2str(a)]))/tv.numFrames);
                            if mod(b,1000)==0
                                figure(f_out);subplot(1,n_subplots,a);

                                imagesc(P{a}');axis off;colormap('gray');drawnow;
                            end
                            if toc>max_time/2
                                disp(['Max time reached for channel ',num2str(a),'.']);
                                P{a}=P{a}*(tv.numFrames/b);
                                disp(['Frames averaged: ',num2str(b)]);

                                break;
                            end
                        end
                    else
                        [y_len,x_len]=size(tv.memmap_matrix_data,1:2);
                        subdiv=500;
                        n_subdiv=ceil(tv.numFrames/subdiv);
                        P{a}=zeros(y_len,x_len/tv.n_ch,'double');
                        tic;
                        for rep=1:n_subdiv
                            frames=1+(rep-1)*subdiv:min(subdiv*rep,tv.numFrames);
                            P{a}=imadd(P{a},sum(tv.memmap_matrix_data(:,(1:x_len/tv.n_ch)+(a-1)*x_len/tv.n_ch,frames),3)/tv.numFrames);
                            if toc>max_time/2
                                disp(['Max time reached for channel ',num2str(a),'.']);
                                P{a}=P{a}*(tv.numFrames/(rep*subdiv));
                                disp(['Frames averaged: ',num2str(rep*subdiv)]);
                                break;
                            end
                            figure(f_out);subplot(1,n_subplots,a);
                            if strcmp(obj.type,'binary')
                                imagesc(P{a});axis off;colormap('gray');drawnow;
                            else
                            imagesc(P{a}');axis off;colormap('gray');drawnow;
                            end
                        end
                    end

                case 'max'
                    subsamp=5;
                    if isempty(tv.memmap_matrix_data)
                        P{a}=tv.memmap_data(1).(['channel',num2str(a)]);
                        [n m]=size(P{a},1:2);
                        P{a}=zeros(size(P{a}));
                        temp_frames=zeros(n,m,subsamp,class(P{a}));
                        for b=1:subsamp:length(tv.memmap_data)-subsamp+1;
                            for c=1:subsamp
                                temp_frames(:,:,c)=tv.memmap_data(b+(c-1)).(['channel',num2str(a)]);
                            end
                            P{a}=max(P{a},median(temp_frames,3));
                            if mod(b,1000)<subsamp
                                figure(f_out);subplot(1,n_subplots,a);

                                imagesc(P{a}');axis off;colormap('gray');drawnow;
                            end
                            if toc>max_time/2
                                disp(['Max time reached for channel ',num2str(a),'.']);
                                disp(['Frames utilized: ',num2str(b)]);
                                break;
                            end
                        end
                    else
                        [y_len,x_len]=size(tv.memmap_matrix_data,1:2);
                        subdiv=500;
                        n_subdiv=ceil(tv.numFrames/subdiv);
                        P{a}=zeros(y_len,x_len/tv.n_ch,'double');
                        tic;
                        for rep=1:n_subdiv
                            frames=1+(rep-1)*subdiv:min(subdiv*rep,tv.numFrames);
                            temp_frames=zeros([size(P{a}),5]);
                            for s=1:subsamp
                                temp_frames(:,:,s)=max(tv.memmap_matrix_data(:,(1:x_len/tv.n_ch)+(a-1)*x_len/tv.n_ch,frames(s:subsamp:end)),[],3);
                            end
                            P{a}=max(P{a},median(temp_frames,3));
                            if toc>max_time/2
                                disp(['Max time reached for channel ',num2str(a),'.']);
                                disp(['Frames utilized: ',num2str(rep*subdiv)]);
                                break;
                            end
                            figure(f_out);subplot(1,n_subplots,a);

                                                        if strcmp(obj.type,'binary')
                                imagesc(P{a});axis off;colormap('gray');drawnow;
                            else
                            imagesc(P{a}');axis off;colormap('gray');drawnow;
                            end
                        end
                    end


            end
            figure(f_out);subplot(1,n_subplots,a);
                                        if strcmp(obj.type,'binary')
                                imagesc(P{a});axis off;colormap('gray');drawnow;
                            else
                            imagesc(P{a}');axis off;colormap('gray');drawnow;
                            end
            title(color_name{a});

        end
        if tv.n_ch>1
            sub_handle_popup(end)=subplot(1,n_subplots,n_subplots);
                                        if strcmp(obj.type,'binary')
allimages=cat(3,P{:});                            
                                        else
                            allimages=permute(cat(3,P{:}),[2 1 3]);
                            end
            
            allimages=allimages./max(allimages,[],1:2);
            if size(allimages,3)==2
                allimages=cat(3,allimages,zeros(size(allimages,[2 1]),class(allimages)));
            end
            imagesc(allimages);axis off;
            title('Merge');
        else
            allimages=P{1}';
        end
        disp('Projection Done.');
        linkaxes(sub_handle_popup);

    case 'file'
        warning('Could not memory map, so projection would take too long.');
end
set(tv.figure, 'pointer', 'arrow');
set(f_out, 'pointer', 'arrow');


end

function play_but_down(hObject,event,tv)
data=guidata(tv.figure);
if data.CurrFrame==tv.numFrames
    data.CurrFrame=1;
end
guidata(tv.figure,data);
set(data.timer,'Period',max(round(1/tv.fps,3),.001),'TimerFcn',{@play_vid,tv});
start(data.timer);
guidata(tv.figure,data);
set(hObject,'callback',@(x,evt) stop_but_down(x,evt,tv));
set(hObject,'String','=');
end

function play_vid(hObject,event,tv)
data=guidata(tv.figure);
frame_rate=1./hObject.InstantPeriod;
data.increment=max(floor(tv.fps/frame_rate),1);
if data.CurrFrame~=tv.numFrames
    data.CurrFrame=data.CurrFrame+data.increment;
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