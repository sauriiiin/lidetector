#!/bin/bash

echo "Begin Spatial Bias Correction"
matlab -nodesktop -nodisplay -r "try; auto_lid; catch; end; quit"
echo "End Spatial Bias Correction"