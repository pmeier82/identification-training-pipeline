classdef (Abstract) IdFeatureProcInterface < IdProcInterface

    %%---------------------------------------------------------------------
    properties (SetAccess = private, Transient)
        buildWp1FileName;
        buildWp2FileName;
    end
    
    %%---------------------------------------------------------------------
    methods (Static)
    end
    
    %%---------------------------------------------------------------------
    methods (Access = public)
        
        function obj = IdFeatureProcInterface()
            obj = obj@IdProcInterface();
        end

        %%-----------------------------------------------------------------
            
        function setWp1FileNameBuilder( obj, wp1FileNameBuilder )
            obj.buildWp1FileName = wp1FileNameBuilder;
        end
            
        function setWp2FileNameBuilder( obj, wp2FileNameBuilder )
            obj.buildWp2FileName = wp2FileNameBuilder;
        end
        
        %%-----------------------------------------------------------------
        
    end
    
    %%---------------------------------------------------------------------
    methods (Access = private)
    end
    
    %%---------------------------------------------------------------------
    methods (Abstract)
        
        wp2Requests = getWp2Requests( obj )
        run ( obj, data )
    
    end
    
end

