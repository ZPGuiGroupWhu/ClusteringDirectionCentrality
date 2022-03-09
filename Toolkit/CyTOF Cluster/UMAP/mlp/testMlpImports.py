#   AUTHORSHIP
#       Stephen Meehan <swmeehan@stanford.edu>
#
#   Provided by the Herzenberg Lab at Stanford University.
#   License: BSD 3 clause
#
try:
    import sys
    import argparse
    from xml.parsers.expat import model
    import numpy as np
    import pandas as pd
    import matplotlib.pyplot as plt
    from sklearn.model_selection import train_test_split
    import tensorflow.keras as keras
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import Dense, Dropout, Activation, Flatten
    from tensorflow.keras.layers import Conv2D, MaxPooling2D
    from tensorflow.keras.layers import Reshape, Input
    from tensorflow.keras.preprocessing.image import ImageDataGenerator
    from tensorflow.keras.callbacks import EarlyStopping
    from tensorflow.keras.regularizers import l2
    from tensorflow.keras.layers import average
    from tensorflow.keras.models import  Model
    from keras.utils.vis_utils import plot_model
    from sklearn.preprocessing import LabelEncoder
    from keras.utils import np_utils
    from sklearn.preprocessing import StandardScaler
    from pickle import dump, load
    import os
    from pathlib import Path
    print('All imports essential to mlp.py are found')
    exit(0)
except ImportError as exc:
    print(exc)
    exit(100)
