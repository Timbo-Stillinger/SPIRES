function [out,fname,vars,divisor,dtype]=fill_and_run_modis(tiles,r0dates,matdates,...
    hdfbasedir,topofile,mask,Ffile,shade,grain_thresh,dust_thresh,tolval,outloc,nameprefix)

% fills input (mod09ga) and runs spires
%input:
% tiles - - tilenames,  cell vector, e.g. {'h08v05','h08v04','h09v04'};
% if tile is a cell vector, assumption is made to mosaic multiple tiles
% together then crop/reproject to topofile. watermask, R0,& dustmask will
% all be assumed to match topofile hdr for spatial info
% r0dates - mat dates for background each tile image, e.g.
% datenum([2015 9 25; 2015 9 25; 2015 9 25]);
% matdates - matdates for cube
% hdfbasedir - where the MOD09GA HDF files live
% must have sub directories that correspond to entries in tile, e.g. h08v04
% topofile- h5 file name from consolidateTopography, part of TopoHorizons
% mask- logical mask w/ ones for pixels to exclude (like water)
% Ffile- location of griddedInterpolant object that produces
% reflectances for each band
% with inputs: grain radius, dust, cosZ, i.e. the look up table, band
% shade -, scalar or vector, length of # bands
% grain_thresh - min fsca value for grain size retrievals , e.g. 0.50
% dust_thresh - min fsca value for dust retrievals, e.g. 0.95
% tolval - threshold for uniquetol spectra, higher runs faster, 0 runs all
% pixels - scalar e.g. 0.05
% outloc - path to write output
% nameprefix - name prefix for outputs, e.g. Sierra
%output:
%   out:
%   fsca: MxNxd
%   grainradius: MxNxd
%   dust: MxNxd
%also writes 1 month .mat files with those outputs
%fname - output filename
% vars - cell, variable list
% divisor - divisors for variables
% dtype - datatype for each variable

red_b=3;
swir_b=6;
%intermediate variables
vars={'fsca','fshade','grainradius','dust','weights','sensorZ'};
divisor=[100 100 1 10 100 1];
dtype={'uint8','uint8','uint16','uint16','uint8','uint8'};

t1=tic;
%run in one month chunks and save output
dv=datevec(matdates);
m=unique(dv(:,2),'stable');
[~,hdr]=GetTopography(topofile,'elevation');

for i=1:length(m)
    idx=dv(:,2)==m(i);
    rundates=matdates(idx);
    fname=fullfile(outloc,[nameprefix datestr(rundates(1),'yyyymm') '.mat']);
    if exist(fname,'file')==0 %don't overwrite existing files
        
        [R,R0,~,solarZ,sensorZ,~,weights,~]=...
            fillMODIScube(tiles,r0dates,rundates,hdfbasedir,swir_b,hdr);
        out=run_spires(R0,R,solarZ,Ffile,mask,shade,...
            grain_thresh,dust_thresh,tolval,hdr,red_b,swir_b,[]);
        out.weights=weights; %put weights into output struct
        out.sensorZ=sensorZ; %put sensor zenith into output struct
        
        mfile=matfile(fname,'Writable',true);
        
        for j=1:length(vars)
            t=isnan(out.(vars{j}));
            if j==3 || j==4  %grain size or dust
                t=t | out.fsca==0 ;
            end
            out.(vars{j})=cast(out.(vars{j})*divisor(j),dtype{j});
            out.(vars{j})(t)=intmax(dtype{j});
            mfile.(vars{j})=out.(vars{j});
        end
        
        mfile.matdates=rundates;
        fprintf('wrote %s \n',fname);
    else
        fprintf('%s already exists, skipping \n',fname);
    end
end
t2=toc(t1);
fprintf('completed in %5.2f hr\n',t2/60/60);