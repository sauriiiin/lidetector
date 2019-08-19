%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  compcorr.m
%
%   Author: Saurin Parikh, August 2019
%   dr.saurin.parikh@gmail.com
%   
%   Competition correction based on neighbor colony growth

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

    jpeg_data.colony = zeros(size(jpeg_data,1),1);
    jpeg_data.colony(~strcmpi(jpeg_data.orf_name, {sprintf('%s',cont.name)})) =...
        ones(length(jpeg_data.colony(~strcmpi(jpeg_data.orf_name, {sprintf('%s',cont.name)}))),1);
    jpeg_data.colony(strcmpi(jpeg_data.orf_name, {''})) =...
        ones(length(jpeg_data.colony(strcmpi(jpeg_data.orf_name, {''}))),1).*-1;
    
    
    compdat <- data.frame()

    for (hr in sort(unique(alldat$hours))) {
      for (pl in sort(unique(alldat$`6144plate`[alldat$hours == hr]))) {
        tempdat <- alldat[alldat$hours == hr & alldat$`6144plate` == pl,]
        tempdat$average[is.na(tempdat$orf_name)] <- 0

        for (i in seq(1,dim(grids)[1])) {
          tempdat$neigh[tempdat$pos == grids[i]] <- mean(tempdat$average[tempdat$pos %in% grids[i,2:9]], na.rm = T)
          tempdat$neigh_sr[tempdat$pos == grids_sr[i]] <- mean(tempdat$average[tempdat$pos %in% grids_sr[i,2:9]], na.rm = T)
        }

        tempdat$neigh[is.na(tempdat$average) & !is.na(tempdat$orf_name)] <- NA
        tempdat$neigh_sr[is.na(tempdat$average) & !is.na(tempdat$orf_name)] <- NA
        tempdat$score <- tempdat$average/((tempdat$neigh + tempdat$neigh_sr)/2)

        md <- mad(tempdat$score[tempdat$orf_name == 'BF_control'], na.rm =T)
        ll <- median(tempdat$score[tempdat$orf_name == 'BF_control'], na.rm =T) - 3*md
        ul <- median(tempdat$score[tempdat$orf_name == 'BF_control'], na.rm =T) + 3*md

        tempdat$size <- NULL
        tempdat$size[tempdat$score < ll & !is.na(tempdat$score)] <- 'Small'
        tempdat$size[tempdat$score > ul & !is.na(tempdat$score)] <- 'Big'
        tempdat$size[is.na(tempdat$size)] <- 'Normal'

        tempdat$sick <- NULL
        tempdat$healthy_neigh <- NULL
        for (p in tempdat$pos[tempdat$size == 'Small']) {
          N <- sum(tempdat$size[tempdat$pos %in% grids[grids[,1] == p, 2:9] | tempdat$pos %in% grids_sr[grids_sr[,1] == p, 2:9]] == 'Big', na.rm = T)
          if (N > 0) {
            tempdat$sick[tempdat$pos == p] <- 'Y'
            tempdat$healthy_neigh[tempdat$pos == p] <- N
          }
        }
        tempdat$sick[is.na(tempdat$sick) & tempdat$size == 'Small'] <- 'N'
        tempdat$sick[is.na(tempdat$sick)] <- 'Normal'

        tempdat$healthy <- NULL
        tempdat$sick_neigh <- NULL
        for (p in tempdat$pos[tempdat$size == 'Big']) {
          N <- sum(tempdat$size[tempdat$pos %in% grids[grids[,1] == p, 2:9] | tempdat$pos %in% grids_sr[grids_sr[,1] == p, 2:9]] == 'Small', na.rm = T)
          if (N > 0) {
            tempdat$healthy[tempdat$pos == p] <- 'Y'
            tempdat$sick_neigh[tempdat$pos == p] <- N
          }
        }
        tempdat$healthy[is.na(tempdat$healthy) & tempdat$size == 'Big'] <- 'N'
        tempdat$healthy[is.na(tempdat$healthy)] <- 'Normal'

        tempdat$comp <- NULL
        for (p in tempdat$pos[tempdat$sick == 'Y' | tempdat$healthy == 'Y']){
          if (tempdat$healthy[tempdat$pos == p] == 'Y') {
            N <- sum(tempdat$healthy_neigh[tempdat$pos %in% grids[grids[,1] == p, 2:9] | tempdat$pos %in% grids_sr[grids_sr[,1] == p, 2:9]] + 1 > 
                       tempdat$sick_neigh[tempdat$pos == p], na.rm = T)
            # a healthy colony should have no sick neighbors which have more or equal number of healthy neighbors than it has sick ones
            if (N == 0) {
              tempdat$comp[tempdat$pos %in% grids[grids[,1] == p, 2:9]] <- 'CH'
            }
          } else {
            N <- sum(tempdat$sick_neigh[tempdat$pos %in% grids[grids[,1] == p, 2:9] | tempdat$pos %in% grids_sr[grids_sr[,1] == p, 2:9]] <= 
                       tempdat$healthy_neigh[tempdat$pos == p], na.rm = T)
            # a sick colony should have atleast one healthy neighbor that has less sick nieghbors than it has healthy ones
            if (N > 0) {
              tempdat$comp[tempdat$pos %in% grids[grids[,1] == p, 2:9]] <- 'CS'
            }
          }
        }
        tempdat$comp[is.na(tempdat$orf_name)] = NA
        tempdat$comp[tempdat$sick == 'Y'] = NA
        tempdat$comp[tempdat$healthy == 'Y' & tempdat$comp == 'CH'] = NA
        tempdat$comp[is.na(tempdat$comp)] = 'No'

        tempdat$average_cc <- tempdat$average
        tempdat$average_cc[tempdat$comp == 'CS'] <- tempdat$average_cc[tempdat$comp == 'CS'] *
          median(tempdat$average_cc[tempdat$orf_name == 'BF_control'], na.rm = T)/median(tempdat$average_cc[tempdat$comp == 'CS'], na.rm = T)
        tempdat$average_cc[tempdat$comp == 'CH'] <- tempdat$average_cc[tempdat$comp == 'CH'] *
          median(tempdat$average_cc[tempdat$orf_name == 'BF_control'], na.rm = T)/median(tempdat$average_cc[tempdat$comp == 'CH'], na.rm = T)

        compdat <- rbind(compdat, tempdat)
      }
    }

    compdat$average[is.na(compdat$orf_name)] <- NA
    compdat$average_cc[is.na(compdat$orf_name)] <- NA

    jpegdat <- data.frame(compdat$pos, compdat$hours, compdat$average, compdat$average_cc)
    colnames(jpegdat) <- c('pos','hours','average_raw', 'average')
    dbWriteTable(conn, tablename_jpeg_cc, jpegdat, overwrite = T)
    
    

