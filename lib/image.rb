class Image
  require 'pnm'

  TILE_SIZE = 11
  SCALE = 4

  UNSOLVED = 15
  SOLVED = 11
  BORDER = 8
  TINES = 3

  def self.from(tiles, width, height)
    self.new(tiles, width, height).translate
  end

  def translate
    index = 0
    height.times do |y|
      TILE_SIZE.times { pixels << [UNSOLVED] * (width * TILE_SIZE) }
      width.times do |x|
        translate_tile(x * TILE_SIZE, y * TILE_SIZE, tiles[index])
        index += 1
      end
    end

    PNM.create(pixels, type: :pgm, maxgray: 15)
  end

  private

  attr_reader :tiles, :width, :height, :pixels

  def initialize(t, w, h)
    @tiles = t
    @width = w
    @height = h
    @pixels = []
  end

  def fill(x0, y0, x1, y1, color)
    y0.upto(y1) do |y|
      x0.upto(x1) do |x|
        pixels[y][x] = color
      end
    end
  end

  def translate_tile(x, y, tile)
    fill(x, y, x+TILE_SIZE-1, y, BORDER)
    fill(x, y, x, y+TILE_SIZE-1, BORDER)
    fill(x, y+TILE_SIZE-1, x+TILE_SIZE-1, y+TILE_SIZE-1, BORDER)
    fill(x+TILE_SIZE-1, y, x+TILE_SIZE-1, y+TILE_SIZE-1, BORDER)

    if tile.solved?
      fill(x+1, y+1, x+TILE_SIZE-2, y+TILE_SIZE-2, SOLVED)
      fill(x+4, y+4, x+6, y+6, TINES)
    end

    pixels[y+5][x+5] = TINES

    case tile.is?(Tile::NORTH)
    when true
      fill(x+4, y+1, x+6, y+4, TINES)
    when nil
      fill(x+5, y+1, x+5, y+4, TINES)
    end

    case tile.is?(Tile::SOUTH)
    when true
      fill(x+4, y+6, x+6, y+9, TINES)
    when nil
      fill(x+5, y+6, x+5, y+9, TINES)
    end

    case tile.is?(Tile::WEST)
    when true
      fill(x+1, y+4, x+4, y+6, TINES)
    when nil
      fill(x+1, y+5, x+4, y+5, TINES)
    end

    case tile.is?(Tile::EAST)
    when true
      fill(x+6, y+4, x+9, y+6, TINES)
    when nil
      fill(x+6, y+5, x+9, y+5, TINES)
    end
  end
end
