%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  buildraw.m

%   Author: Saurin Parikh, April 2020
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
    fileID = fopen(sprintf('%s/info.txt',toolkit_path),'r');
    info = textscan(fileID, '%s%s');
    
%%  INITIALIZATION
    
    file_dir = input('Path to Colony Size file: ', 's');
    expt_set = input('Name of Experiment Arm: ','s');
    density = input('Colony-density of plates: ');
    
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
        'image3 double default null, average double default null, '...
        'primary key (pos, hours))'], tablename_raw));

    colnames_raw = {'pos','hours'...
        'image1','image2','image3',...
        'average'};
    
    master = xlsread(file_dir); %load cs data from .xlsx file
    hours = []; %distinct hours from the cs data file

    tmpdata = [];
    for ii=1:length(hours)
        tmpdata = [tmpdata; p2c.pos];
    end

    data = [tmpdata,master];
    tic
    datainsert(conn,tablename_raw,colnames_raw,data);
    toc
    
%%  SPATIAL CLEANUP
%   Border colonies, light artefact and smudge correction
    disp('Cleaning raw data to remove borders and light artifact.')
    
    tablename_clean  = sprintf('%s_%d_CLEAN',expt_set,density);
    tablename_bpos  = info{1,2}{9};

    exec(conn, sprintf('drop table %s',tablename_clean));
    exec(conn, sprintf(['create table %s (primary key (pos, hours)) ',...
        '(select * from %s)'], tablename_clean, tablename_raw));

    exec(conn, sprintf(['update %s ',...
        'set image1 = NULL, image2 = NULL, ',...
        'image3 = NULL, average = NULL ',...
        'where pos in ',...
        '(select pos from %s)'],tablename_clean,tablename_bpos));

    exec(conn, sprintf(['update %s ',...
        'set image1 = NULL, image2 = NULL, ',...
        'image3 = NULL, average = NULL ',...
        'where average <= 10'],tablename_clean));

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
            '(select pos from %s)'],tablename_clean,tablename_sbox));
    end

%%  END
    close(conn)
%%