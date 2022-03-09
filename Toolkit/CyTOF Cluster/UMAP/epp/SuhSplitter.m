
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

classdef SuhSplitter < SuhAbstractClass
    properties(Constant)
        TEST_2_POLYGONS=false;
    end
    
    properties(SetAccess=protected)
        type;
        
        %TODO pass KLD parameters into mex?
        kld_1D=.16; 
        kld_exponential_1D=.16;
        kld_2D=.16; 
        argued;
        unmatched;
        alternateSplitA;
        alternateSplitB;
        splitsWithPolygons=false;
    end
    
    properties
        args;
        save_csv_before_split=false;
        save_csv_filename;
    end
    
    
    methods
        
        function [X, Y, selectedA, selectedB, splitA_string, ...
                splitB_string, leaf_cause]=getSplit(this, subset)
            %Get the best 2 way split of a subset along any 2 of its N
            %columns (AKA dimensions)
            %
            %Input arguments
            %subset         an instance of SuhSubset which defines a data set
            %
            %Output arguments
            %  X            1st column/dimension of 2-way split
            %  Y            2nd column/dimension of 2-way split
            %  split_data   split data in format that implementing
            %           	sub class understands (eg polygon or cluster ids)
            %  selected     selected data rows for 1st part of the 2 way split.
            %               Client gets 2nd part via the NOT operation 
            %               (~selected)vector of true/false same size as 
            %               # of rows in subset data
            if this.save_csv_before_split
                if isempty(this.save_csv_filename)
                    this.save_csv_filename=fullfile(File.Home, ...
                        'Downloads', 'last.csv');
                end
                File.WriteCsvFile(this.save_csv_filename, ...
                    subset.data, subset.dataSet.columnPrefixes);
            end

            [X, Y, splitA, splitB, leaf_cause]=this.split(subset);
            good=X>0 && Y>0;
            if good
                selectedA=this.select(subset, X, Y, splitA);
                nSplit=sum(selectedA);
                good=nSplit>1 && nSplit<subset.size;
            else
                X=0;
                Y=0;
                selectedA=[];
                splitA_string='';
                selectedB=[];
                splitB_string='';
                return;
            end
            if good                    
                splitA_string=this.to_string(splitA);
                if ~isempty(splitB)
                    selectedB=this.select(subset, X, Y, splitB);
                    splitB_string=this.to_string(splitB);
                    if SuhSplitter.TEST_2_POLYGONS && this.splitsWithPolygons
                        dif=subset.size-(...
                            sum(this.select(subset, X,Y,this.to_data(splitA_string)))...
                            +sum(this.select(subset, X,Y,this.to_data(splitB_string))));
                        if ~isempty(this.alternateSplitA)
                            difAlternate=subset.size-(sum(...
                                this.select(subset, X,Y,this.alternateSplitA))...
                                +sum(this.select(subset, X,Y,this.alternateSplitB)));
                            if difAlternate~=0 || dif ~=0
                                dif=abs(dif);
                                difAlternate=abs(difAlternate);
                                if difAlternate>dif
                                    word='WORSE';
                                elseif difAlternate<dif
                                    word='BETTER';
                                else
                                    word='SAME';
                                end
                                txt=sprintf(['ALTERNATE polygons on '...
                                    '%d cells are %s, alternate=%d, '...
                                    'regular=%d\n'], subset.size, word, ...
                                    abs(difAlternate), abs(dif));
                                fprintf(txt);
                                %warning(txt);
                            end        
                        elseif dif~=0
                            fprintf(...
                                '2 polygons disagree on %d of %d cells\n', ...
                                abs(dif), subset.size);
                        end                        
                    end
                else
                    selectedB=~selectedA; % NOT gate
                    splitB_string='';
                end
            else
                warning('Polygon achieved no split???');
                X=0;
                Y=0;
                selectedA=[];
                splitA_string='';
                selectedB=[];
                splitB_string='';
            end
        end
        
        function [selectedA, selectedB]=getSelected(this, subset, X, Y, ...
                splitA_string, splitB_string)
            %Get selected data rows for both parts of 2-way split.
            %	Client gets 2nd part via the NOT operation (~selected)
            %
            %Input arguments
            %subset         an instance of SuhSubset defining data set
            %X              1st column of 2-way split
            %Y              2nd column of 2-way split
            %splitA_string  split data in the format the implementing
            %           	sub class understands
            %splitB_string  split data in the format the implementing
            %           	sub class understands
            %
            %Output arguments
            %selected       vector of true/false same size as # of rows
            %               in subset data
            
            selectedA=this.select(subset, X, Y, this.to_data(splitA_string));
            if ~isempty(splitB_string)
                selectedB=this.select(subset, X, Y, this.to_data(splitB_string));
            else
                selectedB=~selectedA; % NOT gate
            end
        end
        
        function [ax, highlights, highlightName]=plot(this, ax, ...
                subset, X, Y, split_string, ttl, predictions)
            if nargin<7
                ttl=[num2str(subset.size) ...
                    'x' num2str(this.dataSet.C)];
            end
            showPolygon(subset.data, X,Y,[], ... %empty polygon
                ax,subset.dataSet.columnNames, ttl);
            if nargin>7 && ~isempty(predictions)
                highlightName=predictions.selectedName;
                Gui.Flash(ax, subset.filter(...
                    predictions.selectedData, [X Y]), predictions);
                highlights=subset.filter(predictions.selectedData);
            else
                highlights=[];
                highlightName='';
            end
            split=this.to_data(split_string);
            if ~isempty(split)
                this.showSplit(ax, split);
            end
        end
        
        function ax=plotSelected(this, ax, subset, X, Y, split_string, ...
                not, ttl, predictions)
            if nargin<8
                ttl=[num2str(subset.size) ...
                    'x' num2str(this.dataSet.C)];
                if nargin<7
                    not=false;
                end
            end
            split=this.to_data(split_string);
            data=subset.data;
            selected=showPolygon(data, X,Y, split, ax,... %empty polygon
                subset.dataSet.columnNames, ttl);
            if ~isempty(selected)
                hold(ax, 'on');
                if ~not
                    selected=~selected;
                end
                clr=[.61 .610 .61];
                plot(ax, data(selected, X), data(selected, Y), ...
                    'LineStyle', 'none',...=
                    'Marker', 'd', ...
                    'MarkerSize',3,...
                    'MarkerEdgeColor', clr,...
                    'MarkerFaceColor', clr);
            end
            if nargin>8 && ~isempty(predictions)
                highlighted=subset.filter(predictions.selectedData, [X Y]);
                Gui.Flash(ax, highlighted, predictions);
            end
            
        end
        
        function loadProperties(this, props)
            this.kld_1D=str2double(props.get('kld_1D'));
            this.kld_2D=str2double(props.get('kld_2D'));
            this.kld_exponential_1D=str2double(props.get('kld_exponential_1D'));
            this.loadSubClassProperties(props);
        end

        function saveProperties(this, props)
            props.put('kld_1D', java.lang.String(num2str(this.kld_1D)));
            props.put('kld_2D', java.lang.String(num2str(this.kld_2D)));
            props.put('kld_exponential_1D', java.lang.String(num2str(this.kld_exponential_1D)));
            this.saveSubClassProperties(props);
        end
        
        function suffix=getFileNameSuffix(this)
            suffix=String.ToSystem(this.getSubClassFileNameSuffix);
        end
            
    end
    
    
    methods(Abstract, Access=protected)
        [X, Y, splitA_data, splitB_data, leafCause]=split(this, subset)
        %Get the best 2 way split of a subset along any 2 of its N 
        %columns (AKA dimensions)
        %
        %Input arguments
        %subset         an instance of SuhSubset defining data set
        %
        %Output arguments
        %X              1st column/dimension of 2-way split
        %Y              2nd column/dimension of 2-way split
        %splitA_data    part 1 split data in format that implementing
        %           	sub class understands (eg polygon or cluster ids)
        %splitB_data    part 2 split data in format that implementing
        %           	sub class understands (eg polygon or cluster ids)

        selected=select(this, subset, X, Y, split_data)
        %Get selected data rows for 1st part of the 2 way split.  
        %	Client gets 2nd part via the NOT operation (~selected)
        %
        %Input arguments
        %subset         an instance of SuhSubset defining data set
        %X              1st column of 2-way split
        %Y              2nd column of 2-way split
        %split_data     split data in the format the implementing
        %           	sub class understands
        %
        %Output arguments
        %selected       vector of true/false same size as # of rows
        %               in subset data
        
        split_data=to_data(this, split_string)
        %Convert storeable string previously given to splitter client into 
        %the data format the implementing sub class understands (e.g. polygon 
        %or cluster ids etc)
        %
        %Input arguments
        %split_string   storeable string produced by implementing sub class
        %
        %Output arguments
        %split_data     split data in format that implementing
        %               sub class understands (eg polygon, cluster ids etc)
        %
        
    end
    
    methods(Access=protected)
        function split_string=to_string(this, split_data)
        %convert sub class's internal split data storeable string give to splitter clientto format
        %that implementing sub class understands
        %
        %Input arguments
        %split_string   storeable string produced by impleenting sub class
        %
        %Output arguments
        %split_data     split data in format that implementing
        %               sub class understands (e.g. polygon or cluster
        %               ids etc)
        %
            split_string=num2str(split_data(:)');
        end
        
        function showSplit(this, ax, split)
            this.warnNotImplemented;
        end

        function loadSubClassProperties(this, props)
            this.warnNotImplemented;
        end
        
        function saveSubClassProperties(this, props)
            this.warnNotImplemented;
        end

        function suffix=getSubClassFileNameSuffix(this)
            this.warnNotImplemented;
            suffix='';
        end

        function this=SuhSplitter()
           this=this@SuhAbstractClass();
        end
    
    end

end