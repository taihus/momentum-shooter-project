class Camera
  attr_accessor :target_x, :target_y
  attr_reader :camera

  def initialize
    @world_matrix = nil
    @camera_matrix = nil
    @target_x= 0
    @target_y= 0
    @target_scale= 1.0
    @target_pan_offset_x= 0
    @target_pan_offset_y= 0
    @target_rotation= 0.0
    @x= 0
    @y= 0
    @scale= 1.0
    @rotation= 0.0
  end

  def point_mul x, y, m
    r = Matrix.mul(Matrix.vec3(x, y, 1), m)
    { x: r.x, y: r.y }
  end

  def world_matrix
    Matrix.mul(mat3_rotate(@rotation), mat3_scale(1.0 / @scale), mat3_translate(@x, @y))
  end

  def camera_matrix
    Matrix.mul(mat3_translate(-@x, -@y), mat3_scale(@scale), mat3_rotate(-@rotation))
  end

  def point_to_world_space x, y
    point_mul x, y, @world_matrix
  end

  def point_to_camera_space x, y
    point_mul x, y, @camera_matrix
  end

  def update_matrices!
    @camera_matrix = camera_matrix
    @world_matrix = world_matrix
  end

  def update_camera!
    @x = @x.lerp(@target_x, 0.1)
    @y = @y.lerp(@target_y, 0.1)
    @scale = @scale.lerp(@target_scale, 0.1)
    @rotation = @rotation.lerp(@target_rotation, 0.1)
    update_matrices!
  end

  def rect_to_world_space rect
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

  def rect_to_camera_space rect
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