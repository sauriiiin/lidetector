#!/bin/bash

echo "Begin Initialize"
matlab -nodisplay -nodesktop -r "try; auto_initialize; catch; end; quit"
echo "End Initialize"
