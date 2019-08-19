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
    
    compdat = [];
    for hr = hours
      for pl = sort(unique(jpeg_data.plate(jpeg_data.hours == hr)))
        temp = jpeg_data(jpeg_data.hours == hr & jpeg_data.plate == pl,:);
        temp.average(temp.colony == -1) = 0;
        
        for i = 1:size(grids,1)
          temp.neigh(temp.pos == grids(i,1)) <- mean(temp$average[temp$pos %in% grids[i,2:9]], na.rm = T)
              %%%%%%%%%%%%%% 
          temp$neigh_sr[temp$pos == grids_sr[i]] <- mean(temp$average[temp$pos %in% grids_sr[i,2:9]], na.rm = T)
        end

        temp$neigh[is.na(temp$average) & !is.na(temp$orf_name)] <- NA
        temp$neigh_sr[is.na(temp$average) & !is.na(temp$orf_name)] <- NA
        temp$score <- temp$average/((temp$neigh + temp$neigh_sr)/2)

        md <- mad(temp$score[temp$orf_name == 'BF_control'], na.rm =T)
        ll <- median(temp$score[temp$orf_name == 'BF_control'], na.rm =T) - 3*md
        ul <- median(temp$score[temp$orf_name == 'BF_control'], na.rm =T) + 3*md

        temp$size <- NULL
        temp$size[temp$score < ll & !is.na(temp$score)] <- 'Small'
        temp$size[temp$score > ul & !is.na(temp$score)] <- 'Big'
        temp$size[is.na(temp$size)] <- 'Normal'

        temp$sick <- NULL
        temp$healthy_neigh <- NULL
        for (p in temp$pos[temp$size == 'Small']) {
          N <- sum(temp$size[temp$pos %in% grids[grids[,1] == p, 2:9] | temp$pos %in% grids_sr[grids_sr[,1] == p, 2:9]] == 'Big', na.rm = T)
          if (N > 0) {
            temp$sick[temp$pos == p] <- 'Y'
            temp$healthy_neigh[temp$pos == p] <- N
          }
        }
        temp$sick[is.na(temp$sick) & temp$size == 'Small'] <- 'N'
        temp$sick[is.na(temp$sick)] <- 'Normal'

        temp$healthy <- NULL
        temp$sick_neigh <- NULL
        for (p in temp$pos[temp$size == 'Big']) {
          N <- sum(temp$size[temp$pos %in% grids[grids[,1] == p, 2:9] | temp$pos %in% grids_sr[grids_sr[,1] == p, 2:9]] == 'Small', na.rm = T)
          if (N > 0) {
            temp$healthy[temp$pos == p] <- 'Y'
            temp$sick_neigh[temp$pos == p] <- N
          }
        }
        temp$healthy[is.na(temp$healthy) & temp$size == 'Big'] <- 'N'
        temp$healthy[is.na(temp$healthy)] <- 'Normal'

        temp$comp <- NULL
        for (p in temp$pos[temp$sick == 'Y' | temp$healthy == 'Y']){
          if (temp$healthy[temp$pos == p] == 'Y') {
            N <- sum(temp$healthy_neigh[temp$pos %in% grids[grids[,1] == p, 2:9] | temp$pos %in% grids_sr[grids_sr[,1] == p, 2:9]] + 1 > 
                       temp$sick_neigh[temp$pos == p], na.rm = T)
            # a healthy colony should have no sick neighbors which have more or equal number of healthy neighbors than it has sick ones
            if (N == 0) {
              temp$comp[temp$pos %in% grids[grids[,1] == p, 2:9]] <- 'CH'
            }
          } else {
            N <- sum(temp$sick_neigh[temp$pos %in% grids[grids[,1] == p, 2:9] | temp$pos %in% grids_sr[grids_sr[,1] == p, 2:9]] <= 
                       temp$healthy_neigh[temp$pos == p], na.rm = T)
            # a sick colony should have atleast one healthy neighbor that has less sick nieghbors than it has healthy ones
            if (N > 0) {
              temp$comp[temp$pos %in% grids[grids[,1] == p, 2:9]] <- 'CS'
            }
          }
        }
        temp$comp[is.na(temp$orf_name)] = NA
        temp$comp[temp$sick == 'Y'] = NA
        temp$comp[temp$healthy == 'Y' & temp$comp == 'CH'] = NA
        temp$comp[is.na(temp$comp)] = 'No'

        temp$average_cc <- temp$average
        temp$average_cc[temp$comp == 'CS'] <- temp$average_cc[temp$comp == 'CS'] *
          median(temp$average_cc[temp$orf_name == 'BF_control'], na.rm = T)/median(temp$average_cc[temp$comp == 'CS'], na.rm = T)
        temp$average_cc[temp$comp == 'CH'] <- temp$average_cc[temp$comp == 'CH'] *
          median(temp$average_cc[temp$orf_name == 'BF_control'], na.rm = T)/median(temp$average_cc[temp$comp == 'CH'], na.rm = T)

        compdat <- rbind(compdat, temp)
      }
    }

    compdat$average[is.na(compdat$orf_name)] <- NA
    compdat$average_cc[is.na(compdat$orf_name)] <- NA

    jpegdat <- data.frame(compdat$pos, compdat$hours, compdat$average, compdat$average_cc)
    colnames(jpegdat) <- c('pos','hours','average_raw', 'average')
    dbWriteTable(conn, tablename_jpeg_cc, jpegdat, overwrite = T)
    
    

