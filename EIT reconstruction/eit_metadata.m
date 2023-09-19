function metadata=eit_metadata(fname)
fid= fopen(fname,'rb');
d= fread(fid,[1 1021],'uchar');
str= char(d(3:2:end));

expression = '<(\w+).*>.*</\1>';
[~,matches] = regexp(str,expression,'tokens','match');
metadata.Fs=str2double(cell2mat(regexp(matches{9},'\d+\.?\d*','Match')));
metadata.Frames=str2double(cell2mat(regexp(matches{10},'\d+\.?\d*','Match')));
metadata.Duration = str2double(cell2mat(regexp(matches{11},'\d+\.?\d*','Match')));
metadata.BeginDate= datetime(cell2mat(regexp(matches{8},'\d+\.?\d*','Match')),'InputFormat','yyyyMMddHHmmss');

fclose(fid);

% check all open files and close all
% fids = fopen('all')
% filenames = arrayfun(@fopen, fids, 'UniformOutput', 0)
% fclose('all')