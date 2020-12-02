function a4 = LOF(data,k_num,T_DCM,lof)
DataSet = dataSet(data,'euclidean');
[lofs] = LOFs(DataSet,k_num);
lofs=(lofs-min(lofs))/(max(lofs)-min(lofs));
n = length(data);
a4=ones(n,1);
for i=1:n
    if(lofs(i)>lof)
        a4(i) = 0;
    end
end

data(a4==0,:) = [];
cluster = DirectionClusterKNN(k_num,T_DCM,data);
t = 1;
for i=1:n
    if(a4(i)==1)
        a4(i) = cluster(t);
        t = t+1;
    end
end
end








