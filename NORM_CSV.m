%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  NORM_CSV.m

%   Author: Saurin Parikh, August 2019
%   dr.saurin.parikh@gmail.com

%   Linear Interpolation to predict plate background using control colony
%   pixel counts.

%   IL = 1 : Interleave
%   IL = 0 : No Interleave

%%

    function norm_data = NORM_CSV(hours,n_plates,p2c,cont_name,p2o,jpeg_data,IL)
        norm_data = [];
        for ii = 1:length(hours)
            temp = [];
            for iii = 1:length(n_plates)

                pos.all = p2c.pos(p2c.plate == n_plates(iii));
                pos.cont = p2o.pos(ismember(p2o.pos, pos.all) &...
                    p2o.orf_name == cont_name);

                avg_data = jpeg_data.average(jpeg_data.hours == hours(ii) &...
                    ismember(jpeg_data.pos, pos.all));

        %%  CALCULATE BACKGROUND

                cont_pos = col2grid(ismember(pos.all, pos.cont));
                cont_avg = col2grid(avg_data).*cont_pos;
                cont_avg(cont_avg == 0) = NaN;

                bg{iii} = LIHeart(cont_avg,cont_pos,IL);
                bg{iii}(bg{iii} == 0) = NaN;
                temp = abs([temp; [pos.all, ones(length(pos.all),1)*hours(ii),...
                    bg{iii}, avg_data, avg_data./bg{iii}]]);
            end
            norm_data = [norm_data; temp];
        end
        norm_data = array2table(norm_data,...
            'VariableNames',...
            {'pos','hours','bg','average','fitness'});
    end
    
%%  END    
    
