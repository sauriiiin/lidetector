%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  update_toolkit.m

%   Author: Saurin Parikh, October, 2019
%   Update lidetector and sau-matlab-toolkit to their latest versions
%   dr.saurin.parikh@gmail.com

function update_toolkit(path)

    if exist(sprintf('%s/lidetector-master', path), 'dir') == 7
        rmdir(sprintf('%s/lidetector-master', path),'s')
    end
    
    if exist(sprintf('%s/sau-matlab-toolkit-master', path), 'dir') == 7
        rmdir(sprintf('%s/sau-matlab-toolkit-master', path),'s')
    end

    url_lid = 'https://github.com/sauriiiin/lidetector/archive/master.zip';
    url_smt = 'https://github.com/sauriiiin/sau-matlab-toolkit/archive/master.zip';

    zip_lid = urlwrite(url_lid, sprintf('%s/lid.zip',path));
    zip_smt = urlwrite(url_smt, sprintf('%s/smt.zip',path));

    unzip(zip_lid,path);
    unzip(zip_smt,path);

    delete(sprintf('%s/lid.zip',path));
    delete(sprintf('%s/smt.zip',path));

    fprintf('Files Updated\n');
        
end
