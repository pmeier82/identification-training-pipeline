classdef SVMmodelSelectTrainer < ModelTrainers.HpsTrainer & Parameterized
    
    %% -----------------------------------------------------------------------------------
    properties (SetAccess = {?Parameterized})
        hpsEpsilons;
        hpsKernels;
        hpsCrange;
        hpsGammaRange;
        makeProbModel;
    end
    
    %% -----------------------------------------------------------------------------------
    methods

        function obj = SVMmodelSelectTrainer( varargin )
            pds{1} = struct( 'name', 'hpsEpsilons', ...
                             'default', 0.001, ...
                             'valFun', @(x)(isfloat(x) && x > 0) );
            pds{2} = struct( 'name', 'hpsKernels', ...
                             'default', 0, ...
                             'valFun', @(x)(rem(x,1) == 0 && all(x == 0 | x == 2)) );
            pds{3} = struct( 'name', 'hpsCrange', ...
                             'default', [-6 2], ...
                             'valFun', @(x)(isfloat(x) && length(x)==2 && x(1) < x(2)) );
            pds{4} = struct( 'name', 'hpsGammaRange', ...
                             'default', [-12 3], ...
                             'valFun', @(x)(isfloat(x) && length(x)==2 && x(1) < x(2)) );
            pds{5} = struct( 'name', 'makeProbModel', ...
                             'default', false, ...
                             'valFun', @islogical );
            obj = obj@Parameterized( pds );
            obj = obj@ModelTrainers.HpsTrainer( varargin{:} );
            obj.setParameters( true, ...
                'buildCoreTrainer', @ModelTrainers.SVMtrainer, ...
               'hpsCoreTrainerParams', {'makeProbModel', false}, ...
                varargin{:} );
            obj.setParameters( false, ...
                'finalCoreTrainerParams', ...
                    {'makeProbModel', obj.makeProbModel} );
        end
        %% -------------------------------------------------------------------------------

    end
    
    %% -----------------------------------------------------------------------------------
    methods (Access = protected)
        
        function hpsSets = getHpsGridSearchSets( obj )
            hpsCs = logspace( obj.hpsCrange(1), ...
                              obj.hpsCrange(2), ...
                              obj.hpsSearchBudget );
            hpsGs = logspace( obj.hpsGammaRange(1), ...
                              obj.hpsGammaRange(2), ...
                              obj.hpsSearchBudget );
            [kGrid, eGrid, cGrid, gGrid] = ndgrid( ...
                                                obj.hpsKernels, ...
                                                obj.hpsEpsilons, ...
                                                hpsCs, ...
                                                hpsGs );
            hpsSets = [kGrid(:), eGrid(:), cGrid(:), gGrid(:)];
            hpsSets(hpsSets(:,1)~=2,4) = 1; %set gamma equal for kernels other than rbf
            hpsSets = unique( hpsSets, 'rows' );
            hpsSets = cell2struct( num2cell(hpsSets), {'kernel','epsilon','c','gamma'},2 );
        end
        %% -------------------------------------------------------------------------------
        
        function refinedHpsTrainer = refineGridTrainer( obj, hps )
            refinedHpsTrainer = ModelTrainers.SVMmodelSelectTrainer( ...
                                                       'hpsKernels', obj.hpsKernels, ...
                                                       'makeProbModel', obj.makeProbModel, ...
                                                       'buildCoreTrainer', obj.buildCoreTrainer, ...
                                                       'hpsCoreTrainerParams', obj.hpsCoreTrainerParams, ...
                                                       'finalCoreTrainerParams', obj.finalCoreTrainerParams, ...
                                                       'hpsMaxDataSize', obj.hpsMaxDataSize, ...
                                                       'hpsRefineStages', obj.hpsRefineStages, ...
                                                       'hpsSearchBudget', obj.hpsSearchBudget, ...
                                                       'hpsCvFolds', obj.hpsCvFolds, ...
                                                       'hpsMethod', obj.hpsMethod, ...
                                                       'performanceMeasure', obj.performanceMeasure );
            best3LogMean = @(fn)(mean( log10( [hps.params(end-2:end).(fn)] ) ));
            eRefinedRange = getCenteredHalfRange( ...
                log10(obj.hpsEpsilons), best3LogMean('epsilon') );
            cRefinedRange = getCenteredHalfRange( ...
                obj.hpsCrange, best3LogMean('c') );
            gRefinedRange = getCenteredHalfRange( ...
                obj.hpsGammaRange, best3LogMean('gamma') );
            refinedHpsTrainer.setParameters( false, ...
                'hpsGammaRange', gRefinedRange, ...
                'hpsCrange', cRefinedRange, ...
                'hpsEpsilons', unique( 10.^[eRefinedRange, best3LogMean('epsilon')] ) );
        end
        %% -------------------------------------------------------------------------------
        
    end

    %% -----------------------------------------------------------------------------------
    methods (Access = private)
        
    end
    
end