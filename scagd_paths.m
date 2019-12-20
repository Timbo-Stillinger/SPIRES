%sets up all needed paths for scagd
if isunix
    nbroot = '/raid/sandbox/snowhydro/nbair/';
    jdroot = '/raid/sandbox/snowhydro/jdozier/MATLAB';
elseif ispc
    nbroot = 'C:\raid\data\nbair';
    jdroot = 'C:\Users\dozier\OneDrive\MATLAB';
end
addpath(fullfile(nbroot,'toolbox','SnowCloudReflectance'));
addpath(fullfile(nbroot,'toolbox','SnowCloudReflectance','FunctionLib'));
addpath(fullfile(nbroot,'toolbox','RasterReprojection'));
addpath(fullfile(nbroot,'BoxSync','MATLAB functions','Inpaint_nans'));
addpath(fullfile(nbroot,'BoxSync','MATLAB functions','smoothn'));
addpath(fullfile(nbroot,'BoxSync','JeffFunctionLibSandbox','TimeSpace'));
addpath(fullfile(nbroot,'BoxSync','TimeSpaceSnowSandbox'));

addpath(fullfile(jdroot,'toolbox','SMARTS295'));
addpath(fullfile(jdroot,'toolbox','TopoHorizon','FunctionLib'));

addpath(fullfile(jdroot,'Data','Optical'));

addpath(fullfile(nbroot,'BoxSync','JeffFunctionLibSandbox','General'));
addpath(fullfile(nbroot,'BoxSync','JeffFunctionLibSandbox','SunPosition'));
addpath(fullfile(nbroot,'BoxSync','JeffFunctionLibSandbox','TimeSpace'));
addpath(fullfile(nbroot,'BoxSync','JeffFunctionLibSandbox','Mapping'));
addpath(fullfile(nbroot,'BoxSync','JeffFunctionLibSandbox','MODIS_HDF'));

%deprecated twostream.m
addpath(fullfile(jdroot,'JeffFunctionLib','RadiativeTransfer'),'-end');
%deprecated bandPassReflectance.m
addpath(fullfile(jdroot,'JeffFunctionLib','SnowCloud'),'-end');
%also contained deprecated bandPassReflectance - this is where symbolic
%links would help but are not possible in windows
addpath(fullfile(jdroot,'JeffFunctionLib','RemoteSensing'),'-end');
%don't forget the current path
addpath(pwd);