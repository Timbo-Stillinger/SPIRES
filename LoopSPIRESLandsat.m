function LoopSPIRESLandsat(basedir,R0list,Rlist,subsetmasklist,Ffile,...
    shade,tolval,fsca_thresh,solarZthresh,outdir,el_cutoff)
% call SPIRES Landsat in a loop
%input:
%basedir - base dir where L8 inputs live
%must have subdirs:
%"cc" - canopy cover in pPPPrRRR.mat, where PPP and RRR are 3 digit path &
%rows, each file must contain cc as a canopy fraction, single
%"dem" - dem in pPPPrRRR_dem.mat with variable Z, single
%"fice" - ice fraction in pPPPrRRR.mat with variable fice, single
%"watermask" - watermask in pPPPrRRR.mat with variable watermask, logical
%"sr" - surface reflectance dir w/ subdirs in R & R0 list
% R0list - directory list for R0, cell, Nx1
% Rlist - directory list for R, cell Nx1
% subsetmasklist - list of subset files corresponding to Rlist, cell Nx1
% Ffile - mat file containing F griddedInterpolant R=F(grain radius (um),...
% dust (ppmw),solarZenith (degrees),bands (scalar))
% shade - shade endmeber, scalar or vector, length #bands
% tolval - uniquetol tolerance, e.g. 0.05 for separating unique spectra
% fsca_thresh - minumum fsca value for snow detection, values below are set to
% zero, e.g. 0.10, scalar
% solarZthresh - max solar zenith for dust estimates, deg, e.g. 35
% outdir - where to write files out
% el_cutoff - elevation cutoff, m
%note subset is based of DEM, as L8 has different sized scenes for
%different dates and everything is reprojected to match the dem
%takes a while if not subsetting, e.g. p42r34 

for i=1:length(Rlist)
% for i=1:1
    rdir=fullfile(basedir,'sr',Rlist{i});
    r0dir=fullfile(basedir,'sr',R0list{i});
    [~,fpart]=fileparts(rdir);
    s=strsplit(fpart,'_');
    pathrow=['p' s{3}];
    pathrow=insertAfter(pathrow,4,'r');
    demfile=fullfile(basedir,'dem',[pathrow,'_dem.mat']);
    fname=[pathrow,'.mat'];
    CCfile=fullfile(basedir,'cc',fname);
    WaterMaskfile=fullfile(basedir,'watermask',fname);
    CloudMaskfile=fullfile(basedir,'cloudmask',fname);
    sm=matfile(fullfile(basedir,subsetmasklist{i}));
    hdr=sm.hdr;
    fn=fieldnames(sm);
    match=false;
    j=1;
    
    while ~match && j<=length(fn)
        out=regexp(fn{j},'.*mask','ONCE');
        if ~isempty(out)
           mask=sm.(fn{j});
           match=true;
        end
        j=j+1;
    end
    RefMatrix=RasterRef2RefMat(hdr.RasterReference);
    [x,y]=pixcenters(RefMatrix,hdr.RasterReference.RasterSize,...
        'makegrid');
    if i >= 6 %wv switches to 0 is in study area,
        mask=~mask;
    end
    x=x(mask);
    y=y(mask);
    
    [r,c]=map2pix(RefMatrix,x,y);
    subset=[min(r) max(r);min(c) max(c)];
    
    fIcefile=fullfile(basedir,'fice',fname);
   
    out=run_spires_landsat(r0dir,rdir,demfile,Ffile,shade,tolval,...
    fsca_thresh,solarZthresh,CCfile,WaterMaskfile,CloudMaskfile,fIcefile,...
    el_cutoff,subset);
    
    fn=fieldnames(out);
    outname=fullfile(outdir, [Rlist{i} '.mat']);
    if exist(outname,'file')
        delete(outname);
    end
    m=matfile(outname,'Writable',true);
    
    for j=1:length(fn)
        m.(fn{j})=out.(fn{j});
    end
    
end