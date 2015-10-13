classdef (Abstract) IdProcInterface < handle
    %% data file processor
    %
    
    %% -----------------------------------------------------------------------------------
    properties (SetAccess = protected)
        procName;
        externOutputDeps;
        preloadedConfigs = [];
        preloadedConfigsChanged = false;
        preloadedPath = [];
        configChanged = true;
        currentFolder = [];
        lastClassPath = [];
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Static)
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Access = public)
        
        function init( obj )
            obj.preloadedConfigs = [];
            obj.preloadedConfigsChanged = false;
            obj.preloadedPath = [];
            obj.configChanged = true;
            obj.currentFolder = [];
            obj.lastClassPath = [];
        end
        %% -----------------------------------------------------------------
        
        function savePlaceholderFile( obj, inFilePath )
            obj.save( inFilePath, struct('dummy',[]) );
        end
        %% -----------------------------------------------------------------
        
        function out = saveOutput( obj, inFilePath )
            out = obj.getOutput();
            obj.save( inFilePath, out );
        end
        %% -----------------------------------------------------------------
        
        function out = processSaveAndGetOutput( obj, inFileName )
            if ~obj.hasFileAlreadyBeenProcessed( inFileName )
                obj.process( inFileName );
                out = obj.saveOutput( inFileName );
            else
                out = load( obj.getOutputFileName( inFileName ) );
            end
        end
        %% -----------------------------------------------------------------
        
        function outFileName = getOutputFileName( obj, inFilePath, currentFolder )
%            inFilePath = which( inFilePath ); % ensure absolute path
            if nargin < 3
                currentFolder = obj.getCurrentFolder( inFilePath );
            end
            [~, fileName, fileExt] = fileparts( inFilePath );
            fileName = [fileName fileExt];
            outFileName = fullfile( currentFolder, [fileName obj.getProcFileExt] );
        end
        %% -----------------------------------------------------------------
        
        function fileProcessed = hasFileAlreadyBeenProcessed( obj, filePath, createFolder )
            if isempty( filePath ), fileProcessed = false; return; end
%            filePath = which( filePath ); % ensure absolute path
            currentFolder = obj.getCurrentFolder( filePath );
            fileProcessed = ...
                ~isempty( currentFolder )  && ...
                exist( obj.getOutputFileName( filePath, currentFolder ), 'file' );
            if nargin > 2  &&  createFolder  &&  isempty( currentFolder )
                currentFolder = obj.createCurrentConfigFolder( filePath );
            end
        end
        %% -----------------------------------------------------------------
        
        function setExternOutputDependencies( obj, externOutputDeps )
            obj.configChanged = true;
            obj.externOutputDeps = externOutputDeps;
        end
        %%-----------------------------------------------------------------
        
        function outputDeps = getOutputDependencies( obj )
            outputDeps = obj.getInternOutputDependencies();
            if ~isa( outputDeps, 'struct' )
                error( 'getInternOutputDependencies must combine values in a struct.' );
            end
            if isfield( outputDeps, 'extern' )
                error( 'Intern output dependencies must not contain field of name "extern".' );
            end
            if ~isempty( obj.externOutputDeps )
                outputDeps.extern = obj.externOutputDeps;
            end
        end
        %% -----------------------------------------------------------------
        
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Access = protected)
        
        function obj = IdProcInterface( procName )
            if nargin < 1,
                classInfo = metaclass( obj );
                [classname1, classname2] = strtok( classInfo.Name, '.' );
                if isempty( classname2 ), obj.procName = classname1;
                else obj.procName = classname2(2:end); end
            else
                obj.procName = procName;
            end
            obj.externOutputDeps = [];
        end
        %%-----------------------------------------------------------------
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Access = private)
        
        function out = save( obj, inFilePath, data )
%            inFilePath = which( inFilePath ); % ensure absolute path
            out = data;
            if isempty( inFilePath ), return; end
            currentFolder = obj.getCurrentFolder( inFilePath );
            if isempty( currentFolder )
                currentFolder = obj.createCurrentConfigFolder( inFilePath );
            end
            outFilename = obj.getOutputFileName( inFilePath, currentFolder );
            save( outFilename, '-struct', 'out' );
        end
        %% -----------------------------------------------------------------

        function saveOutputConfig( obj, configFileName )
            outputDeps = obj.getOutputDependencies();
%            outputDeps.configHash = calcDataHash( outputDeps );
            save( configFileName, '-struct', 'outputDeps' );
        end
        %% -----------------------------------------------------------------
        
        function currentFolder = getCurrentFolder( obj, filePath )
            classFolder = fileparts( filePath );
            if ~isempty( obj.currentFolder ) && ...
                    ~obj.configChanged && strcmp( classFolder, obj.lastClassPath )
                currentFolder = obj.currentFolder;
                return;
            end
            currentConfig = obj.getOutputDependencies();
            dbFolder = fileparts( classFolder );
            procFoldersDir = dir( [classFolder filesep obj.procName '.2*'] );
            procFolders = {procFoldersDir.name};
            procFolders = cellfun( @(pfdn)(pfdn(length(obj.procName)+2:end)), ...
                procFolders, 'UniformOutput', false );
            currentFolder = [];
            if isempty( obj.preloadedPath )
                obj.preloadedPath = containers.Map( 'KeyType', 'char', 'ValueType', 'any' );
            end
            if isempty( procFolders ), return; end
            allProcFolders = strcat( procFolders{:} );
            if obj.preloadedPath.isKey( allProcFolders )
                preloaded = obj.preloadedPath(allProcFolders);
                if obj.areConfigsEqual( preloaded{2}, currentConfig )
                    currentFolder = preloaded{1};
                    obj.configChanged = false;
                    obj.lastClassPath = classFolder;
                    obj.currentFolder = currentFolder;
                    return;
                end
            end
            obj.loadPreloadedConfigs( dbFolder );
            for ii = length( procFolders ) : -1 : 1
                if obj.preloadedConfigs.isKey( procFolders{ii} )
                    cfg = obj.preloadedConfigs(procFolders{ii});
                    if obj.areConfigsEqual( currentConfig, cfg )
                        currentFolder = [classFolder filesep ...
                            obj.procName '.' procFolders{ii}];
                        procFolders = {};
                        break;
                    end
                    procFolders(ii) = [];
                end
            end
            for ii = length( procFolders ) : -1 : 1
                cfg = load( fullfile( ...
                    classFolder, [obj.procName '.' procFolders{ii}], 'config.mat' ) );
                if obj.areConfigsEqual( currentConfig, cfg )
                    currentFolder = [classFolder filesep obj.procName '.' procFolders{ii}];
                    obj.preloadedConfigs(procFolders{ii}) = cfg;
                    obj.preloadedConfigsChanged = true;
                    break;
                end
            end
            if ~isempty( currentFolder )
                obj.preloadedPath(allProcFolders) = {currentFolder, currentConfig};
            end
            obj.savePreloadedConfigs( dbFolder );
            obj.configChanged = false;
            obj.lastClassPath = classFolder;
            obj.currentFolder = currentFolder;
        end
        %% -----------------------------------------------------------------
        
        function currentFolder = createCurrentConfigFolder( obj, filePath )
            classFolder = fileparts( filePath );
            timestr = buildCurrentTimeString( true );
            currentFolder = [classFolder filesep obj.procName timestr];
            mkdir( currentFolder );
            obj.saveOutputConfig( fullfile( currentFolder, 'config.mat' ) );
            cfg = load( fullfile( currentFolder, 'config.mat' ) );
            dbFolder = fileparts( classFolder );
            obj.loadPreloadedConfigs( dbFolder );
            obj.preloadedConfigs(timestr(2:end)) = cfg;
            obj.preloadedConfigsChanged = true;
            obj.savePreloadedConfigs( dbFolder );
            obj.configChanged = false;
            obj.lastClassPath = classFolder;
            obj.currentFolder = currentFolder;
        end
        %% -----------------------------------------------------------------
        
        function savePreloadedConfigs( obj, dbFolder )
            if ~obj.preloadedConfigsChanged, return; end
            pcFilename = [dbFolder filesep obj.procName '.preloadedConfigs.mat'];
            preloadedConfigs = obj.preloadedConfigs;
            sema = setfilesemaphore( pcFilename );
            save( pcFilename, 'preloadedConfigs' );
            removefilesemaphore( sema );
            obj.preloadedConfigsChanged = false;
        end
        %% -----------------------------------------------------------------
        
        function loadPreloadedConfigs( obj, dbFolder )
            if isempty( obj.preloadedConfigs )
                pcFilename = [dbFolder filesep obj.procName '.preloadedConfigs.mat'];
                if exist( pcFilename, 'file' )
                    sema = setfilesemaphore( pcFilename );
                    Parameters.dynPropsOnLoad( true, false );
                    pc = load( pcFilename );
                    Parameters.dynPropsOnLoad( true, true );
                    removefilesemaphore( sema );
                    obj.preloadedConfigs = pc.preloadedConfigs;
                    obj.preloadedConfigsChanged = false;
                else
                    obj.preloadedConfigs = ...
                        containers.Map( 'KeyType', 'char', 'ValueType', 'any' );
                end
            end
        end
        %% -----------------------------------------------------------------
        
        function procFileExt = getProcFileExt( obj )
            procFileExt = ['.' obj.procName '.mat'];
        end
        %% -----------------------------------------------------------------
        
        function eq = areConfigsEqual( obj, config1, config2 )
            eq = isequalDeepCompare( config1, config2 );
        end
        %% -----------------------------------------------------------------
        
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Abstract)
        process( obj, inputFileName )
    end
    methods (Abstract, Access = protected)
        outputDeps = getInternOutputDependencies( obj )
        out = getOutput( obj )
    end
    
end

        