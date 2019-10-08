function out=smoothSCAGDcube(outloc,matdates,fsca_nPersist,...
    grainradius_nPersist,fsca_thresh,watermask,topofile,el_cutoff)
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
    
    fsca_t=single(m.fsca(:,:,ind))./100;
    weights_t=single(m.weights(:,:,ind))./100;
    grainradius_t=single(m.grainradius(:,:,ind));
    dust_t=single(m.dust(:,:,ind)).*10^-11; %remove this later
    
    
    fsca(:,:,i)=fsca_t;
    weights(:,:,i)=weights_t;
    grainradius(:,:,i)=grainradius_t;
    dust(:,:,i)=dust_t;
end

t=grainradius > 1190 | (grainradius > 0 & grainradius < 50);
grainmask=snowPersistenceFilter(grainradius < 150, grainradius_nPersist,1);
fsca(t | grainmask)=NaN; 
fsca=snowPersistenceFilter(fsca,fsca_nPersist,fsca_thresh);
wm=repmat(watermask,[1 1 size(fsca,3)]);

Z=GetTopography(topofile,'elevation');
Zmask=Z < el_cutoff;
Zmask=repmat(Zmask,[1 1 length(matdates)]);
fsca(Zmask)=0;

newweights=weights;
newweights(isnan(fsca))=0;
%fill in and smooth NaNs
fsca=smoothDataCube(fsca,newweights,'mask',~watermask);
fsca(wm)=NaN;

grainradius=smoothDataCube(grainradius,newweights,'mask',~watermask);
grainradius(fsca==0 | isnan(fsca))=NaN;

dust=smoothDataCube(dust,newweights,'mask',~watermask);
dust(fsca==0 | isnan(fsca))=NaN;

out.fsca=fsca;
out.grainradius=grainradius;
out.dust=dust;

end

