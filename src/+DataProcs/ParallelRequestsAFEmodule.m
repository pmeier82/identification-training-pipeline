classdef ParallelRequestsAFEmodule < DataProcs.IdProcWrapper
    
    %% -----------------------------------------------------------------------------------
    properties (SetAccess = private)
        individualAfeProcs;
        fs;
        afeRequests;
        indivFiles;
        currentNewAfeRequestsIdx;
        currentNewAfeProc;
        prAfeDepProducer;
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Static)
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Access = public)
        
        function obj = ParallelRequestsAFEmodule( fs, afeRequests )
            for ii = 1:length( afeRequests )
                indivProcs{ii} = DataProcs.AuditoryFEmodule( fs, afeRequests(ii) );
            end
            for ii = 2:length( afeRequests )
                indivProcs{ii}.cacheDirectory = indivProcs{1}.cacheDirectory;
            end
            obj = obj@DataProcs.IdProcWrapper( indivProcs, false );
            obj.individualAfeProcs = indivProcs;
            obj.afeRequests = afeRequests;
            obj.fs = fs;
            obj.prAfeDepProducer = DataProcs.AuditoryFEmodule( fs, afeRequests );
        end
        %% -------------------------------------------------------------------------------

        function process( obj, wavFilepath )
            newAfeRequests = {};
            newAfeRequestsIdx = [];
            for ii = 1 : numel( obj.individualAfeProcs )
                afePartProcessed = ...
                    obj.individualAfeProcs{ii}.hasFileAlreadyBeenProcessed( wavFilepath );
                if ~afePartProcessed
                    newAfeRequests(end+1) = obj.afeRequests(ii);
                    newAfeRequestsIdx(end+1) = ii;
                end
            end
            if ~isempty( newAfeRequestsIdx )
                if ~isequal( newAfeRequestsIdx, obj.currentNewAfeRequestsIdx )
                    obj.currentNewAfeProc = ...
                                     DataProcs.AuditoryFEmodule( obj.fs, newAfeRequests );
                    obj.currentNewAfeProc.setInputProc( obj.inputProc );
                    obj.currentNewAfeProc.cacheSystemDir = obj.cacheSystemDir;
                    obj.currentNewAfeProc.nPathLevelsForCacheName = obj.nPathLevelsForCacheName;
                    obj.currentNewAfeRequestsIdx = newAfeRequestsIdx;
                end
                fprintf( ' [ ' );
                fprintf( '%d ', newAfeRequestsIdx );
                fprintf( '] ' );
                obj.currentNewAfeProc.process( wavFilepath );
                for jj = 1 : numel( newAfeRequestsIdx )
                    ii = newAfeRequestsIdx(jj);
                    obj.individualAfeProcs{ii}.output = obj.currentNewAfeProc.output;
                    obj.individualAfeProcs{ii}.output.afeData = ...
                                 containers.Map( 'KeyType', 'int32', 'ValueType', 'any' );
                    obj.individualAfeProcs{ii}.output.afeData(1) = ...
                                                 obj.currentNewAfeProc.output.afeData(jj);
                    obj.individualAfeProcs{ii}.saveOutput( wavFilepath );
                end
            end
            for ii = 1 : numel( obj.individualAfeProcs )
                obj.indivFiles{ii} = ...
                              obj.individualAfeProcs{ii}.getOutputFilepath( wavFilepath );
            end
        end
        %% -------------------------------------------------------------------------------
        
        % override of DataProcs.IdProcWrapper's method
        function outObj = getOutputObject( obj )
            outObj = getOutputObject@Core.IdProcInterface( obj );
        end
        %% -------------------------------------------------------------------------------
        
        % override of DataProcs.IdProcInterface's method
        function [out, outFilepath] = loadProcessedData( obj, wavFilepath, varargin )
            [tmpOut, outFilepath] = ...
                 loadProcessedData@Core.IdProcInterface( obj, wavFilepath, 'indivFiles' );
            obj.indivFiles = tmpOut.indivFiles;
            try
                out = obj.getOutput;
            catch err
                if strcmp( 'AMLTTP:dataprocs:cacheFileCorrupt', err.identifier )
                    error( 'AMLTTP:dataprocs:cacheFileCorrupt', ...
                           '%s', obj.getOutputFilepath( wavFilepath ) );
                else
                    rethrow( err );
                end
            end
        end
        %% -------------------------------------------------------------------------------
        
        % override of DataProcs.IdProcInterface's method
        function save( obj, wavFilepath, ~ )
            out.indivFiles = obj.indivFiles;
            save@Core.IdProcInterface( obj, wavFilepath, out ); 
        end
        %% -------------------------------------------------------------------------------
        
    end

    %% -----------------------------------------------------------------------------------
    methods (Access = protected)
        
        % override of DataProcs.IdProcWrapper's method
        function outputDeps = getInternOutputDependencies( obj )
            afeDeps = obj.prAfeDepProducer.getInternOutputDependencies.afeParams;
            outputDeps.afeParams = afeDeps;
            outputDeps.v = 2;
        end
        %% -------------------------------------------------------------------------------

        % override of Core.IdProcInterface's method
        function out = getOutput( obj, varargin )
            out.afeData = containers.Map( 'KeyType', 'int32', 'ValueType', 'any' );
            for ii = 1 : numel( obj.indivFiles )
                if ~exist( obj.indivFiles{ii}, 'file' )
                    error( 'AMLTTP:dataprocs:cacheFileCorrupt', '%s not found.', obj.indivFiles{ii} );
                end
                tmp = load( obj.indivFiles{ii}, 'afeData', 'annotations' );
                out.afeData(ii) = tmp.afeData(1);
            end
            out.annotations = tmp.annotations; % if individual AFE modules produced
                                               % individual annotations, they would have
                                               % to be joined here
    end
        %% -------------------------------------------------------------------------------

    end
    
    %% --------------------------------------------------------------------
    methods (Access = private)
    end
    
end
