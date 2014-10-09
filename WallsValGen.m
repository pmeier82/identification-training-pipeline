classdef WallsValGen < ValGen

    %%
    methods
        
        function obj = WallsValGen( val )
            if ~( ...
                    isfield( val, 'front' ) && isa( val.front, 'ValGen' ) && ...
                    isfield( val, 'back' ) && isa( val.back, 'ValGen' ) && ...
                    isfield( val, 'right' ) && isa( val.right, 'ValGen' ) && ...
                    isfield( val, 'left' ) && isa( val.left, 'ValGen' ) && ...
                    isfield( val, 'height' ) && isa( val.height, 'ValGen' ) && ...
                    isfield( val, 'rt60' ) && isa( val.rt60, 'ValGen' ) )
                error( 'val does not provide all needed fields' );
            end
            obj = obj@ValGen( 'manual', val );
            obj.type = 'specific';
        end
        
        function val = genVal( obj )
            wall = simulator.Wall();
            wall.set( 'UnitUp', [0;1;0] );
            wall.set( 'UnitFront', [0;0;1] );
            f = obj.val.front.genVal();
            r = obj.val.right.genVal();
            b = obj.val.back.genVal();
            l = obj.val.left.genVal();
            if f <= b, error( 'front Wall position must be > back' ); end;
            if l <= r, error( 'left Wall position must be > right' ); end;
            wall.Vertices = [f, r; f, l; b, l; b, r]';
            roomheight = obj.val.height.genVal();
            RT60 = obj.val.rt60.genVal();
            walls(1:4) = wall.createUniformPrism( roomheight, '2D', RT60 );
            val = walls;
        end
        
    end
    
    %%
    methods (Access = protected)
        
        
    end
    
end
