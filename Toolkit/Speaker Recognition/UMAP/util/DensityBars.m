%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

classdef DensityBars < handle
    properties(Constant)
        N_BINS=40;
        NUDGE=.1*DensityBars.N_BINS;
        DENOMINATOR=(1/DensityBars.N_BINS);
        MIN_BINS=0-(.1*DensityBars.N_BINS);
        MAX_BINS=DensityBars.N_BINS+(.1*DensityBars.N_BINS);
        
        %top of logicle scale should always be 1 ... but just 8n case
        MAX_DATA_LOGICLE=1.5;
        
        %bottom of logicle scale on I-Ad with BALB/c can be up to -11.0 with logicle 0 to 1 
        MIN_DATA_LOGICLE=-11.5;
    end
    
    % override these if NOT using logicle
    properties
        app;
    end
    
    properties(SetAccess=private)
        mnDataLimit;
        mxDataLimit;
        grid1;
        grid;
        
        jet255;
        bars;
        hadOffScale=false;

        % stuff needing to be saved for superset of data
        nGridRows;
        minBins;
        maxBins;
        idx1;
        minOffscale;
        rangeOffscale;
        offscaleIdxs;
        R;
        C;
    end
    
    
    methods
        function this=DensityBars(data0to1_orProps, old)
            this.app=BasicMap.Global;
            jet=this.app.get(Html.PROP_JET);
            if isempty(jet) || ~iscell(jet)
                j=Html.JET;
                nJets=size(j,1);
                jet=cell(1,nJets);
                for i=1:nJets
                    jet{i}=Gui.HtmlHexColor(j(i,:));
                end
                this.app.set(Html.PROP_JET, jet);
            end
            this.jet255=jet;
            this.mnDataLimit=this.MIN_DATA_LOGICLE;
            this.mxDataLimit=this.MAX_DATA_LOGICLE;
            if isnumeric(data0to1_orProps)
                [this.R, this.C]=size(data0to1_orProps);
                if nargin>1  && old
                    this.getBinsOld(data0to1_orProps, true);
                else
                    this.initScales(data0to1_orProps);
                end
            else
                this.get(data0to1_orProps);
            end
        end
        
        % scales should be initialized with SUPER set of data
        function initScales(this, data0to1)
            [data0to1, mns, mxs]=this.handleOffscale(data0to1, true);
            
            this.maxBins=ceil(max(mxs/this.DENOMINATOR));
            if this.maxBins<this.N_BINS
                this.maxBins=this.N_BINS;
            elseif this.maxBins > this.MAX_BINS
                this.maxBins=this.MAX_BINS;
            end
            this.minBins=ceil(min(mns/this.DENOMINATOR));
            if this.minBins>0
                this.minBins=0;
            elseif this.minBins<this.MIN_BINS
                this.minBins=this.MIN_BINS;
            end
            this.nGridRows=(this.maxBins-this.minBins)+1;
            this.idx1=1-this.minBins;
        end
        
        function [bins, offScale]=getBins(this, data0to1)
            if length(this.offscaleIdxs)>0
                if size(data0to1,2)~=this.C
                    this.handleOffscale(data0to1, false);
                else
                    data0to1(:,this.offscaleIdxs)=...
                        (data0to1(:,this.offscaleIdxs)-this.minOffscale)...
                        ./this.rangeOffscale;
                end
            end 
            bins=ceil(data0to1/this.DENOMINATOR);
            bins(bins<this.minBins)=this.minBins; %force cut off at -.1
            bins(bins>this.maxBins)=this.maxBins; %force cut off at -.1
        end
        
        function [bins, offScale]=getBinsOld(this, data0to1, initializing)
            bins=ceil(data0to1/this.DENOMINATOR);
            mxs=max(bins, [],1);
            mns=min(bins, [],1);
            % need to scale if >1 or < .1*4
            topScale=this.MAX_BINS+(this.NUDGE*2);
            %bottomScale on CD19 can be up to -3.0 with logicle 0 to 1 
            bottomScale=this.MIN_BINS-(this.NUDGE*40);
            not0to1=mxs>topScale | mns<bottomScale; 
            offScale=any(not0to1);
            if offScale
                if ~this.hadOffScale
                    warning('%d items off scale ... ', sum(not0to1));
                    fprintf('min=%d, max=%d\n', bottomScale, topScale);
                    fprintf('mins:\t%s\nmaxs:\t%s', num2str(mns), num2str(mxs));
                    fprintf('\n');
                end
                offScale=data0to1(:,not0to1);
                minOff=min(offScale,[],1);
                rangeOff=(max(offScale, [],1)-minOff)*1.1;
                minOff=minOff-(rangeOff*.044);
                data0to1(:,not0to1)=(offScale-minOff)./rangeOff;
                bins=ceil(data0to1/this.DENOMINATOR);     
            end 
            if initializing
                bins(bins<this.MIN_BINS)=this.MIN_BINS; %force cut off at -.1
                bins(bins>this.MAX_BINS)=this.MAX_BINS; %force cut off at -.1
                this.hadOffScale=offScale;
                this.maxBins=max(bins(:));
                if this.maxBins<this.N_BINS
                    this.maxBins=this.N_BINS;
                end
                this.minBins=min(bins(:));
                if this.minBins>0
                    this.minBins=0;
                end
                this.nGridRows=(this.maxBins-this.minBins)+1;
                this.idx1=1-this.minBins;
            else
                bins(bins<this.minBins)=this.minBins; %force cut off at -.1
                bins(bins>this.maxBins)=this.maxBins; %force cut off at -.1
            end
        end
        
        
        function bars=go(this, data0to1, old)
            if nargin>2 && old
                bins=this.getBinsOld(data0to1, false);
            else
                bins=this.getBins(data0to1);
            end
            [R,C]=size(data0to1);
            this.grid=zeros(this.nGridRows,C);
            for c=1:C
                u=unique(bins(:, c));
                h=MatBasics.HistCounts(bins(:,c), u);
                idxs=u+this.idx1;
                this.grid(idxs,c)=h/R;
            end
            this.bars=cell(...
                edu.stanford.facs.swing.Basics.StrDensity1D(...
                this.grid, this.jet255, this.app.smallStart, this.app.smallEnd));
           if isempty(this.grid1)
               this.grid1=this.grid;
           end
           bars=this.bars;
        end
        
        function [data0to1, mns, mxs]=handleOffscale(this, data0to1, initializing)
            mxs=max(data0to1, [],1);
            mns=min(data0to1, [],1);
            % need to scale if >1 or < .1*4
            not0to1=mxs>this.mxDataLimit | mns<this.mnDataLimit; 
            if any(not0to1)
                nOff=sum(not0to1);
                C_=size(data0to1,2);
                if nOff<C_
                    warning('%d/%d columns are off scale ... columns %s', nOff, C_, num2str(this.offscaleIdxs));
                    fprintf('min=%0.2f, max=%0.2f\n', this.mnDataLimit, this.mxDataLimit);
                    fprintf('mins:\t%s\nmaxs:\t%s', num2str(mns), num2str(mxs));
                    fprintf('\n');
                end
                offScale=data0to1(:,not0to1);
                minOff=min(offScale(:));
                maxOff=max(offScale(:));
                rangeOff=(maxOff-minOff)*1.1;
                minOff=minOff-(rangeOff*.044);
                data0to1(:,not0to1)=(offScale-minOff)./rangeOff;
                mxs=max(data0to1, [],1);
                mns=min(data0to1, [],1);
                if initializing
                    this.hadOffScale=true;
                    this.offscaleIdxs=find(not0to1);
                    this.rangeOffscale=rangeOff;
                    this.minOffscale=minOff;
                end
            elseif initializing
                this.hadOffScale=false;
            end
        end
        function get(this, props)
            this.idx1=props.getNumeric('DensityBars.idx1');
            this.nGridRows=props.getNumeric('DensityBars.nGridRows');
            this.minBins=props.getNumeric('DensityBars.minBins');
            this.maxBins=props.getNumeric('DensityBars.maxBins');
            this.mnDataLimit=props.getNumeric('DensityBars.mnDataLimit');
            this.mxDataLimit=props.getNumeric('DensityBars.mxDataLimit');
            this.minOffscale=props.getNumeric('DensityBars.minOffscale');
            this.rangeOffscale=props.getNumeric('DensityBars.rangeOffscale');
            this.offscaleIdxs=str2num(props.get('DensityBars.offscaleIdxs'));
            this.R=props.getNumeric('DensityBars.R');
            this.C=props.getNumeric('DensityBars.C');
        end

        function set(this, props)
            props.set('DensityBars.idx1', num2str(this.idx1));
            props.set('DensityBars.nGridRows', num2str(this.nGridRows));
            props.set('DensityBars.minBins', num2str(this.minBins));
            props.set('DensityBars.maxBins', num2str(this.maxBins));
            props.set('DensityBars.mnDataLimit', num2str(this.mnDataLimit));
            props.set('DensityBars.mxDataLimit', num2str(this.mxDataLimit));
            props.set('DensityBars.minOffscale', num2str(this.minOffscale));
            props.set('DensityBars.rangeOffscale', num2str(this.rangeOffscale));
            props.set('DensityBars.offscaleIdxs', num2str(this.offscaleIdxs));
            props.set('DensityBars.R', num2str(this.R));
            props.set('DensityBars.C', num2str(this.C));
        end
    end
    
    methods(Static)
        function this=New(data0to1)
            this=DensityBars(data0to1);
            this.go(data0to1);
        end
        
        function Test
            tryIt([-.03 .04 .92 ;.44 .55 -.01; .33 1 .29; .6 .7 .29;.4 .31 .44]);
            tryIt([-.63 .04 .92 ;.44 .55 -.01; .33 1 2.29; .6 .7 .29;.4 -4.31 .44]);
            [input, names]=File.ReadCsv('~/Documents/run_umap/examples/eliverCompensatedLabeled.csv');
            all=input(:,1:end-1); % trim of label column
            tryIt(all);
            function tryIt(all)
                db=DensityBars(all, true);
                db2=DensityBars(all);
                bars1=db.go(all, true);
                bars2=db2.go(all);
                strcmp(bars1,bars2)
                
                %half the rows and half the columns
                bars1=db.go(all(1:2:end,1:2:end));
                bars2=db2.go(all(1:2:end,1:2:end));
                strcmp(bars1,bars2)
            end
        end
    end
end