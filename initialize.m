%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  initialize.m

%   Author: Saurin Parikh, October 2019
%   Generate pos2coor, pos2strainid, pos2orf_name table
%   
%   Needs info.txt, init.txt, init_plates.xlsx, init_s2o.xlsx in the home
%   directory
% 
%   dr.saurin.parikh@gmail.com

%%  Load Paths to Files

%   open load_toolkit.m and update the paths
    load_toolkit;

%%  EXPERIMENTAL DESIGN AND INFORMATION
%   Fill this information before going forward

    images_per_plate = 3;
    username         = 'sbp29';
    password         = 'Ku5hani@28';
    database         = 'saurin_test';
    p2c_tblname     = '4C4_pos2coor';
    p2s_tblname     = '4C4_pos2strainid';
    p2o_tblname     = '4C4_pos2orf_name';
    s2o_tblname     = '4C4_strainid2orf_name';
    bpos_tblname    = '4C4_borderpos';
    cont_name       = 'BF_control';
    
    info = [{'image/plate';'usr';'pwd';'db';...
        'p2c_tblname';'p2s_tblname';'p2o_tblname';...
        's2o_tblname';'bpos_tblname';'cont_name'},...
        {image_plate;usr;pwd;db;...
        p2c_tblname;p2s_tblname;p2o_tblname;...
        s2o_tblname;bpos_tblname;cont_name}];
    
    writetable(cell2table(info), 'info.txt', 'Delimiter',' ',...
        'WriteVariableNames',false)
    
%   Maximum number of Plates/Density at any stage of the experiment
    N_96    = 3;
    N_384   = 2;
    N_1536  = 2;
    N_6144  = 0;
    
    init = [{96;384;1536;6144},...
        {N_96; N_384; N_1536; N_6144}];
    
    writetable(cell2table(init), 'init.txt', 'Delimiter',' ',...
        'WriteVariableNames',false)
    
%   UPSCALE PATTERNS
    upscale = [];
    upscale{4} = []; % how was 6144 made
    upscale{3} = [1,1,2,2;
        1,2,2,1]; % how was 1536 made
    upscale{2} = [1,3,2,1;
        2,1,3,1]; % how was 384 made
    
%%  LOADING DATA
%   Using info.txt and init.txt files just created
    fileID = fopen('info.txt','r');
    info = textscan(fileID, '%s%s');
    fileID = fopen('init.txt','r');
    init = textscan(fileID, '%f%f');
    
    iden = min(init{1,1}(init{1,2} ~= 0));
    
    sql_info = {info{1,2}{2:4}}; % {usr, pwd, db}
    conn = connSQL(sql_info);
    
    oec_plates = [];
    ncont = 2;
    
    if ~isempty(oec_plates)
        data = platemaps(sql_info, init, iden, ncont, oec_plates);
    else
        [~,sheet_name]=xlsfinfo('init_plates.xlsx');
    %   init_plate.xlsx has initial plate maps - one per sheet
    %   each mutant is represented by a unique numeric identifier (strain_id)
        for k=1:numel(sheet_name)
          data{k}=xlsread('init_plates.xlsx',sheet_name{k});
        end
    end
    
%%  INITILIZING VARIABLE NAMES    
    
    tablename_p2id  = info{1,2}{6};
    tablename_p2c   = info{1,2}{5};
    tablename_s2o   = info{1,2}{8};
    tablename_p2o   = info{1,2}{7};
    tablename_bpos  = info{1,2}{9};
    
    colnames_p2id   = {'pos','strain_id'};
    colnames_p2c    = {'pos','density','plate','row','col'};
    colnames_s2o    = {'strain_id','orf_name'};
    
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

%%  STARTER PLATE POS

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

%     find(cellfun(@isempty,upscale))
    
%     for up = 1:4
        if iden == 96
            for i = 1:init{1,2}(1)
                strain{1,i} = grid2row(data{i});
                
                tbl_p2c{1,i} = [pos{1,i};
                    ones(1,length(pos{1,i}))*length(pos{1,i});coor{1,i}{:}]';
                tbl_p2s{1,i} = [pos{1,i};strain{1,i}]';
            end
            for i = 1:init{1,2}(2)
                pos{2,i} = grid2row(plategen(pos{1,upscale{2}(i,1)} + 1000,...
                    pos{1,upscale{2}(i,2)} + 2000,...
                    pos{1,upscale{2}(i,3)} + 3000,...
                    pos{1,upscale{2}(i,4)} + 4000)) + i * 10000;
                strain{2,i} = grid2row(plategen(strain{1,upscale{2}(i,1)},...
                    strain{1,upscale{2}(i,2)},...
                    strain{1,upscale{2}(i,3)},...
                    strain{1,upscale{2}(i,4)}));
                
                tbl_p2c{2,i} = [pos{2,i};
                    ones(1,length(pos{2,i}))*length(pos{2,i});coor{2,i}{:}]';
                tbl_p2s{2,i} = [pos{2,i};strain{2,i}]';
            end
            for i = 1:init{1,2}(3)
                pos{3,i} = grid2row(plategen(pos{2,upscale{3}(i,1)} + 100000,...
                    pos{2,upscale{3}(i,2)} + 200000,...
                    pos{2,upscale{3}(i,3)} + 300000,...
                    pos{2,upscale{3}(i,4)} + 400000)) + i * 1000000;
                strain{3,i} = grid2row(plategen(strain{2,upscale{3}(i,1)},...
                    strain{2,upscale{3}(i,2)},...
                    strain{2,upscale{3}(i,3)},...
                    strain{2,upscale{3}(i,4)}));
                
                tbl_p2c{3,i} = [pos{3,i};
                    ones(1,length(pos{3,i}))*length(pos{3,i});coor{3,i}{:}]';
                tbl_p2s{3,i} = [pos{3,i};strain{3,i}]';
            end
            for i = 1:init{1,2}(4)
                pos{4,i} = grid2row(plategen(pos{3,upscale{4}(i,1)} + 10000000,...
                    pos{3,upscale{4}(i,2)} + 20000000,...
                    pos{3,upscale{4}(i,3)} + 30000000,...
                    pos{3,upscale{4}(i,4)} + 40000000)) + i * 100000000;
                strain{4,i} = grid2row(plategen(strain{3,upscale{4}(i,1)},...
                    strain{3,upscale{4}(i,2)},...
                    strain{3,upscale{4}(i,3)},...
                    strain{3,upscale{4}(i,4)}));
                
                tbl_p2c{4,i} = [pos{4,i};ones(1,length(pos{4,i}))*length(pos{4,i});
                    coor{4,i}{:}]';
                tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            end
        elseif iden == 384
            for i = 1:init{1,2}(2)
                strain{2,i} = grid2row(data{i});
                
                tbl_p2c{2,i} = [pos{2,i};ones(1,length(pos{2,i}))*length(pos{2,i});coor{2,i}{:}]';
                tbl_p2s{2,i} = [pos{2,i};strain{2,i}]';
            end
            for i = 1:init{1,2}(3)
                pos{3,i} = grid2row(plategen(pos{2,upscale{3}(i,1)},...
                    pos{2,upscale{3}(i,2)},...
                    pos{2,upscale{3}(i,3)},...
                    pos{2,upscale{3}(i,4)})) + i * 100000;
                strain{3,i} = grid2row(plategen(strain{2,upscale{3}(i,1)},...
                    strain{2,upscale{3}(i,2)},...
                    strain{2,upscale{3}(i,3)},...
                    strain{2,upscale{3}(i,4)}));
                
                tbl_p2c{3,i} = [pos{3,i};ones(1,length(pos{3,i}))*length(pos{3,i});coor{3,i}{:}]';
                tbl_p2s{3,i} = [pos{3,i};strain{3,i}]';
            end
            for i = 1:init{1,2}(4)
                pos{4,i} = grid2row(plategen(pos{3,upscale{4}(i,1)},...
                    pos{3,upscale{4}(i,2)},...
                    pos{3,upscale{4}(i,3)},...
                    pos{3,upscale{4}(i,4)})) + i * 1000000;
                strain{4,i} = grid2row(plategen(strain{3,upscale{4}(i,1)},...
                    strain{3,upscale{4}(i,2)},...
                    strain{3,upscale{4}(i,3)},...
                    strain{3,upscale{4}(i,4)}));
                
                tbl_p2c{4,i} = [pos{4,i};ones(1,length(pos{4,i}))*length(pos{4,i});coor{4,i}{:}]';
                tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            end
        elseif iden == 1536
            for i = 1:init{1,2}(3)
                strain{3,i} = grid2row(data{i});
                
                tbl_p2c{3,i} = [pos{3,i};ones(1,length(pos{3,i}))*length(pos{3,i});coor{3,i}{:}]';
                tbl_p2s{3,i} = [pos{3,i};strain{3,i}]';
            end
            for i = 1:init{1,2}(4)
                pos{4,i} = grid2row(plategen(pos{3,upscale{4}(i,1)},...
                    pos{3,upscale{4}(i,2)},...
                    pos{3,upscale{4}(i,3)},...
                    pos{3,upscale{4}(i,4)})) + i * 1000000;
                strain{4,i} = grid2row(plategen(strain{3,upscale{4}(i,1)},...
                    strain{3,upscale{4}(i,2)},...
                    strain{3,upscale{4}(i,3)},...
                    strain{3,upscale{4}(i,4)}));
                
                tbl_p2c{4,i} = [pos{4,i};ones(1,length(pos{4,i}))*length(pos{4,i});coor{4,i}{:}]';
                tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            end
        else
            for i = 1:init{1,2}(4)
                strain{4,i} = grid2row(data{i});
                
                tbl_p2c{4,i} = [pos{4,i};ones(1,length(pos{4,i}))*length(pos{4,i});coor{4,i}{:}]';
                tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            end
        end
%     end
    
%%  UPLOAD P2C & P2S DATA TO SQL
    
%   Position to ORF_name
    exec(conn, sprintf('drop table %s',tablename_p2id)); 
    exec(conn, sprintf(['create table %s ',...
        '(pos int not null, strain_id int not null)'], tablename_p2id));
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
    exec(conn, sprintf(['create table %s (pos int not null, ',...
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

        tbl_s2o = readtable('init_s2o.xlsx');
        exec(conn, sprintf('drop table %s',tablename_s2o)); 
        exec(conn, sprintf(['create table %s ',...
            '(strain_id int not null, orf_name varchar(20) null)'],tablename_s2o));

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
