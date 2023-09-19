function [image_slices_all_conductivity,images_slices_separated,eitFile_metadata,voltage_data] = eit_reconstruction(filename, varargin)
%reconstruct EIT data

voltage_data = 0;
if nargin > 1
    indVoltageData = find(strncmpi('VoltageData', varargin, 6));
    if ~isempty(indVoltageData)
       voltage_data  = cell2mat(varargin(indVoltageData+1));
    end
end

if(voltage_data == 0)
    [voltage_data, ~, ~]= eidors_readdata(filename);
end

fmdl = mk_library_model('adult_male_16el_lungs');
[fmdl.stimulation, fmdl.meas_select] = mk_stim_patterns(16,1,'{ad}','{ad}',{'no_meas_current','rotate_meas'}, .005);%'goeiimf-eit' stimulation pattern
fmdl = mdl_normalize(fmdl,1);

img = mk_image(fmdl,1); %img.elem_data(vertcat(fmdl.mat_idx{2:3})) = 0.3;
img.calc_colours.ref_level=0;
%figure
%show_fem_enhanced(img);
%calc_colours('defaults');

opt.imgsz = [32 32];
% opt.distr = 3; % non-random, uniform
% opt.Nsim = 500; % 500 hundred targets to train on, seems enough
% opt.target_size = 0.03; %small targets
% opt.target_offset = 0;
opt.noise_figure = .5; % this is key!
%opt.square_pixels = 1;

%make EIDORS inverse models using the GREIT approach
imdl = mk_GREIT_model(img, 0.25, [], opt);
figure
%calculate imag from an inv_model and data
%imgall = inv_solve(imdl,voltage_data(:,1),voltage_data); %reference frame for reconstruction - single frame
imgall = inv_solve(imdl,mean(voltage_data(:,1:100),2),voltage_data); %reference frame for reconstruction - mean from several initial frames

%Image slices calculation
image_slices_all_conductivity=show_slices(imgall);
close all
images_slices_separated = -calc_slices(imgall); % Negative to air is +  
images_slices_separated(isnan(images_slices_separated(:)))= 0;

% % Show GREIT images
% i_gr = mk_common_gridmdl('GREITc1');
% imdl_bp = mk_common_gridmdl('backproj');
% imgr = inv_solve(imdl_bp, voltage_data(:,1),voltage_data(:,1000:1005));
% imgr.show_slices.img_cols = 5;
% show_slices(imgr);

eitFile_metadata=eit_metadata(filename);
if(size(voltage_data,2)~=eitFile_metadata.Frames)
    eitFile_metadata.Frames=size(voltage_data,2);
end