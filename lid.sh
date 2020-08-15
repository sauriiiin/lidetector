#!/bin/bash

echo "Begin Spatial Bias Correction"
matlab -nodesktop -nodisplay -r "try; lid_t; catch; end; quit"
echo "End Spatial Bias Correction"