%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  fitstats.m

%   Author: Saurin Parikh, August 2019
%   dr.saurin.parikh@gmail.com
%
%   Calculate mean, median & std fitness of strains in an hour-wise
%   replicate-wise manner
%   Input: FITNESS Tablename, SQL usr, pwd and db

%%

    function data = fitstats(table, sql_info)
    
        conn = connSQL(sql_info);
        inc.tt=1;
        hrs = fetch(conn, sprintf(['select distinct hours ',...
            'from %s'],table));
        
        for iii=1:length(hrs.hours)
            clear fit_dat;
            fit_dat = fetch(conn, sprintf(['select a.orf_name, ',...
                'a.hours, a.fitness ',...
                'from %s a ',...
                'where a.hours = %0.2f ',...
                'and a.fitness is not NULL ',...
                'and a.orf_name != ''null'' and a.orf_name is not NULL ',...
                'and a.orf_name != '''' ',...
                'order by a.orf_name asc'],table,hrs.hours(iii)));

            inc.t=1;
            for ii = 1 : (size(fit_dat.orf_name, 1))-1
                if(strcmpi(fit_dat.orf_name{ii, 1},fit_dat.orf_name{ii+1, 1})==1)
                    temp(1, inc.t) = fit_dat.fitness(ii, 1);
                    inc.t=inc.t+1;
                    if (ii == size(fit_dat.orf_name, 1)-1)
                        temp(1, inc.t) = fit_dat.fitness(ii+1, 1);
                        data.orf_name{inc.tt, 1} = fit_dat.orf_name{ii, 1};
                        data.hours(inc.tt, 1) = fit_dat.hours(ii, 1);
                        data.N(inc.tt, 1) = length(temp(~isoutlier(temp)));
                        data.cs_mean(inc.tt, 1) = nanmean(temp(~isoutlier(temp)));
                        data.cs_median(inc.tt, 1) = nanmedian(temp(~isoutlier(temp)));
                        data.cs_std(inc.tt, 1) = nanstd(temp(~isoutlier(temp)));
                        inc.tt=inc.tt+1;
                    end
                else
                    temp(1, inc.t) = fit_dat.fitness(ii, 1);
                    data.orf_name{inc.tt, 1} = fit_dat.orf_name{ii, 1};
                    data.hours(inc.tt, 1) = fit_dat.hours(ii, 1);
                    data.N(inc.tt, 1) = length(temp(~isoutlier(temp)));
                    data.cs_mean(inc.tt, 1) = nanmean(temp(~isoutlier(temp)));
                    data.cs_median(inc.tt, 1) = nanmedian(temp(~isoutlier(temp)));
                    data.cs_std(inc.tt, 1) = nanstd(temp(~isoutlier(temp)));
                    clear temp;
                    inc.t=1;
                    inc.tt=inc.tt+1;
                end
            end
        end
        conn(close);
    end

