module Image
  require 'pnm'

  TILE_SIZE = 11
  SCALE = 4

  UNSOLVED = 15
  SOLVED = 11
  BORDER = 8
  TINES = 3

  def self.from(rows)
    pixels = []

    rows.each_with_index do |cols, y|
      TILE_SIZE.times { pixels << [UNSOLVED] * (cols.count * TILE_SIZE) }
      cols.each_with_index do |tile, x|
        translate_tile(pixels, x * TILE_SIZE, y * TILE_SIZE, tile)
      end
    end

    PNM.create(pixels, type: :pgm, maxgray: 15)
  end

  private

  def self.fill(pixels, x0, y0, x1, y1, color)
    y0.upto(y1) do |y|
      x0.upto(x1) do |x|
        pixels[y][x] = color
      end
    end
  end

  def self.translate_tile(pixels, x, y, tile)
    fill(pixels, x, y, x+TILE_SIZE-1, y, BORDER)
    fill(pixels, x, y, x, y+TILE_SIZE-1, BORDER)
    fill(pixels, x, y+TILE_SIZE-1, x+TILE_SIZE-1, y+TILE_SIZE-1, BORDER)
    fill(pixels, x+TILE_SIZE-1, y, x+TILE_SIZE-1, y+TILE_SIZE-1, BORDER)

    if tile.solved?
      fill(pixels, x+1, y+1, x+TILE_SIZE-2, y+TILE_SIZE-2, SOLVED)
      fill(pixels, x+4, y+4, x+6, y+6, TINES)
    end

    pixels[y+5][x+5] = TINES

    case tile.is?(Tile::NORTH)
    when true
      fill(pixels, x+4, y+1, x+6, y+4, TINES)
    when nil
      fill(pixels, x+5, y+1, x+5, y+4, TINES)
    end

    case tile.is?(Tile::SOUTH)
    when true
      fill(pixels, x+4, y+6, x+6, y+9, TINES)
    when nil
      fill(pixels, x+5, y+6, x+5, y+9, TINES)
    end

    case tile.is?(Tile::WEST)
    when true
      fill(pixels, x+1, y+4, x+4, y+6, TINES)
    when nil
      fill(pixels, x+1, y+5, x+4, y+5, TINES)
    end

    case tile.is?(Tile::EAST)
    when true
      fill(pixels, x+6, y+4, x+9, y+6, TINES)
    when nil
      fill(pixels, x+6, y+5, x+9, y+5, TINES)
    end
  end
end
