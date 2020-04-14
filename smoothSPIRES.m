function out=smoothSPIRES(tile,matdates,topofile,watermask,...
    fsca_thresh,outloc,grainradius_nPersist,el_cutoff,cc,fice,endcondition)

% smoothes SPIRES MODIS cubes 
%input:
% tile - tilename, e.g. 'h08v05'
% matdates - matdates for cube
% topofile- h5 file name from consolidateTopography, part of TopoHorizons
% watermask- logical mask w/ ones for pixels to exclude (like water)
% fsca_thresh: min fsca cutoff, scalar e.g. 0.15
% outloc: path to read output generated by fill_and_run_modis.m
% grainradius_nPersist: min # of consecutive days needed with normal 
% grain sizes to be kept as snow, e.g. 7
% el_cutoff, min elevation for snow, m - scalar, e.g. 1000
% cc - static canopy cover, single or double, same size as watermask,
% 0-1 for viewable gap fraction correction
% fice - ice fraction, single or double 0-1
% endconditions - string, end condition for splines for dust and grain size, 
% e.g. 'estimate' or 'periodic', see slmset.m

%output:
%   h5 cubes written out w/ variables
%   fsca: MxNxd
%   grainradius: MxNxd
%   dust: MxNxd


t1=tic;

%filter and smooth
out=smoothSPIREScube(tile,outloc,matdates,...
    grainradius_nPersist,watermask,topofile,el_cutoff,fsca_thresh,cc,fice,...
    endcondition);

%write out h5 cubes
fname=fullfile(outloc,[tile datestr(matdates(end),'yyyy') '.h5']);
if exist(fname,'file')
    delete(fname); 
end
fn={'fsca','grainradius','dust'};
fntarget={'snow_fraction','grain_size','dust'};
dtype={'uint8','uint16','uint16'};
divisors=[100 1 10];

for i=1:length(fn)   
    member=fntarget{i};
    Value=out.(fn{i});
    dS.(member).divisor=divisors(i);
    dS.(member).dataType=dtype{i};
    dS.(member).maxVal=max(Value(:));
    dS.(member).FillValue=intmax(dS.(member).dataType);
    writeh5stcubes(fname,dS,out.hdr,out.matdates,member,Value);
end
t2=toc(t1);
fprintf('completed in %5.2f hr\n',t2/60/60);