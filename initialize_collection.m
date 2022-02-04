%%  LI Detector
%
%%  initialize_collection.m

%   Author: Saurin Parikh, January 2022
%   Gather platemaps of the appropriate collections to be initialized 
%        from SQL tables.
%
%   dr.saurin.parikh@gmail.com
%%

function [data, tbl_s2o] = initialize_collection(sql_info, iden)
    
    conn = connSQL(sql_info);
    % collections to be used
    getthese = strtrim(split(input('Which collection/s will you be using: ','s'), ','));
    % number of reference strain plates [will be appended at the end]
    n_ref = input('How many reference strain plates will you be using: ');
    
    collection = [];
    for i = 1:size(getthese,1)
       temp_collection = fetch(conn, sprintf('select * from %s ',...
           getthese{i}));
       collection = [collection; temp_collection];
    end
    % the above code runs similar to the below mySQL query to gather collection
    % platemaps
    %     collection = fetch(conn, ['select * from BARFLEX_SPACE_AGAR_180313 ',...
    %         'union ',...
    %         'select * from PROTOGENE_COLLECTION ',...
    %         'union ',...
    %         'select * from TRANS_CONTROL_MAP']);

    % dummy plate to join platemaps to avoid missing data from gaps in the
    % maps.
    tbl_s2o = unique(collection(:,[1,5]), 'rows');
    
    dummy_plate = array2table([1:iden; indices(iden)]', 'VariableNames',...
        {'pos',collection.Properties.VariableNames{3},collection.Properties.VariableNames{4}});
     
    if iden == 6144
        dimensions = [64 96];
    elseif iden == 1536
        dimensions = [32 48];
    elseif iden == 384
        dimensions = [16 24];
    else
        dimensions = [8 12];
    end
    
    col_plates = unique(collection.x384plate_1(~isnan(collection.x384plate_1)));
    n_col_plates = length(col_plates);
    
    for k = 1:n_col_plates
      temp = collection(collection.x384plate_1 == col_plates(k),:);
      temp = outerjoin(temp, dummy_plate, 'Keys', {'x384col_1', 'x384row_1'},...
        'Type', 'right','MergeKeys',true);
      temp = sortrows(temp,'pos','ascend');
      data{k} = col2grid(temp.strain_id);
    end
    
    for kk = (n_col_plates + 1):(n_col_plates + n_ref)
        data{kk} = ones(dimensions)*-1;
    end
    
end
    
    

    
    
    


   
    