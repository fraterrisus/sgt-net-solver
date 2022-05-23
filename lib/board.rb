require_relative './tile'
require_relative './image'

class Board
  SIZE_PATTERN = Regexp.compile /(\d+)x(\d+)(w?)/

  private

  attr_reader :width, :height, :tiles

  def initialize(width, height, is_wrapped, tiles)
    @width = width
    @height = height
    @wrapped = is_wrapped
    @tiles = tiles

    height.times do |y|
      width.times do |x|
        @tiles[y][x].x = x
        @tiles[y][x].y = y
      end
    end
  end

  public

  def self.from_id(game_id)
    puts "Game ID: #{game_id}"

    size, tiles = game_id.split(/:/)

    match_data = SIZE_PATTERN.match(size)
    raise "Unrecognized board size '#{size}'" unless match_data

    width = match_data[1].to_i
    height = match_data[2].to_i
    wrapping = (match_data[3] == 'w')

    tile_set = tiles.split(//).map { |t| Tile.exact(t.to_i(16)) }.each_slice(width).to_a
    Image.from(tile_set).write('/tmp/initial.pgm')

    tile_set = tiles.split(//).map { |t| Tile.like(t.to_i(16)) }.each_slice(width).to_a
    new(width, height, wrapping, tile_set)
  end

  def is_wrapping?
    @wrapped
  end

  def solved?
    tiles.map { |cols| cols.map(&:solved?).reduce(&:&) }.reduce(&:&)
  end

  def name_of(dir)
    case dir
    when Tile::NORTH
      'NORTH'
    when Tile::SOUTH
      'SOUTH'
    when Tile::WEST
      'WEST'
    when Tile::EAST
      'EAST'
    else
      raise ArgumentError
    end
  end

  def opposite_of(dir)
    case dir
    when Tile::NORTH
      Tile::SOUTH
    when Tile::SOUTH
      Tile::NORTH
    when Tile::EAST
      Tile::WEST
    when Tile::WEST
      Tile::EAST
    else
      raise ArgumentError
    end
  end

  def check_adjacent_nodes(tile, dir)
    n = neighbor_of(tile, dir)
    if n&.is_node?
      puts "#{tile.position} cant be #{name_of(dir)} because #{n.position} is also a node"
      tile.cant_be!(dir)
    end
  end

  def check_neighbor(tile, dir)
    n = neighbor_of(tile, dir)
    if n.nil?
      puts "#{tile.position} cant be #{name_of(dir)} because that's the edge of the board"
      tile_at(tile.x, tile.y).cant_be!(dir)
    else
      adj = n.is?(opposite_of(dir))
      if adj == true
        puts "#{tile.position} must be #{name_of(dir)} because #{n.position} must be #{name_of(opposite_of(dir))}"
        tile_at(tile.x, tile.y).must_be!(dir)
      elsif adj == false
        puts "#{tile.position} cant be #{name_of(dir)} because #{n.position} cant be #{name_of(opposite_of(dir))}"
        tile_at(tile.x, tile.y).cant_be!(dir)
      end
    end
  end

  def solve
    step = 0
    changes = true
    until solved? || !changes
      changes = false
      height.times do |y|
        width.times do |x|
          this_tile = tile_at(x, y)
          next if this_tile.solved?

          p = this_tile.possibles.dup

          if this_tile.is_node?
            Tile::ALL_DIRS.each do |d|
              next unless this_tile.is?(d).nil?
              check_adjacent_nodes(this_tile, d)
            end
          end

          Tile::ALL_DIRS.each do |d|
            next unless this_tile.is?(d).nil?
            check_neighbor(this_tile, d)
          end

          if this_tile.possibles != p
            changes = true

            write_image("/tmp/step#{step}.pgm")
            step += 1
            puts "*** Step #{step}"
          end
        end
      end
    end
  end

  def neighbor_of(tile, dir)
    case dir
    when Tile::NORTH
      if tile.y == 0
        if is_wrapping?
          tile_at(tile.x, height-1)
        end
      else
        tile_at(tile.x, tile.y - 1)
      end
    when Tile::SOUTH
      if tile.y == height - 1
        if is_wrapping?
          tile_at(tile.x, 0)
        end
      else
        tile_at(tile.x, tile.y + 1)
      end
    when Tile::WEST
      if tile.x == 0
        if is_wrapping?
          tile_at(width - 1, tile.y)
        end
      else
        tile_at(tile.x - 1, tile.y)
      end
    when Tile::EAST
      if tile.x == width - 1
        if is_wrapping?
          tile_at(0, tile.y)
        end
      else
        tile_at(tile.x + 1, tile.y)
      end
    else
      raise ArgumentError
    end
  end

  def tile_at(x, y)
    tiles[y][x]
  end

  def write_image(filename)
    Image.from(tiles).write(filename)
  end
end
