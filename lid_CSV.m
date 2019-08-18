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
    p2c         = readtable('/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/4C3_pos2coor6144.csv','Format','%f%f%f%f');
    p2c.Properties.VariableNames = {'pos','plate','row','col'};
    n_plates    = unique(p2c.plate)';
    p2o         = readtable('/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/4C3_pos2orf_name2.csv','Format','%f%s');
    sbox        = readtable('/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/4C3_smudgebox.csv','Format','%f');
    bpos        = readtable('/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/4C3_borderpos.csv','Format','%f');
    
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
    hours = unique(jpeg_data.hours);

    norm_data = NORM_CSV(hours,n_plates,p2c,cont.name,p2o,jpeg_data,IL);
    orf_data = [];
    for i=1:length(hours)
        temp = norm_data(norm_data.hours == hours(i),:);
        [ai, bi] = ismember(temp.pos, p2o.pos);
        orf_data = [orf_data; p2o.orf_name(bi)];
    end
    fit_data = table(orf_data, norm_data.pos, norm_data.hours,...
        norm_data.bg, norm_data.average, norm_data.fitness,...
        'VariableNames',...
        {'orf_name','pos','hours','bg','average','fitness'});
    
    writetable(norm_data,...
        '/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/output/4C3_GA2_6144_NORM.csv');
    writetable(fit_data,...
        '/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/output/4C3_GA2_6144_FITNESS.csv');
    
%%  FITNESS STATS

    stat_data = fitstats_CSV(fit_data, hours);
    stat_data = stat_data(~isnan(stat_data.cs_mean),:);

    writetable(stat_data,...
        '/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/output/4C3_GA2_6144_FITNESS_STATS.csv');
  
%%  FITNESS STATS to EMPIRICAL P VALUES
    
    contpos = p2o.pos(strcmp(p2o.orf_name, {'"BF_control"'}) &...
        p2o.pos < 10000 &...
        ~ismember(p2o.pos, bpos.pos));
    contpos = contpos + [110000,120000,130000,140000,...
        210000,220000,230000,240000];
    
    p_data = [];
    for iii = 1:length(hours)
        contfit = [];
        for ii = 1:length(contpos)
            temp = fit_data.fitness(fit_data.hours == hours(iii) & ismember(fit_data.pos,contpos(ii,:)));

            if nansum(temp) > 0
                outlier = isoutlier(temp);
                temp(outlier) = NaN;
                contfit = [contfit, nanmean(temp)];
            end
        end
        contmean = nanmean(contfit);
        contstd = nanstd(contfit);

        orffit = stat_data(stat_data.hours == hours(iii) & ~strcmpi(stat_data.orf_name,{sprintf('"%s"',cont.name)}),:);

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
        
        pdata = table();
        pdata.orf_name = orffit.orf_name;
        pdata.hours = ones(length(pdata.orf_name),1)*hours(iii);
        pdata.p = pvals;
        pdata.stat = stat;
        
        p_data = [p_data; pdata];
    end
    
    writetable(p_data,...
        '/Users/saur1n/Documents/MATLAB/lidetector/csvtrial/output/4C3_GA2_6144_PVALUE.csv');
        
%%  END
    