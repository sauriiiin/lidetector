%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  compcorr.m
%
%   Author: Saurin Parikh, August 2019
%   dr.saurin.parikh@gmail.com
%   
%   Competition correction based on neighbor colony growth

%   p2c, jpeg_data, cont.name

%%  NEIGHBOR POS

    pos = [];
    neigh = zeros(6144*2,8);
    neigh_sr = zeros(6144*2,8);

    i = 1;
    unique_pl = unique(p2c.plate);
    for ii = 1:length(unique_pl)
        pl = unique_pl(ii);
        temp = p2c(p2c.plate == pl,:);
        unique_col = sort(unique(temp.col));
        for iii = 1:length(unique_col)
            c = unique_col(iii);
            unique_row = sort(unique(temp.row(temp.col == c)));
            for iv = 1:length(unique_row)
                r = unique_row(iv);
                pos = [pos; temp.pos(temp.col == c & temp.row == r)];
                len = length(temp.pos(temp.col == c - 1 & ismember(temp.row, [r - 1, r, r + 1]) |...
                    temp.col == c & ismember(temp.row, [r - 1, r + 1]) |...
                    temp.col == c + 1 & ismember(temp.row, [r - 1, r, r + 1])));
                neigh(i,1:len) = temp.pos(temp.col == c - 1 & ismember(temp.row, [r - 1, r, r + 1]) |...
                    temp.col == c & ismember(temp.row, [r - 1, r + 1]) |...
                    temp.col == c + 1 & ismember(temp.row, [r - 1, r, r + 1]));
                len_sr = length(temp.pos(temp.col == c - 2 & ismember(temp.row, [r - 2, r, r + 2]) |...
                    temp.col == c & ismember(temp.row, [r - 2, r + 2]) |...
                    temp.col == c + 2 & ismember(temp.row, [r - 2, r, r + 2])));
                neigh_sr(i,1:len_sr) = temp.pos(temp.col == c - 2 & ismember(temp.row, [r - 2, r, r + 2]) |...
                    temp.col == c & ismember(temp.row, [r - 2, r + 2]) |...
                    temp.col == c + 2 & ismember(temp.row, [r - 2, r, r + 2]));
                i = i + 1;
            end
        end
    end

    grids = [pos, neigh];
    grids_sr = [pos, neigh_sr];
    
%%  COMPETITION SCORE

    hours = sort(unique(jpeg_data.hours));

    jpeg_data.colony = zeros(size(jpeg_data,1),1);
    jpeg_data.colony(~strcmpi(jpeg_data.orf_name, {sprintf('%s',cont.name)})) =...
        ones(length(jpeg_data.colony(~strcmpi(jpeg_data.orf_name, {sprintf('%s',cont.name)}))),1);
    jpeg_data.colony(strcmpi(jpeg_data.orf_name, {''})) =...
        ones(length(jpeg_data.colony(strcmpi(jpeg_data.orf_name, {''}))),1).*-1;
    
    jpeg_data.neigh = zeros(size(jpeg_data,1),1);
    jpeg_data.neigh_sr = zeros(size(jpeg_data,1),1);
    jpeg_data.score = zeros(size(jpeg_data,1),1);
    jpeg_data.size = zeros(size(jpeg_data,1),1);
    jpeg_data.sick = zeros(size(jpeg_data,1),1);
    jpeg_data.healthy_neigh = zeros(size(jpeg_data,1),1);
    jpeg_data.healthy = zeros(size(jpeg_data,1),1);
    jpeg_data.sick_neigh = zeros(size(jpeg_data,1),1);
    jpeg_data.comp = zeros(size(jpeg_data,1),1);
    
    compdat = [];
    for hr = hours'
        for pl = sort(unique(jpeg_data.plate(jpeg_data.hours == hr)))'
            temp = jpeg_data(jpeg_data.hours == hr & jpeg_data.plate == pl,:);
            temp.average(temp.colony == -1) = 0;
        
            for i = 1:size(grids,1)
              temp.neigh(temp.pos == grids(i,1)) = nanmean(temp.average(ismember(temp.pos, grids(i,2:9))));
              temp.neigh_sr(temp.pos == grids_sr(i,1)) = nanmean(temp.average(ismember(temp.pos, grids_sr(i,2:9))));
            end

            temp.neigh(isnan(temp.average) & ~strcmpi(temp.orf_name,{''})) = NaN;
            temp.neigh_sr(isnan(temp.average) & ~strcmpi(temp.orf_name,{''})) = NaN;
            temp.score = temp.average./((temp.neigh + temp.neigh_sr)/2);

            md = mad(temp.score(strcmpi(temp.orf_name, {sprintf('%s', cont.name)})));
            ll = nanmedian(temp.score(strcmpi(temp.orf_name, {sprintf('%s', cont.name)}))) - 3*md;
            ul = nanmedian(temp.score(strcmpi(temp.orf_name, {sprintf('%s', cont.name)}))) + 3*md;

            temp.size(temp.score < ll & ~isnan(temp.score)) = -1;
            temp.size(temp.score > ul & ~isnan(temp.score)) = 1;

            for p = temp.pos(temp.size == -1)'
                N = sum(temp.size(ismember(temp.pos, grids(grids(:,1) == p,2:end)) |...
                    ismember(temp.pos, grids_sr(grids_sr(:,1) == p,2:end))) == 1);
                if (N > 0)
                    temp.sick(temp.pos == p) = 1;
                    temp.healthy_neigh(temp.pos == p) = N;
                end
            end

            for p = temp.pos(temp.size == 1)'
                N = sum(temp.size(ismember(temp.pos, grids(grids(:,1) == p,2:end)) |...
                    ismember(temp.pos, grids_sr(grids_sr(:,1) == p,2:end))) == -1);
                if (N > 0)
                    temp.healthy(temp.pos == p) = 1;
                    temp.sick_neigh(temp.pos == p) = N;
                end
            end

            for p = temp.pos(temp.sick == 1 | temp.healthy == 1)'
                if temp.healthy(temp.pos == p) == 1
                    N = sum(temp.healthy_neigh(ismember(temp.pos, grids(grids(:,1) == p,2:end)) |...
                        ismember(temp.pos, grids_sr(grids_sr(:,1) == p,2:end))) + 1 > temp.sick_neigh(temp.pos == p));
                    % a healthy colony should have no sick neighbors which have more or equal number of healthy neighbors than it has sick ones
                    if N == 0
                        temp.comp(ismember(temp.pos, grids(grids(:,1) == p,2:end))) = 1;
                    end
                else
                    N = sum(temp.sick_neigh(ismember(temp.pos, grids(grids(:,1) == p,2:end)) |...
                        ismember(temp.pos, grids_sr(grids_sr(:,1) == p,2:end))) <= temp.healthy_neigh(temp.pos == p));
                    %a sick colony should have atleast one healthy neighbor that has less sick nieghbors than it has healthy ones
                    if N > 0
                        temp.comp(ismember(temp.pos, grids(grids(:,1) == p,2:end))) = -1;
                    end
                end
            end

            temp.comp(strcmpi(temp.orf_name, {''})) = 0;
            temp.comp(temp.sick == 1) = 0;
            temp.comp(temp.healthy == 1 & temp.comp == 1) = 0;

            temp.average_cc = temp.average;
            temp.average_cc(temp.comp == -1) = temp.average_cc(temp.comp == -1) *...
                nanmedian(temp.average_cc(strcmpi(temp.orf_name,{sprintf('%s',cont.name)}) & temp.comp == 0))/...
                nanmedian(temp.average_cc(temp.comp == -1));
            temp.average_cc(temp.comp == 1) = temp.average_cc(temp.comp == 1) *...
                nanmedian(temp.average_cc(strcmpi(temp.orf_name,{sprintf('%s',cont.name)}) & temp.comp == 0))/...
                nanmedian(temp.average_cc(temp.comp == 1));

            compdat = [compdat; temp];
        end
    end

    compdat.average(compdat.colony == -1) = NaN;
    compdat.average_cc(compdat.colony == -1) = NaN;

    jpeg_data_cc = table(compdat.pos, compdat.hours, compdat.average, compdat.average_cc);
    jpeg_data_cc.Properties.VariableNames = {'pos','hours','average_raw', 'average'};
    
    

