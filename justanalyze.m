%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  analyzeallimages.m

%   Author: Saurin Parikh, October 2020
%
%   Needs info.txt file in the home directory or change path wherever
%   necessary
%
%   dr.saurin.parikh@gmail.com

%%  Load Paths to Files and Expt Info

%   open load_toolkit.m and update the paths
    loadtoolkit;
%   use info.txt in the directory as a example
%   place your file in the MATLAB directory
    fileID = fopen(sprintf('%s/info.txt',toolkit_path),'r');
    info = textscan(fileID, '%s%s');
    
%%  INITIALIZATION
    
    file_dir = input('Path to image directory: ', 's');
    density = input('Colony-density of plates: ');
    
%%  GETTING IMAGE FILES
    
    files = {};
    filedir = dir(file_dir);
    dirFlags = [filedir.isdir] & ~strcmp({filedir.name},'.') & ~strcmp({filedir.name},'..');
    subFolders = filedir(dirFlags);
    for k = 1 : length(subFolders)
        tmpdir = strcat(subFolders(k).folder, '/',  subFolders(k).name);
        filedir2 = dir(tmpdir);
        dirFlags2 = [filedir2.isdir] & ~strcmp({filedir2.name},'.') & ~strcmp({filedir2.name},'..');
        subFolders2 = filedir2(dirFlags2);
        for k2 = 1 : length(subFolders2)
            tmpdir2 = strcat(subFolders2(k2).folder, '/',  subFolders2(k2).name);
            files = [files; dirfiles(tmpdir2, '*.JPG')];  
    %         hrs = strfind(tmpdir, '/'); hrs = tmpdir(hrs(end)+1:end);
    %         hours = [hours, str2num(hrs(1:end-1))];
        end
    end
    
%%  PLATE DENSITY AND ANALYSIS PARAMETERS
    
    if density == 6144
        dimensions = [64 96];
    elseif density == 1536
        dimensions = [32 48];
    elseif density == 384
        dimensions = [16 24];
    else
        dimensions = [8 12];
    end
    
    params = { ...
        'parallel', true, ...
        'verbose', true, ...
        'grid', OffsetAutoGrid('dimensions', dimensions), ... default
        'threshold', BackgroundOffset('offset', 1.25) }; % default = 1.25

%%  IMAGE ANALYSIS

    all = zeros(1, size(files, 1));
    for ii = 1 : size(all, 2)
        all(ii) = exist(strcat(files{ii}, '.binary'));
    end
    pos = find(all==0);
    
    if isempty(pos)
        disp('All files are already analyzed.')
        if input('Do you want to re-analyze them? [Y/N] ', 's') == 'Y'
            analyze_directory_of_images(files, params{:} );
            direct_upload = 'N';
        else
            direct_upload = 'Y';
        end
    else
        fprintf('%d out of %d images remain to be analyzed.\n',...
            length(pos),...
            length(files))
        if input('Do you want to analyze all? [Y/N] ', 's') == 'Y'
            analyze_directory_of_images(files, params{:} );
            direct_upload = 'N';
        else
            files2 = files;
            files2(pos) = [];
            analyze_directory_of_images(files2, params{:} );
            direct_upload = 'N';
        end
    end

    if direct_upload == 'N'
%%  COLLECT IMAGES WITH NO GRID
%   Those images that weren't analyzed correctly

        all = zeros(1, size(files, 1));
        for ii = 1 : size(all, 2)
            all(ii) = exist(strcat(files{ii}, '.binary'));
        end
        pos = find(all==0);

        if isempty(pos)
            disp('All images were successfully analyzed.')
        else
            fprintf('%d image/s were not analyzed.\n',length(pos))
            alt_thresh = input('Would you like to re-analyze all images using a different background threshold? [Y/N] ', 's');
            if alt_thresh == 'Y'
                thresh = input('New threshold (default = 1.25): ');
                params = { ...
                    'parallel', true, ...
                    'verbose', true, ...
                    'grid', OffsetAutoGrid('dimensions', dimensions), ... default
                    'threshold', BackgroundOffset('offset', thresh) };
                analyze_directory_of_images(files, params{:} );

                all = zeros(1, size(files, 1));
                for ii = 1 : size(all, 2)
                    all(ii) = exist(strcat(files{ii}, '.binary'));
                end
                pos2 = find(all==0);
                if isempty(pos2)
                    disp('All images were successfully analyzed with the new threshold.')
                else
                    fprintf('%d image/s were not analyzed.\n Manually place grid using previous threshold\n',length(pos))
                    for ii = 1 : length(pos)
                        analyze_image( files{pos(ii)}, params{:}, ...
                            'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
                    end
                end
            else
                disp('Manually place grid on images')
                for ii = 1 : length(pos)
                    analyze_image( files{pos(ii)}, params{:}, ...
                        'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
                end
            end
        end
    end
    fprintf('Examine binary images to verify proper colony detection before going forward.\nPress enter to proceed.\n')
    pause
    
    if input('Are the images properly analyzed? [Y/N]: ', 's') == 'N'
        if input('Is there a problem with all of them? [Y/N]: ', 's') == 'Y'
            disp('Manually place grid on all images')
            for ii = 1 : length(files)
                analyze_image( files{ii}, params{:}, ...
                    'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
            end
        else
            pos = input('Problematic images: ');
            
            disp('Manually place grid on images')
            for ii = 1 : length(pos)
                analyze_image( files{pos(ii)}, params{:}, ...
                    'grid', ManualGrid('dimensions', dimensions), 'threshold', BackgroundOffset('offset', 1.25));
            end
        end
    end