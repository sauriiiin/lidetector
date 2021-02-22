#!/bin/bash

echo "Begin Spatial Bias Correction"
matlab -nodesktop -nodisplay -r "try; lid; catch ME; disp(ME.message); end; quit"
echo "End Spatial Bias Correction"