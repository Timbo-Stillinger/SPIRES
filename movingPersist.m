function Xout=movingPersist(X,N,thresh)
%moving threshold function
%works along the 3rd (usually time) dimension of a cube and sets values to
%false if their sum is below a threshold
%input
%X: logical cube m x n x t
%N: windows size, integer
%thresh: threshold count
%output: Xout
%logical cube where X is set to false for each pixel at each slice (3rd
%dim) that failed
Xout=false(size(X));
for i=1:size(X,3)
    nstart=max(1,i-N);
    nend=min(size(X,3),i+N);
    st=sum(X(:,:,nstart:nend),3);
    tt=false(size(st));
    tt(st >= thresh)=true;
    Xout(:,:,i)=tt;
end
