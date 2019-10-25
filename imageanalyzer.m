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
     
%%  PIXEL COUNT CORRECTION IF FOCAL LENGTH FOR ALL IMAGES IS NOT THE SAME
%   Divide pix count with pix_cor value for the plate in order to correct
%   for the focal length

    pix_cor = [55,1;54,1.02774694400000;53,1.05549388800000;52,1.08324083200000;51,1.11098777600000;...
        50,1.16710084600000;49,1.22321391500000;48,1.27184644700000;47,1.32047898000000;...
        46,1.36911151200000;45,1.46375048800000;44,1.54303496300000;43,1.62231943700000;...
        42,1.69738224400000;41,1.80471342100000;40,1.90766735600000;39,2.03591150200000;...
        38,2.08014244200000;37,2.12437338200000;36,2.26649952900000;35,2.44870909300000;...
        34,2.64248034900000;33,2.73535486000000;32,2.97924610600000;31,3.06986996700000;...
        30,3.16049382700000;29,3.52166132700000;28,3.79476795600000;27,4.11567367400000;...
        26,4.32989164500000;25,4.54410961600000;24,5.07861929900000;23,5.71339516100000;...
        22,6.06382765600000;21,6.41426015000000;20,7.06411483200000;19,7.62203028600000;...
        18,8.17994574000000];
    
    multplr = [];
    for i = 1:length(files)
       img_info = imfinfo(files{i});
       fl = img_info.DigitalCamera.FocalLength;
       multplr = [multplr; pix_cor(pix_cor(:,1) == fl,2)]; 
    end
    
%%  PLATE DENSITY AND ANALYSIS PARAMETERS

    density = 1536; % EDIT THIS ACCORDING TO IMAGES
    
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
%%
