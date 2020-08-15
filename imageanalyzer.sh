#!/bin/bash

echo "Begin Image Analysis and Upload"
matlab -nodesktop -nosplash -r "try; imageanalyzer_t; catch; end; quit"
echo "End Image Analysis and Upload"