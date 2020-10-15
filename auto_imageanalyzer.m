%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  imageanalyzer_t.m

%   Author: Saurin Parikh, April 2018
%   Update #1: August, 2019
%       - Analyze Images and Upload CS Data to SQL
%   Update #2: October, 2019
%       - removed UI elements and added .txt
%   Update #3: August, 2020
%       - modified for commandline use
%
%   Needs info.txt file in the home directory or change path wherever
%   necessary
%
%   dr.saurin.parikh@gmail.com

%%  Load Paths to Files and Expt Info

%   open load_toolkit.m and update the paths
    loadtoolkit;
%   use info.txt in the directory as a example
%   place your file in the MATLAB directory
    fileID = fopen('info.txt','r');
    info = textscan(fileID, '%s%s');
    
%%  INITIALIZATION
    
    file_dir = input('Path to image directory: ', 's');
    expt_set = input('Name of Experiment Arm: ','s');
    density = input('Colony-density of plates: ');
    
%%  GETTING IMAGE FILES
    
    hours = []; 
    files = {};
    filedir = dir(file_dir);
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
% 
%     pix_cor = [55,1;54,1.02771070000000;53,1.05542140000000;52,1.08313210000000;...
%         51,1.11084280000000;50,1.16399474700000;49,1.21714669400000;...
%         48,1.26852041700000;47,1.31989414100000;46,1.37126786400000;...
%         45,1.39150770600000;44,1.50909135300000;43,1.62667499900000;...
%         42,1.68744457600000;41,1.79371474700000;40,1.89399660000000;...
%         39,2.00545600000000;38,2.05122191100000;37,2.09698782200000;...
%         36,2.24259310800000;35,2.27525516200000;34,2.61089798700000;...
%         33,2.70344852800000;32,2.91500635400000;31,3.04622703700000;...
%         30,3.17744772000000;29,3.46102065700000;28,3.78798182200000;...
%         27,4.08786873800000;26,4.30061327400000;25,4.51335780900000;...
%         24,5.04265185000000;23,5.67768396500000;22,6.01741860700000;...
%         21,6.35715324900000;20,6.92600201900000;19,7.54727851600000;...
%         18,8.16855501300000];
%     
%     multplr = [];
%     time = [];
%     for i = 1:length(files)
%        img_info = imfinfo(files{i});
%        fl = img_info.DigitalCamera.FocalLength;
%        multplr = [multplr; pix_cor(pix_cor(:,1) == fl,2)];
%        time = [time; str2double(strrep(img_info.DateTime(end-7:end-3),':','.'))];
%     end
%     
%     time = round(mean(reshape(time, [4, 12])),2);
%     time = time - time(1);
%     
%     if ~isempty(time)
%         hours = time;
%     end

%%  PLATE DENSITY AND ANALYSIS PARAMETERS
    
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
        'threshold', BackgroundOffset('offset', 1.5) }; % default = 1.25

%%  IMAGE ANALYSIS

    all = zeros(1, size(files, 1));
    for ii = 1 : size(all, 2)
        all(ii) = exist(strcat(files{ii}, '.binary'));
    end
    pos = find(all==0);
    
    if isempty(pos)
        disp('All files are already analyzed.')
        if input('Do you want to re-analyze them? [Y/N] ', 's') == 'Y'
            analyze_directory_of_images(files, params{:} );
            direct_upload = 'N';
        else
            direct_upload = 'Y';
        end
    else
        fprintf('%d out of %d images remain to be analyzed.\n',...
            length(pos),...
            length(files))
        if input('Do you want to re-analyze all? [Y/N] ', 's') == 'Y'
            analyze_directory_of_images(files, params{:} );
            direct_upload = 'N';
        else
            files2 = files;
            files2(pos) = [];
            analyze_directory_of_images(files2, params{:} );
            direct_upload = 'N';
        end
    end

    if direct_upload == 'N'
%%  COLLECT IMAGES WITH NO GRID
%   Those images that weren't analyzed correctly

        all = zeros(1, size(files, 1));
        for ii = 1 : size(all, 2)
            all(ii) = exist(strcat(files{ii}, '.binary'));
        end
        pos = find(all==0);

        if isempty(pos)
            disp('All images were successfully analyzed.')
        else
            fprintf('%d image/s were not analyzed.\n',length(pos))
            alt_thresh = input('Would you like to re-analyze all images using a different background threshold? [Y/N] ', 's');
            if alt_thresh == 'Y'
                thresh = input('New threshold (default = 1.25): ');
                params = { ...
                    'parallel', true, ...
                    'verbose', true, ...
                    'grid', OffsetAutoGrid('dimensions', dimensions), ... default
                    'threshold', BackgroundOffset('offset', thresh) };
                analyze_directory_of_images(files, params{:} );

                all = zeros(1, size(files, 1));
                for ii = 1 : size(all, 2)
                    all(ii) = exist(strcat(files{ii}, '.binary'));
                end
                pos2 = find(all==0);
                if isempty(pos2)
                    disp('All images were successfully analyzed with the new threshold.')
                else
                    fprintf('%d image/s were not analyzed.\n Manually place grid using previous threshold\n',length(pos))
                    for ii = 1 : length(pos)
                        analyze_image( files{pos(ii)}, params{:}, ...
                            'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
                    end
                end
            else
                disp('Manually place grid on images')
                for ii = 1 : length(pos)
                    analyze_image( files{pos(ii)}, params{:}, ...
                        'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
                end
            end
        end
    end
    fprintf('Examine binary images to verify proper colony detection before going forward.\nPress enter to proceed.\n')
    pause
    
    if input('Are the images properly analyzed? [Y/N]: ', 's') == 'N'
        if input('Is there a problem with all of them? [Y/N]: ', 's') == 'Y'
            disp('Manually place grid on all images')
            for ii = 1 : length(files)
                analyze_image( files{ii}, params{:}, ...
                    'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
            end
        else
            pos = input('Problematic images: ');
            
            disp('Manually place grid on images')
            for ii = 1 : length(pos)
                analyze_image( files{pos(ii)}, params{:}, ...
                    'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
            end
        end
    end
    
%     disp('Press enter to proceed.')
%     pause
    
%%  LOAD COLONY SIZE

    disp('Proceeding to upload raw data to mySQL.')
    cs = load_colony_sizes(files);

%  Mean Colony Size For Each Plate

    cs_mean = [];
    tmp = cs';

    if info{1,2}{1} == '3'
        for ii = 1:3:length(files)
            cs_mean = [cs_mean, mean(tmp(:,ii:ii+2),2)];
        end
    else
        for ii = 1:length(files) %single picture/time point
            cs_mean = [cs_mean, tmp(:,ii)];
        end
    end
    cs_mean = cs_mean';

%  Putting Colony Size (pixels) And Averages Together

    master = [];
    tmp = [];
    i = 1;
    
    if info{1,2}{1} == '3'
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

%%  UPLOAD RAW COLONY SIZE DATA TO SQL

    sql_info = {info{1,2}{2:4}}; % {usr, pwd, db}
    conn = connSQL(sql_info);
    
    tablename_raw  = sprintf('%s_%d_RAW',expt_set,density);
        
    p2c_info = {info{1,2}{5},'plate','row','col'};
    p2c = fetch(conn, sprintf(['select * from %s a ',...
        'where density = %d ',...
        'order by a.%s, a.%s, a.%s'],...
        p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));

    exec(conn, sprintf('drop table %s',tablename_raw));  
    exec(conn, sprintf(['create table %s (pos int not null, hours double not null,'...
        'image1 double default null, image2 double default null, ',...
        'image3 double default null, average double default null)'], tablename_raw));

    colnames_raw = {'pos','hours'...
        'image1','image2','image3',...
        'average'};

    tmpdata = [];
    for ii=1:length(hours)
        tmpdata = [tmpdata; [p2c.pos, ones(length(p2c.pos),1)*hours(ii)]];
    end

    data = [tmpdata,master];
    tic
    datainsert(conn,tablename_raw,colnames_raw,data);
    toc
    
%%  SPATIAL CLEANUP
%   Border colonies, light artefact and smudge correction
    disp('Cleaning raw data to remove borders and light artifact.')
    
    tablename_jpeg  = sprintf('%s_%d_JPEG',expt_set,density);
    tablename_bpos  = info{1,2}{9};

    exec(conn, sprintf('drop table %s',tablename_jpeg));
    exec(conn, sprintf(['create table %s ',...
        '(select * from %s)'], tablename_jpeg, tablename_raw));

    exec(conn, sprintf(['update %s ',...
        'set image1 = NULL, image2 = NULL, ',...
        'image3 = NULL, average = NULL ',...
        'where pos in ',...
        '(select pos from %s)'],tablename_jpeg,tablename_bpos));

    exec(conn, sprintf(['update %s ',...
        'set image1 = NULL, image2 = NULL, ',...
        'image3 = NULL, average = NULL ',...
        'where average <= 10'],tablename_jpeg));

%%  SMUDGE_BOX

    if input('Did you notice any smudges on the colony grid? [Y/N] ', 's') == 'Y'
        tablename_sbox  = sprintf('%s_smudgebox', expt_set);

    %   [density, plate, row, col ; density, plate, row, col ;...; density, plate, row, col]
        sbox = input('Enter colony positions to reject: [density, plate, row, col; density, plate, row, col;... ] \n');

        exec(conn, sprintf('drop table %s',tablename_sbox));
        exec(conn, sprintf(['create table %s ',...
            '(pos int not null)'],tablename_sbox));

        for i = 1:size(sbox,1)
            exec(conn, sprintf(['insert into %s ',...
                'select pos from %s ',...
                'where density = %d ',...
                'and plate = %d and row = %d and col = %d'],...
                tablename_sbox, p2c_info{1},...
                sbox(i,:)));
        end  

        exec(conn, sprintf(['update %s ',...
            'set replicate1 = NULL, replicate2 = NULL, ',...
            'replicate3 = NULL, average = NULL ',...
            'where pos in ',...
            '(select pos from %s)'],tablename_jpeg,tablename_sbox));
    end

%%  END
    close(conn)
%%
