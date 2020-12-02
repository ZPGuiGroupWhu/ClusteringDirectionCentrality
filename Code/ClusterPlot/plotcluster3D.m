function [ ] = plotcluster3D( n,X,a3 )  
for i=1:n
    if(a3(i)==0||a3(i)==-1)
        plot3(X(i,1),X(i,2),'k*','markersize',5);
        hold on;
    elseif(a3(i)==2)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.9,0.1,0.1],'markeredgecolor',[0.9,0.1,0.1],'markersize',5);
        hold on;
    elseif(a3(i)==3)
          plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0,0.6,0],'markeredgecolor',[0,0.6,0],'markersize',5);
          hold on;
    elseif(a3(i)==14)
          plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[1,0.6,0],'markeredgecolor',[1,0.6,0],'markersize',5);
          hold on;
    elseif(a3(i)==1)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.3,0.3,1],'markeredgecolor',[0.3,0.3,1],'markersize',5);
        hold on;
    elseif(a3(i)==5)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.6,0,0.6],'markeredgecolor',[0.6,0,0.6],'markersize',5);
        hold on;
    elseif(a3(i)==6)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.9,0.2,0.5],'markeredgecolor',[0.9,0.2,0.5],'markersize',5);
        hold on;
    elseif(a3(i)==7)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[1,0.6,0],'markeredgecolor',[1,0.6,0],'markersize',5);
        hold on;
    elseif(a3(i)==8)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.1,0.8,0.1],'markeredgecolor',[0.1,0.8,0.1],'markersize',5);
        hold on;
    elseif(a3(i)==10)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0,0,0.8],'markeredgecolor',[0,0,0.8],'markersize',5);
        hold on;
     elseif(a3(i)==9)
         plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.8,0.5,0.1],'markeredgecolor',[0.8,0.5,0.1],'markersize',5);
         hold on;
    elseif(a3(i)==11)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0,0.7,0],'markeredgecolor',[0,0.7,0],'markersize',5);
        hold on;
    elseif(a3(i)==12)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.9,0,0.5],'markeredgecolor',[0.9,0,0.5],'markersize',5);
        hold on;  
     elseif(a3(i)==13)
         plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0,0.7,0],'markeredgecolor',[0,0.7,0],'markersize',5);
         hold on; 
    elseif(a3(i)==4)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0,0.75,1],'markeredgecolor',[0,0.75,1],'markersize',5);
        hold on;
    elseif(a3(i)==15)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.6,0.6,0],'markeredgecolor',[0.6,0.6,0],'markersize',5);
        hold on;
    elseif(a3(i)==16)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.1,0.1,0.9],'markeredgecolor',[0.1,0.1,0.9],'markersize',5);
        hold on;  
    elseif(a3(i)==18)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.8,0.1,0.2],'markeredgecolor',[0.8,0.1,0.2],'markersize',5);
        hold on; 
    elseif(a3(i)==17)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[1,0.4,0],'markeredgecolor',[1,0.4,0],'markersize',5);
        hold on;
    elseif(a3(i)==19)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0,0.98,0.6],'markeredgecolor',[0,0.98,0.6],'markersize',5);
        hold on;  
    elseif(a3(i)==20)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0,0,0.8],'markeredgecolor',[0,0,0.8],'markersize',5);
        hold on; 
    elseif(a3(i)==21)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.6,0.2,0.8],'markeredgecolor',[0.6,0.2,0.8],'markersize',5);
        hold on;  
    elseif(a3(i)==22)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[1,0.1,0.18],'markeredgecolor',[1,0.1,0.18],'markersize',5);
        hold on; 
    elseif(a3(i)==23)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[1,0.1,0.18],'markeredgecolor',[1,0.1,0.18],'markersize',5);
        hold on;
    elseif(a3(i)==24)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0.2,0.2,0.8],'markeredgecolor',[0.2,0.2,0.8],'markersize',5);
        hold on; 
    elseif(a3(i)==25)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[1,0.4,0],'markeredgecolor',[1,0.4,0],'markersize',5);
        hold on;  
    elseif(a3(i)==26)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor',[0,0.4,0.9],'markeredgecolor',[0,0.4,0.9],'markersize',5);
        hold on; 
    elseif(a3(i)==27)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','b','markeredgecolor','b','markersize',5);
        hold on; 
    elseif(a3(i)==28)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','g','markeredgecolor','g','markersize',5);
        hold on; 
    elseif(a3(i)==29)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','y','markeredgecolor','y','markersize',5);
        hold on; 
    elseif(a3(i)==30)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','m','markeredgecolor','m','markersize',5);
        hold on; 
    elseif(a3(i)==31)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','c','markeredgecolor','c','markersize',5);
        hold on; 
    elseif(a3(i)==32)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','k','markeredgecolor','k','markersize',5);
        hold on; 
    elseif(a3(i)>32&&mod(a3(i),6)==0)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','g','markeredgecolor','g','markersize',5);
        hold on;
    elseif(a3(i)>32&&mod(a3(i),6)==1)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','r','markeredgecolor','r','markersize',5);
        hold on;
    elseif(a3(i)>32&&mod(a3(i),6)==2)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','b','markeredgecolor','b','markersize',5);
        hold on;
    elseif(a3(i)>32&&mod(a3(i),6)==3)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','y','markeredgecolor','y','markersize',5);
        hold on;
    elseif(a3(i)>32&&mod(a3(i),6)==4)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','c','markeredgecolor','c','markersize',5);
        hold on;
    elseif(a3(i)>32&&mod(a3(i),6)==5)
        plot3(X(i,1),X(i,2),X(i,3),'o','markerfacecolor','m','markeredgecolor','m','markersize',5);
        hold on;
    end
end
end