%%  Sau MATLAB Colony Analyzer Toolkitv
%
%%  connSQL.m

%   Author: Saurin Parikh, May 2019
%   dr.saurin.parikh@gmail.com

%%
    function conn = connSQL(sql_info)

        url = sprintf(['jdbc:mysql://paris.csb.pitt.edu:3306/%s?',...
            'useUnicode=true&useJDBCCompliantTimezoneShift=true&',...
            'useLegacyDatetimeCode=false&serverTimezone=UTC'],sql_info{3});
        conn = database('', sql_info{1}, sql_info{2},'com.mysql.jdbc.Driver', url);

    end
    
%%  END