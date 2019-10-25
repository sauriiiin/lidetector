%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  contBG.m

%   Author: Saurin Parikh, December 2018
%   dr.saurin.parikh@gmail.com

%%
    function out = contBG(in)
        out = [];
        temp = in;
        [row, col] = size(in);
        tt = 1;
        for cc=1:col
            for rr=1:row
                temp(rr,cc) = NaN;
                temp = (fillmissing(fillmissing(temp, 'linear',2),'linear',1) +...
                    (fillmissing(fillmissing(temp, 'linear',1),'linear',2)))/2;
                out(tt) = temp(rr,cc);
                temp = in;
                tt = tt + 1;
            end
        end
        out = col2grid(out);
    end