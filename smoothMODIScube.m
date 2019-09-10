function [smoothedCube,refl,solarZ,cloudmask,snowmask]=...
    smoothMODIScube(tile,matdates,hdfdir,topofile,snowR,fsca_nPersist)
%create time/space smoothed and gap filled (cloud-free) MOD09GA surface
%reflectance

%input:
%tile - tilename, e.g. 'h08v05'
%matdates - matdates for cube
%hdfdir - where the MOD09GA HDF files live for a certain tile, e.g. h08v04
%topofile- h5 file name from consolidateTopography, part of TopoHorizons
%snowR - snow reflectane structure created using prepCloudSnowFilter
% fsca_nPersist: min consectutive days snow must persist for, scalar e.g. 4

%output:
%smoothedCube: smoothed and gap filled (cloud free) cube of MOD09GA values
%refl: terrain-corrected MOD09GA w/ NaNs for clouds and other missing data
%solarZ: solar zenith angles for cube

%set value for too many cloudy days filter
%toomanycloudydays=7;

%get full directory listing for tile
d=dir(fullfile(hdfdir,['*.' tile '.*.hdf']));
d=struct2cell(d);
d=d(1,:);

[ RefMatrix,ProjectionStructure,RasterReference] = sinusoidProjMODtile(tile);

nbands=7;
sz=[RasterReference.RasterReference_500m.RasterSize nbands length(matdates)];
refl=NaN(sz);
solarZ=NaN([sz(1) sz(2) sz(4)]);
snowmask=false([sz(1) sz(2) sz(4)]);
cloudmask=false([sz(1) sz(2) sz(4)]);
bandweights=zeros(sz);

parfor i=1:length(matdates)
    isodate=datenum2iso(matdates(i),7);
    m=regexp(d,['^MOD09GA.A' num2str(isodate) '\.*'],'once');
    m=~cellfun(@isempty,m);
    if any(m)   
        f=fullfile(hdfdir,d{m});
        %get 7 band reflectance
        R=GetMOD09GA(f,'allbands'); 
        [~,~,bWeights] = weightMOD09(f,topofile);
        bandweights(:,:,:,i)=bWeights{1};
        
        x=single(GetMOD09GA(f,'SolarZenith'));
        if any(isnan(x(:)))
            x = inpaint_nans(double(x),4);
        end
        solarZ(:,:,i)=rasterReprojection(x,RefMatrix.RefMatrix_1km,...
            ProjectionStructure,ProjectionStructure,'rasterref',...
            RasterReference.RasterReference_500m);
        x=single(GetMOD09GA(f,'SolarAzimuth'));
        if any(isnan(x(:)))
            x = inpaint_nans(double(x),4);
        end
        solarAzimuth=rasterReprojection(x,RefMatrix.RefMatrix_1km,...
            ProjectionStructure,ProjectionStructure,'rasterref',...
            RasterReference.RasterReference_500m);

        %correct reflectance
        Rc=normalizeReflectance(R,topofile,solarZ(:,:,i),solarAzimuth);
        %fix negative values
        Rc(Rc<0.001)=0.001;
        %create cloud & snow masks
        [likelySnow, maybeSnow, likelyCloud, maybeCloud] =...
        filterCloudSnow(snowR, Rc, solarZ(:,:,i));
        cm=likelyCloud | maybeCloud;
        cloudmask(:,:,i)=cm;
        sm=likelySnow | maybeSnow;
        snowmask(:,:,i)=sm;
        refl(:,:,:,i)=Rc;
        fprintf('loaded, corrected, and created masks for tile:%s date:%i \n',...
            tile,isodate);
    end
end

%trim cloud mask
%cloudmask=cloudPersistenceFilter(cloudmask,toomanycloudydays);

%mark as cloud not snow if it doesnt persist long enough
% trim snowmask using filter (since it can only trim)
snowmask_trim=snowPersistenceFilter(snowmask,fsca_nPersist,1);
% add false positives for snow to cloudmask (snow didn't persist long
% enough)
cloudmask=cloudmask | (~snowmask & snowmask_trim);

snowmask=snowmask_trim;

smoothedCube=NaN(size(refl));

for i=1:size(refl,3) % for each band
    tic;
    bandcube=squeeze(refl(:,:,i,:));
    bandcube(cloudmask)=NaN; %set all the clouds to NaN
    %ski infillDataCube since using smoothn will fill
    %bandcube=infillDataCube(bandcube);
    weights=squeeze(bandweights(:,:,i,:));
    weights(isnan(bandcube))=0;
    smoothedCube(:,:,i,:)=smoothDataCube(bandcube,weights);
    t2=toc;
    fprintf('filled and smoothed band:%i in %g min\n',i,t2/60);
end