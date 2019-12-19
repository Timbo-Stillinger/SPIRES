function out=smoothSCAGDcube(outloc,matdates,...
    grainradius_nPersist,watermask,topofile,el_cutoff,fsca_thresh)

for i=1:length(matdates)
    dv=datevec(matdates(i));
    fname=fullfile(outloc,[datestr(dv,'yyyymm') '.mat']);
    m=matfile(fname);
    if i==1
        fsca=zeros([size(m.fsca,1) size(m.fsca,2) length(matdates)],'single');
        weights=zeros([size(m.fsca,1) size(m.fsca,2) length(matdates)],'single');
        grainradius=zeros([size(m.fsca,1) size(m.fsca,2) length(matdates)],'single');
        dust=zeros([size(m.fsca,1) size(m.fsca,2) length(matdates)],'single');    
    end
    ind=datenum(dv)-datenum([dv(1:2) 1])+1;%1st day of month
    
    %take careful note of scaling coefficients
    fsca_t=single(m.fsca(:,:,ind))./100;
    weights_t=single(m.weights(:,:,ind))./100;
    grainradius_t=single(m.grainradius(:,:,ind));
    dust_t=m.dust(:,:,ind)./10;

    fsca(:,:,i)=fsca_t;
    weights(:,:,i)=weights_t;
    grainradius(:,:,i)=grainradius_t;
    dust(:,:,i)=dust_t;
end

Z=GetTopography(topofile,'elevation');
Zmask=Z < el_cutoff;
Zmask=repmat(Zmask,[1 1 length(matdates)]);

wm=repmat(watermask,[1 1 size(fsca,3)]);

fsca(Zmask | wm) = 0;

%create mask for cube where radius is > 50 & radius < 1190 for 7 or more days

gmask=snowPersistenceFilter(grainradius > 50 & grainradius < 1190,...
    grainradius_nPersist,1);

% set to NAN days that aren't in that mask but are not zero fsca
fsca(~gmask & ~fsca==0)=NaN;

newweights=weights;
newweights(isnan(fsca))=0;
%fill in and smooth NaNs
fsca=smoothDataCube(fsca,newweights,'mask',~watermask);
%get some small fsca values from smoothing - set to zero
fsca(fsca<fsca_thresh)=0;
fsca(wm)=NaN;

% create mask for low fsca (includes zeros)
lowfscamask= fsca < 0.30;
%set all low fsca values to NaN
grainradius(lowfscamask)=NaN;
% set all weights for low fsca to 0
newweights(lowfscamask)=0;

grainradius=smoothDataCube(grainradius,newweights,'mask',...
    ~watermask);
grainradius(fsca==0 | isnan(fsca))=NaN;


dust(lowfscamask)=NaN;
dust=smoothDataCube(dust,newweights,'mask',~watermask);
dust(fsca==0 | isnan(fsca))=NaN;

out.fsca=fsca;
out.grainradius=grainradius;
out.dust=dust;

end

