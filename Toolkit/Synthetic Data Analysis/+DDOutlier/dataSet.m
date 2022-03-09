classdef dataSet < handle
    %dataSet 用来提供数据本身直接相关的基础服务
    %   
    
    properties
        data = [];
        %距离尺度
        disMetric = '';
      
        n = 0; %观测个数
        n_var = 0; %数据维度，变量个数
        
        nn = 0; %数据缓冲量
        dist_obj = struct(); %数据缓冲
    end
    
    methods
        function obj = dataSet(dataIn,disMetric)
            %dataSet 构造此类的实例
             obj.data = dataIn;
             [obj.n,obj.n_var] = size(obj.data);
             obj.disMetric = disMetric;
             %写入初期预测的缓冲量
             obj.nn = ceil(sqrt(obj.n));
             %缓冲距离矩阵
             [id,dist] = DDOutlier.matlabKNN(obj.data,obj.nn,obj.disMetric);
             obj.dist_obj.id = id;
             obj.dist_obj.dist = dist;
             
        end
        
        function [] = increaseBuffer(obj,nn)
            %increaseBuffer 增加缓冲
            %   用来在当前缓冲不够用的时候增加缓冲，
            %并处理由于缓冲增加而导致其他参数变动的问题
            obj.nn = nn;
            [id,dist] = DDOutlier.matlabKNN(obj.data,obj.nn,obj.disMetric);
            obj.dist_obj.id = id;
            obj.dist_obj.dist = dist;
        end
    end
end

