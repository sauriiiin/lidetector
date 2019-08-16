%%  Sau MATLAB Colony Analyzer Toolkitv
%
%%  connSQL.m

%   Author: Saurin Parikh, May 2019
%   dr.saurin.parikh@gmail.com

%%
    function conn = connSQL(db, username, pwd)

        url = sprintf(['jdbc:mysql://paris.csb.pitt.edu:3306/%s?',...
            'useUnicode=true&useJDBCCompliantTimezoneShift=true&',...
            'useLegacyDatetimeCode=false&serverTimezone=UTC'],db);
        conn = database('', username, pwd,'com.mysql.jdbc.Driver', url);

    end
    
%%  END