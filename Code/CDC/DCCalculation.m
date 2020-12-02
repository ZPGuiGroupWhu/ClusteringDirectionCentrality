function [ angle_var ] = DCCalculation( get_knn,X )
% [a1,a2,a3]=textread('iloveu.txt','%f%f%d','delimiter',',');
a1 = X(:,1);
a2 = X(:,2);
[n,m] = size(a1); 
[n,k_num] = size(get_knn);  
angle = zeros(n,k_num);
for i=1:n
    for j=1:k_num
        delta_x = a1(get_knn(i,j))-a1(i);
        delta_y = a2(get_knn(i,j))-a2(i);
        if(delta_x==0)
            if(delta_y==0)
                angle(i,j)=0;
            elseif(delta_y>0)
                angle(i,j)=pi/2;
            else
                angle(i,j)=3*pi/2; 
            end
        elseif(delta_x>0)
            if(atan(delta_y/delta_x)>=0)
                angle(i,j)=atan(delta_y/delta_x);
            else
                angle(i,j)=2*pi+atan(delta_y/delta_x);
            end
        else
            angle(i,j)=pi+atan(delta_y/delta_x);
        end
    end
end                             

angle_var = zeros(n,1);
for i=1:n
    angle_order = sort(angle(i,:));
    for j=1:k_num
        if(j~=k_num)
            point_angle = angle_order(j+1)-angle_order(j);
            angle_var(i) = angle_var(i) + (point_angle-2*pi/k_num).^2;
        else
            point_angle = angle_order(1)-angle_order(k_num)+2*pi;
            angle_var(i) = angle_var(i) + (point_angle-2*pi/k_num).^2;
        end
    end
    angle_var(i) = angle_var(i)/k_num;
end   
angle_var = angle_var/((k_num-1)*4*pi^2/k_num^2);           %%%计算每个点的局部中心度量
end