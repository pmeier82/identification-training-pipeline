function trainAndTest3PointOvrlsModel( classname )

if nargin < 1, classname = 'baby'; end;

%startTwoEars( '../IdentificationTraining.xml' );
addpath( '..' );
startIdentificationTraining();

pipe = TwoEarsIdTrainPipe();
pipe.featureCreator = FeatureCreators.FeatureSetRmBlockmean();
pipe.modelCreator = ModelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @PerformanceMeasures.BAC2, ...
    'cvFolds', 4, ...
    'alpha', 0.99 );
pipe.modelCreator.verbose( 'on' );

pipe.trainset = 'learned_models/IdentityKS/trainTestSets/trainSet_miniMini1.flist';
pipe.setupData();

sc = SceneConfig.SceneConfiguration();
sc.addSource( SceneConfig.PointSource() );
sc.addSource( SceneConfig.PointSource( ...
    'azimuth',SceneConfig.ValGen('manual',-90),...
    'data',SceneConfig.FileListValGen(pipe.pipeline.trainSet('general',:,'wavFileName')),...
    'offset', SceneConfig.ValGen('manual',0.0) ),...
    SceneConfig.ValGen( 'manual', 10 ),...
    true );
sc.addSource( SceneConfig.PointSource( ...
    'azimuth',SceneConfig.ValGen('manual',+90),...
    'data',SceneConfig.FileListValGen(pipe.pipeline.trainSet('general',:,'wavFileName')),...
    'offset', SceneConfig.ValGen('manual',0.0) ),...
    SceneConfig.ValGen( 'manual', 10 ),...
    true );
sc.addSource( SceneConfig.PointSource( ...
    'azimuth',SceneConfig.ValGen('manual',180),...
    'data',SceneConfig.FileListValGen(pipe.pipeline.trainSet('general',:,'wavFileName')),...
    'offset', SceneConfig.ValGen('manual',0.0) ),...
    SceneConfig.ValGen( 'manual', 10 ),...
    true );

pipe.init( sc );
modelPath = pipe.pipeline.run( classname );

fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

pipe.modelCreator = ...
    ModelTrainers.LoadModelNoopTrainer( ...
        fullfile( modelPath, [classname '.model.mat'] ), ...
        'performanceMeasure', @PerformanceMeasures.BAC2,...
        'maxDataSize', inf ...
        );

pipe.trainset = [];
pipe.testset = 'learned_models/IdentityKS/trainTestSets/testSet_miniMini1.flist';
pipe.setupData();

sc = SceneConfig.SceneConfiguration(); % clean
sc.addSource( SceneConfig.PointSource() );
sc.addSource( SceneConfig.PointSource( ...
    'azimuth',SceneConfig.ValGen('manual',-90),...
    'data',SceneConfig.FileListValGen(pipe.pipeline.testSet('general',:,'wavFileName')),...
    'offset', SceneConfig.ValGen('manual',0.0) ),...
    SceneConfig.ValGen( 'manual', 10 ),...
    true );
sc.addSource( SceneConfig.PointSource( ...
    'azimuth',SceneConfig.ValGen('manual',+90),...
    'data',SceneConfig.FileListValGen(pipe.pipeline.testSet('general',:,'wavFileName')),...
    'offset', SceneConfig.ValGen('manual',0.0) ),...
    SceneConfig.ValGen( 'manual', 10 ),...
    true );
sc.addSource( SceneConfig.PointSource( ...
    'azimuth',SceneConfig.ValGen('manual',180),...
    'data',SceneConfig.FileListValGen(pipe.pipeline.testSet('general',:,'wavFileName')),...
    'offset', SceneConfig.ValGen('manual',0.0) ),...
    SceneConfig.ValGen( 'manual', 10 ),...
    true );

pipe.init( sc );
modelPath = pipe.pipeline.run( classname );
