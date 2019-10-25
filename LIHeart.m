%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  LIHeart.m

%   Author: Saurin Parikh, February 2019
%   dr.saurin.parikh@gmail.com
%   
%   Heart of the LI method for background calculation
%   IL = 1 or 0 depending on InterLeaving
%
%%

function bg = LIHeart(cont_avg,cont_pos,IL,dimensions)
    
    rows = dimensions(1)/2;
    cols = dimensions(2)/2;

    if IL == 1
        [a,b,c,d] = downscale(cont_avg);
        plates = {a,b,c,d};
        
        for i=1:4
            [p,q,r,s] = downscale(plates{i});
            [xq,yq] = ndgrid(1:rows,1:cols);
            
            if nansum(nansum(p)) ~= 0 %Top Left
                P = contBG(p);
                p = (fillmissing(fillmissing(p, 'linear',2),'linear',1) +...
                    (fillmissing(fillmissing(p, 'linear',1),'linear',2)))/2;
                [x,y] = ndgrid(1:2:rows,1:2:cols);
                f = griddedInterpolant(x,y,p,'linear');
                plates{i} = f(xq,yq);
                [~,x,y,z] = downscale(plates{i});
                bground{i} = plategen(P,x,y,z);

            elseif nansum(nansum(q)) ~= 0 % Top Right
                Q = contBG(q);
                q = (fillmissing(fillmissing(q, 'linear',2),'linear',1) +...
                    (fillmissing(fillmissing(q, 'linear',1),'linear',2)))/2;
                [x,y] = ndgrid(1:2:rows,2:2:cols); 
                f = griddedInterpolant(x,y,q,'linear');
                plates{i} = f(xq,yq);
                [x,~,y,z] = downscale(plates{i});
                bground{i} = plategen(x,Q,y,z);

            elseif nansum(nansum(r)) ~= 0 % Bottom Left
                R = contBG(r);
                r = (fillmissing(fillmissing(r, 'linear',2),'linear',1) +...
                    (fillmissing(fillmissing(r, 'linear',1),'linear',2)))/2;
                [x,y] = ndgrid(2:2:rows,1:2:cols); 
                f = griddedInterpolant(x,y,r,'linear');
                plates{i} = f(xq,yq);
                [x,y,~,z] = downscale(plates{i});
                bground{i} = plategen(x,y,R,z);

            else % Bottom Right
                S = contBG(s);
                s = (fillmissing(fillmissing(s, 'linear',2),'linear',1) +...
                    (fillmissing(fillmissing(s, 'linear',1),'linear',2)))/2;
                [x,y] = ndgrid(2:2:rows,2:2:cols); 
                f = griddedInterpolant(x,y,s,'linear');
                plates{i} = f(xq,yq);
                [x,y,z,~] = downscale(plates{i});
                bground{i} = plategen(x,y,z,S);

            end
        end
        bg = grid2row(plategen(bground{1},bground{2},bground{3},bground{4}))';
    else
        cbground = contBG(cont_avg).*cont_pos;
        bground = ((fillmissing(fillmissing(cont_avg, 'linear',2),'linear',1) +...
                    (fillmissing(fillmissing(cont_avg, 'linear',1),'linear',2)))/2).*~cont_pos;
        bg = grid2row(cbground + bground)';
    end
end
