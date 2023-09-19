clear all
close all
clc

run './eidors-v3.10-ng/eidors/startup.m'%path to EIDORS

%chunks parameters
chunk_time = 15;%seconds
chunk_overlap = 0.99; %chunk_overlap = 0.9;
%TF parameters
window_size = 64;%ms
overlap_percentage = 0.80;
nfft_spectro = 256;

sound_filename = '..\Sample files\49_05_AAL.wav';
eit_filename = '..\Sample files\49_20211103113648.eit';

eit_synched_interval_frame_init = 601;
eit_synched_interval_frame_end = 1262;

%Audio
audio_info = audioinfo(sound_filename);
[audio, Fs] = audioread(sound_filename);

% EIT
[vv, auxdata, stim]= eidors_readdata(eit_filename,"EIT",[]);
eit_metadata_var = eit_metadata(eit_filename);

fs_eit = eit_metadata_var.Fs;
duration_eit = size(vv,2)/fs_eit;%(s)
fs_eit_aux = length(auxdata.auxtime)/duration_eit;

% EIT reconstruction
[image_slices_all_conductivity, images_slices_separated, eitFile_metadata, voltage_data] = eit_reconstruction(eit_filename, 'VoltageData', vv);

% GIC computation
Global_EIT_waveform = zeros(size(images_slices_separated,3),1);
for f = 1:size(images_slices_separated,3)
    Global_EIT_waveform(f) = sum(sum(images_slices_separated(:,:,f)));
end
Global_EIT_waveform = lowpass(Global_EIT_waveform,0.05,fs_eit);
Global_EIT_waveform = normalize(Global_EIT_waveform,"range");
t_gic = (1:length(Global_EIT_waveform))/fs_eit;


% spectrogram computation
window = round((window_size/1000)*Fs);
noverlap = round(window*overlap_percentage);

[s,f,t,ps] = spectrogram(audio,blackmanharris(window),noverlap,nfft_spectro,Fs,'yaxis');
spectro = flip(10*log10(abs(ps)));%convert spectrogram from power to db %% pow2db(ps)
spectro(~isfinite(spectro))=min(spectro(isfinite(spectro)));
spectro = (spectro - min(min(spectro)))/(max(max(spectro)) - min(min(spectro))); %min-max normalization 0-1

column_time = (window-noverlap)/Fs;%spectrogram temporal resolution
spectro_padded = [zeros( size(spectro,1), round((eit_synched_interval_frame_init/fs_eit) / column_time) ),...
                  spectro,...
                  zeros(size(spectro,1), round( ((size(images_slices_separated,3) - eit_synched_interval_frame_end) / fs_eit) / column_time))];

figure
subplot 211
imagesc(spectro_padded)
title('Respiratory sound spectrogram')
ylabel('Frequency')
set(gca,'xtick',[])
set(gca,'ytick',[])

subplot 212
plot(t_gic, Global_EIT_waveform)
xlim([0, t_gic(end)])
title('Normalized respiratory airflow')
xlabel('Time (s)')



