#!/bin/bash

echo "Begin Initialize"
matlab -nodisplay -nodesktop -r "try; initialize; catch ME; disp(ME.message); end; quit"
echo "End Initialize"
