import numpy as np
from scipy import signal
import os
from sklearn.preprocessing import minmax_scale
from scipy.io import wavfile
import scipy.signal as sps

# Utils
def getFilesExtension(directory, extension):
    filelist = []
    
    for file in os.listdir(directory):
       if(file.endswith(extension)):
           filelist.append(file)
                
    return filelist

# https://stackoverflow.com/questions/38453249/does-numpy-have-a-function-equivalent-to-matlabs-buffer
def buffer(x, n, p=0, opt=None):
    '''Mimic MATLAB routine to generate buffer array
    
    MATLAB docs here: https://se.mathworks.com/help/signal/ref/buffer.html
    
    Parameters
    ----------
    x: ndarray
        Signal array
    n: int
        Number of data segments
    p: int
        Number of values to overlap
    opt: str
        Initial condition options. default sets the first `p` values to zero,
        while 'nodelay' begins filling the buffer immediately.
    
    Returns
    -------
    result : (n,n) ndarray
        Buffer array created from X
    '''
    if opt not in ('nodelay', None):
        raise ValueError('{} not implemented'.format(opt))
       
    i = 0
    if opt == 'nodelay':
        # No zeros at array start
        result = x[:n]
        i = n
    else:
        # Start with `p` zeros
        result = np.hstack([np.zeros(p), x[:n-p]])
        i = n-p
        # Make 2D array, cast to list for .append()
    result = list(np.expand_dims(result, axis=0))
    
    while i < len(x):
        # Create next column, add `p` results from last col if given
        col = x[i:i+(n-p)]
        if p != 0:
            col = np.hstack([result[-1][-p:], col])
    
        # Append zeros if last row and not length `n`
        if len(col):
            col = np.hstack([col, np.zeros(n - len(col))])
    
        # Combine result with next row
        result.append(np.array(col))
        i += (n - p)
    
    if(result[0].size < n): # cases of chunks smaller thant desired size
        result[0] = np.concatenate( (result[0], np.zeros(( n - result[0].size ))), axis = 0 )
        
    return np.vstack(result).T
                 

# data processing
def divide_data_chunks(data, chunk_time, chunk_overlap, column_time, t):
    
    number_time_steps = data.shape[1]
    
    n_instants_chunk = round(chunk_time/column_time)
    n_instants_overlap = round((chunk_time/column_time)*chunk_overlap)
    
    instants_chunks = buffer(np.arange(0, number_time_steps, 1, dtype=int), 
                             n_instants_chunk,
                             n_instants_overlap,
                             opt = 'nodelay') # determine the instants for the chunks
    
    data_chunks = {'chunks': [],
                   'idx_chunks': [],
                   't_chunks': []}
    for i in range(instants_chunks.shape[1]):
        idx = instants_chunks[:,i].astype(int) # get the indexes for each chunk
        idx_remove = np.argwhere(idx == 0)
        idx_remove = np.delete(idx_remove, np.argwhere(idx_remove == 0)) # for the first index
        idx = np.delete(idx, idx_remove)
        
        if(len(idx) == n_instants_chunk):
            chunk = data[:,idx]
    
            data_chunks['chunks'].append(chunk)
            data_chunks['idx_chunks'].append(idx + 1)
            data_chunks['t_chunks'].append(t[idx])
        else: # padding
            chunk = np.concatenate( (data[:,idx], np.zeros((data.shape[0],(n_instants_chunk-len(idx))))), axis = 1 )
            
            data_chunks['chunks'].append(chunk)
            data_chunks['idx_chunks'].append(idx + 1)
            data_chunks['t_chunks'].append(t[idx])
    
    return data_chunks

def processAudio(audio_filename): #audio_filename = '08_01_PBL.wav'
    
    sr, audio = wavfile.read(audio_filename)

    if sr != 4000:
        # Resample data
        number_of_samples = round(len(audio) * float(4000) / sr)
        audio = sps.resample(audio, number_of_samples)
        sr = 4000
        
    audio = minmax_scale(audio, feature_range=(-1, 1), axis = 0)#Global Min-Max normalization

    # chunks parameters
    chunk_time = 15
    chunk_overlap = 0.99

    # spectrogram parameters
    overlap_spect = 0.8        
    nfft = 256
    window_size = 64

    f, t, Sxx = signal.spectrogram(audio,
                                   fs = sr,
                                   return_onesided = True,
                                   nperseg = round((window_size/1000) * sr),
                                   noverlap =  round((window_size/1000) * sr * overlap_spect),
                                   nfft = nfft,
                                   window=('blackmanharris'),
                                   mode = 'psd')

    spectro = np.flipud(10*np.log10(Sxx)) # convert from power to dB
    spectro = (spectro - np.min(spectro)) / (np.max(spectro) - np.min(spectro))

    divided_images_spectro = divide_data_chunks(spectro, chunk_time, chunk_overlap, np.diff(t)[0], t)
    number_chunks = len(divided_images_spectro['chunks'])

    return divided_images_spectro, spectro, number_chunks

# PostProcessing and filters
def butter_lowpass_filtfilt(data, cutoff, fs, order):
    nyq = 0.5 * fs
    normal_cutoff = cutoff / nyq
    
    b, a = signal.butter(order, normal_cutoff, analog=False, btype = 'low')
    data = signal.filtfilt(b, a, data)
    
    return data

def postProcessing(curve, fs, cutoff = 0.05, order = 5, normalize = False):    
    
    curve = butter_lowpass_filtfilt(curve, 0.05, fs, order)
    
    if(normalize == True):
        curve = (curve - np.min(curve)) / (np.max(curve) - np.min(curve))#Global Min-Max normalization
        
    return curve



