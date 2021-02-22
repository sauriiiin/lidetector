#!/bin/bash

echo "Begin Image Analysis and Upload"
matlab -nodesktop -nosplash -r "try; imageanalyzer; catch ME; disp(ME.message); end; quit"
echo "End Image Analysis and Upload"