"""
    DimensionlessAirflowEstimation_console.py - Run trained models for dimensionless respiratory airflow estimation

    Input:
        --directory (str): directory where the .wav files are (default value - current working directory)
        --audioFilenames (string): list with the names of .wav files, with quotes, to run the model on; empty list ("[]") runs all .wav files in directory (default value - "[]")
        --modelType (str): model trained with TbCS and TbDb files ('allfiles') or only TbDb ('tidaldeep') (default value - 'allfiles')
        --storePlot (int): variable to store the plot with the output of the model (1) or not (0) (default value - 0)
    
    Output:
        The script outputs a .txt file with the output of the model for each .wav file processed. The .txt files are stored in the same directory as the .wav files.
        
    Usage (in console): 
        python DimensionlessAirflowEstimation_console.py --directory ".\\Sample files" --audioFilenames "[SampleFile1.wav, SampleFile2.wav]" --modelType "allfiles" --storePlot 0
        
        Note: All arguments are optional. If a specfic argmument is not provided, the default value will be considered (please check the default values).
    
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


def RunModel(directory, audio_filenames, model_type, store_plot): ## New files estimation

    if directory == '':
        directory = os.getcwd()
        
    # verifications
    if os.path.isdir(directory):
        isdirectory = True
        if len(audio_filenames) == 0:        
            audio_filenames = getFilesExtension(directory, '.wav')
            
            if len(audio_filenames) == 0:
                files = False
                print('No .wav files in the directory!')
            else:
                files = True
        else:
            files = True
    else:
        isdirectory = False
        files = False
        print('Invalid directory!')
        
            
    if model_type not in ['allfiles', 'tidaldeep']:
        model_valid = False
        print('Invalid model type!')
    else:
        model_valid = True
        
        
    if files and model_valid and isdirectory:
        for file in audio_filenames:
            
            audio_filename = os.path.normpath(directory) + '\\' + file
            
            if os.path.isfile(audio_filename):
                print("Processing " + file)
            
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
                
                output.to_csv(os.path.normpath(directory) + '\\' + file + '_output.txt', index = False, header = True, sep = ',')
                
                if store_plot == 1:
                    plt.figure()
                    plt.subplot(2,1,1)
                    plt.imshow(spectro, aspect="auto")
                    plt.ylabel('Frequency (kHz)')
                    plt.title(file)
                    ax = plt.gca()
                    ax.set_yticks([0, 65, 129])
                    ax.set_yticklabels(['2', '1', '0'])
                    ax.get_xaxis().set_visible(False)
                    plt.subplot(2,1,2)
                    # Samples
                    plt.plot(time_vector, predicted_chunks_postprocessing, color = "red", linestyle = '--')
                    plt.legend(['Predicted Dimensionless Respiratory Airflow'])
                    plt.ylabel('Normalized Respiratory Airflow')
                    plt.xlabel('Time (s)')
                    plt.xlim([0, np.max(time_vector)])
                    
                    plt.savefig(os.path.normpath(directory) + '\\' + file + '_output.svg')
                    
                    plt.close()
            
            else:
                print(audio_filename + ' does not exist!')
                
                

    return

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Script so useful.')
    parser.add_argument("--directory", type = str, default="")
    parser.add_argument("--audioFilenames", type = str, default = "[]")
    parser.add_argument("--modelType", type = str, default = "allfiles")
    parser.add_argument("--storePlot", type = int, default = 0)

    args = parser.parse_args()

    directory_value = args.directory   
    modelType_value = args.modelType
    storePlot_value = args.storePlot
    
    if args.audioFilenames == "[]":
        audioFilenames_value = []
    else:
        list_argument = args.audioFilenames.replace('[','').replace(']','')
        audioFilenames_value = [item.lstrip().rstrip() for item in list_argument.split(',')]
    
    RunModel(directory = directory_value,
              audio_filenames = audioFilenames_value,
              model_type = modelType_value,
              store_plot = storePlot_value)
    


   