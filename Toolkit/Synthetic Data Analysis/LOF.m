function noise = LOF (X, k_num, T)
[n,~] = size(X);
DataSet = DDOutlier.dataSet(X,'euclidean');
[lofs] = DDOutlier.LOFs(DataSet,k_num);
lofs = (lofs-min(lofs))/(max(lofs)-min(lofs));
noise = [];
for i=1:n
    if(lofs(i)>T)
        noise = [noise; i];
    end
end
end