function [filledCube,R0,refl,SolarZenith,SensorZenith,cloudmask,pxweights,...
    bweights]=fillMODIScube(tiles,r0dates,matdates,hdfbasedir,swir_b,hdr)
%create gap filled (e.g. cloud-free) MOD09GA surface
%reflectance

%input:
%tiles - tilenames,  cell vector, e.g. {'h08v05','h08v04','h09v04'};
%r0dates - matesdates for background each tile image, dates by row, tiles by column
%   e.g. datenum([2015 9 25, 2015 9 25, 2015 9 25]); - same date all tiles
%   e.g. repmat(datenum([2016 8 11; 2016 8 12; 2016 8 13; 2016 9 11 ],[1,3]); - same 4 dates for 3 tiles
%matdates - matdates to process
%hdfbasedir - where the MOD09GA HDF files live must have sub directories
% that correspond to entries in tile, e.g. 'h08v04'
%topofile - h5 target topo file name. This topography file contains the target
%geographic information that everything will be tiled and
%cropped/reprojected to
%swir_b - swir band, scalar
%hdr - geog hdr struct
%output:
%filledCube: gap filled (cloud free) cube of MOD09GA values
%R0: background MOD09GA from r0dates
%refl: terrain-corrected MOD09GA w/ NaNs for clouds and other missing data
%SolarZenith: solar zenith angles for cube
%SensorZenith: sensor zenith angles for cube
%cloudmask: cloudmask cube, logical
%pxweights: weight cube for each pixel (all bands together), 0-1
%bweights: band weights, 0-1 with all operator

nbands=7;
% mask as cloud if swir band (6) is > than
swir_cloud_thresh=0.2;

if ~iscell(tiles)
    tiles={tiles};
end

% get all raster info
R=zeros([length(tiles),3,2]);
lr=zeros(length(tiles),2);
tsiz=zeros(length(tiles),2);

for i=1:length(tiles)
    [r,mstruct,rr] = sinusoidProjMODtile(tiles{i});
    R(i,:,:)=r.RefMatrix_500m;
    lr(i,:)=[rr.RasterReference_500m.RasterSize 1]*r.RefMatrix_500m;
    tsiz(i,:)=rr.RasterReference_500m.RasterSize;
end

%create refmat for mosaic
BigR=zeros(3,2);
BigR(3,1)=min(R(:,3,1));
BigR(2,1)=R(1,2,1); %assume same spacing for all pixels
BigR(1,2)=R(1,1,2);
BigR(3,2)=max(R(:,3,2));

%compute size of mosaic
%xy coords for lower rt corner
xy=[max(lr(:,1)) min(lr(:,2))];
sBig=map2pix(BigR,xy);
sBig=round(sBig);

sz=[sBig nbands];

%allocate 3 & 4D cubes with measurements for all days
sz0=[hdr.RasterReference.RasterSize nbands length(matdates)];
refl=zeros(sz0);
SolarZenith=zeros([sz0(1) sz0(2) sz0(4)]);
SensorZenith=zeros([sz0(1) sz0(2) sz0(4)]);
cloudmask=false([sz0(1) sz0(2) sz0(4)]);
pxweights=zeros([sz0(1) sz0(2) sz0(4)]);
bweights=zeros([sz0(1) sz0(2) sz0(4)]);

%create R0 based on r0dates
R0=zeros([sz0(1) sz0(2) sz0(3)]);
R0SZ=zeros([sz(1) sz(2)]);
R0SA=zeros([sz(1) sz(2)]);

%[num dates, num tiles]
nR0=size(r0dates);
for j=1:length(tiles)
    tile=tiles{j};
    mergeR0w=[];
    mergeR0bw=[];
    mergeR0SR=[]; %by band then date
    mergeR0ZA=[];
    mergeR0AZ=[];
    
    for i=1:nR0(1)
        d=dir(fullfile(hdfbasedir,tile,['*.' tile '.*.hdf']));
        d=struct2cell(d);
        d=d(1,:);
        assert(~isempty(d),'%s empty\n',hdfbasedir);
        isodate=datenum2iso(r0dates(i,j),7);
        m=regexp(d,['^MOD09GA.A' num2str(isodate) '\.*'],'once');
        m=~cellfun(@isempty,m);
        assert(~isempty(m),'%s %s does not exist\n',tile,isodate);
        f=fullfile(hdfbasedir,tile,d{m});
        
        [ ~,weights,bandWeights ] = weightMOD09(f);
        bW=all(bandWeights{1}==1,3);
        mergeR0bw(:,:,i)=bW;
        %if any band weight is 0, overallweight is 0
        weights(~bW)=0;
        mergeR0w(:,:,i)=weights;
        
        
        %get all band reflectance
        sr=GetMOD09GA(f,'allbands');
        mergeR0SR(:,:,:,i)=sr;
        
        sZA=single(GetMOD09GA(f,'SolarZenith'));
        if any(isnan(sZA(:)))
            sZA = inpaint_nans(double(x),4);
        end
        mergeR0ZA(:,:,i)=sZA;
        
        sAZ=single(GetMOD09GA(f,'SolarAzimuth'));
        if any(isnan(sAZ(:)))
            sAZ = inpaint_nans(double(sAZ),4);
        end
        mergeR0AZ(:,:,i)=sAZ;
        
    end
    
    [~,idxL]=max(mergeR0w,[],3,'linear');
    
    %just take the best wieghted ob for each pixel
    tmpSR=[];
    for jj=1:nbands
        x=squeeze(mergeR0SR(:,:,jj,:));
        tmpSR(:,:,jj)=x(idxL);
    end
    
    [x,y]=pixcenters(squeeze(R(j,:,:)),tsiz(j,:));
    [r,c]=map2pix(BigR,x,y);
    r=round(r);
    c=round(c);
    R0(r,c,:)=tmpSR;
    %scale 1km SZ and AZ to 500m measurements
    x=mergeR0ZA;
    x=imresize(x,tsiz(j,:));
    R0SZ(r,c)=x(idxL);
    x=mergeR0AZ;
    x=imresize(x,tsiz(j,:));
    R0SA(r,c)=x(idxL);
end


R0=rasterReprojection(R0,BigR,mstruct,hdr.ProjectionStructure,...
    'rasterref',hdr.RasterReference);
R0(isnan(R0))=0;

parfor i=1:length(matdates)
    isodate=datenum2iso(matdates(i),7);
    %allocate daily cubes
    refl_=NaN(sz);
    SolarZenith_=NaN([sz(1) sz(2)]);
    SensorZenith_=NaN([sz(1) sz(2)]);
    SolarAzimuth_=NaN([sz(1) sz(2)]);
    cloudmask_=false([sz(1) sz(2)]);
    pxweights_=zeros([sz(1) sz(2)]);
    bweights_=zeros([sz(1) sz(2)]);
    %load up each tile
    for k=1:length(tiles)
        tile=tiles{k};
        %get full directory listing for tile
        d=dir(fullfile(hdfbasedir,tile,['*.' tile '.*.hdf']));
        d=struct2cell(d);
        d=d(1,:);
        assert(~isempty(d),'%s empty\n',hdfbasedir);
        m=regexp(d,['^MOD09GA.A' num2str(isodate) '\.*'],'once');
        m=~cellfun(@isempty,m);
        
        if any(m)
            [x,y]=pixcenters(squeeze(R(k,:,:)),tsiz(k,:));
            [r,c]=map2pix(BigR,x,y);
            r=round(r);
            c=round(c);
            f=fullfile(hdfbasedir,tile,d{m});
            [~,pxWeights,bWeights] = weightMOD09(f);
            bWeights=bWeights{1};
            bWeights=sum(bWeights,3);
            bweights_(r,c)= bWeights;
            pxweights_(r,c)= pxWeights;
            
            x=single(GetMOD09GA(f,'SolarZenith'));
            if any(isnan(x(:)))
                x = inpaint_nans(double(x),4);
            end
            x=imresize(x,tsiz(k,:));
            SolarZenith_(r,c)=imresize(x,tsiz(k,:));
            
            
            x=single(GetMOD09GA(f,'SolarAzimuth'));
            if any(isnan(x(:)))
                x = inpaint_nans(double(x),4);
            end
            x=imresize(x,tsiz(k,:));
            SolarAzimuth_(r,c)=imresize(x,tsiz(k,:));
            
            % sensor zenith, and pixel sizes
            x = single(GetMOD09GA(f,'sensorzenith'));
            if any(isnan(x(:)))
                x = inpaint_nans(double(x),4);
            end
            SensorZenith_(r,c) = imresize(x,tsiz(k,:));
            
            %get all band reflectance
            sr=GetMOD09GA(f,'allbands');
            sr(isnan(sr))=0;
            
            %create cloud mask
            S=GetMOD09GA(f,'state');
            mod09gacm=imresize(S.cloud==1,tsiz(k,:));
            swir=sr(:,:,swir_b);
            cm = mod09gacm & swir > swir_cloud_thresh;
            
            sr(cm)=NaN; % mask clouds
            
            refl_(r,c,:)=sr;
            cloudmask_(r,c)=cm;
            
            fprintf('loaded, corrected, and created masks for tile:%s date:%i \n',...
                tile,isodate);
        else
            fprintf('MOD09GA for %s %i not found,skipped\n',tile,isodate);
        end
    end
    
    refl_=rasterReprojection(refl_,BigR,mstruct,...
        hdr.ProjectionStructure,'rasterref',hdr.RasterReference);
    cloudmask_=rasterReprojection(cloudmask_,BigR,mstruct,...
        hdr.ProjectionStructure,'rasterref',hdr.RasterReference,...
        'Method','nearest');
    SolarZenith_=rasterReprojection(SolarZenith_,BigR,mstruct,...
        hdr.ProjectionStructure,'rasterref',hdr.RasterReference);
    SensorZenith_=rasterReprojection(SensorZenith_,BigR,mstruct,...
        hdr.ProjectionStructure,'rasterref',hdr.RasterReference);
    pxweights_=rasterReprojection(pxweights_,BigR,mstruct,...
        hdr.ProjectionStructure,'rasterref',hdr.RasterReference);
    bweights_=rasterReprojection(bweights_,BigR,mstruct,...
        hdr.ProjectionStructure,'rasterref',hdr.RasterReference);
    
    refl(:,:,:,i)=refl_;
    SolarZenith(:,:,i)=SolarZenith_;
    SensorZenith(:,:,i)=SensorZenith_;
    cloudmask(:,:,i)=cloudmask_;
    pxweights(:,:,i)=pxweights_;
    bweights(:,:,i)=bweights_;
end

filledCube=refl;
end