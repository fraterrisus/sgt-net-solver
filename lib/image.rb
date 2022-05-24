class Image
  require 'pnm'

  # sizes
  TILE_SIZE = 10
  SCALE = 4

  # colors
  WHITE = 15
  UNSOLVED = WHITE
  SOLVED = 11
  BORDER = 8
  TINES = 3

  def self.from(tiles, width, height)
    self.new(tiles, width, height).translate
  end

  def translate
    index = 0
    height.times do |y|
      tile_size.times { pixels << [UNSOLVED] * (width * tile_size) }
      width.times do |x|
        translate_tile(x * tile_size, y * tile_size, tiles[index])
        index += 1
      end
    end

    PNM.create(pixels, type: :pgm, maxgray: WHITE)
  end

  private

  attr_reader :tiles, :width, :height, :pixels

  def initialize(t, w, h)
    @tiles = t
    @width = w
    @height = h
    @pixels = []
  end

  def border_size
    1
  end

  # TS = 10, SCALE = 2 -> ts = 21; tile is (0,0)-(20,20) or 21 pixels per side
  def tile_size
    @tile_size ||= (TILE_SIZE * SCALE) + 1
  end

  # TS = 10, SCALE = 2 -> middle = 10
  def middle
    (TILE_SIZE * SCALE) / 2
  end

  def fill(x0, y0, x1, y1, color)
    y0.upto(y1) do |y|
      x0.upto(x1) do |x|
        pixels[y][x] = color
      end
    end
  end

  def draw_border(x, y)
    tile_min_x = x
    tile_max_x = x + tile_size - 1
    tile_min_y = y
    tile_max_y = y + tile_size - 1

    fill(tile_min_x, tile_min_y, tile_min_x, tile_max_y, BORDER)
    fill(tile_min_x, tile_min_y, tile_max_x, tile_min_y, BORDER)
    fill(tile_min_x, tile_max_y, tile_max_x, tile_max_y, BORDER)
    fill(tile_max_x, tile_min_y, tile_max_x, tile_max_y, BORDER)
  end

  def fill_solved_tile(x, y)
    fill(
      x + border_size,
      y + border_size,
      x + tile_size - border_size,
      y + tile_size - border_size,
      SOLVED
    )
  end

  def fill_middle(x, y, tile)
    tine_width = compute_tine_width(tile.solved?)
    fill(
      x + middle - tine_width,
      y + middle - tine_width,
      x + middle + tine_width,
      y + middle + tine_width,
      TINES
    )
  end

  def compute_tine_width(is)
    if is == true
      2 * SCALE - 1
    elsif is.nil?
      SCALE
    end
  end

  def fill_north(x, y, is)
    tine_width = compute_tine_width(is) || return
    fill(
      x + middle - tine_width,
      y + border_size,
      x + middle + tine_width,
      y + middle - SCALE,
      TINES
    )
  end

  def fill_south(x, y, is)
    tine_width = compute_tine_width(is) || return
    fill(
      x + middle - tine_width,
      y + middle + SCALE,
      x + middle + tine_width,
      y + tile_size - border_size,
      TINES
    )
  end

  def fill_west(x, y, is)
    tine_width = compute_tine_width(is) || return
    fill(
      x + border_size,
      y + middle - tine_width,
      x + middle - SCALE,
      y + middle + tine_width,
      TINES
    )
  end

  def fill_east(x, y, is)
    tine_width = compute_tine_width(is) || return
    fill(
      x + middle + SCALE,
      y + middle - tine_width,
      x + tile_size - border_size,
      y + middle + tine_width,
      TINES
    )
  end

  def translate_tile(x, y, tile)
    draw_border(x, y)
    fill_solved_tile(x, y) if tile.solved?
    fill_middle(x, y, tile)

    fill_north(x, y, tile.is?(Tile::NORTH))
    fill_south(x, y, tile.is?(Tile::SOUTH))
    fill_west(x, y, tile.is?(Tile::WEST))
    fill_east(x, y, tile.is?(Tile::EAST))
  end
end
