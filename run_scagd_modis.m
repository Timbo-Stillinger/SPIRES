function out=run_scagd_modis(R0,R,solarZ,Ffile,watermask,fsca_thresh,pshade)
% run LUT version of scagd for 4-D matrix R
% produces cube of: fsca, grain size (um), and dust concentration (by mass)
% input:
% R0 - background image (MxNxb). Recommend using time-spaced smoothed
% cube from a month with minimum fsca and clouds, like August or September,
% then taking minimum of reflectance for each band (b)
% R - 4D cube of time-space smoothed reflectances (MxNxbxd) with
% dimensions: x,y,band,day
% solarZ: solar zenith angles (MxNxd) for R
% Ffile, location of griddedInterpolant object that produces reflectances 
%for each band
% with inputs: grain radius, dust, cosZ
% watermask: logical mask, true for water
% fsca_thresh: min fsca cutoff, scalar e.g. 0.15
% pshade: shade spectra (bx1); reflectances

%output:
%   out : struct w fields
%   fsca: MxNxd
%   grainradius: MxNxd
%   dust: MxNxd


sz=size(R);

fsca=zeros([sz(1)*sz(2) sz(4)]);
grainradius=NaN([sz(1)*sz(2) sz(4)]);
dust=NaN([sz(1)*sz(2) sz(4)]);

solarZ=reshape(solarZ,[sz(1)*sz(2) sz(4)]);
R=reshape(R,[sz(1)*sz(2) sz(3) sz(4)]);
R0=reshape(R0,[sz(1)*sz(2) sz(3)]);
watermask=reshape(watermask,[sz(1)*sz(2) 1]);


veclen=sz(1)*sz(2);

shade=zeros(size(fsca));

[X,Y]=meshgrid(1:sz(2),1:sz(1));

for i=1:sz(4) %for each day
    thisR=squeeze(R(:,:,i));
    thissolarZ=squeeze(solarZ(:,i));
    tic;
    parfor j=1:veclen %for each pixel
        sZ=thissolarZ(j); %solarZ scalar (sometimes NaN on MOD09GA)
        wm=watermask(j); %watermask scalar
        if ~wm && ~isnan(sZ)
            pxR=squeeze(thisR(j,:)); %reflectance vector
            NDSI=(pxR(4)-pxR(6))/(pxR(4)+pxR(6));
            pxR0=squeeze(R0(j,:)); %background reflectance vector
            if NDSI > 0
                % run first pass inversion
                o=speedyinvert(pxR,pxR0,sZ,Ffile,pshade,[]);
                fsca(j,i)=o.x(1)/(1-o.x(2)); %normalize by fshade
                grainradius(j,i)=o.x(3);
                dust(j,i)=o.x(4);
                shade(j,i)=o.x(2);        
            end
        else
            fsca(j,i)=NaN;
        end
    end
    %spatially interpolate dust
    f=reshape(fsca(:,i),[sz(1) sz(2)]);%fsca and dust back to 2D
    d=reshape(dust(:,i),[sz(1) sz(2)]);
    Idust=d;
    t=~isnan(d); %index of solved dust values
    if nnz(t(:)) > 5 %if there are solved dust values, interpolate
        I=scatteredInterpolant(X(t),Y(t),d(t),'linear','nearest');
        %now find unsolved (NaN) dust values where fsca > 0
        %fill using scatteredInt object 
        Idust=I(X,Y);
        %apply spatial filter
        Idust=ndnanfilter(Idust,'gausswin',[25 25]);
        %fix overflow
        Idust(f==0 | isnan(f))=NaN;
        %reshape for recomputing
        Idust=reshape(Idust,[sz(1)*sz(2) 1]);%put back in column vec
    end
    parfor j=1:veclen %for each pixel
        sZ=thissolarZ(j); %solarZ scalar (sometimes NaN on MOD09GA)
        wm=watermask(j); %watermask scalar
        if ~wm && ~isnan(sZ)
            pxR=squeeze(thisR(j,:)); %reflectance vector
            NDSI=(pxR(4)-pxR(6))/(pxR(4)+pxR(6));
            pxR0=squeeze(R0(j,:)); %background reflectance vector
            if NDSI > 0 && ~isnan(Idust(j)) && fsca(j,i) > 0 %e.g. fsca < 0.95
                % run 2nd pass inversion: solve for fsca and fshade using
                % solved grain size and interpolated dust
                o=speedyinvert(pxR,pxR0,sZ,Ffile,pshade,...
                    struct('radius',grainradius(j,i),'dust',Idust(j)));  
                fsca(j,i)=o.x(1)/(1-o.x(2)); %normalize by fshade
                grainradius(j,i)=o.x(3); %same as interpolated input
                dust(j,i)=o.x(4); %same as input
                shade(j,i)=o.x(2);        
            end
        end
    end
    t2=toc;
    fprintf('done w/ day %i in %g min\n',i,t2/60);
end

fsca=reshape(fsca,[sz(1) sz(2) sz(4)]);
grainradius=reshape(grainradius,[sz(1) sz(2) sz(4)]);
dust=reshape(dust,[sz(1) sz(2) sz(4)]);
shade=reshape(shade,[sz(1) sz(2) sz(4)]);

fsca(fsca<fsca_thresh)=0;
grainradius(fsca==0)=NaN;
dust(fsca==0)=NaN;
shade(fsca==0)=NaN;

out.fsca=fsca;
out.grainradius=grainradius;
out.dust=dust;
out.shade=shade;
