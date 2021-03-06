classdef MultiEventTypeLabeler < LabelCreators.Base
    % class for multi-class labeling blocks by event
    %% -----------------------------------------------------------------------------------
    properties (SetAccess = protected)
        minBlockToEventRatio;
        maxNegBlockToEventRatio;
        types;
        negOut;
        srcPrioMethod;
        srcTypeFilterOut;
        nrgSrcsFilter;
        fileFilterOut;
        sourcesMinEnergy;
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Abstract)
    end

    %% -----------------------------------------------------------------------------------
    methods
        
        function obj = MultiEventTypeLabeler( varargin )
            ip = inputParser;
            ip.addOptional( 'minBlockToEventRatio', 0.75 );
            ip.addOptional( 'maxNegBlockToEventRatio', 0 );
            ip.addOptional( 'labelBlockSize_s', [] );
            ip.addOptional( 'types', {{'Type1'},{'Type2'}} );
            ip.addOptional( 'negOut', 'rest' ); % rest, none
            ip.addOptional( 'srcPrioMethod', 'order' ); % energy, order, time
            ip.addOptional( 'srcTypeFilterOut', [] ); % e.g. [2,1;3,2]: throw away type 1 blocks from src 2 and type 2 blocks from src 3
            ip.addOptional( 'nrgSrcsFilter', [] ); % idxs of srcs to be account for block-filtering based on too low energy. If empty, do not use
            ip.addOptional( 'fileFilterOut', {} ); % blocks containing these files get filtered out
            ip.addOptional( 'sourcesMinEnergy', -20 ); 
            ip.parse( varargin{:} );
            obj = obj@LabelCreators.Base( 'labelBlockSize_s', ip.Results.labelBlockSize_s );
            obj.minBlockToEventRatio = ip.Results.minBlockToEventRatio;
            obj.maxNegBlockToEventRatio = ip.Results.maxNegBlockToEventRatio;
            obj.types = ip.Results.types;
            obj.negOut = ip.Results.negOut;
            obj.srcPrioMethod = ip.Results.srcPrioMethod;
            obj.srcTypeFilterOut = ip.Results.srcTypeFilterOut;
            obj.nrgSrcsFilter = ip.Results.nrgSrcsFilter;
            obj.sourcesMinEnergy = ip.Results.sourcesMinEnergy;
            obj.fileFilterOut = sort( ip.Results.fileFilterOut );
        end
        %% -------------------------------------------------------------------------------

    end
    
    %% -----------------------------------------------------------------------------------
    methods (Access = protected)
        
        function outputDeps = getLabelInternOutputDependencies( obj )
            outputDeps.minBlockEventRatio = obj.minBlockToEventRatio;
            outputDeps.maxNegBlockToEventRatio = obj.maxNegBlockToEventRatio;
            outputDeps.types = obj.types;
            outputDeps.negOut = obj.negOut;
            outputDeps.srcPrioMethod = obj.srcPrioMethod;
            outputDeps.nrgSrcsFilter = obj.nrgSrcsFilter;
            outputDeps.sourcesMinEnergy = obj.sourcesMinEnergy;
            outputDeps.srcTypeFilterOut = sortrows( obj.srcTypeFilterOut );
            outputDeps.fileFilterOut = obj.fileFilterOut;
            outputDeps.v = 7;
        end
        %% -------------------------------------------------------------------------------
        
        function eit = eventIsType( obj, typeIdx, type )
            eit = any( strcmp( type, obj.types{typeIdx} ) );
        end
        %% -------------------------------------------------------------------------------
        
        function y = label( obj, blockAnnotations )
            [activeTypes, relBlockEventOverlap, srcIdxs] = obj.getActiveTypes( blockAnnotations );
            [maxPosRelOverlap,maxTimeTypeIdx] = max( relBlockEventOverlap );
            if any( activeTypes )
                switch obj.srcPrioMethod
                    case 'energy'
                        eSrcs = cellfun( @mean, blockAnnotations.srcEnergy(:,:) ); % mean over channels
                        for ii = 1 : numel( activeTypes )
                            if activeTypes(ii)
                                eTypes(ii) = 1/sum( 1./eSrcs([srcIdxs{ii}]) );
                            else
                                eTypes(ii) = -inf;
                            end
                        end
                        [~,labelTypeIdx] = max( eTypes );
                    case 'order'
                        labelTypeIdx = find( activeTypes, 1, 'first' );
                    case 'time'
                        labelTypeIdx = maxTimeTypeIdx;
                    otherwise
                        error( 'AMLTTP:unknownOptionValue', ['%s: unknown option value.'...
                                     'Use ''energy'' or ''order''.'], obj.srcPrioMethod );
                end
                y = labelTypeIdx;
            elseif strcmp( obj.negOut, 'rest' ) && ...
                    (maxPosRelOverlap <= obj.maxNegBlockToEventRatio) 
                y = -1;
            else
                y = NaN;
                return;
            end
            for ii = 1 : size( obj.srcTypeFilterOut, 1 )
                srcfo = obj.srcTypeFilterOut(ii,1);
                typefo = obj.srcTypeFilterOut(ii,2);
                if activeTypes(typefo) && any( srcIdxs{typefo} == srcfo )
                    y = NaN;
                    return;
                end
            end
            if ~isempty( obj.nrgSrcsFilter )
                rejectBlock = LabelCreators.EnergyDependentLabeler.isEnergyTooLow( ...
                              blockAnnotations, obj.nrgSrcsFilter, obj.sourcesMinEnergy );
                if rejectBlock
                    y = NaN;
                    return;
                end
            end
            for ii = 1 : numel( obj.fileFilterOut )
                if any( strcmpi( obj.fileFilterOut{ii}, blockAnnotations.srcFile.srcFile(:,1) ) )
                    y = NaN;
                    return;
                end
            end
        end
        %% -------------------------------------------------------------------------------
        function [activeTypes, relBlockEventOverlap, srcIdxs] = getActiveTypes( obj, blockAnnotations )
            [relBlockEventOverlap, srcIdxs] = obj.relBlockEventsOverlap( blockAnnotations );
            activeTypes = relBlockEventOverlap >= obj.minBlockToEventRatio;
        end
        
        function [relBlockEventsOverlap, srcIdxs] = relBlockEventsOverlap( obj, blockAnnotations )
            blockOffset = blockAnnotations.blockOffset;
            labelBlockOnset = blockOffset - obj.labelBlockSize_s;
            eventOnsets = blockAnnotations.srcType.t.onset;
            eventOffsets = blockAnnotations.srcType.t.offset;
            relBlockEventsOverlap = zeros( size( obj.types ) );
            srcIdxs = cell( size( obj.types ) );
            for ii = 1 : numel( obj.types )
                eventsAreType = cellfun( @(ba)(...
                                  obj.eventIsType( ii, ba )...
                                              ), blockAnnotations.srcType.srcType(:,1) );
                thisTypeEventOnOffs = ...
                               [eventOnsets(eventsAreType)' eventOffsets(eventsAreType)'];
                thisTypeMergedEventOnOffs = sortAndMergeOnOffs( thisTypeEventOnOffs );
                thisTypeMergedOnsets = thisTypeMergedEventOnOffs(:,1);
                thisTypeMergedOffsets = thisTypeMergedEventOnOffs(:,2);
                eventBlockOverlaps = arrayfun( @(eon,eof)(...
                                  min( blockOffset, eof ) - max( labelBlockOnset, eon )...
                                         ), thisTypeMergedOnsets, thisTypeMergedOffsets );
                isEventBlockOverlap = eventBlockOverlaps' > 0;
                eventBlockOverlapLen = sum( eventBlockOverlaps(isEventBlockOverlap) );
                if eventBlockOverlapLen == 0
                    relBlockEventsOverlap(ii) = 0;
                else
                    eventLen = sum( thisTypeMergedOffsets(isEventBlockOverlap) ...
                                            - thisTypeMergedOnsets(isEventBlockOverlap) );
                    maxBlockEventLen = min( obj.labelBlockSize_s, eventLen );
                    relBlockEventsOverlap(ii) = eventBlockOverlapLen / maxBlockEventLen;
                end
                srcIdxs{ii} = unique( [blockAnnotations.srcType.srcType{eventsAreType,2}] );
            end
        end
        %% -------------------------------------------------------------------------------
                
    end
    %% -----------------------------------------------------------------------------------
    
    methods (Static)
        
        %% -------------------------------------------------------------------------------
        
    end
    
end

        

