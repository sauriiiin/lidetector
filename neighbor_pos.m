%%  LI Detector
%
%%  neighbor_pos.m

%   Author: Saurin Parikh, February 2022
%   Generate a file with 8 immediate and 8 penultimate neighbors.
%
%   dr.saurin.parikh@gmail.com
%%

function [grids, grids_sr] = neighbor_pos(p2c_info,density,sql_info,...
    toolkit_path,expt)

    conn = connSQL(sql_info);
    
    p2c = fetch(conn, sprintf(['select * from %s a ',...
            'where density = %d ',...
            'order by a.%s, a.%s, a.%s'],...
            p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));

    pos = [];
    neigh = zeros(density*length(unique(p2c.plate_no)),8);
    neigh_sr = zeros(density*length(unique(p2c.plate_no)),8);
    i = 1;
    for pl = unique(p2c.plate_no)'
        temp = p2c(p2c.plate_no == pl,:);
        for c = sort(unique(temp.plate_col))'
            for r = sort(unique(temp.plate_row(temp.plate_col == c)))'
                pos = [pos; temp.pos(temp.plate_col == c & temp.plate_row == r)];

                neigh(i,1) = isnotempty(temp.pos(temp.plate_col == c - 1 & temp.plate_row == r - 1));
                neigh(i,2) = isnotempty(temp.pos(temp.plate_col == c - 1 & temp.plate_row == r));
                neigh(i,3) = isnotempty(temp.pos(temp.plate_col == c - 1 & temp.plate_row == r + 1));
                neigh(i,4) = isnotempty(temp.pos(temp.plate_col == c & temp.plate_row == r - 1));
                neigh(i,5) = isnotempty(temp.pos(temp.plate_col == c & temp.plate_row == r + 1));
                neigh(i,6) = isnotempty(temp.pos(temp.plate_col == c + 1 & temp.plate_row == r - 1));
                neigh(i,7) = isnotempty(temp.pos(temp.plate_col == c + 1 & temp.plate_row == r));
                neigh(i,8) = isnotempty(temp.pos(temp.plate_col == c + 1 & temp.plate_row == r + 1));
                
                if density >= 6144
                    neigh_sr(i,1) = isnotempty(temp.pos(temp.plate_col == c - 2 & temp.plate_row == r - 2));
                    neigh_sr(i,2) = isnotempty(temp.pos(temp.plate_col == c - 2 & temp.plate_row == r));
                    neigh_sr(i,3) = isnotempty(temp.pos(temp.plate_col == c - 2 & temp.plate_row == r + 2));
                    neigh_sr(i,4) = isnotempty(temp.pos(temp.plate_col == c & temp.plate_row == r - 2));
                    neigh_sr(i,5) = isnotempty(temp.pos(temp.plate_col == c & temp.plate_row == r + 2));
                    neigh_sr(i,6) = isnotempty(temp.pos(temp.plate_col == c + 2 & temp.plate_row == r - 2));
                    neigh_sr(i,7) = isnotempty(temp.pos(temp.plate_col == c + 2 & temp.plate_row == r));
                    neigh_sr(i,8) = isnotempty(temp.pos(temp.plate_col == c + 2 & temp.plate_row == r + 2));
                end
                i = i + 1;
            end
        end
    end
    grids = [pos, neigh];
    grids_sr = [pos, neigh_sr];
    
    save(sprintf('%s/%s_GRIDS.mat',toolkit_path,expt), 'grids', 'grids_sr');
end