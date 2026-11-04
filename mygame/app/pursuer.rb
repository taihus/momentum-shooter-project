class Pursuer
    attr_dr
    attr_accessor :velocity, :state
    attr_reader :x, :y, :w, :h, :squad

    def initialize ordinal, squad
        @x = ordinal.x
        @y = ordinal.y
        @w = 30
        @h = 30
        @angle = 0
        @velocity = { x: 0.0, y: 0.0 }
        @squad = squad
        @state = "patrol"
        puts("spawned #{@x}, #{@y}")
    end

    def getSprite
        return { 
            x: @x, y: @y, 
            anchor_x: 0.5, anchor_y: 0.5,
            w: @w, h: @h, 
            path: 'sprites/triangle/equilateral/red.png',
            angle: @angle + 90
        }
    end

    def getRect
        return { 
            x: @x, y: @y, 
            anchor_x: 0.5, anchor_y: 0.5,
            w: @w, h: @h, 
            angle: @angle + 90
        }
    end

    def update player, world
      case @state
      when "patrol"
        angle = Geometry.angle player, { x: @x, y: @y}
        @angle = angle
        @x -= angle.vector_x * 2.5
        @y -= angle.vector_y * 2.5
    #   puts("moving enemy towards #{@x}, #{@y}")
      else
        puts("oh no")
      end
    end
end