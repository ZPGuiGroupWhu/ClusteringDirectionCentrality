#   AUTHORSHIP
#       Stephen Meehan <swmeehan@stanford.edu>
#
#   Provided by the Herzenberg Lab at Stanford University.
#   License: BSD 3 clause
#
import sys
import argparse
import os
from mlp import mlp_train
from pathlib import Path

script = os.path.basename(sys.argv[0])
nArgs = len(sys.argv)
if nArgs < 3:
    aid = script + ' takes input_file.csv mlp_model\n\t' + \
          'and produces an MLP model for predicting'
else:
    print('script arguments:  ' + " ".join(sys.argv[1:]))
    file, ext = os.path.splitext(sys.argv[1])
    aid = script + ' takes ' + sys.argv[1] + ' and produces a\n\t' + \
          'prediction  result in ' + file + '.csv'
    print(aid)

p = argparse.ArgumentParser(aid + '\n')
p.add_argument('input_csv_file', help='csv file with column labels');
p.add_argument('model', help='csv file with column labels');
p.add_argument("--verbose", help="Increase output verbosity", action="store_true")
# for flow cytometry which is fraught with approximations 75 epochs should be good
p.add_argument("--epochs", help="# of training epochs", type=int, default=75)

args = p.parse_args()

csv_in = args.input_csv_file.replace('~', str(Path.home()))
model = args.model.replace('~', str(Path.home()))

mlp_train(csv_in, model, args.epochs)

sys.exit(0)
