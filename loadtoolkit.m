    
%%  LOAD COLONY ANLYZER TOOLKIT
    
    toolkit_path = input('Path to the folder with LI Detector scripts: ', 's');
    addpath(genpath(sprintf('%s/Matlab-Colony-Analyzer-Toolkit', toolkit_path)))
    addpath(genpath(sprintf('%s/bean-matlab-toolkit', toolkit_path)))
    addpath(genpath(sprintf('%s/sau-matlab-toolkit', toolkit_path)))
    addpath(genpath(sprintf('%s/sau-matlab-toolkit/grid-manipulation', toolkit_path)))
    addpath(genpath(sprintf('%s/lidetector', toolkit_path)))

    java_path = input('Path to mysql-connector .jar file: ', 's');
    javaaddpath(sprintf('%s/mysql-connector-java-8.0.16.jar', java_path));
    