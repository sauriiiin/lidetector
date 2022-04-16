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
    loadtoolkit;
%   use info.txt in the directory as a example
%   place your file in the MATLAB directory
    expt = input('Experiment Name: ', 's');
    fileID = fopen(sprintf('%s/%s_info.txt',toolkit_path,expt),'r');
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
        'threshold', BackgroundOffset('offset', 1.25) }; % default = 1.25

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
        if input('Do you want to analyze all? [Y/N] ', 's') == 'Y'
            analyze_directory_of_images(files, params{:} );
            direct_upload = 'N';
        else
            files2 = files(pos);
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

    if info{1,2}{2} == '3'
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
    
    if info{1,2}{2} == '3'
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

    sql_info = {info{1,2}{3:5}}; % {usr, pwd, db}
    conn = connSQL(sql_info);
    
    tablename_raw  = sprintf('%s_%d_RAW',expt_set,density);
        
    p2c_info = {info{1,2}{6},'plate_no','plate_row','plate_col'};
    p2c = fetch(conn, sprintf(['select * from %s a ',...
        'where density = %d ',...
        'order by a.%s, a.%s, a.%s'],...
        p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));

    exec(conn, sprintf('drop table %s',tablename_raw));  
    exec(conn, sprintf(['create table %s (pos bigint not null, hours double not null,'...
        'image1 double default null, image2 double default null, ',...
        'image3 double default null, average double default null, '...
        'primary key (pos, hours))'], tablename_raw));

    colnames_raw = {'pos','hours'...
        'image1','image2','image3',...
        'average'};

    tmpdata = [];
    for ii=1:length(hours)
        tmpdata = [tmpdata; [p2c.pos, ones(length(p2c.pos),1)*hours(ii)]];
    end

    data = [tmpdata,master];
    tic
%     datainsert(conn,tablename_raw,colnames_raw,data);
    sqlwrite(conn,tablename_raw,array2table(data,...
                    'VariableName',colnames_raw),...
                        'Catalog',sql_info{3});
    toc
    
%%  SPATIAL CLEANUP
%   Border colonies, light artefact and smudge correction
    disp('Cleaning raw data to remove borders and light artifact.')
    
    tablename_clean  = sprintf('%s_%d_CLEAN',expt_set,density);
    tablename_bpos   = info{1,2}{10};

    exec(conn, sprintf('drop table %s',tablename_clean));
    exec(conn, sprintf(['create table %s (primary key (pos, hours)) ',...
        '(select * from %s)'], tablename_clean, tablename_raw));

    exec(conn, sprintf(['update %s ',...
        'set average = NULL ',...
        'where pos in ',...
        '(select pos from %s)'],tablename_clean,tablename_bpos));

    exec(conn, sprintf(['update %s ',...
        'set average = NULL ',...
        'where average <= 10'],tablename_clean));
    
    if input('Do you need to correct for pinning artifacts? [Y/N]: ', 's') == 'Y'
        pin_artifact = input('Threshold for pinning artifact [spImager:300, manual:10]: ');
        exec(conn, sprintf(['update %s ',...
            'set average = NULL ',...
            'where average <= %d'],tablename_clean,pin_artifact));
    end

%%  SMUDGE_BOX

    if input('Did you notice any smudges on the colony grid? [Y/N] ', 's') == 'Y'
        tablename_sbox  = sprintf('%s_smudgebox', expt_set);

    %   [density, plate, row, col ; density, plate, row, col ;...; density, plate, row, col]
        sbox = input('Enter colony positions to reject: [density, plate, row, col; density, plate, row, col;... ] \n');

        exec(conn, sprintf('drop table %s',tablename_sbox));
        exec(conn, sprintf(['create table %s ',...
            '(pos bigint not null)'],tablename_sbox));

        for i = 1:size(sbox,1)
            exec(conn, sprintf(['insert into %s ',...
                'select pos from %s ',...
                'where density = %d ',...
                'and plate_no = %d and plate_row = %d and plate_col = %d'],...
                tablename_sbox, p2c_info{1},...
                sbox(i,:)));
        end  

        exec(conn, sprintf(['update %s ',...
            'set average = NULL ',...
            'where pos in ',...
            '(select pos from %s)'],tablename_clean,tablename_sbox));
    end

%%  END
    close(conn)
%%
