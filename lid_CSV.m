%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  lid_CSV.m
%
%   Author: Saurin Parikh, August 2019
%   dr.saurin.parikh@gmail.com
%   
%   Final version of the LI Detector Pipeline with CSV input output
%
%   Colony Size/JPEG data to Q-VALUES for any experiment with  
%   Linear Interpolation based Reference Normalization.
%   Inputs Required:
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

    prompt={'Experiment Name:'};
    name='expt_name';
    numlines=1;
    defaultanswer={'test'};
    expt_name = char(inputdlg(prompt,name,numlines,defaultanswer));
      
    density = str2num(questdlg('What density plates are you using?',...
        'Density Options',...
        '1536','6144','6144'));
    if density == 6144
        dimensions = [64 96];
    else
        dimensions = [32 48];
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
    p2c         = readtable('/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/4C3_pos2coor6144.csv',...
        'Format','%d%d%d%d');
    n_plates    = unique(p2c.x6144plate)';
    p2o         = readtable('/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/4C3_pos2orf_name2.csv',...
        'Format','%d%C');
    sbox        = readtable('/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/4C3_smudgebox.csv',...
        'Format','%d');
    bpos        = readtable('/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/4C3_borderpos.csv',...
        'Format','%d');
    
    jpeg_data   = importdata('/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/4C3_GA2_6144_JPEG.csv');
    jpeg_data   = array2table(jpeg_data.data);
    jpeg_data.Properties.VariableNames = {'pos','hours','replicate1','replicate2','replicate3','average'};
    
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

    jpeg_data(ismember(jpeg_data.pos, bpos.pos),3:6) = ...
        array2table(ones(size(jpeg_data(ismember(jpeg_data.pos, bpos.pos),3:6),1),4)*NaN);

    jpeg_data(jpeg_data.average < 10,3:6) = ...
        array2table(ones(size(jpeg_data(jpeg_data.average < 10,3:6),1),4)*NaN);

    jpeg_data(ismember(jpeg_data.pos, sbox.pos),3:6) = ...
        array2table(ones(size(jpeg_data(ismember(jpeg_data.pos, sbox.pos),3:6),1),4)*NaN);
    
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
    