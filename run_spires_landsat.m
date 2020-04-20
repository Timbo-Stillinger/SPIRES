function out=run_spires_landsat(r0dir,rdir,demfile,Ffile,tolval,...
    fsca_thresh,dust_thresh,pshade,CCfile,WaterMaskfile,CloudMaskfile,...
    fIcefile,el_cutoff,subset)
%run spires  for a landsat scene
% r0date - date for background scene in yyyymmdd, e.g. 20180923
% r0dir - R0 directory, must contain geotiff surface reflectances from USGS
% rdate - date for snow scene in yyyymmdd, e.g. 20190131
% rdir - R directory
% demfile - matfile containing dem in m in same projection as R&R0
% must contain: Z, elevation in m;
% then hdr struct with fields: RefMatrix, RasterReference, and
% ProjectionStructure
% Ffile - mat file containing F griddedInterpolant R=F(grain radius (um),...
% dust (ppmw),solarZenith (degrees),bands (scalar))
% tolval - uniquetol tolerance, e.g. 0.05 for separating unique spectra
% fsca_thresh - minumum fsca value for snow detection, values below are set to
% zero, e.g. 0.15, scalar
% dust_thresh - minumum fsca value for dust detection, pixels below are
% interpolated, e.g. 0.99, scalar
% pshade - physical shade endmember, vector, bandsx1
% watermask
% CCfile - location of .mat
% canopy cover - canopy cover for pixels 0-1, size of scene
% WaterMaskfile - water mask file location, contains watermask, logical
% 0 is no water, 1 is water
% CloudMaskfile - cloud mask file location, contains cloudmask, logical,
% 0 is no cloud, 1 is cloud
% fIcefile, fice file location, ice fraction 0-1, single, size of cloudmask
% also need RefMatrix and ProjectionStructure
% el_cutoff - elevation cutoff, m
% subset - either empty for none or [row1 row2;col1 col2], where are
% row1/col1 are the starting pixels and row2/col2 are the end pixels,
% e.g. for MMSA on p42r34, % [3280 3460;3740 3920]
%note subset is based of DEM, as L8 has different sized scenes for
%different dates and everything is reprojected to match the dem
%takes a while if not subsetting, e.g. p42r34 


%output
% o struct with fields:
% fsca,0-1, canopy cover adj
% grainradius, um
% dust,0-1
% shade,0-1
% all the size of the first two dimension of R or R0

red_b=3;
swir_b=6;

t1=tic;

[solarZ,phi0]=getOLIsolar(rdir);

dem=load(demfile);

if ~isempty(subset)
%if crop w/o reprojection
    rl=subset(1,1):subset(1,2);
    cl=subset(2,1):subset(2,2);
    [x,y]=pixcenters(dem.hdr.RefMatrix,dem.hdr.RasterReference.RasterSize,...
        'makegrid');
    x=x(rl,cl);
    y=y(rl,cl);
    dem.hdr.RefMatrix=makerefmat(x(1,1),y(1,1),x(1,2)-x(1,1),y(2,1)-y(1,1));
    dem.hdr.RasterReference=refmatToMapRasterReference(dem.hdr.RefMatrix,...
        size(x));
    dem.Z=dem.Z(rl,cl);
end
    [Slope,Aspect] = SlopeAzmProjected(dem.hdr.RefMatrix, ...
    dem.hdr.ProjectionStructure, dem.Z);
    [x,y]=pixcenters(dem.hdr.RefMatrix,size(Slope),'makegrid');
    [lat,lon]=minvtran(dem.hdr.ProjectionStructure,x,y);
    sinF=Horizons2Directions('earth',180-phi0,lat,lon,dem.Z);
    h=asind(sinF);
    mu=sunslope(cosd(solarZ),180-phi0,Slope,Aspect);

    %in sun if solarZ > 10 deg, shaded if solarZ <= 10 deg
    smask= (90-acosd(mu))-h > 10;

smask=~imfill(~smask,8,'holes'); %fill in errant holes

%get R0 refl and reproject to hdr
R0=getOLIsr(r0dir,dem.hdr);

nanmask=all(isnan(R0.bands),3);

%get sun data
[solarZR0,phi0R0]=getOLIsolar(r0dir);

%snow-covered scene and reproject to hdr
R=getOLIsr(rdir,dem.hdr);

%load adjustment files
% adjust_files={'CloudMaskfile','fIcefile','CCfile'};
adjust_vars={'cloudmask','fice','cc','watermask'};

for i=1:length(adjust_vars)
if i==1
    in=load(CloudMaskfile);  
elseif i==2
    in=load(fIcefile);
elseif i==3
    in=load(CCfile);
elseif i==4
    in=load(WaterMaskfile);
end
A.(adjust_vars{i})=rasterReprojection(double(in.(adjust_vars{i})),...
    in.hdr.RefMatrix,in.hdr.ProjectionStructure,...
    dem.hdr.ProjectionStructure,'rasterref',...
    dem.hdr.RasterReference);
t=isnan(A.(adjust_vars{i}));
A.(adjust_vars{i})(t)=0;
end

%normalizeReflectance
t=normalizeReflectance(R.bands,Slope,Aspect,solarZ,phi0);
t0=normalizeReflectance(R0.bands,Slope,Aspect,solarZR0,phi0R0);


o=run_spires(t0,t,acosd(mu),Ffile,~smask | nanmask | A.cloudmask | ...
    A.watermask,fsca_thresh,pshade,dust_thresh,tolval,A.cc,dem.hdr,red_b,...
    swir_b);

% spatial interpolation
ifsca=single(o.fsca);

ifsca=ifsca./(1-A.cc);
ifsca=ifsca./(1-A.fice);
ifsca(ifsca>1)=1;
ifsca(ifsca<fsca_thresh)=0;

%elevation cutoff
el_mask=dem.Z<el_cutoff;
ifsca(el_mask)=0;

% set pixels outside boundary, in cloudy mask, or in shade
ifsca(nanmask | A.cloudmask | ~smask)=NaN;

igrainradius=single(o.grainradius);
igrainradius(isnan(ifsca) | ifsca==0)=NaN;

idust=single(o.dust);
idust(isnan(ifsca) | ifsca==0)=NaN;

out.fsca=ifsca;
out.grainradius=igrainradius;
out.dust=idust;
out.shade=o.shade;
out.hdr=dem.hdr;

et=toc(t1);
fprintf('total elapsed time %4.2f min\n',et/60);
end