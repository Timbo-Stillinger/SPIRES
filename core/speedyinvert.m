function [out,modelRefl] = speedyinvert(R,R0,solarZ,Ffile,shade,...
     dustmask,shadebool,w)
%stripped down inversion for speed
% input:
%   R - Nx1 band reflectance as vector, center of bandpass
%   R0 - Nx1 band background reflectance
%   solarZ - solar zenith angle for flat surface, deg, scalar
%   Ffile, location of griddedInterpolant with 4 inputs: radius (um),
% dust (ppm), solarZ (deg),
%   and band for a specific sensor, e.g. LandSat 8 OLI or MODIS
%   shade, shade endmember, scalar and vector length of R&R0
%   dustmask - only retrieve dust values where this is true
%   shadebool - use shade or not
%   w - weight vector, Nx1
% output:
%   out: fsca, fshade, grain radius (um), and dust conc (ppm)
persistent F
if isempty(F)
    X=load(Ffile);
    F=X.F;
end

options = optimoptions('fmincon','Display','none','Algorithm','sqp');

% make all inputs column vectors
if ~iscolumn(R)
    R=R';
end
if ~iscolumn(R0)
    R0=R0';
end
if ~iscolumn(shade)
    shade=shade';
end

out.x=NaN(4,1);

A=[1 1 0 0];
b=1;

%full dirty snow (dustmask) values
%fsca, fshade,grain size (um), dust (ppm)
fsca0=0.5;
fsca_range=[0 1];
fshade0=0.05;
fshade_range=[0 1];
r0=250;
r_range=[30 1200];
d0=10;
d_range=[0 1000];

if ~dustmask %clean snow solution
   d0=0;
   d_range=[0 0];
end
if ~shadebool
    fshade0=0;
    fshade_range=[0 0];
end


x0=[fsca0 fshade0 r0 d0];
lb=[fsca_range(1) fshade_range(1) r_range(1) d_range(1)];
ub=[fsca_range(2) fshade_range(2) r_range(2) d_range(2)];

try
    [X,fval] = fmincon(@SnowCloudDiff,x0,A,b,[],[],lb,ub,[],options);
    out.x=X;
    out.stats=fval;
catch ME
    warning([ME.message,' solver crashed, skipping']);
end

    function diffR = SnowCloudDiff(x)
        modelRefl=zeros(length(R),1);
        %x is fsca,fshade,radius,dust
        for i=1:length(R)
            %use radius,dust,solarZ, and band # for look up
            modelRefl(i)=F([x(3),x(4),solarZ,i]);
        end
        
        modelRefl=x(1).*modelRefl + x(2).*shade + (1-x(1)-x(2)).*R0;
         diffR = norm(w.*R - w.*modelRefl);
%MLE
%          resid=(w.*R - w.*modelRefl);
%          params=[0,std(resid)];
%          negL=normlike(params,resid);

    end
end