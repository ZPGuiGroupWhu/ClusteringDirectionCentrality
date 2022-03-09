#   AUTHORSHIP
#       Stephen Meehan <swmeehan@stanford.edu>
#
#   Provided by the Herzenberg Lab at Stanford University.
#   License: BSD 3 clause
#
import sys
import argparse
import os
from mlp import mlp_predict
from pathlib import Path

script = os.path.basename(sys.argv[0])
nArgs = len(sys.argv)
if nArgs < 4:
    aid = script + ' takes input_file.csv mlp_model output_file\n\t' + \
          'and produces a prediction result in file specifed by output_ile.csv'
else:
    print('script arguments:  ' + " ".join(sys.argv[1:]))
    file, ext = os.path.splitext(sys.argv[1])
    aid = script + ' takes ' + sys.argv[1] + ' and produces a\n\t' + \
          'prediction  result in ' + file + '.csv'
    print(aid)

p = argparse.ArgumentParser(aid + '\n')
p.add_argument('input_csv_file', help='csv file (with column labels) for input measurements plus classification label to train by');
p.add_argument('model', help='csv file with column labels');
p.add_argument('--output_csv_file', help='csv file with original input measurements  plus column for predicted classification label');
p.add_argument('--predictions_csv_file', help='csv file describing confidence of classification for each row of input_csv_file');
p.add_argument("--verbose", help="Increase output verbosity", action="store_true")
p.add_argument("--output_label_only", help="outputFile only contains label", action="store_false")
args = p.parse_args()
csv_in = args.input_csv_file.replace('~', str(Path.home()))
dirName = os.path.dirname(csv_in)
fileName, file_extension = os.path.splitext(csv_in)
model = args.model
model = model.replace('~', str(Path.home()))
csv_out=args.output_csv_file;
if not csv_out:
    csv_out = os.path.join(dirName, fileName + '_mlp.csv')
csv_predictions = args.predictions_csv_file
if not csv_predictions:
    csv_predictions=os.path.join(dirName, fileName + '_mlp_predictions.csv')

csv_out = csv_out.replace('~', str(Path.home()))
csv_predictions = csv_predictions.replace('~', str(Path.home()))
mlp_predict(csv_in, model, csv_out, csv_predictions)
sys.exit(0)

#my toekn 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
