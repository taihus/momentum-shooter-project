require 'app/pursuer.rb'

# Using samples/99_genre_arcade/twinstick as a starting point
# samples/07_advanced_rendering/07_simple_camera
# samples/07_advanced_rendering/07_shake_camera
# samples/07_advanced_rendering/10_camera_and_large_map
# perlin noise sample
# box collision 3

# Design goal: high speed but rewards thinking 2 seconds ahead instead of fast
# reflexes. Reflexes are rewarded but focus needs to be on entering a flow
# state via constant moderation of how much information the player is presented
# with so that their mental picture of the next few seconds is able to be
# updated.

# Problem: player needs to be able to see what's coming in their direction
# of travel if travelling at high speed.
# Possible solution: inspired by Sorath; Devil Daggers and HYPER DEMON. Warp
# the camera's POV based on combination of velocity and acceleration.
# this is gonna be interesting to pull off

class Game
  attr_dr
  attr_accessor :time_factor, :world, :enemies

  def initialize args
    # @on_screen_gamepad_left = OnScreenGamepad.new args.inputs, side: :left
    # @on_screen_gamepad_right = OnScreenGamepad.new args.inputs, side: :right
    reset_game
    # perlin_
  end

  def reset_game
    $world  = { w: 1280, h: 720, tiles: [] }
    @time_factor = 1.0
    $squad_size = 8
    $squad_id = 0
    @player = { x: 700, y: 500, w: 20, h: 20,
                anchor_x: 0.5,
                anchor_y: 0.5,
                path: 'sprites/circle/solid.png',
                vx: 0,
                vy: 0,
                aim_dir: { x: 0, y: 0},
                aim_deviation: 1.5, # should be half the cone
                health: 10,
                health_perc: 1.0,
                cooldown: 0,
                boost_cooldown: 0,
                score: 0,
                # rotation: 90.to_radians 
              }
    # camera x and y correspond to the player's position on camera
    # @camera = { x: 640, y: 360, scale: 1.0 }
    @camera = {
      target_x: 0,
      target_y: 0,
      target_scale: 1.0,
      target_pan_offset_x: 0,
      target_pan_offset_y: 0,
      target_rotation: 0.0,
      x: 0,
      y: 0,
      scale: 1.0,
      rotation: 0.0
    }
    @spawn_timer = 180
    @enemies = []
    @bullets = []
    $map_loaded = false
    @camera_matrix = nil
    @world_matrix = nil
  end

  def tick
    update_matrices!
    @mouse_in_world = point_to_world_space(inputs.mouse.x, inputs.mouse.y)
    # @on_screen_gamepad_left.tick
    # @on_screen_gamepad_right.tick
    # generate_collision_test_map unless $map_loaded
    # generate_perlin_map unless $map_loaded
    generate_blank_map unless $map_loaded
    calc_player
    calc_enemies
    calc_camera
    render
    calc_game_over
    # input_edit_map
  end

  def calc_game_over
    if @player.health < 0
      reset_game
    end
  end

  def generate_collision_test_map
    $world  = { w: 400, h: 400,
                tile_size: 32,
                tiles: [] }
    # place_tile({ x: 6, y: 3 })
    place_tile({ x: 6, y: 4 })
    # place_tile({ x: 6, y: 5 })
    # place_tile({ x: 6, y: 6 })
    # place_tile({ x: 6, y: 7 })
    # place_tile({ x: 6, y: 8 })
    # place_tile({ x: 7, y: 3 })
    # place_tile({ x: 7, y: 4 })
    # place_tile({ x: 7, y: 5 })
    # place_tile({ x: 7, y: 6 })
    # place_tile({ x: 7, y: 7 })
    # place_tile({ x: 7, y: 8 })
    recompute_tiles
    $map_loaded = true
  end

  def generate_blank_map
    $world  = { w: 4800, h: 4800,
                tile_size: 32,
                tiles: [] }
    recompute_tiles
    $map_loaded = true;
  end

  def generate_perlin_map
    $world  = { w: 2400, h: 1200,
                tile_size: 32,
                tiles: [] }
    tile_width = $world.w.idiv($world.tile_size)
    tile_height = $world.h.idiv($world.tile_size)
    tile_width.times do |x|
      tile_height.times do |y|
        ordinal = { x: x , y: y }
        normalized_x = (x - $world.w.idiv(2)).fdiv($world.w)
        normalized_y = (y - $world.h.idiv(2)).fdiv($world.h)
        normalized_z = 0
        lacunarity = 7.0
        gain = 0.6
        offset = 1.0
        octaves = 6
        result = Geometry.perlin_ridge_noise( normalized_x,
                                              normalized_y,
                                              normalized_z,
                                              lacunarity,
                                              gain,
                                              offset,
                                              octaves)
        if result > 0.55
          place_tile ordinal
        end
      end
    end
    recompute_tiles
    $map_loaded = true;
  end

  def input_edit_map
    state.mouse_held = true  if inputs.mouse.down
    state.mouse_held = false if inputs.mouse.up

    return unless state.mouse_held

    cursor_in_scene = calc_cursor_in_scene

    ordinal = { x: (cursor_in_scene.x.idiv $world.tile_size),
                y: (cursor_in_scene.y.idiv $world.tile_size) }

    place_tile ordinal
    recompute_tiles
  end

  def place_tile ordinal
    found = find_tile ordinal
    if !found
      $world.tiles << state.new_entity(:tile).merge(ordinal)
    end
  end

  def recompute_tiles
    $world.tiles.each do |t|
      t.w = $world.tile_size
      t.h = $world.tile_size
      t.neighbors = tile_neighbors t, $world.tiles

      t.rect = {x: t.x * $world.tile_size,
                y: t.y * $world.tile_size,
                w: $world.tile_size,
                h: $world.tile_size}.to_hash

      sprite_sub_path = t.neighbors.mask.map { |m| flip_bit m }.join("")

      t.sprite = {
        x: t.x * $world.tile_size,
        y: t.y * $world.tile_size,
        w: $world.tile_size,
        h: $world.tile_size,
        path: "sprites/tile/wall-#{sprite_sub_path}.png"
      }
    end
  end

  def flip_bit bit
    return 0 if bit == 1
    return 1
  end

  def find_tile ordinal
    $world.tiles.find { |t| t.x == ordinal.x && t.y == ordinal.y }
  end

  def find_tiles &block
    $world.tiles.find_all(&block)
  end

  def find_colliding_tile tiles, target
    tiles.find { |t| t.rect.intersect_rect? target }
  end

  def tile_neighbors tile, other_points
    t = find_tile x: tile.x + 0, y: tile.y + 1
    r = find_tile x: tile.x + 1, y: tile.y + 0
    b = find_tile x: tile.x + 0, y: tile.y - 1
    l = find_tile x: tile.x - 1, y: tile.y + 0

    tile_t, tile_r, tile_b, tile_l = 0

    tile_t = 1 if t
    tile_r = 1 if r
    tile_b = 1 if b
    tile_l = 1 if l

    state.new_entity(:neighbors).merge({mask: [tile_t, tile_r, tile_b, tile_l],
                                 t:    t ? :some : :none,
                                 b:    b ? :some : :none,
                                 l:    l ? :some : :none,
                                 r:    r ? :some : :none})
  end

  def health_progress_bar_primitives

  end

  def calc_scene_position
    result = {  x: @camera.x - (@player.x * @camera.scale),
                y: @camera.y - (@player.y * @camera.scale),
                w: $world.w * @camera.scale,
                h: $world.h * @camera.scale,
                scale: @camera.scale }

    return result
  end

  def calc_cursor_in_scene
    to_world_space inputs.mouse.rect
    # result = { x: @player.x + (inputs.mouse.x - @camera.x),
    #           y: @player.y + (inputs.mouse.y - @camera.y)}
    # return result
  end

  def calc_enemies
    spawn_enemies
    kill_enemies
    move_enemies
  end

  def spawn_enemies
    should_spawn_enemy ||= Kernel.tick_count == 0
    should_spawn_enemy ||= Kernel.tick_count.zmod?(@spawn_timer.clamp(30 * (1.0 + time_factor), 180 * (1.0 + time_factor)))
    return if !should_spawn_enemy

    angle = rand 360
    enemy_xpos = @player.x + angle.vector_x * 800
    enemy_ypos = @player.y + angle.vector_y * 800
    # puts("spawning #{enemy_xpos}, #{enemy_ypos}")
    ordinal = {x: enemy_xpos, y: enemy_ypos}
    num_spawned = 0
    while num_spawned < $squad_size
      new_enemy = Pursuer.new(ordinal, $squad_id)
      @enemies << new_enemy
      puts("spawning #{new_enemy}")
      delta_x = 50.0 * Numeric.rand(0..2)
      delta_y = 50.0 * Numeric.rand(0..2) 
      delta_y += 50.0 * Numeric.rand(1..2) while (delta_x == 0.0 && delta_y == delta_x)
      ordinal.x += delta_x
      ordinal.y += delta_y
      num_spawned += 1
    end
    $squad_id += 1
    # @enemies << {
    #   x: 600 + angle.vector_x * 800,
    #   y: 320 + angle.vector_y * 800,
    #   w: 80, h: 80, path: "sprites/circle/solid.png",
    #   r: 128 + rand(128), g: 128 + rand(128), b: 128 + rand(128)
    # }
  end

  def kill_enemies
    enemy_collision = Geometry.find_intersect_rect(@player, @enemies)
    if enemy_collision
      @enemies.delete enemy_collision
      @player.health -= 1
    end
    # @enemies.each do |enemy|
    #   if Geometry.intersect_rect?(@player, enemy.getRect)
    #     @enemies.delete enemy
    #     @player.health -= 1
    #   end
    # end

    @bullets.each do |bullet|
      bullet_collision = Geometry.find_intersect_rect(bullet, @enemies)
      next if !bullet_collision

      @enemies.delete bullet_collision
      # bullet.kills ||= 0
      # bullet.kills += 1
      bullet.killed ||= true
      # @player.score += bullet.kills
      @spawn_timer -= 2.0 / $squad_size
      # @player.health += 1 if @player.health < 10 && bullet.kills > 1
      # @time_factor = 0.0
    end
    @bullets.reject!{ |bullet| bullet.killed }

    @player.health_perc = @player.health_perc.lerp(@player.health.fdiv(10), 0.1)
  end

  def move_enemies
    @enemies.each do |enemy|
      enemy.update @player, $game
    end
  end

  def calc_player
    if inputs.mouse.button_right
      @time_factor -= 0.024 unless @time_factor <= 0.15
      # @time_factor = @time_factor.lerp(0.3, 0.1, tolerance: 0.0001) unless @time_factor >= 0.3
    end
    if !inputs.mouse.button_right
      # @time_factor += @time_factor.lerp(0.3, 0.1, tolerance: 0.0001) unless @time_factor >= 0.3
      @time_factor += 0.03 unless @time_factor >= 1.0
      @time_factor.clamp 0.0, 1.0
    end
    if inputs.keyboard.key_down.minus
      @camera.target_scale *= 0.9
    elsif inputs.keyboard.key_down.equal
      @camera.target_scale *= 1.1
    end
    # TODO if collision issues due to velocity:
    #   consider using the quarter-step collision logic 
    #   in the matrix camera w/rotation sample file
    calc_player_v
    calc_player_rect
    calc_player_aim
    calc_below
    calc_left
    calc_right
    calc_above
    move_player
    fire_player
    move_player_bullets
  end

  def calc_player_aim
    cursor_pos = calc_cursor_in_scene
    dir = { x: cursor_pos.x - @player.x, y: cursor_pos.y - @player.y }
    dir = Geometry.vec2_normalize dir
    @player.aim_dir = dir
  end
  
  def calc_player_rect
    @player.rect      = current_player_rect
    @player.next_rect = @player.rect.merge x: @player.x + @player.vx,
                                         y: @player.y + @player.vy
    @player.prev_rect = @player.rect.merge x: @player.x - @player.vx,
                                         y: @player.y - @player.vy
  end

  def calc_below
    return unless @player.vy < 0
    tiles_below = find_tiles { |t| t.rect.top <= @player.prev_rect.y }
    collision = find_colliding_tile tiles_below, (@player.rect.merge y: @player.next_rect.y)
    return unless collision
    @player.y  = collision.rect.top + (@player.rect.h * 0.5)
    @player.vy = 0
  end

  def calc_left
    return unless @player.vx < 0
    tiles_left = find_tiles { |t| t.rect.right <= @player.prev_rect.x }
    # puts("player prev rect")
    # puts(@player.prev_rect)
    # puts("player prev rect left")
    # puts(@player.prev_rect.left)
    collision = find_colliding_tile tiles_left, (@player.rect.merge x: @player.next_rect.x)
    # puts(collision)
    return unless collision
    # puts("colliding left")
    @player.x  = collision.rect.right + (@player.rect.w * 0.5)
    @player.vx = 0
  end

  def calc_right
    return unless @player.vx > 0
    # puts("player prev rect")
    # puts(@player.prev_rect)
    # puts("player prev rect right")
    # puts(@player.prev_rect.right)
    tiles_right = find_tiles { |t| t.rect.left >= @player.prev_rect.x }
    # puts("right collision check; tiles:")
    # puts(tiles_right)
    # puts("player rect")
    # puts(@player.rect)
    # puts("player next rect")
    # puts(@player.rect.merge x: @player.next_rect.x)
    collision = find_colliding_tile tiles_right, (@player.rect.merge x: @player.next_rect.x)
    # puts(collision)
    return unless collision
    # puts("colliding right")
    @player.x  = collision.rect.left - (@player.rect.w * 0.5)
    @player.vx = 0
  end

  def calc_above
    return unless @player.vy > 0
    tiles_above = find_tiles { |t| t.rect.y >= @player.prev_rect.y }
    collision = find_colliding_tile tiles_above, (@player.rect.merge y: @player.next_rect.y)
    # puts(collision)
    return unless collision
    @player.vy = 0
    @player.y  = collision.rect.bottom - (@player.rect.h * 0.5)
  end

  def calc_player_v
    dir = inputs.keyboard.directional_vector_wasd
          # || inputs.controller_one.directional_vector_left_analog_cardinal
          # || @on_screen_gamepad_left.dpad_vector

    # return if !dir

    boost = 1.0;
    @player.boost_cooldown -= 1;

    if inputs.keyboard.key_down.left_shift && @player.boost_cooldown <= 0
      boost = 50.0;
      boost_cooldown = 120;
    end

    if dir
      @player.vx += dir.x * 0.75 * boost
      @player.vy += dir.y * 0.75 * boost
    end

    friction_factor = 0.87;

    if inputs.keyboard.key_held.space
      friction_factor = 1.0;
    end

    @player.vx = @player.vx * friction_factor
    @player.vy = @player.vy * friction_factor
  end

  # Idea: normal movement doesn't work when boost mode is enabled?
  # idea: movement works differently in boost mode?
  # or do we just clamp the max speed attainable with walking?
  def move_player
    @player.x += @player.vx * @time_factor
    @player.y += @player.vy * @time_factor
    # @player.x = @player.x.clamp @player.w * 0.5, $world.w - (@player.w * 0.5)
    # @player.y = @player.y.clamp @player.h * 0.5, $world.h - (@player.h * 0.5)
  end

  def fire_player

    @player.cooldown -= 1 * @time_factor

    return if @player.cooldown > 0

    @player.aim_deviation -= 0.2 * @time_factor unless @player.aim_deviation < 1.5

    @player.aim_deviation = 1.5 if @player.aim_deviation < 1.5

    # dir = inputs.keyboard.directional_vector_arrow ||
    #       inputs.controller_one.directional_vector_right_analog_cardinal
    #       # || @on_screen_gamepad_right.dpad_vector

    return if !inputs.mouse.button_left
    # outputs.debug << "this is a debug output"

    bullet_speed = 60.0
    player_momentum_quotient = 7.5
    bullet_angle = Geometry.vec2_angle(@player.aim_dir) + Numeric.rand((@player.aim_deviation * -1.0)..@player.aim_deviation)
    bullet_dir = Geometry.angle_vec2(bullet_angle)
    bullet = {
      x: @player.x + @player.w * bullet_dir.x * 0.5,
      y: @player.y + @player.h * bullet_dir.y * 0.5,
      anchor_x: 0.5, anchor_y: 0.5,
      w: 5, h: 5, path: "sprites/circle/solid.png", r: 232, g: 232, b: 232,
      vx: bullet_dir.x * bullet_speed + @player.vx / player_momentum_quotient,
      vy: bullet_dir.y * bullet_speed + @player.vy / player_momentum_quotient,
      lifetime: 3.seconds
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
    @bullets << bullet

    @player.aim_deviation += 0.5 * (3.0 / @player.aim_deviation)

    @player.vx += bullet_dir.x * 2.0 * -1
    @player.vy += bullet_dir.y * 2.0 * -1

    @player.cooldown = 5
  end

  def move_player_bullets
    @bullets.each do |bullet|
      bullet.x += bullet.vx * @time_factor
      bullet.y += bullet.vy * @time_factor
    end

    # @bullets.reject! do |bullet|
    #   bullet.x < -100 || bullet.y < -100 || bullet.x > $world.w + 100 || bullet.y > $world.h + 100
    # end

    @bullets.reject! do |bullet|
      bullet.lifetime < 0
    end

    @bullets.each do |bullet|
      bullet_vel = { x: bullet.vx, y: bullet.vy }
      bullet_speed = Geometry.vec2_magnitude(bullet_vel)
      bullet.tracer.x = bullet.x
      bullet.tracer.y = bullet.y
      bullet.tracer.angle = Geometry.vec2_angle(bullet_vel)
      # bullet.tracer.rotation = (bullet.tracer.angle + 90).to_radians
      bullet.tracer.w = 2.0 * bullet_speed
      bullet.lifetime -= 1 * time_factor
    end
  end

  def current_player_rect
    { x: @player.x, y: @player.y, w: @player.w, h: @player.h, anchor_x: @player.anchor_x, anchor_y: @player.anchor_y}.to_hash
  end

  # helper method that gives the player's circle collision shape
  def player_hit_circ
    { x: @player.x + @player.w / 2,
      y: @player.y + @player.h / 2,
      radius: @player.w / 2 }
  end

  # do I want everything to tell the camera what to do
  # ie camera behavior is emergent based on competing target weights
  # or do I create dedicated camera logic?
  def calc_camera
    @camera.target_x = @player.x
    @camera.target_y = @player.y

    # turning does the same thing, rotates the player, rotates the camera,
    # and invalidates the camera matrix
    # if inputs.keyboard.e
    #   @camera.target_rotation -= 0.05
    # elsif inputs.keyboard.q
    #   @camera.target_rotation += 0.05
    # end

    @camera.x = @camera.x.lerp(@camera.target_x, 0.1)
    @camera.y = @camera.y.lerp(@camera.target_y, 0.1)
    @camera.scale = @camera.scale.lerp(@camera.target_scale, 0.1)
    @camera.rotation = @camera.rotation.lerp(@camera.target_rotation, 0.1)
  end

  
  # TODO position camera based on cursor and player, not just player
  def render
    # cursor in scene is important for calculations, but final UI elements should render ON TOP of scene
    # this is important to avoid scaling the UI with the scene.
    cursor_world_rect = calc_cursor_in_scene
    outputs.watch DR.current_framerate
    # outputs.watch cursor_world_rect
    # outputs.watch current_player_rect
    # guide_line_center = { 
    #                       x: @player.x, 
    #                       y: @player.y, 
    #                       x2: cursor_pos.x, 
    #                       y2: cursor_pos.y
    #                     }
    line_len = Geometry.distance({ x: @player.x, y: @player.y },cursor_world_rect)

    aim_angle = Geometry.vec2_angle(@player.aim_dir)

    guide_left_dir = Geometry.angle_vec2(aim_angle + @player.aim_deviation)

    guide_line_left = {
                        x: @player.x + guide_left_dir.x * line_len * 0.5, 
                        y: @player.y + guide_left_dir.y * line_len * 0.5,
                        x2: @player.x + guide_left_dir.x * line_len * 1.2, 
                        y2: @player.y + guide_left_dir.y * line_len * 1.2,
                        r: 102, g: 255, b: 51
                      }

    guide_right_dir = Geometry.angle_vec2(aim_angle - @player.aim_deviation)

    guide_line_right = {
                        x: @player.x + guide_right_dir.x * line_len * 0.5, 
                        y: @player.y + guide_right_dir.y * line_len * 0.5,
                        x2: @player.x + guide_right_dir.x * line_len * 1.2, 
                        y2: @player.y + guide_right_dir.y * line_len * 1.2,
                        r: 102, g: 255, b: 51
                      }

    outputs[:scene].background_color = [30, 30, 30]

    outputs[:scene].w = Grid.allscreen_w
    outputs[:scene].h = Grid.allscreen_h
    
    camera_space_player = to_camera_space(@player)
    # puts("#{@enemies.map { |e| e.getSprite}}")
    outputs[:scene].primitives << camera_space_player
    outputs[:scene].primitives << @enemies.map { |e| to_camera_space(e.getSprite) }
    # puts("#{outputs[:scene].primitives}")

    outputs[:scene].sprites << @bullets.map { |b| to_camera_space(b) }
    outputs[:scene].sprites << $world.tiles.map { |t| to_camera_space(t.sprite) }
    outputs[:scene].sprites << @bullets.map { |b| to_camera_space(b.tracer) }

    # outputs[:scene].lines << guide_line_center
    outputs[:scene].lines << line_to_camera_space(guide_line_left)
    outputs[:scene].lines << line_to_camera_space(guide_line_right)

    # scene_position = calc_scene_position
    outputs.sprites << { 
      x: 0, y: 0,
      w: Grid.allscreen_w, h: Grid.allscreen_h,
      path: :scene, anchor_x: 0.5, anchor_y: 0.5 }
    
    progress_bar = Geometry.rect(
      x: camera_space_player.x,
      y: camera_space_player.y + 30,
      w: 128,
      h: 16,
      anchor_x: 0.5,
      anchor_y: 0.5,
    ).merge(r: 0, g: 0, b: 0, path: :solid)

    health_area = Geometry.zoom_rect(rect: progress_bar, px: -8)
    current_health = { **health_area, w: health_area.w * @player.health_perc }

    outputs.primitives << progress_bar
    outputs.primitives << health_area.merge(r: 255, g: 255, b: 255, path: :solid)
    outputs.primitives << current_health.merge(r: 80, g: 155, b: 80, path: :solid)

    # outputs.lines << { x: 0, y: -360, h: 720, r: 255, g: 255, b: 255 }
    # outputs.lines << { x: -640, y: 0, w: 1280, r: 255, g: 255, b: 255 }

    # if DR.platform?(:touch)
    #   outputs.primitives << { x: 640, y: 720, text: "Finger on left side of screen to move. Finger on right side of screen to shoot.", anchor_x: 0.5, anchor_y: 1.5, r: 255, g: 255, b: 255 }
    # elsif inputs.last_active == :keyboard || inputs.last_active == :mouse
    #   outputs.primitives << { x: 640, y: 720, text: "WASD to move, Arrow Keys to shoot.", anchor_x: 0.5, anchor_y: 1.5, r: 255, g: 255, b: 255 }
    # elsif inputs.last_active == :controller
    #   outputs.primitives << { x: 640, y: 720, text: "Left Analog to move, Right Analog to shoot.", anchor_x: 0.5, anchor_y: 1.5, r: 255, g: 255, b: 255 }
    # end

    # outputs.primitives << @on_screen_gamepad_left.primitives
    # outputs.primitives << @on_screen_gamepad_right.primitives
  end

  def world_matrix camera
    Matrix.mul(mat3_rotate(@camera.rotation), mat3_scale(1.0 / camera.scale), mat3_translate(camera.x, camera.y))
  end

  def camera_matrix camera
    Matrix.mul(mat3_translate(-camera.x, -camera.y), mat3_scale(camera.scale), mat3_rotate(-@camera.rotation))
  end

  def update_matrices!
    @camera_matrix = camera_matrix @camera
    @world_matrix = world_matrix @camera
  end

  def point_mul x, y, m
    r = Matrix.mul(Matrix.vec3(x, y, 1), m)
    { x: r.x, y: r.y }
  end

  def point_to_world_space x, y
    point_mul x, y, @world_matrix
  end

  def point_to_camera_space x, y
    point_mul x, y, @camera_matrix
  end

  def to_world_space rect
    projection_bottom_left = point_to_world_space(rect.x, rect.y)
    projection_top_right = point_to_world_space(rect.x + rect.w, rect.y + rect.h)
    # compute the new angle of the rect and use that to compute the angle of rotation
    # within the screen for the sprite
    # rect_angle = (rect.rotation || 0).to_degrees * -1
    # projection_angle = Geometry.angle(projection_bottom_left, projection_top_right)
    rect.merge x: projection_bottom_left.x,
               y: projection_bottom_left.y,
               w: (projection_bottom_left.x - projection_top_right.x).abs,
               h: (projection_bottom_left.y - projection_top_right.y).abs
              #  angle: projection_angle - 45 + rect_angle
  end

  def to_camera_space rect
    projection_bottom_left = point_to_camera_space(rect.x, rect.y)
    projection_top_right = point_to_camera_space(rect.x + rect.w, rect.y + rect.h)

    # compute the new angle of the rect and use that to compute the angle of rotation
    # within the screen for the sprite
    # rect_angle = (rect.rotation || 0).to_degrees
    # projection_angle = Geometry.angle(projection_bottom_left, projection_top_right)

    rect.merge x: projection_bottom_left.x,
               y: projection_bottom_left.y,
               w: (projection_bottom_left.x - projection_top_right.x).abs,
               h: (projection_bottom_left.y - projection_top_right.y).abs
              #  angle: projection_angle - 45 + rect_angle
  end

  def line_to_camera_space line
    projection_point_1 = point_to_camera_space(line.x, line.y)
    projection_point_2 = point_to_camera_space(line.x2, line.y2)

    line.merge x: projection_point_1.x,
               y: projection_point_1.y,
               x2: projection_point_2.x,
               y2: projection_point_2.y
  end
  
  def mat3_translate x, y
    Matrix.mat3 1, 0, x,
                0, 1, y,
                0, 0, 1
  end

  def mat3_scale s
    Matrix.mat3 s, 0, 0,
                0, s, 0,
                0, 0, 1
  end

  def mat3_rotate t
    Matrix.mat3 Math.cos(t), -Math.sin(t), 0,
                Math.sin(t), Math.cos(t), 0,
                0, 0, 1
  end
end

module Main
  def tick
    $game ||= Game.new args
    $game.args = args
    $game.tick
  end

  def boot
    $state = {}
    Grid.origin_center!
  end

  def reset
    $game = nil
  end
end

# On screen game pad implementation from DragonRuby's sample code
# class OnScreenGamepad
#   attr :inputs, :directional_vector, :directional_angle, :dpad_vector

#   def initialize inputs, side: :left
#     @side = side
#     @inputs = inputs
#   end

#   def tick
#     if finger
#       @joystick ||= {
#         center: { x: finger.x, y: finger.y },
#         a: 0
#       }
#       @joystick.distance = Geometry.distance(finger, @joystick.center)
#       @joystick.angle = Geometry.angle(finger, @joystick.center)
#       @joystick.vector = @joystick.angle.to_vector
#       if @joystick.distance > 160
#         @joystick.center.x = @joystick.center.x.lerp(finger.x + @joystick.vector.x * 160, 0.1)
#         @joystick.center.y = @joystick.center.y.lerp(finger.y + @joystick.vector.y * 160, 0.1)
#       end

#       perc = @joystick.distance.clamp(0, 48).fdiv(48)
#       @directional_angle = (@joystick.angle + 180) % 360

#       @directional_vector = {
#         x: @directional_angle.to_vector.x * perc ** 4,
#         y: @directional_angle.to_vector.y * perc ** 4,
#       }

#       if perc > 0.8
#         @dpad_vector = {
#           x: Geometry.angle_cardinal_vec2(@directional_angle).x,
#           y: Geometry.angle_cardinal_vec2(@directional_angle).y,
#         }
#       else
#         @dpad_vector = nil
#       end

#       @joystick.a = @joystick.a.lerp(128, 0.01)
#     elsif @joystick
#       @joystick.a = @joystick.a.lerp(0, 0.25)
#       @directional_vector = nil
#       @dpad_vector = nil
#       @joystick = nil if @joystick.a < 1
#     end
#   end

#   def joystick_primitive
#     return nil if !@joystick
#     {
#       **@joystick.center,
#       w: 64,
#       h: 64,
#       path: "sprites/circle/solid.png",
#       anchor_x: 0.5,
#       anchor_y: 0.5,
#       r: 255,
#       g: 255,
#       b: 255,
#       a: @joystick.a
#     }
#   end

#   def finger
#     if @side == :left
#       inputs.finger_left
#     else
#       inputs.finger_right
#     end
#   end

#   def direction_indicator_primitive
#     return nil if !finger
#     return nil if !@joystick

#     joystick_center = if @joystick.distance > 48
#                         { x: @joystick.center.x + 48 * -@joystick.vector.x,
#                           y: @joystick.center.y + 48 * -@joystick.vector.y }
#                       else
#                         finger
#                       end

#     {
#       x: joystick_center.x,
#       y: joystick_center.y,
#       w: 16,
#       h: 16,
#       path: "sprites/circle/solid.png",
#       r: 255,
#       g: 0,
#       b: 0,
#       a: @joystick.a,
#       anchor_x: 0.5,
#       anchor_y: 0.5
#     }
#   end

#   def primitives
#     [
#       joystick_primitive,
#       direction_indicator_primitive
#     ]
#   end
# end

DR.reset
