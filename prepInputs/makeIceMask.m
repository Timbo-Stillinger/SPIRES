function fice=makeIceMask(S,hdr,glims_res)
% make a fractional image of glacier ice
%input: S - output from shapread of GLIMS polygons w/ M and Z data removed
% hdr - hdr geo info for target
% glims_res - multiple of pixel size for rasterizing glims, e.g. 5
gmask=false(hdr.RasterReference.RasterSize);
%create a higher res mask with 5% larger extent to deal with edge problems


pixelsize=[hdr.RasterReference.CellExtentInWorldX/glims_res, ...
    hdr.RasterReference.CellExtentInWorldY/glims_res];

%extend image 5 pixels to deal w/ edges when reprojected
Xlimit=[hdr.RasterReference.XWorldLimits(1)-hdr.RasterReference.CellExtentInWorldX*5 ...
        hdr.RasterReference.XWorldLimits(2)+hdr.RasterReference.CellExtentInWorldX*5];
Ylimit=[hdr.RasterReference.YWorldLimits(1)-hdr.RasterReference.CellExtentInWorldY*5 ...
        hdr.RasterReference.YWorldLimits(2)+hdr.RasterReference.CellExtentInWorldY*5];


[gmaskBig,RefMatrixB,RasterReferenceB]=rasterReprojection(gmask,hdr.RefMatrix,...
    hdr.ProjectionStructure,hdr.ProjectionStructure,'method','nearest','PixelSize',...
    pixelsize,'XLimit',Xlimit,'YLimit',Ylimit);


X=RasterReferenceB.XWorldLimits;
Y=RasterReferenceB.YWorldLimits;
bbox=[X(1) Y(1); X(2) Y(1);X(2) Y(2);X(1) Y(2)];
[lat,lon]=minvtran(hdr.ProjectionStructure,...
    bbox(:,1),bbox(:,2));
XV=[min(lon); max(lon)];
YV=[min(lat); max(lat)];
for i=1:length(S)
    xx=S(i).X;
    yy=S(i).Y;
%     t=isnan(xx) | isnan(yy);
%     xx=xx(~t);
%     yy=yy(~t);
    in=inpolygon(xx,yy,XV,YV);
    if any(in(:))
        [x,y]=mfwdtran(hdr.ProjectionStructure,yy,xx);
        [r,c]=map2pix(RefMatrixB,x,y);
        %build mask for each NaN separated polygon
        t=find(isnan(xx) | isnan(yy));
        for j=1:length(t)
            if j==1
               ind=1:(t(j)-1); 
            else
               ind=(t(j-1)+1):(t(j)-1);
            end
            mask=poly2mask(c(ind),r(ind),...
                size(gmaskBig,1),size(gmaskBig,2));
            gmaskBig(mask)=true;
        end
    end
end

fice=rasterReprojection(single(gmaskBig),RefMatrixB,...
    hdr.ProjectionStructure,hdr.ProjectionStructure,...
    'rasterref',hdr.RasterReference);
fice(fice<0.01)=0;