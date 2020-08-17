%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  tutorial.m

%   Author: Saurin Parikh, August 2020
%   Generate pos2coor, pos2strainid, pos2orf_name table
%   
%   Needs info.txt, init.txt, init_plates.xlsx, init_s2o.xlsx in the home
%   directory
% 
%   dr.saurin.parikh@gmail.com

%%  Load Paths to Files

%   open load_toolkit.m and update the paths
    loadtoolkit;

%%  EXPERIMENTAL DESIGN AND INFORMATION
%   Basic information regarding the experiment and data management

%     mysql            = input('Are you using MySQL for data management? [Y/N] ', 's');
    mysql = 'Y';
    if mysql == 'Y'  
        username         = input('MySQL username: ','s');
        password         = input('MySQL password: ','s');
        database         = input('MySQL database: ','s');
    end
    
    expt             = input('Experiment Name: ', 's');
    if isempty(expt)
        expt = 'test';
    end
    p2c_tblname      = sprintf('%s_pos2coor', expt);
    p2s_tblname      = sprintf('%s_pos2strainid', expt);
    p2o_tblname      = sprintf('%s_pos2orf_name', expt);
    s2o_tblname      = sprintf('%s_strainid2orf_name', expt);
    bpos_tblname     = sprintf('%s_borderpos', expt);
    p2p_tblname      = sprintf('%s_pos2rep', expt);
    
    cont_name        = input('Reference Strain Name: ','s');
    images_per_plate = input('How many images did you take per plate? ');
    
    info = [{'image/plate';'usr';'pwd';'db';...
        'p2c_tblname';'p2s_tblname';'p2o_tblname';...
        's2o_tblname';'bpos_tblname';'cont_name';...
        'p2p_tblname';'mysql'},...
        {images_per_plate;username;password;database;...
        p2c_tblname;p2s_tblname;p2o_tblname;...
        s2o_tblname;bpos_tblname;cont_name;...
        p2p_tblname;mysql}];
    
    writetable(cell2table(info), 'info.txt', 'Delimiter',' ',...
        'WriteVariableNames',false)
    
%   Maximum number of Plates/Density at any stage of the experiment
%   and their upscale pattern

    upscale = [];
    
    N_96    = input('Number of 96-density plates: ');
    if isempty(N_96)
        N_96 = 0;
    end
    
    N_384   = input('Number of 384-density plates: ');
    if isempty(N_384)
        N_384 = 0;
    elseif N_384 > 0
        upscale{2} = input('How were they made? [TL,TR,BL,BR; TL,TR,BL,BR;...] ');
    end
    
    N_1536  = input('Number of 1536-density plates: ');
    if isempty(N_1536)
        N_1536 = 0;
    elseif N_1536 > 0
        upscale{3} = input('How were they made? [TL,TR,BL,BR; TL,TR,BL,BR;...] ');
    end
    
    N_6144  = input('Number of 6144-density plates: ');
    if isempty(N_6144)
        N_6144 = 0;
    elseif N_6144 > 0
        upscale{4} = input('How were they made? [TL,TR,BL,BR; TL,TR,BL,BR;...] ');
    end
    
    init = [{96;384;1536;6144},...
        {N_96; N_384; N_1536; N_6144}];
    
    writetable(cell2table(init), 'init.txt', 'Delimiter',' ',...
        'WriteVariableNames',false)
   
%%  LOADING DATA
%   Using info.txt and init.txt files just created
    fileID = fopen('info.txt','r');
    info = textscan(fileID, '%s%s');
    fileID = fopen('init.txt','r');
    init = textscan(fileID, '%f%f');
    
    iden = min(init{1,1}(init{1,2} ~= 0));
    
    sql_info = {info{1,2}{2:4}}; % {usr, pwd, db}
    conn = connSQL(sql_info);
    
    oec = input('Are you using plates from the Expanded BarFLEX Collection? [Y/N] ','s');
    if oec == 'Y'
        oec_plates = input('Provide the plate numbers: ');
        ncont = input('How many reference population plates will you be using? ');
        data = platemaps(sql_info, init, iden, ncont, oec_plates);
    else
        oec_plates = [];
        fprintf('The present working directory is: %s\n',pwd)
        plate_design_path = input('Path to lowest-density plate-design file (.xlsx): ','s');
        if exist(plate_design_path, 'file') == 0
            plate_design_path = input('Please re-enter the path: ','s');
            if exist(plate_design_path, 'file') == 0
                plate_design_path = input('Please re-enter the path: ','s');
            end
        end
        
        [~,sheet_name]=xlsfinfo(plate_design_path);
    %   init_plate.xlsx has initial plate maps - one per sheet
    %   each mutant is represented by a unique numeric identifier (strain_id)
        for k=1:numel(sheet_name)
          data{k}=xlsread(plate_design_path,sheet_name{k});
        end
    end
    
%%  INITILIZING VARIABLE NAMES    
    
    tablename_p2id  = info{1,2}{6};
    tablename_p2c   = info{1,2}{5};
    tablename_s2o   = info{1,2}{8};
    tablename_p2o   = info{1,2}{7};
    tablename_bpos  = info{1,2}{9};
    tablename_p2p   = info{1,2}{11};
    
    colnames_p2id   = {'pos','strain_id'};
    colnames_p2c    = {'pos','density','plate','row','col'};
    colnames_s2o    = {'strain_id','orf_name'};
    colnames_p2p    = {'density','pos','rep_pos'};
    
 %%  INDICES

    coor = [];
    for i = 1:init{1,2}(1)
        coor{1,i} = {[ones(1,96)*i;indices(96)]};
    end
    for i = 1:init{1,2}(2)
        coor{2,i} = {[ones(1,384)*i;indices(384)]};
    end
    for i = 1:init{1,2}(3)
        coor{3,i} = {[ones(1,1536)*i;indices(1536)]};
    end
    for i = 1:init{1,2}(4)
        coor{4,i} = {[ones(1,6144)*i;indices(6144)]};
    end
    
%%  POSITIONS FOR STARTER PLATES

    pos = [];
    
    if iden == 6144
        for i = 1:init{1,2}(4)
            pos{4,i} = linspace(iden*(i-1)+1,iden*i,iden);
        end
    elseif iden == 1536
        for i = 1:init{1,2}(3)
            pos{3,i} = linspace(iden*(i-1)+1,iden*i,iden);
        end
    elseif iden == 384
        for i = 1:init{1,2}(2)
            pos{2,i} = linspace(iden*(i-1)+1,iden*i,iden);
        end
    else
        for i = 1:init{1,2}(1)
            pos{1,i} = linspace(iden*(i-1)+1,iden*i,iden);
        end
    end
    
%%  GENERARTING POS2COOR and POS2STRAINID TABLES

    strain = [];
    tbl_p2c = [];
    tbl_p2s = [];
    
    tbl_p2p = [];
    p2p = [];

    if iden == 96
        for i = 1:init{1,2}(1)
            strain{1,i} = grid2row(data{i});

            tbl_p2c{1,i} = [pos{1,i};
                ones(1,length(pos{1,i}))*length(pos{1,i});coor{1,i}{:}]';
            tbl_p2s{1,i} = [pos{1,i};strain{1,i}]';
            tbl_p2p{1,i} = [ones(1,length(pos{1,i}))*length(pos{1,i});
                pos{1,i}; pos{1,i}]';
        end
        for i = 1:init{1,2}(2)
            pos{2,i} = grid2row(plategen(pos{1,upscale{2}(i,1)} + 10000,...
                pos{1,upscale{2}(i,2)} + 20000,...
                pos{1,upscale{2}(i,3)} + 30000,...
                pos{1,upscale{2}(i,4)} + 40000)) + i * 100000;
            strain{2,i} = grid2row(plategen(strain{1,upscale{2}(i,1)},...
                strain{1,upscale{2}(i,2)},...
                strain{1,upscale{2}(i,3)},...
                strain{1,upscale{2}(i,4)}));
            p2p{2,i} = grid2row(plategen(pos{1,upscale{2}(i,1)},...
                pos{1,upscale{2}(i,2)},...
                pos{1,upscale{2}(i,3)},...
                pos{1,upscale{2}(i,4)}));

            tbl_p2c{2,i} = [pos{2,i};
                ones(1,length(pos{2,i}))*length(pos{2,i});coor{2,i}{:}]';
            tbl_p2s{2,i} = [pos{2,i};strain{2,i}]';
            tbl_p2p{2,i} = [ones(1,length(pos{2,i}))*length(pos{2,i});
                p2p{2,i}; pos{2,i}]';
        end
        for i = 1:init{1,2}(3)
            pos{3,i} = grid2row(plategen(pos{2,upscale{3}(i,1)} + 1000000,...
                pos{2,upscale{3}(i,2)} + 2000000,...
                pos{2,upscale{3}(i,3)} + 3000000,...
                pos{2,upscale{3}(i,4)} + 4000000)) + i * 10000000;
            strain{3,i} = grid2row(plategen(strain{2,upscale{3}(i,1)},...
                strain{2,upscale{3}(i,2)},...
                strain{2,upscale{3}(i,3)},...
                strain{2,upscale{3}(i,4)}));
            p2p{3,i} = grid2row(plategen(p2p{2,upscale{3}(i,1)},...
                p2p{2,upscale{3}(i,2)},...
                p2p{2,upscale{3}(i,3)},...
                p2p{2,upscale{3}(i,4)}));

            tbl_p2c{3,i} = [pos{3,i};
                ones(1,length(pos{3,i}))*length(pos{3,i});coor{3,i}{:}]';
            tbl_p2s{3,i} = [pos{3,i};strain{3,i}]';
            tbl_p2p{3,i} = [ones(1,length(pos{3,i}))*length(pos{3,i});
                p2p{3,i}; pos{3,i}]';
        end
        for i = 1:init{1,2}(4)
            pos{4,i} = grid2row(plategen(pos{3,upscale{4}(i,1)} + 100000000,...
                pos{3,upscale{4}(i,2)} + 200000000,...
                pos{3,upscale{4}(i,3)} + 300000000,...
                pos{3,upscale{4}(i,4)} + 400000000)) + i * 1000000000;
            strain{4,i} = grid2row(plategen(strain{3,upscale{4}(i,1)},...
                strain{3,upscale{4}(i,2)},...
                strain{3,upscale{4}(i,3)},...
                strain{3,upscale{4}(i,4)}));
            p2p{4,i} = grid2row(plategen(p2p{3,upscale{4}(i,1)},...
                p2p{3,upscale{4}(i,2)},...
                p2p{3,upscale{4}(i,3)},...
                p2p{3,upscale{4}(i,4)}));

            tbl_p2c{4,i} = [pos{4,i};ones(1,length(pos{4,i}))*length(pos{4,i});
                coor{4,i}{:}]';
            tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            tbl_p2p{4,i} = [ones(1,length(pos{4,i}))*length(pos{4,i});
                p2p{4,i}; pos{4,i}]';
        end
    elseif iden == 384
        for i = 1:init{1,2}(2)
            strain{2,i} = grid2row(data{i});

            tbl_p2c{2,i} = [pos{2,i};ones(1,length(pos{2,i}))*length(pos{2,i});coor{2,i}{:}]';
            tbl_p2s{2,i} = [pos{2,i};strain{2,i}]';
            tbl_p2p{2,i} = [ones(1,length(pos{2,i}))*length(pos{2,i});
                pos{2,i}; pos{2,i}]';
        end
        for i = 1:init{1,2}(3)
            pos{3,i} = grid2row(plategen(pos{2,upscale{3}(i,1)} + 1000000,...
                pos{2,upscale{3}(i,2)} + 2000000,...
                pos{2,upscale{3}(i,3)} + 3000000,...
                pos{2,upscale{3}(i,4)} + 4000000)) + i * 10000000;
            strain{3,i} = grid2row(plategen(strain{2,upscale{3}(i,1)},...
                strain{2,upscale{3}(i,2)},...
                strain{2,upscale{3}(i,3)},...
                strain{2,upscale{3}(i,4)}));
            p2p{3,i} = grid2row(plategen(pos{2,upscale{3}(i,1)},...
                pos{2,upscale{3}(i,2)},...
                pos{2,upscale{3}(i,3)},...
                pos{2,upscale{3}(i,4)}));

            tbl_p2c{3,i} = [pos{3,i};
                ones(1,length(pos{3,i}))*length(pos{3,i});coor{3,i}{:}]';
            tbl_p2s{3,i} = [pos{3,i};strain{3,i}]';
            tbl_p2p{3,i} = [ones(1,length(pos{3,i}))*length(pos{3,i});
                p2p{3,i}; pos{3,i}]';
        end
        for i = 1:init{1,2}(4)
            pos{4,i} = grid2row(plategen(pos{3,upscale{4}(i,1)} + 100000000,...
                pos{3,upscale{4}(i,2)} + 200000000,...
                pos{3,upscale{4}(i,3)} + 300000000,...
                pos{3,upscale{4}(i,4)} + 400000000)) + i * 1000000000;
            strain{4,i} = grid2row(plategen(strain{3,upscale{4}(i,1)},...
                strain{3,upscale{4}(i,2)},...
                strain{3,upscale{4}(i,3)},...
                strain{3,upscale{4}(i,4)}));
            p2p{4,i} = grid2row(plategen(p2p{3,upscale{4}(i,1)},...
                p2p{3,upscale{4}(i,2)},...
                p2p{3,upscale{4}(i,3)},...
                p2p{3,upscale{4}(i,4)}));

            tbl_p2c{4,i} = [pos{4,i};ones(1,length(pos{4,i}))*length(pos{4,i});
                coor{4,i}{:}]';
            tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            tbl_p2p{4,i} = [ones(1,length(pos{4,i}))*length(pos{4,i});
                p2p{4,i}; pos{4,i}]';
        end
    elseif iden == 1536
        for i = 1:init{1,2}(3)
            strain{3,i} = grid2row(data{i});

            tbl_p2c{3,i} = [pos{3,i};ones(1,length(pos{3,i}))*length(pos{3,i});coor{3,i}{:}]';
            tbl_p2s{3,i} = [pos{3,i};strain{3,i}]';
            tbl_p2p{3,i} = [ones(1,length(pos{3,i}))*length(pos{3,i});
                pos{3,i}; pos{3,i}]';
        end
        for i = 1:init{1,2}(4)
            pos{4,i} = grid2row(plategen(pos{3,upscale{4}(i,1)} + 100000000,...
                pos{3,upscale{4}(i,2)} + 200000000,...
                pos{3,upscale{4}(i,3)} + 300000000,...
                pos{3,upscale{4}(i,4)} + 400000000)) + i * 1000000000;
            strain{4,i} = grid2row(plategen(strain{3,upscale{4}(i,1)},...
                strain{3,upscale{4}(i,2)},...
                strain{3,upscale{4}(i,3)},...
                strain{3,upscale{4}(i,4)}));
            p2p{4,i} = grid2row(plategen(pos{3,upscale{4}(i,1)},...
                pos{3,upscale{4}(i,2)},...
                pos{3,upscale{4}(i,3)},...
                pos{3,upscale{4}(i,4)}));

            tbl_p2c{4,i} = [pos{4,i};ones(1,length(pos{4,i}))*length(pos{4,i});
                coor{4,i}{:}]';
            tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            tbl_p2p{4,i} = [ones(1,length(pos{4,i}))*length(pos{4,i});
                p2p{4,i}; pos{4,i}]';
        end
    else
        for i = 1:init{1,2}(4)
            strain{4,i} = grid2row(data{i});

            tbl_p2c{4,i} = [pos{4,i};ones(1,length(pos{4,i}))*length(pos{4,i});coor{4,i}{:}]';
            tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            tbl_p2p{4,i} = [ones(1,length(pos{4,i}))*length(pos{4,i});
                pos{4,i}; pos{4,i}]';
        end
    end
    
%%  UPLOAD P2C, P2S & P2P DATA TO SQL
    
%   Position to Strain_ID
    exec(conn, sprintf('drop table %s',tablename_p2id)); 
    exec(conn, sprintf(['create table %s ',...
        '(pos bigint not null primary key, strain_id int not null)'], tablename_p2id));
    for i = 1:size(tbl_p2s,1)
        if ~isempty(tbl_p2s{i})
            for ii = 1:size(tbl_p2s,2)
                if ~isempty(tbl_p2s{i,ii})
                    datainsert(conn,tablename_p2id,colnames_p2id,tbl_p2s{i,ii});
                end
            end
        end
    end
    
%   Position to Coordinate
    exec(conn, sprintf('drop table %s',tablename_p2c)); 
    exec(conn, sprintf(['create table %s (pos bigint not null primary key, ',...
            'density int not null, plate int not null, '...
            'row int not null, col int not null)'],tablename_p2c));
    for i = 1:size(tbl_p2c,1)
        if ~isempty(tbl_p2c{i})
            for ii = 1:size(tbl_p2c,2)
                if ~isempty(tbl_p2c{i,ii})
                    datainsert(conn,tablename_p2c,colnames_p2c,tbl_p2c{i,ii});
                end
            end
        end
    end
    
%   Position to Replicate Position
    exec(conn, sprintf('drop table %s',tablename_p2p)); 
    exec(conn, sprintf(['create table %s (density int not null, ',...
            'pos bigint not null, rep_pos bigint not null primary key)'],tablename_p2p));
    for i = 1:size(tbl_p2p,1)
        if ~isempty(tbl_p2p{i})
            for ii = 1:size(tbl_p2p,2)
                if ~isempty(tbl_p2p{i,ii})
                    datainsert(conn,tablename_p2p,colnames_p2p,tbl_p2p{i,ii});
                end
            end
        end
    end
   
    
%%  POS2ORF_NAME

    exec(conn, sprintf('drop table %s',tablename_p2o));
    
    if ~isempty(oec_plates)
        exec(conn, sprintf(['create table %s ',...
            ' (select a.pos, b.orf_name',...
            ' from %s a, STRAINID2ORFNAME b',...
            ' where a.strain_id = b.strain_id)'],...
            tablename_p2o,...
            tablename_p2id));
    else
%  STRAIN_ID 2 ORF_NAME
        s2o_path = input('Path to strain_id to orf_name file (.xlsx): ','s');
        if exist(s2o_path, 'file') == 0
            s2o_path = input('Please re-enter the path: ','s');
            if exist(s2o_path, 'file') == 0
                s2o_path = input('Please re-enter the path: ','s');
            end
        end
        
        tbl_s2o = readtable(s2o_path);
        exec(conn, sprintf('drop table %s',tablename_s2o)); 
        exec(conn, sprintf(['create table %s ',...
            '(strain_id int not null primary key, orf_name varchar(20) null)'],tablename_s2o));

        datainsert(conn,tablename_s2o,colnames_s2o,tbl_s2o);
    
        exec(conn, sprintf(['create table %s ',...
            ' (select a.pos, b.orf_name',...
            ' from %s a, %s b',...
            ' where a.strain_id = b.strain_id)'],...
            tablename_p2o,...
            tablename_p2id,...
            tablename_s2o));
    end
    
%%  BORDERPOS

    exec(conn, sprintf('drop table %s',tablename_bpos));
    exec(conn, sprintf(['create table %s ',...
        '(pos int not null)'],tablename_bpos));
    
    p2c_den = fetch(conn, sprintf(['select distinct density ',...
        'from %s order by density asc'], tablename_p2c));
    
    for d = 1:length(p2c_den.density)
        if p2c_den.density(d) == 384
            exec(conn, sprintf(['insert into %s ',...
                'select pos from %s ',...
                'where density = 384 ',...
                'and (row in (1,16) or col in (1,24))'],...
                tablename_bpos, tablename_p2c));
        elseif p2c_den.density(d) == 1536
            exec(conn, sprintf(['insert into %s ',...
                'select pos from %s ',...
                'where density = 1536 ',...
                'and (row in (1,2,31,32) or col in (1,2,47,48))'],...
                tablename_bpos, tablename_p2c));
        elseif p2c_den.density(d) == 6144
            exec(conn, sprintf(['insert into %s ',...
                'select pos from %s ',...
                'where density = 6144 ',...
                'and (row in (1,2,3,4,61,62,63,64) or ',...
                'col in (1,2,3,4,93,94,95,96))'],...
                tablename_bpos, tablename_p2c));
        else
            
        end
    end

%%  END
    close(conn)
%% 