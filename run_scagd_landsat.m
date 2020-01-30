function out=run_scagd_landsat(r0dir,rdir,topofile,...
    Ffile,tolval,fsca_thresh,dust_thresh,pshade,CCfile,...
    plotbool,subset)
%run scagd over for a landsat scene
% r0date - date for background scene in yyyymmdd, e.g. 20180923
% r0dir - R0 directory, must contain geotiff surface reflectances from USGS
% rdate - date for snow scene in yyyymmdd, e.g. 20190131
% rdir - R directory
% topofile - h5 file containing scene topgraphy, outut of
% consolidate_topograpy
% Ffile - mat file containing F griddedInterpolant R=F(grain radius (um),...
% dust (ppmw),solarZenith (degrees),bands (scalar))
% tolval - uniquetol tolerance, e.g. 0.05 for separating unique spectra
% fsca_thresh - minumum fsca value for snow detection, values below are set to
% zero, e.g. 0.15, scalar
% dust_thresh - minumum fsca value for dust detection, pixels below are
% interpolated, e.g. 0.99, scalar
% pshade - physical shade endmember, vector, bandsx1
% CCfile - location of .mat
% canopy cover - canopy cover for pixels 0-1, size of scene
% also need RefMatrix and ProjectionStructure
% plootbool - logical - plot results?
% subset - either empty for none or [row1 row2;col1 col2], where are
% row1/col1 are the starting pixels and row2/col2 are the end pixels,
% e.g. for MMSA on p42r34, % [3280 3460;3740 3920]

%output
% o struct with fields:
% fsca,0-1, canopy cover adj
% grainradius, um
% dust,0-1
% shade,0-1
% all the size of the first two dimension of R or R0

%do terrain first
%need to account for shaded pixels

%get sun data, R

t1=tic;

[solarZ,phi0]=getOLIsolar(rdir);

[Slope,hdr]=GetTopography(topofile,'slope');
Aspect=GetTopography(topofile,'aspect');

mu=sunslope(cosd(solarZ),180-phi0,Slope,Aspect);
smask=GetHorizon(topofile,180-phi0,acosd(mu));

%if crop w/o reprojection
if ~isempty(subset)
    rl=subset(1,1):subset(1,2);
    cl=subset(2,1):subset(2,2);
    [x,y]=pixcenters(hdr.RefMatrix,hdr.RasterReference.RasterSize,'makegrid');
    x=x(rl,cl);
    y=y(rl,cl);
    hdr.RefMatrix=makerefmat(x(1,1),y(1,1),x(1,2)-x(1,1),y(2,1)-y(1,1));
    hdr.RasterReference=refmatToMapRasterReference(hdr.RefMatrix,size(x));
    mu=mu(rl,cl);
    smask=smask(rl,cl);
    Slope=Slope(rl,cl);
    Aspect=Aspect(rl,cl);
end

smask=~imfill(~smask,8,'holes'); %fill in errant holes

%reproject both to match R
% mu=rasterReprojection(mu,hdr.RefMatrix,hdr.ProjectionStructure,...
%     R0.ProjectionStructure,'rasterref',R0.RasterReference);
% smask=rasterReprojection(smask,hdr.RefMatrix,hdr.ProjectionStructure,...
%     R0.ProjectionStructure,'Method','nearest','rasterref',...
%     R0.RasterReference);

%get R0 refl and reproject to hdr
R0=getOLIsr(r0dir,hdr);

nanmask=all(isnan(R0.bands),3);

%get sun data
[solarZR0,phi0R0]=getOLIsolar(r0dir);

%snow-covered scene and reproject to hdr
R=getOLIsr(rdir,hdr);

% load and reproject canopy data to hdr
CC=load(CCfile);
cc=rasterReprojection(CC.cc,CC.RefMatrix,CC.ProjectionStructure,...
    hdr.ProjectionStructure,'rasterref',hdr.RasterReference);
cc(isnan(cc))=0;

t=normalizeReflectance(R.bands,Slope,Aspect,solarZ,phi0);
t0=normalizeReflectance(R0.bands,Slope,Aspect,solarZR0,phi0R0);

o=run_scagd_modis(t0,t,acosd(mu),Ffile,~smask | nanmask,...
    fsca_thresh,pshade,dust_thresh,tolval);

% spatial interpolation
ifsca=o.fsca;
ifsca(nanmask)=0;
ifsca(~smask & ~nanmask)=NaN;
ifsca=inpaint_nans(ifsca,4);
ifsca=ifsca./(1-cc);
ifsca(ifsca>1)=1;
ifsca(ifsca<fsca_thresh)=0;
ifsca(nanmask)=NaN;

igrainradius=o.grainradius;
igrainradius(nanmask)=0;
igrainradius(~smask & ~nanmask)=NaN;
igrainradius(igrainradius>1000)=NaN;
igrainradius=inpaint_nans(igrainradius,4);
igrainradius(ifsca==0)=NaN;
igrainradius(nanmask)=NaN;

idust=o.dust;
idust(nanmask)=0;
idust(~smask & ~nanmask)=NaN;
idust=inpaint_nans(idust,4);
idust(ifsca==0)=NaN;
idust(nanmask)=NaN;

out.fsca=ifscag;
out.grainradius=igrainradius;
out.dust=idust;

et=toc(t1);
sprintf('total elapsed time %4.2f min\n',et/60);

if plotbool
    % plot up results
    f1=figure('Position',[0 0 1500 800],'Color',[0.6 0.6 0.6]);
    ha=tight_subplot(2, 3, 0.01, 0.02, [0 0.03]);
    
    for j=1:6
        axes(ha(j));
        ax=gca;
        
        if j==1
            xx=squeeze(R.bands(:,:,[3 2 1]));
        elseif j==2
            xx=ifsca;
        elseif j==3
            xx=igrainradius;
        elseif j==4
            xx=idust;
        elseif j==5
            xx=o.shade;
        elseif j==6
            xx=cc;
        end
        
        if j==1
            image(xx);
        else
            imagesc(xx);
        end
        axis image;
        
        ax.XAxis.Color = 'none';
        ax.YAxis.Color = 'none';
        set(ax,'XTick',[],'YTick',[],'YDir','reverse',...
            'Color',[0.6 0.6 0.6]);
        freezeColors('nancolor',[0.6 0.6 0.6]);
        
        if j>1
            c=colorbar('Location','EastOutside','Color','w');
            c.Label.Color=[1 1 1];
            c.FontSize=15;
            if j==2
                c.Label.String='fsca, canopy adj. ';
            elseif j==3
                c.Label.String='grain radius, \mum';
            elseif j==4
                c.Label.String='dust conc, ppmw';
            elseif j==5
                c.Label.String='fshade';
            elseif j==6
                c.Label.String='fcanopy, static';
            end
        end 
    end
end