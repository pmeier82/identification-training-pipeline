classdef FeatureSetRawRmAmsCcIld < FeatureCreators.Base
% 

    %% --------------------------------------------------------------------
    properties (SetAccess = private)
        Channels; 
        amChannels;
        wsize;
        shift;
    end
    
    %% --------------------------------------------------------------------
    methods (Static)
    end
    
    %% --------------------------------------------------------------------
    methods (Access = public)
        
        function obj = FeatureSetRawRmAmsCcIld( )
            obj = obj@FeatureCreators.Base();
            obj.Channels = 16;           
            obj.amChannels = 8;
            obj.wsize = 20e-3; %32e-3;
            obj.shift = 10e-3; %16e-3;              
        end
        %% ----------------------------------------------------------------

        function afeRequests = getAFErequests( obj )
            para=genParStruct(...         
                'pp_bNormalizeRMS', false, ...            
                'fb_type', 'gammatone', ...
                'fb_lowFreqHz', 80, ...
                'fb_highFreqHz', 8000, ...
                'fb_nChannels', obj.Channels, ...
                'ihc_method', 'halfwave', ...
                'ild_wSizeSec', obj.wsize, ...
                'ild_hSizeSec', obj.shift, ...
                'rm_scaling', 'power', ...
                'rm_wSizeSec', obj.wsize, ...
                'rm_hSizeSec', obj.shift, ...
                'rm_decaySec', 8E-3, ...
                'ams_fbType', 'log', ...
                'ams_nFilters', obj.amChannels, ...
                'ams_lowFreqHz', 1, ...
                'ams_highFreqHz', 256, ...
                'ams_wSizeSec',obj.wsize,...
                'ams_hSizeSec',obj.shift,...
                'cc_wSizeSec', obj.wsize, ...
                'cc_hSizeSec', obj.shift, ...
                'cc_wname', 'hann');
            afeRequests{1}.name = 'amsFeatures';
            afeRequests{1}.params = para;
            afeRequests{2}.name = 'ratemap';
            afeRequests{2}.params = para;          
            afeRequests{3}.name = 'crosscorrelation';
            afeRequests{3}.params = para;
            afeRequests{4}.name = 'ild';
            afeRequests{4}.params = para;
        end
        %% ----------------------------------------------------------------

        function x = constructVector( obj )
            rmR = obj.makeBlockFromAfe( 2, 1, ...
                @(a)(compressAndScale( a.Data, 0.33, @(x)(median( x(x>0.01) )), 0 )), ...
                {@(a)(a.Name),@(a)([num2str(numel(a.cfHz)) '-ch']),@(a)(a.Channel)}, ...
                {@(a)(strcat('t', arrayfun(@(t)(num2str(t)),1:size(a.Data,1),'UniformOutput',false)))}, ...
                {@(a)(strcat('f', arrayfun(@(f)(num2str(f)),a.cfHz,'UniformOutput',false)))} );
            rmL = obj.makeBlockFromAfe( 2, 2, ...
                @(a)(compressAndScale( a.Data, 0.33, @(x)(median( x(x>0.01) )), 0 )), ...
                {@(a)(a.Name),@(a)([num2str(numel(a.cfHz)) '-ch']),@(a)(a.Channel)},...
                {@(a)(strcat('t', arrayfun(@(t)(num2str(t)),1:size(a.Data,1),'UniformOutput',false)))},...
                {@(a)(strcat('f', arrayfun(@(f)(num2str(f)),a.cfHz,'UniformOutput',false)))} );
            rm = obj.combineBlocks( @(b1,b2)(0.5*b1+0.5*b2), 'LRmean', rmR, rmL );
            x = obj.reshape2featVec( rm );
            modR = obj.makeBlockFromAfe( 1, 1, ...
                @(a)(compressAndScale( a.Data, 0.33 )), ...
                {@(a)(a.Name),@(a)([num2str(numel(a.cfHz)) '-ch']),@(a)(a.Channel)}, ...
                {@(a)(strcat('t', arrayfun(@(t)(num2str(t)),1:size(a.Data,1),'UniformOutput',false)))}, ...
                {@(a)(strcat('f', arrayfun(@(f)(num2str(f)),a.cfHz,'UniformOutput',false)))},...
                {@(a)(strcat('mf', arrayfun(@(f)(num2str(f)),a.modCfHz,'UniformOutput',false)))} );
            modL = obj.makeBlockFromAfe( 1, 2, ...
                @(a)(compressAndScale( a.Data, 0.33 )), ...
                {@(a)(a.Name),@(a)([num2str(numel(a.cfHz)) '-ch']),@(a)(a.Channel)}, ...
                {@(a)(strcat('t', arrayfun(@(t)(num2str(t)),1:size(a.Data,1),'UniformOutput',false)))}, ...
                {@(a)(strcat('f', arrayfun(@(f)(num2str(f)),a.cfHz,'UniformOutput',false)))},...
                {@(a)(strcat('mf', arrayfun(@(f)(num2str(f)),a.modCfHz,'UniformOutput',false)))} );
            mod = obj.combineBlocks( @(b1,b2)(0.5*b1+0.5*b2), 'LRmean', modR, modL );
            mod = obj.reshapeBlock( mod, 1 );
            x = obj.concatFeats( x, obj.reshape2featVec( mod ) );
            CCF = obj.makeBlockFromAfe( 3, 1, ...
                @(a)(compressAndScale( a.Data, 0.33 )), ...
                {@(a)(a.Name),@(a)([num2str(numel(a.cfHz)) '-ch']),@(a)(a.Channel)}, ...
                {@(a)(strcat('t', arrayfun(@(t)(num2str(t)),1:size(a.Data,1),'UniformOutput',false)))}, ...
                {@(a)(strcat('f', arrayfun(@(f)(num2str(f)),a.cfHz,'UniformOutput',false)))} );
%             CCF = obj.reshapeBlock( CCF, 1 );
            x = obj.concatFeats( x, obj.reshape2featVec( CCF ) );
            ILD = obj.makeBlockFromAfe( 4, 1, ...
                @(a)(compressAndScale( a.Data, 0.33 )), ...
                {@(a)(a.Name),@(a)([num2str(numel(a.cfHz)) '-ch']),@(a)(a.Channel)}, ...
                {@(a)(strcat('t', arrayfun(@(t)(num2str(t)),1:size(a.Data,1),'UniformOutput',false)))}, ...
                {@(a)(strcat('f', arrayfun(@(f)(num2str(f)),a.cfHz,'UniformOutput',false)))} );
%             ILD = obj.reshapeBlock( ILD, 1 );
            x = obj.concatFeats( x, obj.reshape2featVec( ILD ) );
           
        end
        %% ----------------------------------------------------------------
        
        function outputDeps = getFeatureInternOutputDependencies( obj )
            outputDeps.Channels = obj.Channels;  
            outputDeps.amChannels = obj.amChannels;   
            outputDeps.wsize= obj.wsize;
            outputDeps.shift= obj.shift;
            classInfo = metaclass( obj );
            [classname1, classname2] = strtok( classInfo.Name, '.' );
            if isempty( classname2 ), outputDeps.featureProc = classname1;
            else outputDeps.featureProc = classname2(2:end); end
            outputDeps.v = 2;
        end
        %% ----------------------------------------------------------------
        
    end
    
    %% --------------------------------------------------------------------
    methods (Access = protected)
    end
    
end
