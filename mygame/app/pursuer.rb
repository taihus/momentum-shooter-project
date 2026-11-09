class Pursuer
  attr_accessor :x, :y, :w, :h, :angle
  attr_reader :anchor_x, :anchor_y, :squad, :velocity, :path

  def initialize ordinal, squad
    @x = ordinal.x
    @y = ordinal.y
    @w = 16
    @h = 32
    @angle = -90.0
    @velocity = { x: 0.0, y: 0.0 }
    @squad = squad
    @ai_state = "patrol"
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
            # rotation: (@angle - 90).to_radians 
          }
  end

  # TODO update patrol to integrate boids behavior
  # TODO implement framework for state machine
  def update player, game
    case @ai_state
    when "patrol"
      angle_to_player = Geometry.angle player, { x: @x, y: @y}
      # @angle = angle - 90
      @velocity.x -= angle_to_player.vector_x * 0.05
      @velocity.y -= angle_to_player.vector_y * 0.05

      squad = getSquad(game.enemies)
      squad_vel_component = Geometry.vec2_scale(getSquadVel(squad),0.0005)
      @velocity = Geometry.vec2_add(@velocity, squad_vel_component)

      angle_to_squad_center = Geometry.angle({ x: @x, y: @y}, getSquadPos(squad))
      @velocity.x -= angle_to_squad_center.vector_x * 0.0005
      @velocity.y -= angle_to_squad_center.vector_y * 0.0005

      speed_factor = (15.0/Geometry.vec2_magnitude(@velocity)).clamp(0.0,1.0)
      @velocity = Geometry.vec2_scale(@velocity, speed_factor)

      @x += @velocity.x * game.time_factor
      @y += @velocity.y * game.time_factor
      @angle = Geometry.vec2_angle(@velocity) - 90.0
    else
      puts("oh no")
    end
  end

  def getSquad enemies
    squad = enemies.reject {|enemy| enemy.squad != @squad }
  end

  def getSquadVel squad
    squad_vel = { x: 0.0, y: 0.0 }
    squad.each do |enemy|
      squad_vel = Geometry.vec2_add(squad_vel,enemy.velocity)
    end
    squad_vel = Geometry.vec2_scale(squad_vel, 1.0/squad.size)
    return squad_vel
  end

  def getSquadPos squad
    squad_pos = { x: 0.0, y: 0.0 }
    squad.each do |enemy|
      squad_pos = Geometry.vec2_add(squad_pos,enemy)
    end
    squad_pos = Geometry.vec2_scale(squad_pos, 1.0/squad.size)
    return squad_pos
  end

  def getNearbyEnemies enemies
    enemies.reject { |enemy| enemy.point_inside_circle?({x:@x,y:@y}, @w*2.0) }
  end
end