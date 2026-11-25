class Shooter
  attr_accessor :x, :y, :w, :h, :angle
  attr_reader :anchor_x, :anchor_y, :squad, :velocity, :path

  def initialize ordinal, squad
    @x = ordinal.x
    @y = ordinal.y
    @w = 16
    @h = 16
    @angle = -90.0
    @velocity = { x: 0.0, y: 0.0 }
    @squad = squad
    @ai_state = :patrol
    @anchor_x = 0.5
    @anchor_y = 0.5
    # @avoidance_radius = 64
    @detection_range = 50
    # @detection_angle = 20 # half of cone
    # @disengage_angle = 90
    # @windup_time = 1.seconds
    # @recovery_time = 1.seconds
    # puts("spawned #{@x}, #{@y}")
  end

  def getSprite
    return { 
            x: @x, y: @y, 
            anchor_x: 0.5, anchor_y: 0.5,
            w: @w, h: @h, 
            path: 'sprites/square/red.png',
            angle: @angle
            # rotation: (@angle - 90).to_radians 
          }
  end

  def update player, game
    think player
    case @ai_state
    when :open_fire
        puts("open fire test")
        @velocity.x = 0
        @velocity.y = 0
    when :patrol
        player_direction = Geometry.angle({x: @x, y: @y}, player)
        @velocity = Geometry.vec2_scale(Geometry.angle_vec2(player_direction),3)
    else
      puts("oh no")
      puts("Updating with invalid state: #{@ai_state}")
    end
    @x += @velocity.x * game.time_factor
    @y += @velocity.y * game.time_factor
    # puts("vroom #{@velocity}")
  end

  def think player
    distance_to_player = Geometry.distance(player, {x: @x, y: @y})

    case @ai_state
    when :open_fire
        @ai_state = :patrol if (distance_to_player > @detection_range)
    when :patrol
        @ai_state = :open_fire if (distance_to_player < @detection_range)
    else
      puts("ah fuck")
      puts("Thinking with invalid state: #{@ai_state}")
    end
  end

  def getSquad enemies
    squad = enemies.reject { |enemy| enemy.squad != @squad or enemy == self }
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
    enemies.reject { |enemy| !Geometry.point_inside_circle?(enemy, {x:@x,y:@y}, @avoidance_radius) }
  end

  def calcAvoidanceDir nearby
    avoid_x = 0.0;
    avoid_y = 0.0;
    return { x: avoid_x, y: avoid_y } if nearby.length == 0 
    nearby.each do |enemy|
      sqDist = @avoidance_radius.fdiv(Geometry.distance_squared({x:@x,y:@y}, enemy))
      avoid_x += (@x - enemy.x) * sqDist
      avoid_y += (@y - enemy.y) * sqDist
    end
    return Geometry.vec2_normalize({ x: avoid_x, y: avoid_y })
  end
end