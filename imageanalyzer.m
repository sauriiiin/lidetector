%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  imageanalyzer.m

%   Author: Saurin Parikh, April 2018
%   Updated: August, 2019
%       - Analyze Images and Upload CS Data to SQL
%   Updated: October, 2019
%       - removed UI elements and added .txt
%
%   Needs info.txt file in the home directory or change path wherever
%   necessary
%
%   dr.saurin.parikh@gmail.com

%%  Load Paths to Files and Data

%     open load_toolkit.m and update the paths
    load_toolkit;
%     use info.txt in the directory as a example
%     place your file in the MATLAB directory
    fileID = fopen('info.txt','r');
    info = textscan(fileID, '%s%s');

%%  Initialization
    
    hours = []; 
    files = {};
    filedir = dir(info{1,2}{1});
    dirFlags = [filedir.isdir] & ~strcmp({filedir.name},'.') & ~strcmp({filedir.name},'..');
    subFolders = filedir(dirFlags);
    for k = 1 : length(subFolders)
        tmpdir = strcat(subFolders(k).folder, '/',  subFolders(k).name);
        files = [files; dirfiles(tmpdir, '*.JPG')];  
        hrs = strfind(tmpdir, '/'); hrs = tmpdir(hrs(end)+1:end);
        hours = [hours, str2num(hrs(1:end-1))];
    end
    
    if isempty(hours)
        hours = -1;
    end
    
    density = str2num(info{1,2}{2});
    if density == 6144
        dimensions = [64 96];
    elseif density == 1536
        dimensions = [32 48];
    elseif density == 384
        dimensions = [16 24];
    else
        dimensions = [8 12];
    end
    
    params = { ...
        'parallel', true, ...
        'verbose', true, ...
        'grid', OffsetAutoGrid('dimensions', dimensions), ... default
        'threshold', BackgroundOffset('offset', 1.25) }; % default = 1.25
    
%%  Image Analysis

    analyze_directory_of_images(files, params{:} );

%%  All images with no grid
%   Those images that weren't analyzed correctly

    all = zeros(1, size(files, 1));
    for ii = 1 : size(all, 2)
        all(ii) = exist(strcat(files{ii}, '.binary'));
    end
    pos = find(all==0);

%%  Manually fix images #1

    for ii = 1 : length(pos)
        tic;
        analyze_image( files{pos(ii)}, params{:}, ...
            'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
        toc;
    end

% %%  Find Low Correlation Images
% 
%     tmp = strfind(files, '/');
%     threshold = 0.99;
%     pos = [];
% 
%     for ii = 1:3:length(files)
%         if nancorrcoef(load_colony_sizes(files{ii}),...
%                 load_colony_sizes(files{ii+1})) < threshold
%             pos = [pos, ii];
%         elseif nancorrcoef(load_colony_sizes(files{ii+1}),...
%                 load_colony_sizes(files{ii+2})) < threshold
%             pos = [pos, ii];
%         elseif nancorrcoef(load_colony_sizes(files{ii+2}),...
%                 load_colony_sizes(files{ii})) < threshold
%             pos = [pos, ii];
%         end
%     end
% 
% %%  Manually fix images #2
% 
%     for ii = 1 : size(pos,2)
%         analyze_image(files{pos(ii)}, params{:}, ...
%             'grid', ManualGrid('dimensions', dimensions), 'threshold',...
%             BackgroundOffset('offset', 1.15));
% 
%         analyze_image(files{pos(ii) + 1}, params{:}, ...
%             'grid', ManualGrid('dimensions', dimensions), 'threshold',...
%             BackgroundOffset('offset', 1.15));
% 
%         analyze_image(files{pos(ii) + 2}, params{:}, ...
%             'grid', ManualGrid('dimensions', dimensions), 'threshold',...
%             BackgroundOffset('offset', 1.15));
%     end
% 
% 
% %%  View Analyzed Images
% 
%     pos = [];
%     for ii = 1:length(files)
%         view_plate_image(files{ii},'applyThreshold', true)
%         switch questdlg('Was the Binary Image look fine?',...
%             'Binary Image',...
%             'Yes','No','Yes')
%             case 'No'
%                 pos = [pos, ii];
%         end
%     end
    
%%  Load Colony Size Data

    cs = load_colony_sizes(files);
%     size(cs)    % should be = (number of plates x 3 x number of time points) x density

%%  Mean Colony Size For Each Plate

    cs_mean = [];
    tmp = cs';

    if info{1,2}{3} == 3
        for ii = 1:3:length(files)
            cs_mean = [cs_mean, mean(tmp(:,ii:ii+2),2)];
        end
    else
        for ii = 1:length(files) %single picture/time point
            cs_mean = [cs_mean, tmp(:,ii)];
        end
    end
    cs_mean = cs_mean';

%%  Putting Colony Size (pixels) And Averages Together

    master = [];
    tmp = [];
    i = 1;
    
    if info{1,2}{3} == 3
        for ii = 1:3:size(cs,1)
            tmp = [cs(ii,:); cs(ii+1,:); cs(ii+2,:);...
                cs_mean(i,:)];
            master = [master, tmp];
            i = i + 1;
        end
    else
        for ii = 1:size(cs,1) %single picture/time point
            tmp = [cs(ii,:); cs(ii,:); cs(ii,:);...
                cs_mean(ii,:)];
            master = [master, tmp];
        end
    end
    master = master';

%%  Upload Colony Size Data to SQL

    sql_info = {info{1,2}{4:6}}; % {usr, pwd, db}
    conn = connSQL(sql_info);
    
    expt_name = info{1,2}{7};
    tablename_raw  = sprintf('%s_%d_RAW',expt_name,density);
        
    p2c_info = {info{1,2}{8:11}};
    p2c = fetch(conn, sprintf(['select * from %s a ',...
        'order by a.%s, a.%s, a.%s'],...
        p2c_info{:}));
    p2c.Properties.VariableNames = {'pos','plate','row','col'};

    exec(conn, sprintf('drop table %s',tablename_raw));  
    exec(conn, sprintf(['create table %s (pos int not null, hours int not null,'...
        'replicate1 int default null, replicate2 int default null, ',...
        'replicate3 int default null, average double default null)'], tablename_raw));

    colnames_raw = {'pos','hours'...
        'replicate1','replicate2','replicate3',...
        'average'};

    tmpdata = [];
    for ii=1:length(hours)
        tmpdata = [tmpdata; [p2c.pos, ones(length(p2c.pos),1)*hours(ii)]];
    end

    data = [tmpdata,master];
    tic
    datainsert(conn,tablename_raw,colnames_raw,data);
    toc

%%  END
