require 'ruby-processing'

# Dan Fitch <dgfitch@gmail.com>
# Last updated: 20090514
#
# HORRIBLE HACKS INSIDE!
#

class Graph < Processing::App
  attr_accessor :nodes, :click_x, :click_y

  # Used by some math-intensive subobjects to postpone updates
  def frame_skip
    1
  end

  def setup
    color_mode HSB, 1.0
    frame_rate 30
    smooth
    @nodes = []
    random_nodes 8

    self.mode = :SELECT
  end

  def random_nodes x
    (1..x).each do |i|
      @nodes << random_node
    end
    (1..x-4).each do |i|
      @nodes[i+2].connect @nodes[i]
    end
    (3..x-4).each do |i|
      @nodes[i+2].connect @nodes[i]
    end
  end

  def update
    @nodes.each {|n| n.update}
  end

  def draw
    update
    background 1
    draw_nodes
    draw_ui
  end

  def draw_nodes
    @nodes.each {|x| x.draw}
  end

  def draw_ui
    case self.mode
    when :SELECT_ACTIVE: draw_selection
    when :CREATE_LINK: draw_create_link
    when :MOVE: draw_moving
    end
  end

  def draw_selection
    fill 0.7, 0.2, 0.2, 0.2
    stroke_weight 2
    stroke 0, 0.5
    rect_mode CORNERS
    rect click_x, click_y, mouse_x, mouse_y
  end

  def draw_moving
    selected_nodes.each do |n|
      dx = click_x - mouse_x
      dy = click_y - mouse_y
      fill 1
      arrow_between n.x, n.y, n.x-dx, n.y-dy
    end
  end

  def draw_create_link
    under = unselected_nodes_under_cursor
    if under.length > 0 and under[0] then
      u = under[0]
      stroke 1, 1, 0.5, 0.9
      fill 1, 0.5
      stroke_width 1
      [1.6, 1.4, 1.2].each do |i|
        ellipse u.x, u.y, u.r*i, u.r*i
      end
      u.draw
    end

    fill 0
    selected_nodes.each do |n|
      dx = click_x - mouse_x
      dy = click_y - mouse_y
      arrow_between n.x, n.y, mouse_x, mouse_y
    end
  end


  def arrow_between x1, y1, x2, y2
    stroke_weight 1
    stroke 0, 0.5
    line x1, y1, x2, y2
    push_matrix
    translate x2, y2
    scale(Math.distance(x1, y1, x2, y2) / 400 + 0.5)
    rotate atan2(y2-y1, x2-x1)
    triangle 0, 0, -10, 5, -10, -5
    pop_matrix
    # TODO: animation would be cool here, or dashed lines
  end

  def random_node
    Node.new(
      :app => self,
      :x => random(width),
      :y => random(height),
      :r => random(20) + 40,
      :fill => random(1)
    )
  end

  def mouse_pressed
    @click_x = mouse_x
    @click_y = mouse_y
    case self.mode
    when :CREATE:
      if selected_under_cursor?
        self.mode = :CREATE_LINK
      end
    when :SELECT:
      if selected_under_cursor? and @key_shift
        self.mode = :CREATE_LINK
      elsif selected_under_cursor?
        self.mode = :MOVE
      else
        self.mode = :SELECT_ACTIVE
      end
    end
  end

  def mouse_released
    case self.mode 
    when :SELECT_ACTIVE:
      @nodes.each {|x| x.selected = false} unless @key_shift
      if (mouse_x - click_x).abs < 5 and (mouse_y - click_y).abs < 5 then
        s = nodes_under_cursor
      else
        s = nodes_under_box
      end

      unless s.any?
        deselect
      else
        s.each {|x| x.selected = true}
      end
    when :MOVE:
      selected_nodes.each do |n|
        dx = click_x - mouse_x
        dy = click_y - mouse_y
        n.move dx, dy
      end
    when :CREATE:
      s = nodes_under_cursor
      if s.any?
        s.each {|x| x.selected = true}
      else
        n = random_node
        n.selected = true
        n.x = mouse_x
        n.y = mouse_y
        @nodes << n
      end
      return
    when :CREATE_LINK:
      if (mouse_x - click_x).abs < 5 and (mouse_y - click_y).abs < 5 then
        # tiny moves => user actually wants to deselect
        selected_nodes[0].selected = false
      else
        under = unselected_nodes_under_cursor
        if under.length > 0 and under[0] then
          selected_nodes.each do |n|
            n.connect under[0]
          end
        end
      end
    end
    self.mode = :SELECT
  end

  

  def key_pressed
    @key_shift = key == CODED and key_code == SHIFT
    if @key_shift
      case self.mode 
      when :SELECT: self.mode = :CREATE
      when :MOVE: self.mode = :CREATE_LINK if one_selected?
      end
    end
  end

  def key_released
    if @key_shift
      case self.mode 
      when :CREATE_LINK: self.mode = :MOVE
      when :CREATE: self.mode = :SELECT
      end
    end
    @key_shift = false
  end


  def deselect
    @nodes.each {|x| x.selected = false}
  end

  def unselected_nodes_under_cursor
    nodes_under_cursor.reject {|x| x.selected}
  end

  def nodes_under_cursor
    @nodes.find_all {|x| x.under_cursor}
  end

  def nodes_under_box
    @nodes.find_all {|x| x.under_cursor click_x, click_y, mouse_x, mouse_y}
  end

  def selected_node
    sel = selected_nodes
    if sel.length > 0
      sel[0]
    else
      nil
    end
  end

  def selected_nodes
    @nodes.find_all {|x| x.selected?}
  end

  def selected_under_cursor?
    selected_nodes.find_all {|x| x.under_cursor}.any?
  end

  def one_selected?
    selected_nodes.length == 1
  end

  def none_selected?
    selected_nodes.length == 0
  end

  def some_selected?
    selected_nodes.length > 0
  end

  def mode
    @mode
  end
  
  def mode= x
    @mode = x
  end
end

module Math
  # I should probably put more of the useful trig crap in here eventually, but 
  # ruby already has atan2
  def Math.distance x1, y1, x2, y2
    a = (x1 - x2).abs
    b = (y1 - y2).abs
    return Math.sqrt(a**2 + b**2)
  end
end


class GraphObject
  attr_accessor :a, :x, :y, :fill, :stroke, :selected

  def initialize opts={}
    @a = opts[:app]
    @x = opts[:x] || 0
    @y = opts[:y] || 0
    @fill = opts[:fill] || 1.0
    @stroke = opts[:stroke] || 0.0
  end

  def under_cursor x1=nil, y1=nil, x2=nil, y2=nil
    return false
  end

  def selected?
    @selected
  end

  def only_selected?
    @selected and a.one_selected?
  end

  def draw
  end
end

class Node < GraphObject
  attr_accessor :r, :pulse, :connections, :dendrites

  def initialize opts={}
    super opts
    @original_r = opts[:r] || 10
    @r = @original_r
    @pulse = rand / 10.0
    @connections = []
    @dendrites = []
  end

  def connect node
    unless @connections.detect {|x| x.destination == node}
      c = Connection.new(
        :app => @a,
        :source => self,
        :destination => node
      )
      @connections << c
      add_dendrite c if self.selected
    end
  end

  def add_dendrite c
    @dendrites << NodeDendrite.new(
      :app => @a,
      :node => self,
      :connection => c
    )
  end

  def selected= x
    if x then
      @connections.each { |c| add_dendrite c }
    else
      @dendrites.clear
    end
    @selected = x
  end

  def under_cursor x1=nil, y1=nil, x2=nil, y2=nil
    if x1 == nil then
      node_distance = Math.distance(a.mouse_x, a.mouse_y, @x, @y)
      return true if node_distance < @r / 1.8
    else
      # If the bounding box covers at least half of the circle or so, select it
      x1, x2 = x2, x1 if x2 < x1
      y1, y2 = y2, y1 if y2 < y1
      half_radius = @r / 3.0

      if x1 < x - half_radius and x2 > x + half_radius and
         y1 < y - half_radius and y2 > y + half_radius then
         true
      end
    end
  end

  def move dx, dy
    @dest_x = x - dx
    @dest_x = r if @dest_x < r
    @dest_x = a.width - r if @dest_x > a.width - r
    @dest_y = y - dy
    @dest_y = r if @dest_y < r
    @dest_y = a.width - r if @dest_y > a.width - r
  end

  def draw
    @connections.each { |c| c.draw }

    if only_selected?
      a.fill @fill, 0.9 if @fill
      a.stroke_weight 4
      a.stroke 0, 1
    elsif selected?
      a.fill @fill, 0.7 if @fill
      a.stroke_weight 3
      a.stroke 0, 0.7
    else
      a.fill @fill, 0.5 if @fill
      a.stroke_weight 1
      a.stroke 0, 0.5
    end

    a.ellipse @x, @y, @r, @r

    @dendrites.each { |d| d.draw }
  end

  def update
    @r = @original_r + (@original_r / 20.0) * Math.sin(a.frame_count * @pulse)

    accel = 10.0
    if @dest_x and (@x-@dest_x).abs > 2
      @x -= (@x-@dest_x)/accel
    else
      @dest_x = nil
    end
    if @dest_y and (@y-@dest_y).abs > 2
      @y -= (@y-@dest_y)/accel
    else
      @dest_y = nil
    end

    accel = 100.0
    @x += (@x-@r).abs/accel if @x - @r < 0
    @y += (@y-@r).abs/accel if @y - @r < 0
    @x -= (a.width-@x+@r).abs/accel if @x + @r > a.width
    @y -= (a.width-@x+@r).abs/accel if @y + @r > a.height

    @dendrites.each { |d| 
      d.update 

      # Do this to the closest dendrite
      closest = @dendrites.min do |d1, d2|
        Math.distance(d1.x,d1.y,a.mouse_x,a.mouse_y) <=>
        Math.distance(d2.x,d2.y,a.mouse_x,a.mouse_y) 
      end
      if closest and d.under_cursor
        d.closest = true
        closest.r += 1.5 if closest.r < 14
      else
        d.closest = false
      end
    }
  end
end

class NodeDendrite < GraphObject
  attr_accessor :node, :connection, :r, :closest

  def initialize opts={}
    super opts
    @node = opts[:node]
    @connection = opts[:connection]
    @r = 3.0
    update
  end

  def draw
    a.stroke_weight 1
    a.stroke 0, 1
    a.fill 1, 1, 0.5, 0.8

    a.ellipse @x, @y, @r, @r
  end

  def update
    if a.frame_count % a.frame_skip == 0 then
      angle, @x, @y, x2, y2 = @connection.coords(@node, @connection.other(@node))
    end
    @r -= 0.5 if r > 3 and not @closest
  end

  def under_cursor
    node_distance = Math.distance(a.mouse_x, a.mouse_y, @x, @y)
    return true if node_distance < 7
  end
end

class Connection < GraphObject
  attr_accessor :source, :destination

  def initialize opts={}
    super opts
    @source = opts[:source]
    @destination = opts[:destination]
  end

  def coords n1, n2
    x1, y1 = n1.x, n1.y
    x2, y2 = n2.x, n2.y

    angle = Math.atan2(y2-y1, x2-x1)
    [
      angle, 
      n1.x + Math.cos(angle) * n1.r / 2.0,
      n1.y + Math.sin(angle) * n1.r / 2.0,
      n2.x - Math.cos(angle) * n2.r / 2.0,
      n2.y - Math.sin(angle) * n2.r / 2.0,
    ]
  end

  def other x
    if x == @source
      @destination
    else
      @source
    end
  end

  def draw
    a.stroke_weight 1
    a.stroke 0, 1

    angle, x1, y1, x2, y2 = coords(source, destination)

    #a.line x1, y1, x2, y2

    a.push_matrix
    a.translate x1, y1
    a.rotate angle

    length = Math.distance(x1,y1,x2,y2)

    if length > 0 then 
      curve = length * source.pulse * Math.sin(a.frame_count * source.pulse / 4.0)
      a.no_fill
      a.bezier 0, 0, length/2.0, curve, length/2.0, -1 * curve, length, 0
    end

    a.translate length, 0
    a.fill 0, 1
    a.rotate curve / length
    a.triangle 0, 0, -6, 3, -6, -3
    a.pop_matrix
  end
end

Graph.new :title => "Graph", :width => 900, :height => 600