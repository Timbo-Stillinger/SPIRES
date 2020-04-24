function out=run_spires(R0,R,solarZ,Ffile,watermask,fsca_thresh,...
    pshade,dustmask,tolval,hdr,red_b,swir_b)
% run LUT version of scagd for 4-D matrix R
% produces cube of: fsca, grain size (um), and dust concentration (by mass)
% input:
% R0 - background image (MxNxb). Recommend a sinle day with no clouds, 
%no snow and and low sensor zenith angle
% R - 4D cube of time-space smoothed reflectances (MxNxbxd) with
% dimensions: x,y,band,day
% solarZ: solar zenith angles (MxNxd) for R
% Ffile, location of griddedInterpolant object that produces reflectances
%for each band
% with inputs: grain radius (um), dust (ppmw), solar zenith angle (deg),
% band # (not necessarily in order of wavelength)
% watermask: logical mask (MxN), true for water
% fsca_thresh: min fsca cutoff, scalar e.g. 0.15
% pshade: shade spectra (bx1) or photometric scalar, e.g. 0
% dustmask: make where dust values can be retrieved, 0-1
% tolval: unique row tolerance value, i.e. 0.05 - bigger number goes faster
% as more pixels are grouped together
% hdr - header struct w/ map info, see GetCoordinateInfo.m
% red_b - red band, e.g. 3 for MODIS and L8
% swir_b - SWIR band, e.g. 6 for MODIS and L8

%output:
%   out : struct w fields
%   fsca: MxNxd
%   grainradius: MxNxd
%   dust: MxNxd

sz=size(R);

if length(sz) == 3
   sz(4)=1; % singleton 4th dimenson
end

[X,Y]=pixcenters(hdr.RefMatrix,size(watermask),'makegrid');

fsca=zeros([sz(1)*sz(2) sz(4)]);
grainradius=NaN([sz(1)*sz(2) sz(4)]);
dust=NaN([sz(1)*sz(2) sz(4)]);

solarZ=reshape(double(solarZ),[sz(1)*sz(2) sz(4)]);
R=reshape(double(R),[sz(1)*sz(2) sz(3) sz(4)]);
R0=reshape(double(R0),[sz(1)*sz(2) sz(3)]);
watermask=reshape(watermask,[sz(1)*sz(2) 1]);
fshade=zeros(size(fsca));
X=reshape(X,[sz(1)*sz(2) 1]);
Y=reshape(Y,[sz(1)*sz(2) 1]);
dm=reshape(dustmask,[sz(1)*sz(2) 1]);

for i=1:sz(4) %for each day
    thisR=squeeze(R(:,:,i));
    thissolarZ=squeeze(solarZ(:,i));
    
    NDSI=(thisR(:,red_b)-thisR(:,swir_b))./...
        (thisR(:,red_b)+thisR(:,swir_b));
    t=NDSI > 0  & ~watermask & ~isnan(thissolarZ);
    M=[round(thisR,2) round(R0,2) round(thissolarZ) dm];
    
    %keep track of indices
    Rind=1:sz(3);
    R0ind=(Rind(end)+1):(Rind(end)+sz(3));
    sZind=R0ind(end)+1;
    dmind=sZind(end)+1;
    
    M=M(t,:); % only values w/ > 0 NDSI and no water
    XM=X(t); % X coordinates for M
    YM=Y(t); % Y coordinates for M
    [c,im,~]=uniquetol(M,tolval,'ByRows',true,'DataScale',1,...
        'OutputAllIndices',true);
    im1=zeros(size(im));
    for k=1:length(im)
       im1(k)=im{k}(1); 
    end
        
    XC=XM(im1); %X coordinates for c
    YC=YM(im1); %Y coordinates for c
    t1=tic;
    
    %first pass, solve for dust/grain sizes
    temp=NaN(size(c,1),4); %fsca,shade,grain radius,dust
    
   
    parfor j=1:size(c,1) %solve for unique (w/ tol) rows
        thisdm=c(j,dmind);
        if thisdm %only solve dustmask pixels
            pxR=c(j,Rind);
            pxR0=c(j,R0ind);
            sZ=c(j,sZind);
            o=speedyinvert(pxR,pxR0,sZ,Ffile,pshade,thisdm,[],[]);
            if o.x(1) > 0.50
                temp(j,:)=o.x;
            end
        end
    end
    %second pass, use interpolated dust/grain sizes
    tt=~isnan(temp(:,3));
    if nnz(tt) >= 4 % if there are at least 4 solved dust/grain values
        sgrain=temp(tt,3); %solved grain size values
        sdust=temp(tt,4); %solved dust values
        XCYC=[XC(tt),YC(tt)];
        parfor j=1:size(c,1) 
            if ~tt(j)
                %interpolated dust 
                pxR=c(j,Rind);
                pxR0=c(j,R0ind);
                sZ=c(j,sZind);
                thisdm=c(j,dmind);
                dist=pdist2(XCYC,[XC(j),YC(j)]);
                %inverse distance weighted average
                w=1./dist;
                D=(sum(w.*sdust))./(sum(w));
                G=(sum(w.*sgrain))./(sum(w));
                o=speedyinvert(pxR,pxR0,sZ,Ffile,pshade,thisdm,D,G);
                sol=o.x; %fsca,shade,grain radius,dust
                temp(j,:)=sol;
            end
        end
    end
    %create a list of indices
    %and fill matrices corresponding to NDSI > 0 & ~water
    %can't use parfor for this
    repxx=zeros(size(M,1),4);
    for j=1:size(temp,1) % the unique indices
        idx=im{j}; %indices for each unique val
        repxx(idx,1)=temp(j,1); %fsca
        repxx(idx,2)=temp(j,2); %shade
        repxx(idx,3)=temp(j,3); %grain radius
        repxx(idx,4)=temp(j,4); %dust
    end
    %now fill out all pixels
    fsca(t,i)=repxx(:,1);
    fshade(t,i)=repxx(:,2);
    grainradius(t,i)=repxx(:,3);
    dust(t,i)=repxx(:,4);
    t2=toc(t1);
    fprintf('done w/ day %i in %g min\n',i,t2/60);
end

fsca=reshape(fsca,[sz(1) sz(2) sz(4)]);
fshade=reshape(fshade,[sz(1) sz(2) sz(4)]);
grainradius=reshape(grainradius,[sz(1) sz(2) sz(4)]);
dust=reshape(dust,[sz(1) sz(2) sz(4)]);


%this normalization occurs before others because fshade changes, unlike
%cc or fice, so this step drastically reduces I/O.
fsca=fsca./(1-fshade);

fsca(fsca<fsca_thresh)=0;
grainradius(fsca==0)=NaN;
dust(fsca==0)=NaN;
fshade(fsca==0)=NaN;

out.fsca=fsca;
out.fshade=fshade;
out.grainradius=grainradius;
out.dust=dust;

