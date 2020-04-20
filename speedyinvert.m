function [out,modelRefl] = speedyinvert(R,R0,solarZ,Ffile,pshade,...
    dust_thresh,dust,cc)
%stripped down inversion for speed
% input: 
%   R - Nx1 band reflectance as vector, center of bandpass
%   R0 - Nx1 band background reflectance
%   solarZ - solar zenith angle for flat surface, deg, scalar
%   Ffile, location of griddedInterpolant with 4 inputs: radius (um), 
% dust (ppm), solarZ (deg), 
%   and band for a specific sensor, e.g. LandSat 8 OLI or MODIS
%   pshade:  shade spectra (bx1)
%   dust_thresh - threshhold value for dust retrievals, e.g. 0.85
% dust -dust val (ppmw), [] if needs to be solved for
% cc - cc val
% output:
%   out: fsca, fshade, grain radius (um), and dust conc (ppm)
persistent F
if isempty(F)
   X=load(Ffile);
   F=X.F;
end

ccflag=true;
if cc==0
    ccflag=false;
end 

options = optimoptions('fmincon','Display','none',...
    'Algorithm','sqp');
%options=optimoptions('fmincon','Display','none');

% make all inputs column vectors
if ~iscolumn(R)
    R=R';
end
if ~iscolumn(R0)
    R0=R0';
end
if ~iscolumn(pshade)
    pshade=pshade';
end

out.x=NaN(4,1);

A=[1 1 0 0];
b=1;
   
try
    if ~isempty(dust)
        if ccflag
            x0=[0.5 cc 250 dust];
            lb=[0 cc 30 dust];
            ub=[1 1 1200 dust];
        else
            x0=[0.5 0.1 250 dust];
            lb=[0 0 30 dust];
            ub=[1 1 1200 dust];
        end
        X = fmincon(@SnowCloudDiff,x0,A,b,[],[],lb,ub,[],options); 
    else
    %try a clean snow solution
    if ccflag
        x0=[0.5 cc 250 0]; %fsca, fshade,grain size (um), dust (ppm)
        lb=[0 cc 30 0];
        ub=[1 1 1200 0];
    else
        x0=[0.5 0.1 250 0]; %fsca, fshade,grain size (um), dust (ppm)
        lb=[0 0 30 0];
        ub=[1 1 1200 0];
    end
        X = fmincon(@SnowCloudDiff,x0,A,b,[],[],lb,ub,[],options);
        X(4)=NaN; %dust is NaN unless...
        %if fsca is above threshold, re-solve for shade & dust 
        if X(1) >= dust_thresh
            x0=[0.5 0.1 250 0.1]; %fsca,fshade,grain size (um), dust (ppm)
            lb=[0 0 30 0];
            ub=[1 1 1200 1000];
            X = fmincon(@SnowCloudDiff,x0,A,b,[],[],lb,ub,[],options);
        end
    end
    out.x=X;
catch ME

      warning([ME.message,' solver crashed, skipping']);
end

    function diffR = SnowCloudDiff(x)
        modelRefl=zeros(length(R),1);
        %x is fsca,radius,dust
        for i=1:length(R)
            %use radius,dust,solarZ, and band # for look up
            modelRefl(i)=F([x(3),x(4),solarZ,i]);
        end
        
        modelRefl=x(1).*modelRefl + x(2).*pshade + (1-x(1)-x(2)).*R0;
        diffR = norm(R - modelRefl);        
    end
end