# Using samples/99_genre_arcade/twinstick as a starting point
# samples/07_advanced_rendering/07_simple_camera
# samples/07_advanced_rendering/07_shake_camera
# samples/07_advanced_rendering/10_camera_and_large_map

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

  def initialize args
    # @on_screen_gamepad_left = OnScreenGamepad.new args.inputs, side: :left
    # @on_screen_gamepad_right = OnScreenGamepad.new args.inputs, side: :right
    reset_game
    generate_map
  end

  def reset_game
    # @world  = { w: 1280, h: 720 }
    generate_map
    @player = { x: 40, y: 40, w: 40, h: 40,
                anchor_x: 0.5,
                anchor_y: 0.5,
                path: 'sprites/circle/solid.png',
                vx: 0,
                vy: 0,
                aim_dir: { x: 0, y: 0 },
                health: 10,
                health_perc: 1.0,
                cooldown: 0,
                score: 0 }
    # camera x and y correspond to the player's position on camera
    @camera = { x: 640, y: 360, scale: 1.0 }
    @spawn_timer = 120
    @enemies = []
    @bullets = []
  end

  def tick
    # @on_screen_gamepad_left.tick
    # @on_screen_gamepad_right.tick
    # calc_enemies
    calc_player
    render
    calc_game_over
    input_edit_map
  end

  def calc_game_over
    if @player.health < 0
      reset_game
    end
  end

  def generate_map
    @world  = { w: 1280, h: 720,
                tile_size: 32,
                tiles: [] }
    # tile_width = @world.w.idiv(@world.tile_size)
    # tile_height = @world.h.idiv(@world.tile_size)
    # tile_width.times do |x|
    #   tile_height.times do |y|
    #     ordinal = { x: x , y: y }
    #     normalized_x = (x - @world.w.idiv(2)).fdiv(@world.w)
    #     normalized_y = (y - @world.h.idiv(2)).fdiv(@world.h)
    #     normalized_z = 0
    #     lacunarity = 7.0
    #     gain = 0.6
    #     offset = 1.0
    #     octaves = 6
    #     result = Geometry.perlin_ridge_noise( normalized_x,
    #                                           normalized_y,
    #                                           normalized_z,
    #                                           lacunarity,
    #                                           gain,
    #                                           offset,
    #                                           octaves)
    #     if result > 0.0
    #       place_tile ordinal
    #     end
    #   end
    # end
    # recompute_tiles
  end

  def input_edit_map
    state.mouse_held = true  if inputs.mouse.down
    state.mouse_held = false if inputs.mouse.up

    return unless state.mouse_held
    cursor_pos = calc_cursor_in_scene
    ordinal = { x: (cursor_pos.x.idiv @world.tile_size),
                y: (cursor_pos.y.idiv @world.tile_size) }

    place_tile ordinal
    recompute_tiles
  end

  def place_tile ordinal
    found = find_tile ordinal
    if !found
      @world.tiles << (state.new_entity(:tile).merge(ordinal))
    end
  end

  def recompute_tiles
    @world.tiles.each do |t|
      t.w = @world.tile_size
      t.h = @world.tile_size
      t.neighbors = tile_neighbors t, @world.tiles

      t.rect = {x: t.x * @world.tile_size,
                y: t.y * @world.tile_size,
                w: @world.tile_size,
                h: @world.tile_size}

      sprite_sub_path = t.neighbors.mask.map { |m| flip_bit m }.join("")

      t.sprite = {
        x: t.x * @world.tile_size,
        y: t.y * @world.tile_size,
        w: @world.tile_size,
        h: @world.tile_size,
        path: "sprites/tile/wall-#{sprite_sub_path}.png"
      }
    end
  end

  def flip_bit bit
    return 0 if bit == 1
    return 1
  end

  def find_tile ordinal
    @world.tiles.find { |t| t.x == ordinal.x && t.y == ordinal.y }
  end

  def find_tiles &block
    @world.tiles.find_all(&block)
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

  def render
    progress_bar = Geometry.rect(
      x: @camera.x,
      y: @camera.y + 30,
      w: 128,
      h: 32,
      anchor_x: 0.5,
      anchor_y: 0.5,
    ).merge(r: 0, g: 0, b: 0, path: :solid)

    health_area = Geometry.zoom_rect(rect: progress_bar, px: -8)
    current_health = { **health_area, w: health_area.w * @player.health_perc }

    outputs.primitives << progress_bar
    outputs.primitives << health_area.merge(r: 255, g: 255, b: 255, path: :solid)
    outputs.primitives << current_health.merge(r: 80, g: 155, b: 80, path: :solid)

    # TODO: create and store a hash representing the position of the cursor IN THE SCENE, not on screen

    # concept: two lines extending out from player past location of cursor.

    # cursor in scene is important for calculations, but final UI elements should render ON TOP of scene
    # this is important to avoid scaling the UI with the scene.

    cursor_pos = calc_cursor_in_scene
    guide_line_left = { x: @player.x, y: @player.y, x2: cursor_pos.x, y2: cursor_pos.y}

    outputs[:scene].background_color = [30, 30, 30]

    outputs[:scene].primitives << [@player, @enemies, @bullets, @world.tiles.map(&:sprite)]

    outputs[:scene].lines << guide_line_left

    outputs[:scene].w = @world.w
    outputs[:scene].h = @world.h

    scene_position = calc_scene_position
    outputs.sprites << { x: scene_position.x,
                            y: scene_position.y,
                            w: scene_position.w,
                            h: scene_position.h,
                            path: :scene }

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

  def health_progress_bar_primitives

  end

  def calc_scene_position
    result = { x: @camera.x - (@player.x * @camera.scale),
              y: @camera.y - (@player.y * @camera.scale),
              w: @world.w * @camera.scale,
              h: @world.h * @camera.scale,
              scale: @camera.scale }

    return result
  end

  def calc_cursor_in_scene
    result = { x: @player.x + (inputs.mouse.x - @camera.x),
              y: @player.y + (inputs.mouse.y - @camera.y)}
    return result
  end

  def spawn_enemies
    should_spawn_enemy ||= Kernel.tick_count == 0
    should_spawn_enemy ||= Kernel.tick_count.zmod?(@spawn_timer.clamp(30, 120))
    return if !should_spawn_enemy

    angle = rand 360
    @enemies << {
      x: 600 + angle.vector_x * 800,
      y: 320 + angle.vector_y * 800,
      w: 80, h: 80, path: "sprites/circle/solid.png",
      r: 128 + rand(128), g: 128 + rand(128), b: 128 + rand(128)
    }
  end

  def kill_enemies
    enemy_collision = Geometry.find_intersect_rect(@player, @enemies)
    if enemy_collision
      @enemies.delete enemy_collision
      @player.health -= 1
    end

    @bullets.each do |bullet|
      bullet_collision = Geometry.find_intersect_rect(bullet, @enemies)
      next if !bullet_collision

      @enemies.delete bullet_collision
      bullet.kills ||= 0
      bullet.kills += 1
      @player.score += bullet.kills
      @spawn_timer -= bullet.kills * 2
      @player.health += 1 if @player.health < 10 && bullet.kills > 1
    end

    @player.health_perc = @player.health_perc.lerp(@player.health.fdiv(10), 0.1)
  end

  def move_enemies
    @enemies.each do |enemy|
      angle = Geometry.angle @player, enemy
      enemy.x -= angle.vector_x * 2.5
      enemy.y -= angle.vector_y * 2.5
    end
  end

  def calc_player
    calc_player_rect
    calc_below
    calc_left
    calc_right
    calc_above
    move_player
    # fire_player
    # move_player_bullets
  end

  def move_player_bullets
    @bullets.each do |bullet|
      bullet.x += bullet.vx
      bullet.y += bullet.vy
    end

    @bullets.reject! do |bullet|
      bullet.x < -20 || bullet.y < -20 || bullet.x > 1300 || bullet.y > 740
    end
  end

  def calc_player_rect
    @player.rect      = current_player_rect
    @player.next_rect = @player.rect.merge x: @player.x + @player.vx,
                                         y: @player.y + @player.vy
    @player.prev_rect = @player.rect.merge x: @player.x - @player.vx,
                                         y: @player.y - @player.vy
  end

  def calc_below
    return unless @player.vy <= 0
    tiles_below = find_tiles { |t| t.rect.top <= @player.prev_rect.y }
    collision = find_colliding_tile tiles_below, (@player.rect.merge y: @player.next_rect.y)
    return unless collision
    @player.y  = collision.rect.y + @world.tile_size
    @player.vy = 0
  end

  def calc_left
    return unless @player.vx < 0
    tiles_left = find_tiles { |t| t.rect.right <= @player.prev_rect.left }
    collision = find_colliding_tile tiles_left, (@player.rect.merge x: @player.next_rect.x)
    return unless collision
    @player.x  = collision.rect.right
    @player.vx = 0
  end

  def calc_right
    return unless @player.vx > 0
    tiles_right = find_tiles { |t| t.rect.left >= @player.prev_rect.right }
    collision = find_colliding_tile tiles_right, (@player.rect.merge x: @player.next_rect.x)
    return unless collision
    @player.x  = collision.rect.left - @player.rect.w
    @player.vx = 0
  end

  def calc_above
    return unless @player.vy > 0
    tiles_above = find_tiles { |t| t.rect.y >= @player.prev_rect.y }
    collision = find_colliding_tile tiles_above, (@player.rect.merge y: @player.next_rect.y)
    return unless collision
    @player.vy = 0
    @player.y  = collision.rect.bottom - @player.rect.h
  end

  # Idea: normal movement doesn't work when boost mode is enabled?
  # idea: movement works differently in boost mode?
  # or do we just clamp the max speed attainable with walking?
  def move_player
    friction_factor = 0.9;

    if inputs.keyboard.key_held.shift
      friction_factor = 1.0;
    end

    @player.vx = @player.vx * friction_factor
    @player.vy = @player.vy * friction_factor

    @player.x += @player.vx
    @player.y += @player.vy
    @player.x = @player.x.clamp 0, @world.w - @player.w
    @player.y = @player.y.clamp 0, @world.h - @player.h

    dir = inputs.keyboard.directional_vector_wasd ||
          inputs.controller_one.directional_vector_left_analog_cardinal
          # || @on_screen_gamepad_left.dpad_vector

    return if !dir

    boost = 1.0;

    if inputs.keyboard.key_down.space
      boost = 100.0;
    end

    @player.vx += dir.x * 0.75 * boost
    @player.vy += dir.y * 0.75 * boost
  end

  def fire_player
    dir = { x: inputs.mouse.x - @player.x, y: inputs.mouse.y - @player.y }
    dir = Geometry.vec2_normalize dir
    @player.aim_dir = dir

    @player.cooldown -= 1

    return if @player.cooldown > 0

    # dir = inputs.keyboard.directional_vector_arrow ||
    #       inputs.controller_one.directional_vector_right_analog_cardinal
    #       # || @on_screen_gamepad_right.dpad_vector

    # return if !inputs.mouse.button_left
    # outputs.debug << "this is a debug output"

    
    # print dir
    @bullets << {
      x: @player.x + 30 + 40 * dir.x,
      y: @player.y + 30 + 40 * dir.y,
      w: 20, h: 20, path: "sprites/circle/solid.png", r: 232, g: 232, b: 232,
      vx: dir.x * 10 + @player.vx / 7.5, vy: dir.y * 10 + @player.vy / 7.5
    }

    @player.cooldown = 30
  end
end

def current_player_rect
  { x: @player.x, y: @player.y, w: @player.w, h: @player.h }
end

module Main
  def tick
    @game ||= Game.new args
    @game.args = args
    @game.tick
  end

  def boot
    @state = {}
  end

  def reset
    @game = nil
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
