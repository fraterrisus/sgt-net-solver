class Tile
  EAST = 0x1
  NORTH = 0x2
  WEST = 0x4
  SOUTH = 0x8

  ALL_DIRS = [EAST, NORTH, WEST, SOUTH].freeze

  attr_accessor :x, :y
  attr_reader :possibles

  def self.node
    Tile.new(EAST, NORTH, WEST, SOUTH)
  end

  def self.line
    Tile.new(NORTH|SOUTH, EAST|WEST)
  end

  def self.bend
    Tile.new(NORTH|EAST, EAST|SOUTH, SOUTH|WEST, WEST|NORTH)
  end

  def self.tee
    Tile.new(NORTH|EAST|SOUTH, EAST|SOUTH|WEST, SOUTH|WEST|NORTH, WEST|NORTH|EAST)
  end

  def self.exact(tines)
    Tile.new(tines)
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

  def initialize(*tine_sets)
    @possibles = tine_sets
  end

  def self.can_be?(poss, dir)
    poss & dir > 0
  end

  public

  def is_node?
    @possibles.all? { |p| p == NORTH || p == EAST || p == WEST || p == SOUTH }
  end

  def solved?
    @possibles.count == 1
  end

  def must_be!(dir)
    @possibles.select! { |p| Tile.can_be?(p, dir) }
  end

  def cant_be!(dir)
    @possibles.reject! { |p| Tile.can_be?(p, dir) }
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
