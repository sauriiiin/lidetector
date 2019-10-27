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

%%  Load Paths to Files and Expt Info

%   open load_toolkit.m and update the paths
    load_toolkit;
%   use info.txt in the directory as a example
%   place your file in the MATLAB directory
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
     
%%  PIXEL COUNT CORRECTION IF FOCAL LENGTH FOR ALL IMAGES IS NOT THE SAME
%   Divide pix count with pix_cor value for the plate in order to correct
%   for the focal length

    pix_cor = [55,1;54,1.02771070000000;53,1.05542140000000;52,1.08313210000000;...
        51,1.11084280000000;50,1.16399474700000;49,1.21714669400000;...
        48,1.26852041700000;47,1.31989414100000;46,1.37126786400000;...
        45,1.39150770600000;44,1.50909135300000;43,1.62667499900000;...
        42,1.68744457600000;41,1.79371474700000;40,1.89399660000000;...
        39,2.00545600000000;38,2.05122191100000;37,2.09698782200000;...
        36,2.24259310800000;35,2.27525516200000;34,2.61089798700000;...
        33,2.70344852800000;32,2.91500635400000;31,3.04622703700000;...
        30,3.17744772000000;29,3.46102065700000;28,3.78798182200000;...
        27,4.08786873800000;26,4.30061327400000;25,4.51335780900000;...
        24,5.04265185000000;23,5.67768396500000;22,6.01741860700000;...
        21,6.35715324900000;20,6.92600201900000;19,7.54727851600000;...
        18,8.16855501300000];
    
    multplr = [];
%     dimen = [];
    for i = 1:length(files)
       img_info = imfinfo(files{i});
       fl = img_info.DigitalCamera.FocalLength;
       multplr = [multplr; pix_cor(pix_cor(:,1) == fl,2)];
%         dimen = [dimen; [img_info.Height, img_info.Width]];
    end
    
%%  PLATE DENSITY AND ANALYSIS PARAMETERS

    density = 384; % EDIT THIS ACCORDING TO IMAGES
    
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

%   zoom level corrector of pixel counts    
    if ~isempty(multplr)
        cs = cs.*multplr;
    end

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

%%  Upload RAW Colony Size Data to SQL

    sql_info = {info{1,2}{3:5}}; % {usr, pwd, db}
    conn = connSQL(sql_info);
    
    expt_name = info{1,2}{6};
    tablename_raw  = sprintf('%s_%d_RAW',expt_name,density);
        
    p2c_info = {info{1,2}{7:10}};
    p2c = fetch(conn, sprintf(['select * from %s a ',...
        'where density = %d ',...
        'order by a.%s, a.%s, a.%s'],...
        p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));
%     p2c.Properties.VariableNames = {'pos','density','plate','row','col'};

    exec(conn, sprintf('drop table %s',tablename_raw));  
    exec(conn, sprintf(['create table %s (pos int not null, hours double not null,'...
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
    
%%  SPATIAL cleanup
%   Border colonies, light artefact and smudge correction

    tablename_jpeg  = sprintf('%s_%d_JPEG',expt_name,density);
    tablename_bpos  = info{1,2}{14};
    tablename_sbox  = info{1,2}{15};

    exec(conn, sprintf('drop table %s',tablename_jpeg));
    exec(conn, sprintf(['create table %s ',...
        '(select * from %s)'], tablename_jpeg, tablename_raw));

    exec(conn, sprintf(['update %s ',...
        'set replicate1 = NULL, replicate2 = NULL, ',...
        'replicate3 = NULL, average = NULL ',...
        'where pos in ',...
        '(select pos from %s)'],tablename_jpeg,tablename_bpos));

    exec(conn, sprintf(['update %s ',...
        'set replicate1 = NULL, replicate2 = NULL, ',...
        'replicate3 = NULL, average = NULL ',...
        'where average <= 10'],tablename_jpeg));

    exec(conn, sprintf(['update %s ',...
        'set replicate1 = NULL, replicate2 = NULL, ',...
        'replicate3 = NULL, average = NULL ',...
        'where pos in ',...
        '(select pos from %s)'],tablename_jpeg,tablename_sbox));

%%  END
    close(conn)
%%
