function [feature, label] = RastaPLP (dataname)
    feature = [];
    if (strcmp(dataname,'ELSDSR')==1)
        label = zeros(198,1);
        for i=1:198
            addpath RastaPLP
            path=['ELSDSR\v (',num2str(i),').wav'];
            sig = audioread(path);
            [cep1, ~] = rastaplp(sig,160000,0,30);
            cep1(:,isnan(cep1(2,:))==1)=[];
            feature=[feature,mean(cep1,2)];
            label(i) = ceil(i/9);
        end
        feature = feature';
    elseif (strcmp(dataname,'MSLT')==1)
        label = zeros(200,1);
        for i=1:200
            addpath RastaPLP
            path=['MSLT\s (',num2str(i),').wav'];
            sig = audioread(path);
            [cep1, ~] = rastaplp(sig,160000,0,30);
            cep1(:,isnan(cep1(2,:))==1)=[];
            feature=[feature,mean(cep1,2)];
            label(i) = ceil(i/10);
        end   
        feature = feature';
    else
       disp('Please input ELSDSR or MSLT data !'); 
    end
end
