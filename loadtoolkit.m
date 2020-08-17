    
%%  LOAD COLONY ANLYZER TOOLKIT

    restoredefaultpath;
    
    temp = strsplit(matlabpath(), ':');
    matlab_path = temp{1};
    cd(matlab_path)
    
    toolkit_path = input('Path to the folder with LI Detector scripts: ', 's');
    if ~isempty(toolkit_path)
        toolkit_path = sprintf('%s/%s',matlab_path,toolkit_path);
    else
        toolkit_path = matlab_path;
    end
    
    addpath(genpath(sprintf('%s/Matlab-Colony-Analyzer-Toolkit', toolkit_path)))
    addpath(genpath(sprintf('%s/bean-matlab-toolkit', toolkit_path)))
    addpath(genpath(sprintf('%s/sau-matlab-toolkit', toolkit_path)))
    addpath(genpath(sprintf('%s/sau-matlab-toolkit/grid-manipulation', toolkit_path)))
    addpath(genpath(sprintf('%s/lidetector', toolkit_path)))

    javaaddpath(sprintf('%s/mysql-connector-java-8.0.16.jar', matlab_path));
    