%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  imageanalyzer.m

%   Author: Saurin Parikh, October 2019
%   Generate pos2coor, pos2strainid, pos2orf_name table
%   
%   Needs info.txt, init.txt, init_plates.xlsx, init_s2o.xlsx in the home
%   directory
%   dr.saurin.parikh@gmail.com

%%  Load Paths to Files and Data

%     open load_toolkit.m and update the paths
    load_toolkit;
%     use info.txt in the directory as a example
%     place your file in the MATLAB directory
    fileID = fopen('info.txt','r');
    info = textscan(fileID, '%s%s');
    fileID = fopen('init.txt','r');
    init = textscan(fileID, '%s%s');
    
    [~,sheet_name]=xlsfinfo('init_plates.xlsx');
    for k=1:numel(sheet_name)
      data{k}=xlsread('init_plates.xlsx',sheet_name{k});
    end
    
    sql_info = {info{1,2}{4:6}}; % {usr, pwd, db}
    conn = connSQL(sql_info);
    
    expt_name = info{1,2}{7};
    
    tablename_p2id      = sprintf('%s_pos2strainid',expt_name);
    colnames_p2id       = {'pos','strain_id'};
    
    tablename_p2c96    = sprintf('%s_pos2coor96',expt_name);
    colnames_p2c96     = {'pos','96plate','96row','96col'};
    tablename_p2c384    = sprintf('%s_pos2coor384',expt_name);
    colnames_p2c384     = {'pos','384plate','384row','384col'};
    tablename_p2c1536   = sprintf('%s_pos2coor1536',expt_name);
    colnames_p2c1536    = {'pos','1536plate','1536row','1536col'};    
    tablename_p2c6144   = sprintf('%s_pos2coor6144',expt_name);
    colnames_p2c6144    = {'pos','6144plate','6144row','6144col'};
    
    tablename_s2o      = sprintf('%s_strainid2orf_name',expt_name);
    colnames_s2o       = {'strain_id','orf_name'};
    
    tablename_p2o   = sprintf('%s_pos2orf_name',expt_name);
    
%%  INDICES

    coor = [];
    for i = 1:str2num(init{1,2}{4})
        coor{4,i} = {[ones(1,6144)*i;indices(6144)]};
    end

    for i = 1:str2num(init{1,2}{3})
        coor{3,i} = {[ones(1,1536)*i;indices(1536)]};
    end

    for i = 1:str2num(init{1,2}{2})
        coor{2,i} = {[ones(1,384)*i;indices(384)]};
    end
    
    for i = 1:str2num(init{1,2}{1})
        coor{1,i} = {[ones(1,96)*i;indices(96)]};
    end
    
%%  STARTER PLATE POS

    pos = [];
    iden = size(data{1},1) * size(data{1},2);
    
    if iden == 6144
        for i = 1:str2num(init{1,2}{4})
            pos{4,i} = linspace(iden*(i-1)+1,iden*i,iden);
        end
    elseif iden == 1536
        for i = 1:str2num(init{1,2}{3})
            pos{3,i} = linspace(iden*(i-1)+1,iden*i,iden);
        end
    elseif iden == 384
        for i = 1:str2num(init{1,2}{2})
            pos{2,i} = linspace(iden*(i-1)+1,iden*i,iden);
        end
    else
        for i = 1:str2num(init{1,2}{1})
            pos{1,i} = linspace(iden*(i-1)+1,iden*i,iden);
        end
    end
    
%%  UPSCALE PATTERN
%%
%   EDIT THIS PER EXPERIMENT
    upscale = [];
    upscale{4} = [];
    upscale{3} = [1,1,1,1;...
                  2,2,2,2];
    upscale{2} = [];
%%
    strain = [];
    tbl_p2c = [];
    tbl_p2s = [];
    
    for up = 1:4
        if iden == 96
            for i = 1:str2num(init{1,2}{1})
                strain{1,i} = grid2row(data{i});
                
                tbl_p2c{1,i} = [pos{1,i};coor{1,i}{:}]';
                tbl_p2s{1,i} = [pos{1,i};strain{1,i}]';
            end
            for i = 1:str2num(init{1,2}{2})
                pos{2,i} = grid2row(plategen(pos{1,upscale{2}(i,1)}+1000,...
                    pos{1,upscale{2}(i,2)}+2000,...
                    pos{1,upscale{2}(i,3)}+3000,...
                    pos{1,upscale{2}(i,4)}+4000));
                strain{2,i} = grid2row(plategen(strain{1,upscale{2}(i,1)},...
                    strain{1,upscale{2}(i,2)},...
                    strain{1,upscale{2}(i,3)},...
                    strain{1,upscale{2}(i,4)}));
                
                tbl_p2c{2,i} = [pos{2,i};coor{2,i}{:}]';
                tbl_p2s{2,i} = [pos{2,i};strain{2,i}]';
            end
            for i = 1:str2num(init{1,2}{3})
                pos{3,i} = grid2row(plategen(pos{2,upscale{3}(i,1)}+10000,...
                    pos{2,upscale{3}(i,2)}+20000,...
                    pos{2,upscale{3}(i,3)}+30000,...
                    pos{2,upscale{3}(i,4)}+40000));
                strain{3,i} = grid2row(plategen(strain{2,upscale{3}(i,1)},...
                    strain{2,upscale{3}(i,2)},...
                    strain{2,upscale{3}(i,3)},...
                    strain{2,upscale{3}(i,4)}));
                
                tbl_p2c{3,i} = [pos{3,i};coor{3,i}{:}]';
                tbl_p2s{3,i} = [pos{3,i};strain{3,i}]';
            end
            for i = 1:str2num(init{1,2}{4})
                pos{4,i} = grid2row(plategen(pos{3,upscale{4}(i,1)}+100000,...
                    pos{3,upscale{4}(i,2)}+200000,...
                    pos{3,upscale{4}(i,3)}+300000,...
                    pos{3,upscale{4}(i,4)}+400000));
                strain{4,i} = grid2row(plategen(strain{3,upscale{4}(i,1)},...
                    strain{3,upscale{4}(i,2)},...
                    strain{3,upscale{4}(i,3)},...
                    strain{3,upscale{4}(i,4)}));
                
                tbl_p2c{4,i} = [pos{4,i};coor{4,i}{:}]';
                tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            end
        elseif iden == 384
            for i = 1:str2num(init{1,2}{2})
                strain{2,i} = grid2row(data{i});
                
                tbl_p2c{2,i} = [pos{2,i};coor{2,i}{:}]';
                tbl_p2s{2,i} = [pos{2,i};strain{2,i}]';
            end
            for i = 1:str2num(init{1,2}{3})
                pos{3,i} = grid2row(plategen(pos{2,upscale{3}(i,1)}+10000,...
                    pos{2,upscale{3}(i,2)}+20000,...
                    pos{2,upscale{3}(i,3)}+30000,...
                    pos{2,upscale{3}(i,4)}+40000));
                strain{3,i} = grid2row(plategen(strain{2,upscale{3}(i,1)},...
                    strain{2,upscale{3}(i,2)},...
                    strain{2,upscale{3}(i,3)},...
                    strain{2,upscale{3}(i,4)}));
                
                tbl_p2c{3,i} = [pos{3,i};coor{3,i}{:}]';
                tbl_p2s{3,i} = [pos{3,i};strain{3,i}]';
            end
            for i = 1:str2num(init{1,2}{4})
                pos{4,i} = grid2row(plategen(pos{3,upscale{4}(i,1)}+100000,...
                    pos{3,upscale{4}(i,2)}+200000,...
                    pos{3,upscale{4}(i,3)}+300000,...
                    pos{3,upscale{4}(i,4)}+400000));
                strain{4,i} = grid2row(plategen(strain{3,upscale{4}(i,1)},...
                    strain{3,upscale{4}(i,2)},...
                    strain{3,upscale{4}(i,3)},...
                    strain{3,upscale{4}(i,4)}));
                
                tbl_p2c{4,i} = [pos{4,i};coor{4,i}{:}]';
                tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            end
        elseif iden == 1536
            for i = 1:str2num(init{1,2}{3})
                strain{3,i} = grid2row(data{i});
                
                tbl_p2c{3,i} = [pos{3,i};coor{3,i}{:}]';
                tbl_p2s{3,i} = [pos{3,i};strain{3,i}]';
            end
            for i = 1:str2num(init{1,2}{4})
                pos{4,i} = grid2row(plategen(pos{3,upscale{4}(i,1)}+100000,...
                    pos{3,upscale{4}(i,2)}+200000,...
                    pos{3,upscale{4}(i,3)}+300000,...
                    pos{3,upscale{4}(i,4)}+400000));
                strain{4,i} = grid2row(plategen(strain{3,upscale{4}(i,1)},...
                    strain{3,upscale{4}(i,2)},...
                    strain{3,upscale{4}(i,3)},...
                    strain{3,upscale{4}(i,4)}));
                
                tbl_p2c{4,i} = [pos{4,i};coor{4,i}{:}]';
                tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            end
        else
            for i = 1:str2num(init{1,2}{4})
                strain{4,i} = grid2row(data{i});
                
                tbl_p2c{4,i} = [pos{4,i};coor{4,i}{:}]';
                tbl_p2s{4,i} = [pos{4,i};strain{4,i}]';
            end
        end
    end
    
%%  UPLOAD P2C & P2S DATA TO SQL
    
    exec(conn, sprintf('drop table %s',tablename_p2id)); 
    exec(conn, sprintf(['create table %s ',...
        '(pos int not null, strain_id int not null)'], tablename_p2id));
    
    for i = 1:length(tbl_p2s)
        if ~isempty(tbl_p2s{i})
            for ii = 1:size(tbl_p2s{2},2)
                datainsert(conn,tablename_p2id,colnames_p2id,tbl_p2s{i,ii});
            end
        end
    end
    
    if ~isempty(tbl_p2c{1})
        exec(conn, sprintf('drop table %s',tablename_p2c96)); 
        exec(conn, sprintf(['create table %s (pos int not null, ',...
            '96plate int not null, '...
            '96row int not null, 96col int not null)'],tablename_p2c96));
        for ii = 1:str2num(init{1,2}{1})
            datainsert(conn,tablename_p2c96,colnames_p2c96,tbl_p2c{1,ii});
        end
    end
    
    if ~isempty(tbl_p2c{2})
        exec(conn, sprintf('drop table %s',tablename_p2c384)); 
        exec(conn, sprintf(['create table %s (pos int not null, ',...
            '384plate int not null, '...
            '384row int not null, 384col int not null)'],tablename_p2c384));
        for ii = 1:str2num(init{1,2}{2})
            datainsert(conn,tablename_p2c384,colnames_p2c384,tbl_p2c{2,ii});
        end
    end
    
    if ~isempty(tbl_p2c{3})
        exec(conn, sprintf('drop table %s',tablename_p2c1536)); 
        exec(conn, sprintf(['create table %s (pos int not null, ',...
            '1536plate int not null, '...
            '1536row int not null, 1536col int not null)'],tablename_p2c1536));
        for ii = 1:str2num(init{1,2}{3})
            datainsert(conn,tablename_p2c1536,colnames_p2c1536,tbl_p2c{3,ii});
        end
    end
    
    if ~isempty(tbl_p2c{4})
        exec(conn, sprintf('drop table %s',tablename_p2c6144)); 
        exec(conn, sprintf(['create table %s (pos int not null, ',...
            '6144plate int not null, '...
            '6144row int not null, 6144col int not null)'],tablename_p2c6144));
        for ii = 1:str2num(init{1,2}{4})
            datainsert(conn,tablename_p2c6144,colnames_p2c6144,tbl_p2c{4,ii});
        end
    end
    
%%  STRAIN_ID 2 ORF_NAME

    tbl_s2o = readtable('init_s2o.xlsx');

    exec(conn, sprintf('drop table %s',tablename_s2o)); 
    exec(conn, sprintf(['create table %s ',...
        '(strain_id int not null, orf_name varchar(20) not null)'],tablename_s2o));
    
    datainsert(conn,tablename_s2o,colnames_s2o,tbl_s2o);
    
%%  POS2ORF_NAME
    
    exec(conn, sprintf('drop table %s',tablename_p2o));
    exec(conn, sprintf(['create table %s ',...
        ' (select a.pos, b.orf_name',...
        ' from %s a, %s b',...
        ' where a.strain_id = b.strain_id)'],...
        tablename_p2o,...
        tablename_p2id,...
        tablename_s2o));
    
    

    