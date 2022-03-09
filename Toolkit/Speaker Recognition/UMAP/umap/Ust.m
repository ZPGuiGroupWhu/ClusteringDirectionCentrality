classdef Ust<handle
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
    methods(Static)
        
        function New(varargin)
            args=Ust.Args(varargin{:});
            [sample, ust]=UmapUtil.SampleNameFromArgs(args, true);
            run_umap([sample '.csv'], ...
                'label_column', 'end', ...
                'label_file', [sample '.properties'], ...
                'compress', args.compress, ...
                'save_template_file', [ust '.mat'], ...
                args.run_umap{:}); 
        end
        
        function Go(varargin)
            args=Ust.Args(varargin{:});
            [~, ust]=UmapUtil.SampleNameFromArgs(args, true);
            location=fullfile(File.Home, 'Documents/run_umap/examples',...
                [ust '.mat']);
            if ~exist(location, 'file')
                msg(Html.WrapHr(['Building template 1st, see '...
                    '<br>console for progress...']));
                varargs=Args.Set('run_umap', [args.run_umap ...
                    'verbose', 'text'], varargin{:});
                Ust.New(varargs{:});
            end
            sampleTestSet=UmapUtil.SampleNameFromArgs(args, false);
            run_umap([sampleTestSet '.csv'], ...
                'label_column', 'end', ...
                'label_file', [sampleTestSet '.properties'], ...
                'match_scenarios', 4, ...
                'match_histogram_figs', false,...
                'see_training', true, ...
                'false_positive_negative_plot', true, ...
                'template_file', [ust '.mat'], ...
                args.run_umap{:}); 
        end
        
         function [args, argued, unmatchedArgs]=Args(varargin)
             defaultGate=Args.Get('gate', varargin{:});
             if isempty(defaultGate)
                 app=BasicMap.Global;
                 defaultGate=app.get('UstTest.gate');
                 if isempty(defaultGate)
                     warning(['No value in global properties for '...
                         '"UstTest.gate"\n\tassuming "omip69_35D"']);
                     defaultGate='omip69_35D';
                 end
             end
             if contains(defaultGate, 'samusik')
                 possibleSampleNumbers=1:10;
             elseif contains(defaultGate, 'omip69')
                 possibleSampleNumbers=1:4;
             else
                 possibleSampleNumbers=1:300; %DeRosa can have hundreds in 1 dataset
             end
             p=inputParser;
             addParameter(p,'run_umap',{}, @iscell);
             addParameter(p,'training_set',2, @validateSample);
             addParameter(p,'test_set',1, @validateSample);
             addParameter(p, 'gate', defaultGate, @ischar);
             addParameter(p, 'compress', 1, @(x)isnumeric(x) && length(x)<=2);
             addParameter(p, 'synthesize', [], @(x)isnumeric(x) && length(x)<=2);
             [args, argued, unmatchedArgs]=Args.NewKeepUnmatched(p, varargin{:});
             
             function ok=validateSample(x)
                 ok=true;
                 if ~isnumeric(x) || isempty(find(x==possibleSampleNumbers,1))
                     error('Gate %s expects samples %s ', defaultGate, ...
                         StringArray.toString(possibleSampleNu7mbers));
                 end
             end
         end
    end
end