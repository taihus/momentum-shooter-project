class Pursuer
    attr_dr
    attr_accessor :x, :y, :w, :h, :angle
    attr_reader :anchor_x, :anchor_y, :squad, :velocity, :path

    def initialize ordinal, squad
        @x = ordinal.x
        @y = ordinal.y
        @w = 32
        @h = 32
        @angle = 0
        @velocity = { x: 0.0, y: 0.0 }
        @squad = squad
        @state = "patrol"
        @anchor_x = 0.5
        @anchor_y = 0.5
        # puts("spawned #{@x}, #{@y}")
    end

    def getSprite
        return { 
            x: @x, y: @y, 
            anchor_x: 0.5, anchor_y: 0.5,
            w: @w, h: @h, 
            path: 'sprites/triangle/equilateral/red.png',
            angle: @angle
        }
    end

    # TODO update patrol to integrate boids behavior
    # TODO implement framework for state machine
    def update player, game
      case @state
      when "patrol"
        angle = Geometry.angle player, { x: @x, y: @y}
        @angle = angle + 90
        @velocity.x *= 0.8
        @velocity.y *= 0.8
        @velocity.x -= angle.vector_x * 0.5
        @x += @velocity.x * game.time_factor
        @velocity.y -= angle.vector_y * 0.5
        @y += @velocity.y * game.time_factor
    #   puts("moving enemy towards #{@x}, #{@y}")
      else
        puts("oh no")
      end
    end
end