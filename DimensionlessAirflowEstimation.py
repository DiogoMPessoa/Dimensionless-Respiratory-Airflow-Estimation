"""
    DimensionlessAirflowEstimation.py - Run trained models for dimensionless respiratory airflow estimation

    Input:    
        --audioFilenames (string): Audio filename (directory + filename)
        --modelType (str): model trained with TbCS and TbDb files ('allfiles') or only TbDb ('tidaldeep') (default value - 'allfiles')
        --storePlot (int): variable to store the plot with the output of the model (1) or not (0) (default value - 0)
    
    Output:
        output: DataFrame with the normalized dimensionless airflow and according time vector
        
    Usage: 
        import DimensionlessAirflowEstimation
        output = DimensionlessAirflowEstimation.RunModel(".\\Sample Files\\SampleFile1.wav", model_type = 'allfiles', store_output = True)
"""


# Libraries
import pandas as pd
import tensorflow as tf
import numpy as np
import matplotlib.pyplot as plt
import matplotlib 
matplotlib.use('Agg')
import os
from Utils import *
import argparse
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3' 

configuration = tf.compat.v1.ConfigProto()
configuration.gpu_options.allow_growth = True
session = tf.compat.v1.Session(config=configuration)


def RunModel(audio_filename, model_type, store_output): ## New files estimation

  if os.path.isfile(audio_filename):            
        divided_images_spectro, spectro, number_chunks = processAudio(audio_filename)
        
        #### Run model
        if model_type == 'allfiles':
            model = tf.keras.models.load_model('model_allfiles.h5', compile = False)
        elif model_type == 'tidaldeep':
            model = tf.keras.models.load_model('model_tidaldeep.h5', compile = False)
        
        # variable to store the output of all chunks
        output_all_chunks = np.empty((number_chunks, spectro.shape[1])) 
        output_all_chunks[:] = np.NaN      
        
        time_vector = np.empty((number_chunks,spectro.shape[1])) 
        time_vector[:] = np.NaN      
        
        for chk in range(number_chunks):
            time_chunk = divided_images_spectro['t_chunks'][chk]
            indices_chunk = divided_images_spectro['idx_chunks'][chk] - 1
            chunk = divided_images_spectro['chunks'][chk]
            chunk = np.reshape(chunk, (1, chunk.shape[0], chunk.shape[1], 1))
            
            test_output_chunk = model.predict(chunk, verbose=0)
            
            output_all_chunks[chk,indices_chunk.tolist()] = np.reshape(test_output_chunk[0,0:indices_chunk.size],(indices_chunk.size,))
            time_vector[chk,indices_chunk.tolist()] = time_chunk
            
        predicted_chunks = np.nanmean(output_all_chunks,axis=0)
        predicted_chunks_postprocessing = postProcessing(predicted_chunks, 1, cutoff = 0.01, normalize = True)
        time_vector = np.nanmean(time_vector,axis=0)
        
        output = pd.DataFrame({'Time': time_vector,
                               'Normalized Dimensionless Airflow': predicted_chunks_postprocessing})
        
        if store_output:
            output.to_csv(str.replace(audio_filename,'.wav','_output.txt'), index = False, header = True, sep = ',')
    
  else:
      print(audio_filename + ' does not exist!')
        
  return output

    

