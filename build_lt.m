function F=build_lt(sensor,bands)
%input: sensor, string, e.g. 'LandsatOLI' or 'MODIS'
%bands: 1xN vector indicating bands needed, e.g. 1:7
% output: gridded interpolant with inputs: 
%grain size (um), dust (conc. by 
% weight, ppm), solar zenith angle (deg), and band (N)

sT=SensorTable(sensor);
sT=sT(bands,:);

radius=30:10:1200;
dust=[0 0.1 1:10:1000];
solarZ=0:1:89;

lTbl=zeros(length(radius),length(dust),...
    length(solarZ),length(bands));
N=length(radius)*length(dust);

n=0;
tic;

for i=1:length(radius)
        for j=1:length(dust)
%           for j=1:length(soot)
            for k=1:length(solarZ)
            T=SolarIrrad('solarZ',solarZ(k));
            T.BOTDIF(T.BOTDIF<0)=0;
            S=table(T.WL,[T.BOTDIR T.BOTDIF],'VariableNames',...
                {'wavelength','irradiance'});

            S.Properties.VariableUnits={'um','W m^-2 um'};
            out=SnowCloudIntgRefl(S,'snow',...
                        'cosZ',cosd(solarZ(k)),...
                        'radius',radius(i),...
                        'dust',dust(j)*1e-6,...
                        'bandPass',[sT.LowerWavelength sT.UpperWavelength],...
                         'waveu','um',...
                         'lookup',false);
                    lTbl(i,j,k,:)=out.refl;
            end
            n=n+1;
               etime=toc;
               fprintf('pct done=%2.5f; time=%2.5f hr\n',...
                   n/N*100,etime/60/60);      
        end
end
[w,x,y,z]=ndgrid(radius,dust,solarZ,1:length(bands));
F=griddedInterpolant(w,x,y,z,lTbl,'linear','nearest');