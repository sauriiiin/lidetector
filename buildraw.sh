#!/bin/bash

echo "Begin Building Raw File"
matlab -nodisplay -nodesktop -r "try; buildraw; catch ME; disp(ME.message); end; quit"
echo "Finished Building Raw File"