#!/bin/bash
if [ "$#" -lt 2 ]; 
    then echo $# argument\(s\) are NOT enough!!
        echo "Need 2 args:  $0 input_csv_file model_file"
	echo "   For example:"
	echo "   $0 ~/Documents/run_umap/examples/sampleBalbc12k.csv ~/temp/balbc55"
	echo " "
    exit 9
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
python3.7 $DIR/mlpPredict.py $1 $2 
