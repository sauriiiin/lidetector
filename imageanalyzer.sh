#!/bin/bash

echo "Begin Image Analysis and Upload"
matlab -nodesktop -nosplash -r "try; auto_imageanalyzer; catch; end; quit"
echo "End Image Analysis and Upload"