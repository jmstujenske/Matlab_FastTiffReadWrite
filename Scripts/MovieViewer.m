classdef MovieViewer < handle
    %Class to view tiffs using memory mapping
    %tv=TiffViewer(input,n_ch);
    %
    %input = .tif file path, .bin file path, folder (for multi-file tif stack)
    %or matrix
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
        n_ch = 1;
        numFrames
        memmap_data
        memmap_matrix_data
        fps
        map_type
        max_time = 20;
        type
        width
        height
        CurrFrame = 1;
    end
    
    properties(Hidden = true)
        ax
        memmap
        memmap_matrix
        listener
        image_object
    end
    
    methods
        function obj = MovieViewer(filename, n_ch)
            if nargin < 2, obj.n_ch = []; else obj.n_ch=n_ch;end
            if nargin < 1 || isempty(filename)
                filename = uigetfile({'*.tif;*.tiff'});
                if isempty(obj.n_ch)
                    userinputs = inputdlg({'Number of channels:'});
                    obj.n_ch = str2double(userinputs{1});
                end
            end
            
            if ischar(filename)
                obj.resolveFileName(filename);
                [~,~,ext]=fileparts(filename);
                if ~isempty(ext)
                info = obj.readTiffInfo;
                else
                    info=[];
                end
                obj.setNumFrames(info);
                uneven_flag = obj.checkUnevenFlag(info);
                obj.setupMemoryMapping(filename, obj.n_ch, info, uneven_flag);
                if isempty(info)
                    if iscell(obj.filename)
                    info = obj.readTiffInfo(obj.filename{1});
                    end
                end
                dims = obj.getDimensions(info);
                file=filename;
            else
                if isempty(obj.n_ch), obj.n_ch = 1; end
                obj.setupFromMatrix(filename, obj.n_ch);
                file='Matrix';
                dims=size(filename);
                ext=[];
            end
            obj.setupFigure(file, ext);
            obj.setupAxes(dims, obj.n_ch);
            obj.setupSlider();
            obj.setupTimer();
            obj.displayFrame(1);
        end
        
        function displayFrame(obj,opt)
            if nargin < 2, opt = 0; end
            obj.validateFrame();
            for a = 1:obj.n_ch
                if obj.map_type == "mem"
                    obj.updateFrameFromMemory(a, opt);
                else
                    obj.updateFrameFromFile(a, opt);
                end
            end
        end

        function allimages = mm_proj(obj, type)
            allimages = mm_proj([], [], obj, type);
        end
    end
    
    methods (Access = private)
        function resolveFileName(obj, filename)
            [folder, file, ext] = fileparts(filename);
            if isempty(ext)
                temp = dir(fullfile(folder, file, '*.tif*'));
                obj.filename = arrayfun(@(x) fullfile(x.folder, x.name), temp, 'UniformOutput', false);
            elseif any(strcmp(ext, {'.tif', '.tiff', '.bin'}))
                obj.filename = filename;
            else
                obj.filename = [];
            end
        end

        function setNumFrames(obj,info)
            if isempty(info)
                obj.numFrames=length(obj.filename);
            else
                obj.numFrames=length(info);
            end
        end
        
        function info = readTiffInfo(obj,filename)
            if nargin<2
                filename=obj.filename;
            end
            [folder,file,ext]=fileparts(filename);
            if any(strcmp(ext, {'.tif', '.tiff'}))
                try
                info = readtifftags(filename);
                catch
                    info=imfinfo(filename);
                    info.ImageWidth=info.Width;
                    info.ImageHeight=info.Height;
                end
            else
                info = [];
            end
        end
        
        function uneven_flag = checkUnevenFlag(~, info)
            if length(info) > 3 && info(2).StripOffsets(1) - info(1).StripOffsets(1) ~= info(3).StripOffsets(1) - info(2).StripOffsets(1)
                uneven_flag = 1;
            elseif isempty(info) || info(1).Compression~=1
                uneven_flag = 1;
            else
                uneven_flag = 0;
            end
        end
        
        function setupMemoryMapping(obj, filename, n_ch, info, uneven_flag)
            [~,~,ext]=fileparts(filename);
            if strcmp(ext, '.bin') || ~uneven_flag
                obj.map_type = 'mem';
                obj.handleMemoryMapping(filename, n_ch, info);
                    if exist('info','var') && ~isempty(info)
                        if isfield(info,'GapBetweenImages') && info(1).GapBetweenImages==0
                            obj.n_ch=length(fieldnames(obj.memmap_data));
                        elseif length(info)>2
                            obj.n_ch=length(fieldnames(obj.memmap_data))/2;
                        else
                            obj.n_ch=length(fieldnames(obj.memmap_data));
                        end
                    else
                        if isempty(n_ch)
                            n_ch=1;
                        end
                        obj.n_ch=n_ch;
                    end
            else
                obj.map_type = 'file';
                obj.setupFileMapping(filename, info, n_ch);
                if ~isempty(n_ch)
                    obj.n_ch=n_ch;
                    else
                        n_ch=1;
                        obj.n_ch=1;
                end
            end
            n_ch=obj.n_ch;
        end

        function handleMemoryMapping(obj, filename, n_ch, info)
            [~,~,ext]=fileparts(filename);
            switch ext
                case {'.tif', '.tiff', []}
                    obj.setupTiffMapping(filename, n_ch, info);
                    if ~iscell(obj.memmap_data)
                    obj.memmap_data=obj.memmap.Data;
                    obj.map_type = 'file';
                    end
                    obj.type='tif';
                case '.bin'
                    obj.setupBinaryMapping(filename, n_ch);
                    obj.type='binary';
                otherwise
                    obj.map_type = 'file';
            end
        end
        
        function setupFileMapping(obj, filename, info, n_ch)
            % obj.memmap = set_up_file(filename, info, n_ch);
            % obj.memmap_data = obj.memmap.Data;
        end
        
        function setupFromMatrix(obj, filename, n_ch)
            % filename = permute(filename, [2 1 3]);
            [height, width, obj.numFrames] = size(filename);
            % datavals = obj.processChannels(filename, height, width, n_ch);
            % obj.memmap_data = cell2struct(datavals, obj.generateChannelNames(n_ch), 2)';
            obj.memmap_matrix_data = filename;
            obj.map_type = 'mem';
            obj.type='matrix';
        end

        % function datavals = processChannels(~, filename, height, width, n_ch)
        %     datavals = [];
        %     for ch_rep = 1:n_ch
        %         datavals = cat(2, datavals, mat2cell(filename(:, :, ch_rep:n_ch:end), height, width, ones(size(filename, 3) / n_ch, 1)));
        %     end
        % end
        
        function ch_names = generateChannelNames(~, n_ch)
            ch_names = arrayfun(@(x) ['channel', num2str(x)], 1:n_ch, 'UniformOutput', false);
        end
        
        function setupFigure(obj, file, ext)
            obj.figure = figure('Units', 'normalized', 'Position', [.1 .1 .6 .6], 'AutoResizeChildren', 'off', 'CloseRequestFcn', @(x, event) obj.closeFigure(x, event), 'Name', [file, ext], 'NumberTitle', 'off');
        end
        
        function setupAxes(obj, dims, n_ch)
            obj.n_ch = n_ch;
            height=dims(1);
            width=dims(2);
            for rep = 1:obj.n_ch
                obj.ax{rep} = axes('Units', 'normalized', 'Parent', obj.figure, 'Position', [0+(rep-1)*.5 0 .5 .89], 'XTick', [], 'YTick', []);
                set(obj.ax{rep}, 'XLim', [1 width], 'YLim', [1 height]);
            end
            linkaxes(cat(1, obj.ax{:}));
        end

        function dims = getDimensions(obj, info)
            if ~isempty(info)
            dims = [info(1).ImageHeight info(1).ImageWidth];
            else
                dims=[obj.height obj.width];
            end
        end

        function setupSlider(tv)
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

        function setupTimer(obj)
            data = guidata(obj.figure);
            data.increment = 1;
            obj.CurrFrame = 1;
            obj.fps = 30;
            data.timer = timer('ExecutionMode', 'fixedRate', 'TimerFcn', {@play_vid, obj}, 'Period', max(round(1 / obj.fps, 3), .001));
            guidata(obj.figure, data);
        end

        function closeFigure(obj, ~, ~)
            data = guidata(obj.figure);
            try;delete(obj.listener);end
            try;stop(data.timer);end
            try;obj.cleanupMemoryMapping();end
            delete(obj.figure);
        end
        
        function cleanupMemoryMapping(obj)
            obj.memmap_data = [];
            obj.memmap_matrix_data = [];
            obj.memmap = [];
            obj.memmap_matrix = [];
        end
        
        function validateFrame(obj)
            if nargin < 2 || isempty(frame)
                obj.CurrFrame = min(max(obj.CurrFrame, 1), obj.numFrames);
            end
            if obj.CurrFrame > obj.numFrames
                obj.CurrFrame = obj.numFrames;
            end
        end

        function updateFrameFromMemory(obj, channel, opt)
            data=guidata(obj.figure);
            dataField = ['channel', num2str(channel)];
            frame=obj.CurrFrame;
            
            if isempty(obj.memmap_matrix_data)
            imgData = obj.memmap_data(frame).(dataField);
            else
            [y_len, x_len] = size(obj.memmap_matrix_data, 1:2);
            if strcmp(obj.type,'matrix')
                imgData = obj.memmap_matrix_data(:,:,(frame-1)*obj.n_ch+channel);    
            else
                imgData = obj.memmap_matrix_data(:, (1:x_len/obj.n_ch) + (channel-1) * x_len/obj.n_ch, frame);
            end
            end

            % if strcmp(obj.type, 'binary') || strcmp(obj.type, 'matrix')
            %     imgData = imgData';
            % end
            if ~strcmp(obj.type, 'binary') & ~strcmp(obj.type, 'matrix')
                imgData = imgData';
            end
            if opt == 0
                set(data.im{channel}, 'CData', imgData);
            else
                imagesc(obj.ax{channel}, imgData);
                set(obj.ax{channel}, 'XTick', [], 'YTick', []);
                data.im{channel}=obj.ax{channel}.Children;
                colormap('gray');
            end
            obj.image_object{channel}=obj.ax{channel}.Children;
            guidata(obj.figure,data);
        end
        
        function updateFrameFromFile(obj, channel, opt)
            data=guidata(obj.figure);
            obj.memmap_data = (obj.CurrFrame - 1) * obj.n_ch + channel;
            if ~iscell(obj.filename)
                datavals = bigread4(obj.filename, obj.memmap_data, obj.n_ch);
            else
                datavals = bigread4(obj.filename{obj.memmap_data}, 1, obj.n_ch);
            end
            imgData = datavals(:,:,1);
            if opt == 0
                set(data.im{channel}, 'CData', imgData);
            else
                imagesc(obj.ax{channel}, imgData);
                data.im{channel}=obj.ax{channel}.Children;
                set(obj.ax{channel}, 'XTick', [], 'YTick', []);
            end
            guidata(obj.figure,data);
        end
function tv = setupTiffMapping(tv, filename, n_ch, info)
    % setupTiffMapping - Set up memory mapping for TIFF files
    %
    % Arguments:
    %   filename - Path to the TIFF file or folder containing TIFFs
    %   n_ch     - Number of channels
    %
    % Returns:
    %   tv - Struct containing memory-mapped TIFF data and related info
    
    % Check if filename is a string (single TIFF file)
    if ischar(filename)
        [folder, file, ext] = fileparts(filename);
        if isempty(ext)  % Case when we provide a folder, not a file
            % Read all TIFF files in the folder
            tv.memmap_data = tv.filename;
        else
            tv.filename = filename;
            if nargin<3 || isempty(info)
            info = readtifftags(filename);
            end
            offset_field = get_offset_field(info);
            
            % Determine if the TIFF frames have uniform offsets
            if length(info) > 3
                uneven_flag = info(2).(offset_field)(1) - info(1).(offset_field)(1) ~= info(3).(offset_field)(1) - info(2).(offset_field)(1);
            else
                uneven_flag = false;
            end
            
            if ~uneven_flag
                tv.map_type = 'mem';
                tv.memmap = memory_map_tiff(filename, [], n_ch, true);
                if isfield(info, 'GapBetweenImages') && info(1).GapBetweenImages == 0

                    % tv.memmap = memory_map_tiff(filename,[],n_ch,true);
                                tv.memmap_matrix = memory_map_tiff(filename,'matrix',n_ch,true);
                                tv.memmap_matrix_data = tv.memmap_matrix.Data.allchans;           
                end
                
                tv.width = info(1).ImageWidth;
                tv.height = info(1).ImageHeight;
            else
                tv.map_type = 'file';
            end
        end
    end
end

function tv = setupBinaryMapping(tv, filename, n_ch, framesize, form)
    % setupBinaryMapping - Set up memory mapping for binary files
    %
    % Arguments:
    %   filename  - Path to the binary file
    %   n_ch      - Number of channels
    %   framesize - Size of each image frame as [height, width]
    %   form      - Data format in the binary file (e.g., 'double', 'uint16')
    %
    % Returns:
    %   tv - Struct containing memory-mapped binary data and related info

    tv.filename = filename;
    tv.map_type = 'mem';
    
    % Prepare memory mapping format for each channel
    % format_string = cell(n_ch, 3);
    % for ch_rep = 1:n_ch
    %     format_string(ch_rep, :) = {form, framesize, ['channel', num2str(ch_rep)]};
    % end

    % Set up memory mapping

                if isempty(tv.n_ch)
                    userinputs = inputdlg({'Number of channels:','Height and Width (as matrix):','Data Format:'});
                    tv.n_ch = str2double(userinputs{1});
                    framesize = str2num(userinputs{2});
                    tv.height=framesize(1);
                    tv.width=framesize(2);
                    form=userinputs{3};
                end
    tv.memmap_matrix = memmapfile(filename, 'Format', {form, [framesize], 'allchans'}, 'Writable', false);
n=length(tv.memmap_matrix.Data);
    tv.memmap_matrix = memmapfile(filename, 'Format', {form, [framesize n], 'allchans'}, 'Writable', false);
    % Store mapped data
    tv.memmap_matrix_data = tv.memmap_matrix.Data.allchans;    
    % Number of frames is determined by the binary file size
    tv.numFrames = n / tv.n_ch;
end

    end
end

function makeplot(hObject,event,tv)
data=guidata(tv.figure);
tv.CurrFrame=round(get(hObject,'Value'));
set(data.h.edit,'String',num2str(tv.CurrFrame));
guidata(tv.figure,data);
displayFrame(tv);
end

function makeplot2(hObject,event,tv)
data=guidata(tv.figure);
curval=get(hObject,'String');
try
    obj.CurrFrame=max(min(round(str2double(get(hObject,'String'))),tv.numFrames),1);
    hObject.String=num2str(obj.CurrFrame);
catch
    hObject.String=curval;
    return;
end
set(data.h.slide,'Value',obj.CurrFrame);
guidata(tv.figure,data);
displayFrame(tv);
end

function allimages = mm_proj(~, ~, tv, type)
    color_name = {'Red', 'Green', 'Blue'};
    f_out = figure;
    max_time = tv.max_time;
    
    % Set cursor to 'watch' during processing
    set([tv.figure, f_out], 'pointer', 'watch');
    drawnow;
    
    % Determine the number of subplots
    n_subplots = tv.n_ch + (tv.n_ch > 1); % Add extra plot for merged channels if more than one channel
    
    sub_handle_popup = zeros(1, n_subplots); % Initialize subplots
    P = cell(1, tv.n_ch); % Cell to store each channel's projection

    switch tv.map_type
        case 'mem'
            for ch = 1:tv.n_ch
                tic;
                sub_handle_popup(ch) = subplot(1, n_subplots, ch);
                
                % Compute projection based on type ('mean' or 'max')
                P{ch} = compute_projection(tv, type, ch, max_time, f_out, sub_handle_popup, n_subplots);
                
                % Display image for each channel
                if tv.n_ch==1
                    color_name{ch}=[];
                end
                display_image(P{ch}, f_out, sub_handle_popup(ch), tv.type, color_name{ch});
            end
            
            % Handle merged channel view if more than one channel
            if tv.n_ch > 1
                sub_handle_popup(end) = subplot(1, n_subplots, n_subplots);
                allimages = merge_channels(P, tv.type);
                imagesc(allimages); axis off;
                title('Merge');
            else
                allimages = P{1}';
            end
            
            disp('Projection Done.');
            linkaxes(sub_handle_popup); % Link the subplots for panning and zooming together
            
        case 'file'
            warning('Could not memory map, so projection would take too long.');
    end
    
    % Reset cursor to default
    set([tv.figure, f_out], 'pointer', 'arrow');
end

% Function to compute projection for each channel
function projection = compute_projection(tv, type, ch, max_time, f_out, sub_handle_popup, n_subplots)
    projection = [];
    
    if isempty(tv.memmap_matrix_data)
        projection = process_memmap(tv, ch, type, max_time, f_out, sub_handle_popup, n_subplots, 'memmap_data');
    else
        projection = process_memmap(tv, ch, type, max_time, f_out, sub_handle_popup, n_subplots, 'memmap_matrix_data');
    end
end

% Function to process memory-mapped data for projections
function P = process_memmap(tv, ch, type, max_time, f_out, sub_handle_popup, n_subplots, data_type)
    % Combined function to process memory-mapped data or matrix data based on type
    %
    % Arguments:
    %   tv                - Struct containing memory-mapped data
    %   ch                - Current channel being processed
    %   type              - Projection type (e.g., 'mean', 'max')
    %   max_time          - Maximum time allowed for processing
    %   f_out             - Figure handle for displaying images
    %   sub_handle_popup  - Subplot handles for displaying images
    %   n_subplots        - Number of subplots to display images
    %   data_type         - 'memmap_data' or 'memmap_matrix_data'
    
    tic;
    
    if strcmp(data_type, 'memmap_data')
        % Process memory-mapped data
        P = double(tv.memmap_data(1).(['channel', num2str(ch)])) / tv.numFrames;
        
        for b = 2:length(tv.memmap_data)
            P = imadd(P, double(tv.memmap_data(b).(['channel', num2str(ch)])) / tv.numFrames);
            
            if mod(b, 1000) == 0
                figure(f_out); subplot(1, n_subplots, ch);
                imagesc(P'); axis off; colormap('gray'); drawnow;
            end
            
            if toc > max_time / 2
                disp(['Max time reached for channel ', num2str(ch), '.']);
                P = P * (tv.numFrames / b);
                disp(['Frames averaged: ', num2str(b)]);
                break;
            end
        end
        
    elseif strcmp(data_type, 'memmap_matrix_data')
        % Process memory-mapped matrix data
        [y_len, x_len] = size(tv.memmap_matrix_data, 1:2);
        subdiv = 5; % Process in chunks to avoid memory overload
        n_subdiv = ceil(tv.numFrames / subdiv);
        P = zeros(x_len, y_len / tv.n_ch, 'double');
        
        for rep = 1:n_subdiv
            frames = 1 + (rep - 1) * subdiv : min(subdiv * rep, tv.numFrames);
            temp_frames = sum(tv.memmap_matrix_data(:, (1:x_len/tv.n_ch) + (ch-1) * x_len/tv.n_ch, frames), 3) / tv.numFrames;
            P = imadd(P, permute(temp_frames,[2 1 3]));
            
            if toc > max_time / 2
                disp(['Max time reached for channel ', num2str(ch), '.']);
                P = P / (rep * subdiv);
                disp(['Frames averaged: ', num2str(rep * subdiv)]);
                break;
            end
            
            figure(f_out); subplot(1, n_subplots, ch);
            imagesc(P'); axis off; colormap('gray'); drawnow;
        end
    else
        error('Unknown data_type specified. Use ''memmap_data'' or ''memmap_matrix_data''.');
    end
end

% Function to display an image
function display_image(image_data, f_out, subplot_handle, img_type, title_name)
    figure(f_out); subplot(subplot_handle);
    if strcmp(img_type, 'binary')
        imagesc(image_data); axis off; colormap('gray'); drawnow;
    else
        imagesc(image_data'); axis off; colormap('gray'); drawnow;
    end
    title(title_name);
end

% Function to merge channels for visualization
function merged_image = merge_channels(P, img_type)
    merged_image = permute(cat(3, P{:}), [2, 1, 3]);
    merged_image = merged_image ./ max(merged_image, [], [1, 2]);
    
    if size(merged_image, 3) == 2
        % Add a third zero-filled channel for RGB display if only 2 channels
        merged_image = cat(3, merged_image, zeros(size(merged_image, 1, 2), class(merged_image)));
    end
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

function play_vid(hObject,event,tv)
data=guidata(tv.figure);
frame_rate=1./hObject.InstantPeriod;
data.increment=max(floor(tv.fps/frame_rate),1);
tv.CurrFrame=mod(tv.CurrFrame+data.increment,tv.numFrames);
if tv.CurrFrame==0
    tv.CurrFrame=tv.numFrames;
end
data.h.slide.Value=tv.CurrFrame;
data.h.edit.String=num2str(tv.CurrFrame);
displayFrame(tv);
guidata(tv.figure,data);
end

function play_but_down(hObject,event,tv)
data=guidata(tv.figure);
if tv.CurrFrame==tv.numFrames
    tv.CurrFrame=1;
end
guidata(tv.figure,data);
set(data.timer,'Period',max(round(1/tv.fps,3),.001),'TimerFcn',{@play_vid,tv});
start(data.timer);
guidata(tv.figure,data);
set(hObject,'callback',@(x,evt) stop_but_down(x,evt,tv));
set(hObject,'String','=');
end

function stop_but_down(hObject,event,tv)
data=guidata(tv.figure);
stop(data.timer);
set(hObject,'callback',@(x,evt) play_but_down(x,evt,tv));
set(hObject,'String','>');
guidata(tv.figure,data);
end

function ROI_select(hOject,event,tv)
data=guidata(tv.figure);
ax=gca;
if length(ax.Children)>1
    in=isa(ax.Children,'matlab.graphics.primitive.Image');
else
    in=1;
end
if ~isfield(data,'ROI_precalc')
    if strcmp(tv.type,'tif')
         data.ROI_precalc.frame_size=size(ax.Children(in).CData');
             [data.ROI_precalc.x,data.ROI_precalc.y]=ind2sub(data.ROI_precalc.frame_size,1:prod(data.ROI_precalc.frame_size));
    else
        data.ROI_precalc.frame_size=size(ax.Children(in).CData);
            [data.ROI_precalc.y,data.ROI_precalc.x]=ind2sub(data.ROI_precalc.frame_size,1:prod(data.ROI_precalc.frame_size));
    end
end
data.ROI=drawpolygon(ax);
set(tv.figure, 'pointer', 'watch');

drawnow;
pixels=inpolygon(data.ROI_precalc.x,data.ROI_precalc.y,data.ROI.Position(:,1),data.ROI.Position(:,2));
in=find(pixels);
% pixel_mask=zeros(data.ROI_precalc.frame_size);
% pixel_mask(pixels)=1;
% pixel_mask=logical(pixel_mask);
z_series=zeros(tv.n_ch,tv.numFrames);
if isempty(tv.memmap_matrix_data)
    for b=1:tv.n_ch
        for t=1:tv.numFrames
            z_series(b,t)=nanmean(tv.memmap_data(t).(['channel',num2str(b)])(in));
        end
    end
else
    for b=1:tv.n_ch
        % ins=find(pixel_mask(:));
        z_series(b,:)=mean(tv.memmap_matrix_data(in'+(b-1)*numel(pixels)+(0:tv.numFrames-1)*numel(pixels)*tv.n_ch),1);
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