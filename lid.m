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

%%  Load Paths to Files and Expt Info
    
%   open load_toolkit.m and update the paths
    load_toolkit;
%   use info.txt in the directory as a example
%   place your file in the MATLAB directory
    fileID = fopen('info.txt','r');
    info = textscan(fileID, '%s%s');

%%  INITIALIZATION

%   Set preferences with setdbprefs.
    setdbprefs('DataReturnFormat', 'structure');
    setdbprefs({'NullStringRead';'NullStringWrite';'NullNumberRead';'NullNumberWrite'},...
                  {'null';'null';'NaN';'NaN'})
    
%   MySQL Connection
    sql_info = {info{1,2}{2:4}}; % {usr, pwd, db}
    conn = connSQL(sql_info);

%   EXPT Name, Density and Tables
    expt_name = 'SDS_LI'; % EDIT THIS ACCORDING TO THE EXPT
    density = 6144; % EDIT THIS ACCORDING TO IMAGES
%%   
    if density == 6144
        dimensions = [64 96];
    elseif density == 1536
        dimensions = [32 48];
    elseif density == 384
        dimensions = [16 24];
    else
        dimensions = [8 12];
    end
      
    tablename_jpeg      = sprintf('%s_%d_JPEG',expt_name,density);
    tablename_norm      = sprintf('%s_%d_NORM',expt_name,density);
    tablename_fit       = sprintf('%s_%d_FITNESS',expt_name,density);
    tablename_fits      = sprintf('%s_%d_FITNESS_STATS',expt_name,density);
    tablename_es        = sprintf('%s_%d_FITNESS_ES',expt_name,density);
    tablename_pval      = sprintf('%s_%d_PVALUE',expt_name,density);
    tablename_res       = sprintf('%s_%d_RES',expt_name,density);
    
    tablename_p2s  = info{1,2}{6};
    tablename_p2o  = info{1,2}{7};
    tablename_bpos = info{1,2}{9};
    
    p2c_info = {info{1,2}{5},'plate','row','col'};
    p2c = fetch(conn, sprintf(['select * from %s a ',...
        'where density = %d ',...
        'order by a.%s, a.%s, a.%s'],...
        p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));
%     p2c.Properties.VariableNames = {'pos','density','plate','row','col'};
    
    n_plates = fetch(conn, sprintf(['select distinct %s from %s ',...
        'where density = %d ',...
        'order by %s asc'],...
        p2c_info{2},p2c_info{1},density,p2c_info{2}));
    
%     if density >384
%         prompt={'Enter the name of your source table:'};
%         tablename_null = char(inputdlg(prompt,...
%             'Source Table',1,...
%             {'expt_384_SPATIAL'}));
%         source_nulls = fetch(conn, sprintf(['select a.pos from %s a ',...
%             'where a.csS is NULL ',...
%             'order by a.pos asc'],tablename_null));
%     end
  
%%  CONTROL STRAIN NAME
    cont.name = info{1,2}{10};

%%  JPEG COMPETITION CORRECTION
    
%     jpeg_data = fetch(conn, sprintf(['select a.*, b.orf_name, c.%s, c.%s, c.%s '...
%         'from %s a, %s b, %s c '...
%         'where a.pos = b.pos and a.pos = c.pos '...
%         'order by a.hours, c.%s, c.%s, c.%s'],...
%         p2c_info(2,:), p2c_info(4,:), p2c_info(3,:),...
%         tablename_jpeg, tablename_p2o, p2c_info(1,:),...
%         p2c_info(2,:), p2c_info(3,:), p2c_info(4,:)));
%     jpeg_data.Properties.VariableNames = {'pos','hours','replicate1','replicate2','replicate3','average',...
%         'orf_name','plate','row','col'};
    

%%  Upload JPEG to NORM data
%   Linear Interpolation based CN

    IL = 1; % 1 = to interleave / 0 = to not

    hours = fetch(conn, sprintf(['select distinct hours from %s ',...
        'order by hours asc'], tablename_jpeg));
    hours = hours.hours;

    fit_data = LinearInNorm(hours,n_plates,p2c_info,cont.name,...
        tablename_p2o,tablename_jpeg,IL,density,dimensions,sql_info);

    exec(conn, sprintf('drop table %s',tablename_norm));
    exec(conn, sprintf(['create table %s ( ',...
                'pos int(11) not NULL, ',...
                'hours double not NULL, ',...
                'bg double default NULL, ',...
                'average double default NULL, ',...
                'fitness double default NULL ',...
                ')'],tablename_norm));
    for i=1:length(hours)
        datainsert(conn, tablename_norm,...
            {'pos','hours','bg','average','fitness'},fit_data{i});
    end

    exec(conn, sprintf('drop table %s',tablename_fit)); 
    exec(conn, sprintf(['create table %s ',...
        '(select c.strain_id, b.orf_name, a.pos, a.hours, a.bg, a.average, a.fitness ',...
        'from %s a, %s b , %s c ',...
        'where a.pos = b.pos and b.pos = c.pos ',...
        'order by a.hours, a.pos asc)'],...
        tablename_fit,tablename_norm,tablename_p2o,tablename_p2s));

%%  FITNESS STATS

    clear data

    exec(conn, sprintf('drop table %s', tablename_fits));
    exec(conn, sprintf(['create table %s (strain_id int not null, ',...
        'orf_name varchar(255) null, ',...
        'hours double not null, N int not null, cs_mean double null, ',...
        'cs_median double null, cs_std double null)'],tablename_fits));

    colnames_fits = {'strain_id','orf_name','hours','N','cs_mean','cs_median','cs_std'};

    stat_data = fitstats_sid(tablename_fit,sql_info);
    
    tic
    datainsert(conn,tablename_fits,colnames_fits,stat_data)
%     sqlwrite(conn,tablename_fits,struct2table(stat_data));
    toc
  
%%  FITNESS STATS to EMPIRICAL P VALUES

    exec(conn, sprintf('drop table %s',tablename_pval));
    exec(conn, sprintf(['create table %s (strain_id int not null, ',...
        'orf_name varchar(255) null,'...
        'hours double not null, p double null, stat double null, ',...
        'es double null)'],tablename_pval));
    colnames_pval = {'strain_id','orf_name','hours','p','stat','es'};

    contpos = fetch(conn, sprintf(['select pos from %s ',...
        'where orf_name = ''%s'' and pos < 100000 ',...
        'and pos not in ',...
        '(select pos from %s)'],...
        tablename_p2o,cont.name,tablename_bpos));
    
    if density == 1536
        contpos = contpos.pos + [100000,200000,300000,400000,...
            500000,600000,700000,800000];
    elseif density == 6144
        contpos = contpos.pos + [100000,200000,300000,400000,...
            500000,600000,700000,800000];
        contpos = [contpos + 1000000, contpos + 2000000, contpos + 3000000, contpos + 4000000,...
            contpos + 5000000, contpos + 6000000, contpos + 7000000, contpos + 8000000];
%         contpos = contpos.pos + [110000,120000,130000,140000,...
%             210000,220000,230000,240000,...
%             310000,320000,330000,340000,...
%             410000,420000,430000,440000];
%         contpos = contpos.pos + [110000,120000,130000,140000,...
%             210000,220000,230000,240000];
    end

    for iii = 1:length(hours)
        contfit = [];
        for ii = 1:length(contpos)
            cp = sprintf('%d,',contpos(ii,:));
            temp = fetch(conn, sprintf(['select fitness from %s ',...
                'where hours = %0.2f and pos in (%s) ',...
                'and fitness is not null'],tablename_fit,hours(iii),...
                cp(1:end-1)));

            if nansum(temp.fitness) > 0
                outlier = isoutlier(temp.fitness);
                temp.fitness(outlier) = NaN;
                contfit = [contfit, nanmean(temp.fitness)];
            end
        end
        contmean = nanmean(contfit);
        contstd = nanstd(contfit);

        orffit = fetch(conn, sprintf(['select strain_id, ',...
            'orf_name, cs_median, ',...
            'cs_mean, cs_std from %s ',...
            'where hours = %0.2f and orf_name != ''%s'' ',...
            'order by orf_name asc'],tablename_fits,hours(iii),cont.name));

        m = contfit';
        tt = length(m);
        pvals = [];
        es = [];
        stat = [];
        for i = 1:length(orffit.strain_id)
            if sum(m<orffit.cs_mean(i)) < tt/2
                if m<orffit.cs_mean(i) == 0
                    pvals = [pvals; 1/tt];
                    es = [es; (orffit.cs_mean(i) - contmean)/contmean];
                    stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
                else
                    pvals = [pvals; ((sum(m<=orffit.cs_mean(i)))/tt)*2];
                    es = [es; (orffit.cs_mean(i) - contmean)/contmean];
                    stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
                end
            else
                pvals = [pvals; ((sum(m>=orffit.cs_mean(i)))/tt)*2];
                es = [es; (orffit.cs_mean(i) - contmean)/contmean];
                stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
            end
        end

        pdata{iii}.strain_id                                = orffit.strain_id;
        pdata{iii}.orf_name                                 = orffit.orf_name;
        pdata{iii}.hours                                    = ones(length(pdata{iii}.orf_name),1)*hours(iii);
        pdata{iii}.p                                        = num2cell(pvals);
        pdata{iii}.p(cellfun(@isnan,pdata{iii}.p))          = {[]};
        pdata{iii}.stat                                     = num2cell(stat);
        pdata{iii}.stat(cellfun(@isnan,pdata{iii}.stat))    = {[]};
        pdata{iii}.es                                       = num2cell(es);
        pdata{iii}.es(cellfun(@isnan,pdata{iii}.es))        = {[]};

        sqlwrite(conn,tablename_pval,struct2table(pdata{iii}));
    end
        
%%  END
    