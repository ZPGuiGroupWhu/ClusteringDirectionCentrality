function cluster = LOF(k_num,noise,T,X)
DataSet = dataSet(X,'euclidean');
[lofs] = LOFs(DataSet,k_num);
lofs=(lofs-min(lofs))/(max(lofs)-min(lofs));
n = length(X);

cluster = ones(n,1);
for i=1:n
    if(lofs(i)<noise)
        cluster(i) = 0;
    end
end
X(cluster==0,:)=[];

temp = OptCDC(k_num,T,X);
mark = 1;
for i=1:n
    if(cluster(i)==1)
        cluster(i) = temp(mark);
        mark = mark + 1;
    end
end








