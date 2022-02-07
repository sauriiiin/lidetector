%%  LI Detector
%
%%  localcorrection.m

%   Author: Saurin Parikh, April 2018
%   LI Detector's local artifact correction
%
%   dr.saurin.parikh@gmail.com
%%

function out = LocalCorrection(p2c_info,density,cont_name,...
        tablename_s2o,tablename_p2s,tablename_raw,sql_info,...
        toolkit_path,expt)

    conn = connSQL(sql_info);

    cont.id = fetch(conn, sprintf(['select strain_id from %s ',...
        'where orf_name = "%s" '], tablename_s2o, cont_name));
    cont.id = cont.id.strain_id;
    
    if exist(sprintf('%s/%s_GRIDS.mat',toolkit_path,expt), 'file') == 1
        load(sprintf('%s/%s_GRIDS.mat',toolkit_path,expt), 'grids', 'grids_sr');
    else
        [grids, grids_sr] = neighbor_pos(p2c_info,density,sql_info,...
            toolkit_path,expt);
    end

%     p2c = fetch(conn, sprintf(['select * from %s a ',...
%             'where density = %d ',...
%             'order by a.%s, a.%s, a.%s'],...
%             p2c_info{1},density,p2c_info{2},p2c_info{4},p2c_info{3}));
% 
%     pos = [];
%     neigh = zeros(density*length(unique(p2c.plate_no)),8);
%     neigh_sr = zeros(density*length(unique(p2c.plate_no)),8);
%     i = 1;
%     for pl = unique(p2c.plate_no)'
%         temp = p2c(p2c.plate_no == pl,:);
%         for c = sort(unique(temp.plate_col))'
%             for r = sort(unique(temp.plate_row(temp.plate_col == c)))'
%                 pos = [pos; temp.pos(temp.plate_col == c & temp.plate_row == r)];
% 
%                 neigh(i,1) = isnotempty(temp.pos(temp.plate_col == c - 1 & temp.plate_row == r - 1));
%                 neigh(i,2) = isnotempty(temp.pos(temp.plate_col == c - 1 & temp.plate_row == r));
%                 neigh(i,3) = isnotempty(temp.pos(temp.plate_col == c - 1 & temp.plate_row == r + 1));
%                 neigh(i,4) = isnotempty(temp.pos(temp.plate_col == c & temp.plate_row == r - 1));
%                 neigh(i,5) = isnotempty(temp.pos(temp.plate_col == c & temp.plate_row == r + 1));
%                 neigh(i,6) = isnotempty(temp.pos(temp.plate_col == c + 1 & temp.plate_row == r - 1));
%                 neigh(i,7) = isnotempty(temp.pos(temp.plate_col == c + 1 & temp.plate_row == r));
%                 neigh(i,8) = isnotempty(temp.pos(temp.plate_col == c + 1 & temp.plate_row == r + 1));
%                 
%                 if density >= 6144
%                     neigh_sr(i,1) = isnotempty(temp.pos(temp.plate_col == c - 2 & temp.plate_row == r - 2));
%                     neigh_sr(i,2) = isnotempty(temp.pos(temp.plate_col == c - 2 & temp.plate_row == r));
%                     neigh_sr(i,3) = isnotempty(temp.pos(temp.plate_col == c - 2 & temp.plate_row == r + 2));
%                     neigh_sr(i,4) = isnotempty(temp.pos(temp.plate_col == c & temp.plate_row == r - 2));
%                     neigh_sr(i,5) = isnotempty(temp.pos(temp.plate_col == c & temp.plate_row == r + 2));
%                     neigh_sr(i,6) = isnotempty(temp.pos(temp.plate_col == c + 2 & temp.plate_row == r - 2));
%                     neigh_sr(i,7) = isnotempty(temp.pos(temp.plate_col == c + 2 & temp.plate_row == r));
%                     neigh_sr(i,8) = isnotempty(temp.pos(temp.plate_col == c + 2 & temp.plate_row == r + 2));
%                 end
%                 i = i + 1;
%             end
%         end
%     end
%     grids = [pos, neigh];
%     grids_sr = [pos, neigh_sr];

    rawdata = fetch(conn, sprintf(['select b.*, c.strain_id, a.hours, a.average ',...
        'from %s a, %s b, %s c ',...
        'where a.pos = b.pos and b.pos = c.pos ',...
        'order by a.hours, b.%s, b.%s, b.%s'],...
        tablename_raw,...
        p2c_info{1},tablename_p2s,...
        p2c_info{2},p2c_info{4},p2c_info{3}));
    rawdata.plate_colony(rawdata.strain_id == cont.id) = 1;

    %% COMPETITION CORRECTION
    out = [];
    for hr = sort(unique(rawdata.hours))'
        for pl = sort(unique(rawdata.plate_no(rawdata.hours == hr)))'
            tempdat = rawdata(rawdata.hours == hr & rawdata.plate_no == pl,:);
%             tempdat.average(tempdat.strain_id == 0) = 0;

            for i = 1:size(grids, 1)
                tempdat.neigh(tempdat.pos == grids(i)) = mean(tempdat.average(ismember(tempdat.pos, grids(i,2:9))), 'omitnan') + 0.0001;
                if density >= 6144
                    tempdat.neigh_sr(tempdat.pos == grids_sr(i)) = mean(tempdat.average(ismember(tempdat.pos, grids_sr(i,2:9))), 'omitnan') + 0.0001;
                end
            end

%             tempdat.neigh(isnan(tempdat.average) & tempdat.strain_id ~= -2) = NaN;
%             tempdat.neigh_sr(isnan(tempdat.average) & tempdat.strain_id ~= -2) = NaN;
            if density >= 6144
                tempdat.score = tempdat.average./((tempdat.neigh + tempdat.neigh_sr)/2);
            else
                tempdat.score = tempdat.average./tempdat.neigh;
            end

            md = 1.4826 * median(abs(tempdat.score(tempdat.strain_id == cont.id) - median(tempdat.score(tempdat.strain_id == cont.id), 'omitnan')), 'omitnan');
            ll = median(tempdat.score(tempdat.strain_id == cont.id),'omitnan') - 3*md;
            ul = median(tempdat.score(tempdat.strain_id == cont.id),'omitnan') + 3*md;

            tempdat.size(tempdat.score < ll) = -1;
            tempdat.size(tempdat.score > ul) = 1;

            tempdat.sick = zeros(size(tempdat,1),1);
            tempdat.healthy_neigh = zeros(size(tempdat,1),1);
            for p = tempdat.pos(tempdat.size == -1)'
                N = sum(tempdat.size(ismember(tempdat.pos, grids(grids(:,1) == p, 2:9)) == 1), 'omitnan');
                if N > 0 
                    tempdat.sick(tempdat.pos == p) = 1;
                    tempdat.healthy_neigh(tempdat.pos == p) = N;
                end
            end

            tempdat.healthy = zeros(size(tempdat,1),1);
            tempdat.sick_neigh = zeros(size(tempdat,1),1);
            for p = tempdat.pos(tempdat.size == 1)'
                N = sum(tempdat.size(ismember(tempdat.pos, grids(grids(:,1) == p, 2:9)) == -1), 'omitnan');
                if N > 0 
                    tempdat.healthy(tempdat.pos == p) = 1;
                    tempdat.sick_neigh(tempdat.pos == p) = N;
                end
            end

            tempdat.compB = zeros(size(tempdat,1),1);
            tempdat.compS = zeros(size(tempdat,1),1);
            tempdat.comp = zeros(size(tempdat,1),1);
            tempdat.driver = zeros(size(tempdat,1),1);
            for p = tempdat.pos(tempdat.sick == 1 | tempdat.healthy == 1)'
                if tempdat.healthy(tempdat.pos == p) == 1
                    N = sum(tempdat.healthy_neigh(ismember(tempdat.pos, grids(grids(:,1) == p, 2:9))) + 1 > tempdat.sick_neigh(tempdat.pos == p), 'omitnan');
                    % a healthy colony should have no sick neighbors which have more healthy neighbors than it has sick ones
                    if N == 0
                        tempdat.comp(ismember(tempdat.pos, grids(grids(:,1) == p, 2:9))) = 1;
                        tempdat.compB(ismember(tempdat.pos, grids(grids(:,1) == p, 2:9))) = 1;
                        tempdat.driver(tempdat.pos == p) = 1;
                    end
                else
                    N = sum(tempdat.sick_neigh(ismember(tempdat.pos, grids(grids(:,1) == p, 2:9))) < tempdat.healthy_neigh(tempdat.pos == p), 'omitnan');
                    % a sick colony should have atleast one healthy neighbor that has less sick nieghbors than it has healthy ones
                    if N > 0
                      tempdat.comp(ismember(tempdat.pos, grids(grids(:,1) == p, 2:9))) = -1;
                      tempdat.compS(ismember(tempdat.pos, grids(grids(:,1) == p, 2:9))) = -1;
                      tempdat.driver(tempdat.pos == p) = -1;
                    end
                end
            end
            tempdat.comp(tempdat.compS == -1 & tempdat.compB == 1) = 0;
            tempdat.comp(tempdat.sick == 1 & tempdat.comp == -1) = 0;
            tempdat.comp(tempdat.healthy == 1 & tempdat.comp == 1) = 0;

            tempdat.lac = tempdat.average;
            tempdat.average(tempdat.comp == -1) = tempdat.lac(tempdat.comp == -1) * ...
                median(tempdat.lac(tempdat.strain_id == cont.id & tempdat.comp == 0), 'omitnan')./median(tempdat.lac(tempdat.comp == -1), 'omitnan');
            tempdat.average(tempdat.comp == 1) = tempdat.lac(tempdat.comp == 1) * ...
                median(tempdat.lac(tempdat.strain_id == cont.id & tempdat.comp == 0), 'omitnan')./median(tempdat.lac(tempdat.comp == 1), 'omitnan');

            out = [out; tempdat(:,[1,7,8])];
        end
    end
end