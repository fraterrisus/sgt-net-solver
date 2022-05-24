require_relative './errors/illegal_board_state_error'

class Tile
  EAST = 0x1
  NORTH = 0x2
  WEST = 0x4
  SOUTH = 0x8

  ALL_DIRS = [EAST, NORTH, WEST, SOUTH].freeze

  attr_accessor :x, :y
  attr_reader :possibles

  def self.node
    Tile.new([EAST, NORTH, WEST, SOUTH])
  end

  def self.line
    Tile.new([NORTH|SOUTH, EAST|WEST])
  end

  def self.bend
    Tile.new([NORTH|EAST, EAST|SOUTH, SOUTH|WEST, WEST|NORTH])
  end

  def self.tee
    Tile.new([NORTH|EAST|SOUTH, EAST|SOUTH|WEST, SOUTH|WEST|NORTH, WEST|NORTH|EAST])
  end

  def self.exact(tines)
    Tile.new([tines])
  end

  def self.like(tines)
    case tines
    when EAST, NORTH, WEST, SOUTH
      return self.node
    when NORTH|SOUTH, EAST|WEST
      return self.line
    when NORTH|EAST, EAST|SOUTH, SOUTH|WEST, WEST|NORTH
      return self.bend
    when NORTH|EAST|SOUTH, EAST|SOUTH|WEST, SOUTH|WEST|NORTH, WEST|NORTH|EAST
      return self.tee
    end
  end

  private

  def initialize(tine_sets)
    raise ArgumentError unless tine_sets.is_a?(Array)
    @possibles = tine_sets
  end

  def self.can_be?(poss, dir)
    poss & dir > 0
  end

  public

  def dup
    x = self.class.new(@possibles.dup)
    x.x = @x
    x.y = @y
    x
  end

  def position
    "(#{x},#{y})"
  end

  def is_node?
    @possibles.all? { |p| p == NORTH || p == EAST || p == WEST || p == SOUTH }
  end

  def solved?
    @possibles.count == 1
  end

  def cant_be!(tines)
    raise IllegalBoardStateError unless @possibles.include? tines
    @possibles.delete(tines)
  end

  def must_be!(tines)
    raise IllegalBoardStateError unless @possibles.include? tines
    @possibles = [tines]
  end

  def must_point!(dir)
    @possibles.select! { |p| Tile.can_be?(p, dir) }
    raise IllegalBoardStateError if @possibles.empty?
  end

  def cant_point!(dir)
    @possibles.reject! { |p| Tile.can_be?(p, dir) }
    raise IllegalBoardStateError if @possibles.empty?
  end

  def is?(dir)
    cans = @possibles.map { |p| Tile.can_be?(p, dir) }
    must = cans.reduce(&:&)
    might = cans.reduce(&:|)

    if must
      true
    elsif might
      nil
    else
      false
    end
  end
end
