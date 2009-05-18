require 'ruby-processing'

# Dan Fitch <dgfitch@gmail.com>
# Last updated: 20090514
#
# HORRIBLE HACKS INSIDE!
#

class NeuralGraph < Processing::App
  attr_accessor :nodes, :click_x, :click_y, :dt, :current_time, :tick, :bpm

  # Used by some math-intensive subobjects to postpone updates
  def frame_skip
    1
  end

  def setup
    color_mode HSB, 1.0
    frame_rate 30
    smooth
    @nodes = []
    #random_nodes 20

    @mode = :SELECT
    @font = create_font('Helvetica', 12)
    text_font @font

    @tick = Time.now.to_f
    @last_time = @tick
    @bpm = 120.0
    background 1
  end

  def random_nodes x
    (1..x).each do |i|
      @nodes << random_node
    end
    (1..x-3).each do |i|
      @nodes[i+2].connect @nodes[i]
    end
    (2..x-3).each do |i|
      @nodes[i+2].connect @nodes[i]
    end
  end

  def update
    @current_time = Time.now.to_f
    @dt = @current_time - @last_time
    if @current_time - @tick > (60.0 / @bpm) then
      @tick = @last_time + (60.0 / @bpm)
      @nodes.each {|n| n.activate}
    end
    @last_time = @current_time
    @nodes.each do |n| 
      # This makes node activation grow by rate slowly over time...
      # Not sure I like that yet
      n.activate @dt
      n.check
      n.update
    end
  end

  def draw
    no_stroke
    fill 1, 0.7
    rect 0, 0, width, height
    update
    draw_nodes
    draw_ui
  end

  def draw_nodes
    @nodes.each {|x| x.draw}
  end

  def draw_ui
    case @mode
    when :SELECT_ACTIVE: draw_selection
    when :CREATE_LINK: draw_create_link
    when :MOVE: draw_moving
    end

    draw_menu
    fill 0
    text frame_rate(), 10, 20
  end

  def draw_menu
    @menu.draw if @menu
  end

  def draw_selection
    fill 0.7, 0.2, 0.2, 0.2
    stroke_weight 2
    stroke 0, 0.5
    rect_mode CORNERS
    rect click_x, click_y, mouse_x, mouse_y
    rect_mode CORNER
  end

  def draw_moving
    selected(@nodes).each do |n|
      dx = click_x - mouse_x
      dy = click_y - mouse_y
      fill 1
      arrow_between n.x, n.y, n.x-dx, n.y-dy
    end
  end

  def draw_create_link
    under = unselected_under_cursor @nodes
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
    selected(@nodes).each do |n|
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
    if mouse_button == RIGHT then
      if @mode == :MENU then
        @mode = :SELECT
        @menu = nil
      else
        @mode = :MENU
        @menu = SliceMenu.new(
          :app => self,
          :x => mouse_x,
          :y => mouse_y
        )
        (1..7).each do
          @menu.add "", nil, nil do nil end
        end
      end
    else
      active_nodes = selected_under_cursor? @nodes
      case @mode
      when :CREATE:
        if active_nodes
          @mode = :CREATE_LINK
        end
      when :SELECT:
        if active_nodes and @key_shift
          @mode = :CREATE_LINK
        elsif active_nodes
          @mode = :MOVE
        else
          @mode = :SELECT_ACTIVE
        end
      end
    end
  end

  def mouse_released
    return if mouse_button == RIGHT
    case @mode 
    when :SELECT_ACTIVE:
      @nodes.each {|x| x.selected = false} unless @key_shift
      if (mouse_x - click_x).abs < 5 and (mouse_y - click_y).abs < 5 then
        s = under_cursor @nodes
      else
        s = under_box @nodes
      end

      unless s.any?
        deselect
      else
        s.each {|x| x.selected = true}
      end
    when :MOVE:
      selected(@nodes).each do |n|
        dx = click_x - mouse_x
        dy = click_y - mouse_y
        n.move dx, dy
      end
    when :CREATE:
      s = under_cursor @nodes
      if s.any?
        s.each {|x| x.selected = true}
      else
        if mouse_button == LEFT then
          n = random_node
        else
          n = SamplerNode.new :app => self
        end
        n.selected = true
        n.x = mouse_x
        n.y = mouse_y
        @nodes << n
      end
      return
    when :CREATE_LINK:
      if (mouse_x - click_x).abs < 5 and (mouse_y - click_y).abs < 5 then
        # tiny moves => user actually wants to deselect
        selected(@nodes)[0].selected = false
      else
        under = unselected_under_cursor @nodes
        if under.length > 0 and under[0] then
          selected(@nodes).each do |n|
            n.connect under[0]
          end
        end
      end
    end
    @mode = :SELECT
  end

  def key_pressed
    if key == 'd'
      delete_selected_nodes
    end
    @key_shift = key == CODED and key_code == SHIFT
    if @key_shift
      case @mode 
      when :SELECT: @mode = :CREATE
      when :MOVE: @mode = :CREATE_LINK if one_selected? @nodes
      end
    end
  end

  def key_released
    if @key_shift
      case @mode 
      when :CREATE_LINK: @mode = :MOVE
      when :CREATE: @mode = :SELECT
      end
    end
    @key_shift = false
  end


  def delete_selected_nodes
    selected(@nodes).each do |x|
      @nodes.each {|n| n.disconnect x }
      @nodes.delete x
    end
  end

  def deselect
    @nodes.each {|x| x.selected = false}
  end

  def unselected_under_cursor n
    under_cursor(n).reject {|x| x.selected}
  end

  def under_cursor n
    n.find_all {|x| x.under_cursor?}
  end

  def under_box n
    n.find_all {|x| x.under_cursor? click_x, click_y, mouse_x, mouse_y}
  end

  def selected n
    n.find_all {|x| x.selected?}
  end

  def selected_under_cursor? n
    selected(under_cursor(n)).any?
  end

  def one_selected? n
    selected(n).length == 1
  end

  def none_selected? n
    selected(n).length == 0
  end

  def some_selected? n
    selected(n).length > 0
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


class CanvasObject
  attr_accessor :a, :x, :y, :hue, :sat, :val, :stroke, :selected

  def initialize opts={}
    @a = opts[:app]
    @x = opts[:x] || 0
    @y = opts[:y] || 0
    @hue = opts[:hue] || rand
    @sat = opts[:sat] || rand
    @val = opts[:val] || rand
    @stroke = opts[:stroke] || 0.0
  end

  def under_cursor? x1=nil, y1=nil, x2=nil, y2=nil
    return false
  end

  def selected?
    @selected
  end

  def only_selected?
    @selected and a.one_selected? a.nodes
  end

  def draw
  end
end

class RectObject < CanvasObject
  attr_accessor :h, :w

  def initialize opts={}
    super opts
    @h = opts[:h] || 10
    @w = opts[:w] || 10
  end

  def under_cursor? x1=nil, y1=nil, x2=nil, y2=nil
    if (a.mouse_x >= @x and a.mouse_x <= @x + @w and
        a.mouse_y >= @y and a.mouse_y <= @y + @h)
      true
    end
  end

  def draw
    if under_cursor?
      a.fill @hue, @sat, @val, 0.9
      a.stroke_weight 2
      a.stroke 0, 0.9
    else
      a.fill @hue, @sat, @val, 0.7
      a.stroke_weight 1
      a.stroke 0, 0.7
    end
    a.rect x, y, w, h
  end
end

class RectMenuItem < RectObject
  attr_accessor :text

  def initialize opts={}
    super opts
    @hue, @sat, @val = 0, 0, 0.8
    @text = opts[:text] || ""
  end

  def draw
    super
    a.fill 0
    a.text @text, x + 4, y + 12
  end
end

class SliceMenu < CanvasObject
  def initialize opts={}
    super opts
    @menu = []
  end

  def add object, get, set, &block
    @menu << SliceMenuItem.new(
      :app => @a,
      :parent => self,
      :index => @menu.length + 1
      # TODO
    )
  end

  def length
    @menu.length
  end

  def draw
    @menu.each {|m| m.draw}
  end
end

class SliceMenuItem < CanvasObject
  attr_accessor :parent, :tick, :index

  def initialize opts={}
    super opts
    @parent = opts[:parent]
    @index = opts[:index] || 0
    @tick = a.current_time
  end

  def length
    len = 50
    age = (a.current_time - @tick) * 4.0
    len *= age if age < 1
    len *= 1.2 if under_cursor?
    return len
  end

  def under_cursor?
    # TODO
    false
  end

  def draw
    if under_cursor?
      a.fill @hue, @sat, @val, 0.9
      a.stroke_weight 2
      a.stroke 0, 0.9
    else
      a.fill @hue, @sat, @val, 0.7
      a.stroke_weight 1
      a.stroke 0, 0.7
    end

    len = length

    a.push_matrix
    a.translate @parent.x, @parent.y
    a.push_matrix
    a.rotate(Math::PI * 2 * index / @parent.length.to_f)
    a.translate -2, length / 2.0
    a.line 0, 0, 0, length
    a.line 0, length, -20, length
    a.pop_matrix
    a.rotate(Math::PI * 2 * (index + 1) / @parent.length.to_f)
    a.translate 2, length / 2.0
    a.line 0, 0, 0, length
    a.pop_matrix
  end
end

class Node < CanvasObject
  attr_accessor :r, :level, :rate, :pulse, :connections, :dendrites

  def initialize opts={}
    super opts
    @original_r  = opts[:r] || 10
    @r           = @original_r
    @rate        = 0.25
    @level       = (a.current_time - a.tick) * @rate
    @pulse       = 0.1 + rand / 10.0
    @tick        = 0
    @connections = []
    @dendrites   = []
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

  def disconnect node
    @connections.delete_if {|x| x.destination == node}
  end

  def activate x=1
    @level += @rate * x
  end

  def check
    fire if @level >= 1.0
  end

  def fire
    @connections.each {|x| x.other(self).activate}
    @rate = 0.25
    @level -= 1
    while @level >= 1 do
      @level -= 1
      @rate = @rate + 0.25
    end
    @tick = a.current_time
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

  def under_cursor? x1=nil, y1=nil, x2=nil, y2=nil
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
      a.fill @hue, @sat, 0.5, 0.9
      a.stroke_weight 4
      a.stroke 0, 1
    elsif selected?
      a.fill @hue, @sat, 0.5, 0.7
      a.stroke_weight 3
      a.stroke 0, 0.7
    else
      a.fill @hue, @sat, 0.5, 0.5
      a.stroke_weight 1
      a.stroke 0, 0.5
    end


    a.ellipse @x, @y, @r, @r
    a.no_stroke
    a.ellipse @x, @y, @r * @level, @r * @level

    since_fired = a.current_time - @tick
    if since_fired < 0.5
      a.no_fill
      a.stroke @hue, @sat, 0.5, 0.5 - since_fired
      a.stroke_weight 2
      echo = r * (1.2 + (since_fired * 2))
      a.ellipse @x, @y, echo, echo
    end

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
      if closest and d.under_cursor?
        d.closest = true
        closest.r += 1.5 if closest.r < 14
      else
        d.closest = false
      end
    }
  end
end

class SamplerNode < Node
  def initialize opts={}
    opts[:r]   ||= rand(5) + 20
    opts[:sat] ||= 0.8 + rand(0.2)
    super opts
    @hue = 0.01
  end

  def draw
    super

    a.no_stroke 
    a.fill 1, 1, 0.5, 0.9
    a.ellipse @x, @y, @r / 2.0, @r / 2.0
  end
end

class NodeDendrite < CanvasObject
  attr_accessor :node, :connection, :r, :closest

  def initialize opts={}
    super opts
    @node = opts[:node]
    @connection = opts[:connection]
    @hue = @node.hue
    @sat = @node.sat
    @r = 3.0
    update
  end

  def draw
    a.stroke_weight 1
    a.stroke 0, 1
    a.fill @hue, @sat, 0.5, 0.8

    a.ellipse @x, @y, @r, @r
  end

  def update
    if a.frame_count % a.frame_skip == 0 then
      angle, @x, @y, x2, y2 = @connection.coords(@node, @connection.other(@node))
    end
    @r -= 0.5 if r > 3 and not @closest
  end

  def under_cursor?
    node_distance = Math.distance(a.mouse_x, a.mouse_y, @x, @y)
    return true if node_distance < 7
  end
end

class Connection < CanvasObject
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
    a.translate 0, 2

    length = Math.distance(x1,y1,x2,y2)

    if length > 0 then 
      curve = length * source.pulse * Math.sin(a.frame_count * source.pulse / 8.0) * 0.4
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

NeuralGraph.new :title => "Neural Graph", :width => 600, :height => 300
