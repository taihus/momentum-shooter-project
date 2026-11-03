class Pursuer
    attr_dr
    attr_accessor :velocity, :state
    attr_reader :x, :y, :width, :height, :squad

    def initialize args, ordinal, squad
        @x = ordinal.x
        @y = ordinal.y
        @width = 10
        @height = 10
        @velocity = { x: 0.0, y: 0.0 }
        @squad = squad
        @state = "patrol"
    end

    def getSprite args
        return { 
            x: @x, y: @y, 
            anchor_x: 0.5, anchor_y: 0.5,
            w: @width, h: @height, 
            path: 'sprites/triangle/red.png',
            angle: 0
        }
    end

    def update args
        
    end
end