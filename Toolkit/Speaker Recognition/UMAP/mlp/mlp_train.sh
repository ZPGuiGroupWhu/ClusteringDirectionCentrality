#!/bin/bash
#
#./mlp_train.sh ~/Documents/run_umap/examples/balbc10DLabeled134k.csv balbc10D 50
#
#./mlp_predict.sh ~/Documents/run_umap/examples/balbcFmo10D133k.csv balbc10D ~/Documents/run_umap/examples/balbcFmo10D133k_mlp.csv
#suh_pipelines pipe match training_set balbcFmo10DLabeled133k.csv test_set balbcFmo10D133k_mlp.csv training_label_file balbcFmo10DLabeled133k.properties test_label_file balbc10DLabeled134k.properties check_equivalence true
#
#./mlp_predict.sh ~/Documents/run_umap/examples/rag10D148k.csv balbc10D ~/Documents/run_umap/examples/rag10D148k_mlp.csv
#suh_pipelines pipe match training_set rag10DLabeled148k.csv test_set rag10D148k_mlp.csv training_label_file balbcFmo10DLabeled133k.properties test_label_file balbc10DLabeled134k.properties check_equivalence true
#
if [ "$#" -lt 3 ]; 
    then echo $# argument\(s\) are NOT enough!!
   	 echo "Need 3 args:  $0 input_csv_file model_file epochs"
	echo "   For example:"
	echo "   $0 ~/Documents/run_umap/examples/sampleBalbcLabeled55k.csv ~/temp/balbc55 10"
	echo " "
    exit 9
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
python3.7 $DIR/mlpTrain.py $1 $2 --epochs $3
