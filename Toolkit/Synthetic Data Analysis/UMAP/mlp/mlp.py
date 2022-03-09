#   AUTHORSHIP
#       Jonathan Ebrahimian <jebrahimian@mail.smu.edu>:  
#       Connor Meehan <connor.gw.meehan@gmail.com>: 
#       Stephen Meehan <swmeehan@stanford.edu>
#
#   Provided by the Herzenberg Lab at Stanford University.
#   License: BSD 3 clause
#
from xml.parsers.expat import model
import pandas as pd
import numpy as np
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




def mlp_train(csv_file_name, model_file_name, max_epochs):

    df = pd.read_csv(csv_file_name)

    columns = df.columns
    #get the element in columns that contains the string "Unnamed" and drop them
    unnamed_cols = [col for col in columns if 'Unnamed' in col]
    df = df.drop(unnamed_cols, axis=1)

    #target_col = [col for col in columns if 'CytoGenie GatingTree' in col]

    df.rename(columns={df.columns[-1]: 'target'}, inplace=True)

    # We are going to change the target variable to be values from 0-x.
    replace_dict = {}
    unreplace_dict = {}
    x = 0
    for val in np.sort(df.target.unique()):
        replace_dict[val] = x
        unreplace_dict[x] = val
        x += 1

    unique_classes = len(df.target.unique())


    # ML imports


    keras.__version__


    X = df.drop(['target'], axis=1)
    y = df.target

    # encode class values as integers
    encoder = LabelEncoder()
    encoder.fit(y)
    encoded_Y = encoder.transform(y)
    # convert integers to dummy variables (i.e. one hot encoded)
    dummy_y = np_utils.to_categorical(encoded_Y)


    #apply standard scaler
    scaler = StandardScaler()
    X = scaler.fit_transform(X)


    input = Input(shape=(X.shape[1],), name='numeric')
    x_dense = Dense(units=100, activation='relu',name='dense1')(input)
    #add dropout
    x_dense = Dropout(0.25)(x_dense)
    x_dense = Dense(units=50, activation='relu',name='dense2')(x_dense)
    x_dense = Dense(units=25, activation='relu',name='dense3')(x_dense)
    x_dense = Dense(units=unique_classes, activation='softmax',name='dense4')(x_dense)


    dense_model = Model(inputs=input,
                    outputs=x_dense)

    dense_model.compile(optimizer='adam',
                loss='kullback_leibler_divergence',
                metrics=['accuracy'])

    history = dense_model.fit(X,
                        dummy_y,
                        epochs=max_epochs,
                        batch_size=128,
                        verbose=1
                        # validation_data=(X_test,y_test)
                        )
    if not os.path.dirname(model_file_name):

        # save this model to a file
        dense_model.save('./Models/' + model_file_name + '.h5')

        # save standard scaler
        dump(scaler, open('./Scalers/' + model_file_name + '.pkl', 'wb'))

        # save unreplace_dict
        dump(unreplace_dict, open('./Dicts/' + model_file_name + '.pkl', 'wb'))

    else:
        mfn = model_file_name.replace('~', str(Path.home()))
        dense_model.save(mfn + '.h5')
        dump(scaler, open(mfn + '_scale.pkl', 'wb'))
        dump(unreplace_dict, open(mfn + '_dict.pkl', 'wb'))

    return history.history["accuracy"][-1]


def mlp_predict(csv_file_name,model_file_name,csv_result_file_name,predictions_file_name):
    if not os.path.dirname(model_file_name):
        # load model
        model = keras.models.load_model('./Models/' + model_file_name + '.h5')

        # load scaler
        scaler = load(open('./Scalers/' + model_file_name + '.pkl', 'rb'))

        # load unreplace_dict
        unreplace_dict = load(open('./Dicts/' + model_file_name + '.pkl', 'rb'))
    else:
        mfn = model_file_name.replace('~', str(Path.home()))
        model = keras.models.load_model(mfn + '.h5')
        scaler = load(open(mfn + '_scale.pkl', 'rb'))
        unreplace_dict = load(open(mfn + '_dict.pkl', 'rb'))


    df = pd.read_csv(csv_file_name)

    #X_test = df.to_numpy()

    X_test = scaler.transform(df)

    predictions_mat = model.predict(X_test)

    predictions = np.argmax(predictions_mat, axis=1)

    predictions_df = pd.DataFrame(predictions_mat)

    predictions_df.rename(columns=unreplace_dict, inplace=True)

    predictions_df.to_csv(predictions_file_name, index=False)

    

    #replace a value in a numpy array
    def replace_value(array, old_value, new_value):
        array[array == old_value] = new_value
        return array

    for key in unreplace_dict:
        replace_value(predictions, key, unreplace_dict[key])

    df['target'] = predictions

    df.to_csv(csv_result_file_name, index=False)

    return True

def mlp_predict2(input_data,model_file_name):
    if not os.path.dirname(model_file_name):
        # load model
        model = keras.models.load_model('./Models/' + model_file_name + '.h5')

        # load scaler
        scaler = load(open('./Scalers/' + model_file_name + '.pkl', 'rb'))

        # load unreplace_dict
        unreplace_dict = load(open('./Dicts/' + model_file_name + '.pkl', 'rb'))
    else:
        mfn = model_file_name.replace('~', str(Path.home()))
        model = keras.models.load_model(mfn + '.h5')
        scaler = load(open(mfn + '_scale.pkl', 'rb'))
        unreplace_dict = load(open(mfn + '_dict.pkl', 'rb'))

    X_test = scaler.transform(input_data)

    predictions_mat = model.predict(X_test)

    predictions = np.argmax(predictions_mat, axis=1)

    def replace_value(array, old_value, new_value):
        array[array == old_value] = new_value
        return array

    for key in unreplace_dict:
        replace_value(predictions, key, unreplace_dict[key])

    return predictions, predictions_mat


#main
if __name__ == "__main__":
    #model_file_name = 'eliver55'
    #mlp_train('~/Documents/run_umap/examples/sampleBalbcLabeled55k.csv',model_file_name)
    #mlp_predict('~/Documents/run_umap/examples/sample30k.csv',model_file_name,'~/Documents/run_umap/examples/sample30k_mlp.csv')


    #mlp_predict('~/Documents/run_umap/examples/sampleBalbc12k.csv', model_file_name,
 #               '~/Documents/run_umap/examples/sampleBalbc12k_mlp.csv')
    #suh_pipelines pipe match training_set sampleBalbcLabeled12k.csv test_set sampleBalbc12k_mlp.csv training_label_file balbcLabels.properties


    # bash shell invocation
    #/mlp_predict.sh ~/Documents/run_umap/examples/sampleRag60k.csv ~/temp/balbc55_v2 ~/Documents/run_umap/examples/sampleRag60k_mlp.csv
    #MATLAB checking for above result requires 2 label files for translating target labels
    #suh_pipelines pipe match training_set sampleRagLabeled60k.csv test_set sampleRag60k_mlp.csv training_label_file ragLabels.properties test_label_file balbcLabels.properties


    model_file_name = 'omip69'
    # mlp_train('~/Documents/run_umap/examples/omip69Labeled.csv', 'omip69',1)
    mlp_predict('~/Documents/run_umap/examples/omip69.csv',model_file_name,'~/Documents/run_umap/examples/omip69_mlp.csv','Predictions/omip69_predictions.csv')
    #suh_pipelines pipeline match test_label_column end test_set omip69_mlp.csv training_label_column end training_label_file omip69Labeled.properties training_set omip69Labeled.csv check_equivalence true
    #suh_pipelines('pipeline', 'match', 'test_label_column',28, 'test_set','omip69_mlp.csv', 'training_label_column', 'end','training_label_file','omip69Labeled.properties','training_set','omip69Labeled.csv', 'check_equivalence', true);
