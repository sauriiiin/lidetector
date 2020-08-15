#!/bin/bash

echo "Begin Initialize"
matlab -nodisplay -nodesktop -r "try; initialize_t; catch; end; quit"
echo "End Initialize"
