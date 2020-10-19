# LI Detector
## A framework for sensitive colony-based screens regardless of the distribution of fitness effects
### Pre-print available on [bioRxiv](https://doi.org/10.1101/2020.06.27.175216).

## 1. Initialize
### Generating tables necessary for the effective use of the LI Detector
#### initialize.m

1. Information to keep in hand before proceeding:
    - MySQL credentials - username, password, database name
    - Upscale patterns from the experiment - ie in what combinations were the lower density plates condensed to form the higher density plates
    - Name of reference strain being used
    - Plate maps of the starting density plate
        - One plate per sheet in excel
        - Cells contain strain-id
        - File should be in .xlsx format
        - [Example](https://pitt-my.sharepoint.com/:x:/g/personal/sbp29_pitt_edu/EUqQET4XWYtNktm35JmFjrkBugFrj3fPiRk_Mk2MjN2MQQ)
    - Excel table specifying strain-id to orf-name relationships
        - First column is strain_id
        - Second column is orf_name (should include the reference strain)
        - Unique strain-ids for each orf (mutant strain)
        - Each strain-id from the platemaps should have an associated orf-name
        - File should be in .xlsx format
        - [Example](https://pitt-my.sharepoint.com/:x:/g/personal/sbp29_pitt_edu/EX_KyGzwFp9DvrcKN9pwREcBeWoA4viPlbWRnVuCxlKw6A)
2. Successful run will create the following tables:
    - <strong>_borderpos</strong> = border positions of all plates in the experiment
        - 1 border for 384 density, 2 for 1536 and 4 for 6144
    - <strong>_pos2coor</strong> = position ids and their corresponding plate coordinate
        - unique position ids for all possible colony positions in the experiment and thei correspoing plate coordinates ie colony density, plate number, row number and column number
    - <strong>_pos2orf_name</strong> = position ids and the corresponding orf-name (or mutant name)
    - <strong>_pos2rep</strong> = position ids of lowest density plates to their replicates at higher density plates based on the upscale pattern
        - for internal use
    - <strong>_pos2strain_id</strong> = position ids and their corresponding strain ids
    - <strong>_strainid2orf_name</strong> = same as excel table from above
3. Example files can be found in [Data.zip](https://github.com/sauriiiin/lidetector/blob/master/Data.zip).
    
## 2. Analyze Images
### Pixel count estimation from pictures using the MATLAB Colony Analyzer Toolkit
#### imageanalyzer.m

1. Information to keep in handy before proceeding:
    - Location of any smudges on the plates ie the colonies you want to remove from the analysis because of any technical issues
        - plate number, row number, column number
2. User will be asked to verify binary files before uploading raw pixel count data
    - Each image will now have 3 additional files - .binary, .cs.txt and .info.mat
    - View the .binary file (using Preview in Mac) to verify if the colonies have been correctly identified
3. Successful run will create the following tables:
    - <strong>_RAW</strong> = raw colony size estimations per hour per position id of all the images
        - image1, image2 and image3 columns correspond to the three images per plate
        - average column is the mean of the pixel count estimation from the three images
            - image1 = image2 = image3 = average if there is a single image per plate
    - <strong>_smudgebox</strong> = position ids corresponding to the user defined coordinates
    - <strong>_JPEG</strong> = similar to <strong>_RAW</strong> with
        - pixel count estimations for borders and smudgebox NULL'd
        - and any pixel count estimation < 10 is also NULL'd - likely to be a light artifact  
4. If the images are already analyzed using a different software then make sure the colony sizes in the _JPEG table are arranged in ascending order of hours, plate number, column number, row number.
5. Example files can be found in [Data.zip](https://github.com/sauriiiin/lidetector/blob/master/Data.zip).
    
## 3. Spatial Bias Correction
### Relative fitness measurements and p-value estimation from colony-size data
#### lid.m

1. Successful run will create the following tables:
    - <strong>_NORM</strong> = position ids and their corresponding relative fitness measurements
        - also includes the background pixel count measurement based on references
    - <strong>_FITNESS</strong> = similar to <strong>_NORM</strong> but with strain ids and orf-names included
    - <strong>_FITNESS_STAT</strong> = strain-id-wise mean, median and standard deviation of relative fitness
    - <strong>_PVALUE</strong> = strain-id-wise empirical p-values
        - stat = (strain mean fitness - reference mean fitness)/reference fitness standard deviation
        - es = (strain mean fitness - reference mean fitness)reference mean fitness
2. Example files can be found in [Data.zip](https://github.com/sauriiiin/lidetector/blob/master/Data.zip).
        
        
