%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  fitstats_CSV.m

%   Author: Saurin Parikh, August 2019
%   dr.saurin.parikh@gmail.com
%
%   Calculate mean, median & std fitness of strains in an hour-wise
%   replicate-wise manner
%   Input: FITNESS Tablename, SQL usr, pwd and db

%%

    function stats_data = fitstats_CSV(fit_data, hours)
    
        inc.tt=1;
        for iii=1:length(hours)
            temp_data = fit_data(fit_data.hours == hours(iii),:); 
            [~, srt] = sort(temp_data.orf_name);
            temp_data = temp_data(srt, :);
            inc.t=1;
            for ii = 1 : (size(temp_data.orf_name, 1))-1
                if(strcmpi(temp_data.orf_name{ii, 1},temp_data.orf_name{ii+1, 1})==1)
                    temp(1, inc.t) = temp_data.fitness(ii, 1);
                    inc.t=inc.t+1;
                    if (ii == size(temp_data.orf_name, 1)-1)
                        temp(1, inc.t) = temp_data.fitness(ii+1, 1);
                        stats_data.orf_name{inc.tt, 1} = temp_data.orf_name{ii, 1};
                        stats_data.hours(inc.tt, 1) = temp_data.hours(ii, 1);
                        stats_data.N(inc.tt, 1) = length(temp(~isoutlier(temp)));
                        stats_data.cs_mean(inc.tt, 1) = nanmean(temp(~isoutlier(temp)));
                        stats_data.cs_median(inc.tt, 1) = nanmedian(temp(~isoutlier(temp)));
                        stats_data.cs_std(inc.tt, 1) = nanstd(temp(~isoutlier(temp)));
                        inc.tt=inc.tt+1;
                    end
                else
                    temp(1, inc.t) = temp_data.fitness(ii, 1);
                    stats_data.orf_name{inc.tt, 1} = temp_data.orf_name{ii, 1};
                    stats_data.hours(inc.tt, 1) = temp_data.hours(ii, 1);
                    stats_data.N(inc.tt, 1) = length(temp(~isoutlier(temp)));
                    stats_data.cs_mean(inc.tt, 1) = nanmean(temp(~isoutlier(temp)));
                    stats_data.cs_median(inc.tt, 1) = nanmedian(temp(~isoutlier(temp)));
                    stats_data.cs_std(inc.tt, 1) = nanstd(temp(~isoutlier(temp)));
                    clear temp;
                    inc.t=1;
                    inc.tt=inc.tt+1;
                end
            end
        end
        stat_data = struct2table(stat_data);
    end

