class Shooter
  attr_accessor :x, :y, :w, :h, :angle, :velocity
  attr_reader :anchor_x, :anchor_y, :squad, :path

  def initialize ordinal, squad
    @x = ordinal.x
    @y = ordinal.y
    @w = 16
    @h = 16
    @angle = 0.0
    @velocity = { x: 0.0, y: 0.0 }
    @squad = squad
    @ai_state = :patrol
    @anchor_x = 0.5
    @anchor_y = 0.5
    # @avoidance_radius = 64
    @detection_range = 360
    # @detection_angle = 20 # half of cone
    # @disengage_angle = 90
    # @windup_time = 1.seconds
    # @aim_dir = {x: 0, y: 0}
    @aim_deviation = 0.5
    @recovery_time = 12
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
    @aim_deviation -= 0.05 * game.time_factor unless @aim_deviation < 0.2
    @aim_deviation = 0.2 if @aim_deviation < 0.2
    
    @recovery_time -= 1
    player_direction = Geometry.angle({x: @x, y: @y}, player)
    case @ai_state
    when :firing
      fire game
      @angle += 0.5 * Geometry.angle_turn_direction(@angle, player_direction) * game.time_factor
      @velocity = Geometry.vec2_scale(@velocity, 0.95)
    when :tracking_target
      @angle += 5 * Geometry.angle_turn_direction(@angle, player_direction) * game.time_factor
      @velocity = Geometry.vec2_scale(@velocity, 0.95)
    when :patrol
      @angle += 2 * Geometry.angle_turn_direction(@angle, player_direction) * game.time_factor
      @velocity = Geometry.vec2_scale(Geometry.angle_vec2(@angle),3)
    else
      puts("oh no")
      puts("Updating with invalid state: #{@ai_state}")
    end
  end

  def think player
    distance_to_player = Geometry.distance(player, {x: @x, y: @y})

    case @ai_state
    when :firing
      @ai_state = :tracking_target if Geometry.angle_delta(@angle,Geometry.angle({x: @x, y: @y}, player)).abs > 3.0
      @ai_state = :patrol if (distance_to_player > @detection_range)
    when :tracking_target
      @ai_state = :patrol if (distance_to_player > @detection_range)
      @ai_state = :firing if Geometry.angle_delta(@angle,Geometry.angle({x: @x, y: @y}, player)).abs < 3.0
    when :patrol
      @ai_state = :tracking_target if (distance_to_player < @detection_range)
    else
      puts("ah fuck")
      puts("Thinking with invalid state: #{@ai_state}")
    end
  end

  def fire game
    return if @recovery_time > 0

    bullet_speed = 40.0
    momentum_quotient = 5.0
    bullet_angle = @angle + Numeric.rand((@aim_deviation * -1.0)..@aim_deviation)
    bullet_dir = Geometry.angle_vec2(bullet_angle)
    bullet = {
      x: @x + @w * bullet_dir.x * 0.5,
      y: @y + @h * bullet_dir.y * 0.5,
      anchor_x: 0.5, anchor_y: 0.5,
      w: 5, h: 5, path: "sprites/circle/solid.png", r: 232, g: 232, b: 232,
      vx: bullet_dir.x * bullet_speed + @velocity.x / momentum_quotient,
      vy: bullet_dir.y * bullet_speed + @velocity.y / momentum_quotient,
      lifetime: 3.seconds, faction: :enemy
    }
    bullet_vel = { x: bullet.vx, y: bullet.vy }
    bullet_speed = Geometry.vec2_magnitude(bullet_vel)
    bullet.tracer = {
                x: bullet.x,
                y: bullet.y,
                anchor_x: 1.0, anchor_y: 0.5,
                angle: Geometry.vec2_angle(bullet_vel),
                angle_anchor_x: 1.0, angle_anchor_y: 0.5,
                # rotation: (Geometry.vec2_angle(bullet_vel) + 90).to_radians,
                w: 1.5 * bullet_speed, h: 5, path: "sprites/circle/solid.png", r: 255, g: 255, b: 96, a: 120
              }
    # print dir
    game.bullets << bullet

    @aim_deviation = @aim_deviation.lerp(10.0, 0.05)

    @velocity.x += bullet_dir.x * -0.5
    @velocity.y += bullet_dir.y * -0.5

    @recovery_time = 12
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