%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  lid.m
%
%   Author: Saurin Parikh, August 2019
%   dr.saurin.parikh@gmail.com
%   
%   Final version of the LI Detector Pipeline
%
%   Colony Size/JPEG data to Q-VALUES for any experiment with  
%   Linear Interpolation based Reference Normalization.
%   Inputs Required:
%       sql info (username, password, database name),
%       experiment name, pos2coor tablename, pos2orf_name tablename, 
%       control name, borderpos, smudgebox
%   Provides option to work with .csv rather than SQL

%%  Load Paths to Files and Data
    
    load_toolkit;

%%  Initialization

%   Set preferences with setdbprefs.
    setdbprefs('DataReturnFormat', 'structure');
    setdbprefs({'NullStringRead';'NullStringWrite';'NullNumberRead';'NullNumberWrite'},...
                  {'null';'null';'NaN';'NaN'})
    
    prompt={'Username:',...
        'Password:',...
        'Database:'};
    name='SQL Database';
    sql_info = char(inputdlg(prompt,...
        name,1,...
        {'usr','pwd','db'}));

    prompt={'Experiment Name:'};
    name='expt_name';
    numlines=1;
    defaultanswer={'test'};
    expt_name = char(inputdlg(prompt,name,numlines,defaultanswer));
      
    switch questdlg('Is plate density 384 or higher?',...
        'Density Options',...
        'Yes','No','Yes')
        case 'Yes'
            density = str2num(questdlg('What density plates are you using?',...
                'Density Options',...
                '384','1536','6144','6144'));
            if density == 6144
                dimensions = [64 96];
            elseif density == 1536
                dimensions = [32 48];
            else
                dimensions = [16 24];
            end
        case 'No'
            density = 96;
            dimensions = [8 12];
    end
    
%   MySQL Tablenames  
    tablename_jpeg      = sprintf('%s_%d_JPEG',expt_name,density);
    tablename_norm      = sprintf('%s_%d_NORM',expt_name,density);
    tablename_fit       = sprintf('%s_%d_FITNESS',expt_name,density);
    tablename_fits      = sprintf('%s_%d_FITNESS_STATS',expt_name,density);
    tablename_es        = sprintf('%s_%d_FITNESS_ES',expt_name,density);
    tablename_pval      = sprintf('%s_%d_PVALUE',expt_name,density);
    tablename_res       = sprintf('%s_%d_RES',expt_name,density);
    
%   MySQL Connection and fetch pos2coor data
    conn = connSQL(strtrim(sql_info(3,:)),...
        strtrim(sql_info(1,:)),...
        strtrim(sql_info(2,:)));
    
    prompt={'Name:',...
        '"Plate" column:',...
        '"Column" column:',...
        '"Row" column:'};
    name='P2C Table Info';
    defaultanswers={'expt_pos2coor','384plate','384col','384row'};
    p2c_info = char(inputdlg(prompt,...
        name,1,defaultanswers));

    p2c = fetch(conn, sprintf(['select * from %s a ',...
        'order by a.%s, a.%s, a.%s'],...
        p2c_info(1,:),...
        p2c_info(2,:),...
        p2c_info(3,:),...
        p2c_info(4,:)));
    
    n_plates = fetch(conn, sprintf(['select distinct %s from %s a ',...
        'order by %s asc'],...
        p2c_info(2,:),...
        p2c_info(1,:),...
        p2c_info(2,:)));
    
    prompt = {'POS2ORF_NAME table:',...
        'BORDER POS table:',...
        'SMUDGEBOX table:'};
    name = 'Other Tables';
    tablename_other = char(inputdlg(prompt,...
        name,1,...
        {'expt_pos2orf_name','expt_borderpos','expt_smudgebox'}));
    
    tablename_p2o   = strtrim(tablename_other(1,:));
    tablename_bpos  = strtrim(tablename_other(2,:));
    tablename_sbox  = strtrim(tablename_other(3,:));
    
%     prompt={'Enter the number of replicates in this study:'};
%     replicate = str2num(cell2mat(inputdlg(prompt,...
%         'Replicates',1,...
%         {'4'})));

%     if density >384
%         prompt={'Enter the name of your source table:'};
%         tablename_null = char(inputdlg(prompt,...
%             'Source Table',1,...
%             {'expt_384_SPATIAL'}));
%         source_nulls = fetch(conn, sprintf(['select a.pos from %s a ',...
%             'where a.csS is NULL ',...
%             'order by a.pos asc'],tablename_null));
%     end
    
    prompt={'Enter the control stain orf_name:'};
    cont.name = char(inputdlg(prompt,...
        'Control Strain',1,...
        {'BF_control'}));
    
%     close(conn);
    
%%  SPATIAL cleanup
%   Border colonies, light artefact and smudge correction

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
    
%%  Upload JPEG to NORM data
%   Linear Interpolation based CN

    IL = 1; % 1 = interleave

    hours = fetch(conn, sprintf(['select distinct hours from %s ',...
        'order by hours asc'], tablename_jpeg));
    hours = hours.hours;

    data_fit = LinearInNorm(hours,n_plates,p2c_info,cont.name,...
        tablename_p2o,tablename_jpeg,IL);

    exec(conn, sprintf('drop table %s',tablename_norm));
    exec(conn, sprintf(['create table %s ( ',...
                'pos int(11) not NULL, ',...
                'hours int(11) not NULL, ',...
                'bg double default NULL, ',...
                'average double default NULL, ',...
                'fitness double default NULL ',...
                ')'],tablename_norm));
    for i=1:length(hours)
        datainsert(conn, tablename_norm,...
            {'pos','hours','bg','average','fitness'},data_fit{i});
    end

    exec(conn, sprintf('drop table %s',tablename_fit)); 
    exec(conn, sprintf(['create table %s ',...
        '(select b.orf_name, a.pos, a.hours, a.bg, a.average, a.fitness ',...
        'from %s a, %s b ',...
        'where a.pos = b.pos ',...
        'order by a.pos asc)'],tablename_fit,tablename_norm,tablename_p2o));

%%  FITNESS STATS

    clear data

    exec(conn, sprintf('drop table %s', tablename_fits));
    exec(conn, sprintf(['create table %s (orf_name varchar(255) null, ',...
        'hours int not null, N int not null, cs_mean double null, ',...
        'cs_median double null, cs_std double null)'],tablename_fits));

    colnames_fits = {'orf_name','hours','N','cs_mean','cs_median','cs_std'};

    stat_data = fitstats(tablename_fit,...
        strtrim(sql_info(3,:)),...
        strtrim(sql_info(1,:)),...
        strtrim(sql_info(2,:)));
    tic
    datainsert(conn,tablename_fits,colnames_fits,stat_data)
    sqlwrite(conn,tablename_fits,struct2table(stat_data));
    toc
  
%%  FITNESS STATS to EMPIRICAL P VALUES

    exec(conn, sprintf('drop table %s',tablename_pval));
    exec(conn, sprintf(['create table %s (orf_name varchar(255) null,'...
        'hours int not null, p double null, stat double null)'],tablename_pval));
    colnames_pval = {'orf_name','hours','p','stat'};

    contpos = fetch(conn, sprintf(['select pos from %s ',...
        'where orf_name = ''%s'' and pos < 10000 ',...
        'and pos not in ',...
        '(select pos from %s)'],...
        tablename_p2o,cont.name,tablename_bpos));
    contpos = contpos.pos + [110000,120000,130000,140000,...
        210000,220000,230000,240000];

    for iii = 1:length(hours)
        contfit = [];
        for ii = 1:length(contpos)
            temp = fetch(conn, sprintf(['select fitness from %s ',...
                'where hours = %d and pos in (%s) ',...
                'and fitness is not null'],tablename_fit,hours(iii),...
                sprintf('%d,%d,%d,%d,%d,%d,%d,%d',contpos(ii,:))));

            if nansum(temp.fitness) > 0
                outlier = isoutlier(temp.fitness);
                temp.fitness(outlier) = NaN;
                contfit = [contfit, nanmean(temp.fitness)];
            end
        end
        contmean = nanmean(contfit);
        contstd = nanstd(contfit);

        orffit = fetch(conn, sprintf(['select orf_name, cs_median, ',...
            'cs_mean, cs_std from %s ',...
            'where hours = %d and orf_name != ''%s'' ',...
            'order by orf_name asc'],tablename_fits,hours(iii),cont.name));

        m = contfit';
        tt = length(m);
        pvals = [];
        stat = [];
        for i = 1:length(orffit.orf_name)
            if sum(m<orffit.cs_mean(i)) < tt/2
                if m<orffit.cs_mean(i) == 0
                    pvals = [pvals; 1/tt];
                    stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
                else
                    pvals = [pvals; ((sum(m<=orffit.cs_mean(i)))/tt)*2];
                    stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
                end
            else
                pvals = [pvals; ((sum(m>=orffit.cs_mean(i)))/tt)*2];
                stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
            end
        end

        pdata{iii}.orf_name = orffit.orf_name;
        pdata{iii}.hours = ones(length(pdata{iii}.orf_name),1)*hours(iii);
        pdata{iii}.p = num2cell(pvals);
        pdata{iii}.p(cellfun(@isnan,pdata{iii}.p)) = {[]};
        pdata{iii}.stat = num2cell(stat);
        pdata{iii}.stat(cellfun(@isnan,pdata{iii}.stat)) = {[]};

        sqlwrite(conn,tablename_pval,struct2table(pdata{iii}));
    end
        
%%  END
    