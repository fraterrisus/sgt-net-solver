require_relative './tile'
require_relative './image'
require_relative './errors/illegal_board_state_error'
require_relative './errors/loop_detected_error'

class Board
  SIZE_PATTERN = Regexp.compile /(\d+)x(\d+)(w?)/

  protected

  attr_reader :step

  private ###############################################################

  attr_reader :width, :height, :tiles

  def initialize(width, height, is_wrapped, tiles, step = 0)
    @width = width
    @height = height
    @wrapped = is_wrapped
    @tiles = tiles
    @step = step

    height.times do |y|
      width.times do |x|
        @tiles[y][x].x = x
        @tiles[y][x].y = y
      end
    end
  end

  public ################################################################

  def self.from_id(game_id)
    puts "Game ID: #{game_id}"

    size, tiles = game_id.split(/:/)

    match_data = SIZE_PATTERN.match(size)
    raise "Unrecognized board size '#{size}'" unless match_data

    width = match_data[1].to_i
    height = match_data[2].to_i
    wrapping = (match_data[3] == 'w')

    tines = tiles.split(//).map { |t| t.to_i(16) }
    raise "Game ID is wrong length" unless tines.count == width * height

    tile_set = tines.map { |t| Tile.exact(t) }
    Image.from(tile_set, width, height).write('/tmp/initial.pgm')

    return

    tile_set = tines.map { |t| Tile.like(t) }
    new(width, height, wrapping, tile_set)
  end

  def dup
    dup_tiles = []
    @tiles.each do |row|
      dup_tiles << row.map(&:dup)
    end
    self.class.new(@width, @height, @wrapped, dup_tiles, @step)
  end

  def is_wrapping?
    @wrapped
  end

  def solve
    log_step
    solve_once

    # 10.times do
      solve_deterministic
      if solved?
        write_image("/tmp/solved.pgm")
        return true
      end

=begin
      solve_speculative
      if solved?
        write_image("/tmp/solved.pgm")
        return true
      end
    end
=end

    write_image("/tmp/failed.pgm")
    false
  end

  def solved?
    tiles.map { |cols| cols.map(&:solved?).reduce(&:&) }.reduce(&:&)
  end

  def tile_at(x, y)
    tiles[y][x]
  end

  def write_image(filename)
    Image.from(tiles).write(filename)
  end

  private ###############################################################

  def solve_once
    height.times do |y|
      width.times do |x|
        this_tile = tile_at(x, y)

        changes = false
        if this_tile.is_node?
          Tile::ALL_DIRS.each do |d|
            next unless this_tile.is?(d).nil?
            changes = check_adjacent_nodes(this_tile, d) || changes
          end
        end
        log_step if changes
      end
    end
  end

  def solve_deterministic
    changes = true
    until solved? || !changes
      changes = false
      height.times do |y|
        width.times do |x|
          this_tile = tile_at(x, y)
          next if this_tile.solved?

          p = this_tile.possibles.dup

          Tile::ALL_DIRS.each do |d|
            next unless this_tile.is?(d).nil?
            check_neighbor(this_tile, d)
          end

          if this_tile.possibles != p
            changes = true
            write_image("/tmp/step#{@step}.pgm")
            check_pipes
            log_step
          end
        end
      end
    end
  end

  def solve_speculative
    speculative_tile = tiles.flatten.reject(&:solved?).shuffle.first
    speculative_poss = speculative_tile.possibles.shuffle.first
    puts "Speculatively assigning #{speculative_tile.position} to #{speculative_poss}"
    new_board = dup
    new_tile = new_board.tile_at(speculative_tile.x, speculative_tile.y)
    new_tile.must_be!(speculative_poss)
    begin
      new_board.solve
    rescue IllegalBoardStateError
      puts "Caught illegal state; #{speculative_tile.position} cant be #{speculative_poss}"
      @step = new_board.step
      write_image("/tmp/error#{@step}.pgm")
      speculative_tile.cant_be!(speculative_poss)
      log_step
    end
  end

  def check_adjacent_nodes(tile, dir)
    changes = false
    n = neighbor_of(tile, dir)
    if n&.is_node?
      puts "#{tile.position} cant point #{name_of(dir)} because #{n.position} is also a node"
      tile.cant_point!(dir)
      changes = true
    end
    changes
  end

  def check_neighbor(tile, dir)
    n = neighbor_of(tile, dir)
    if n.nil?
      puts "#{tile.position} cant point #{name_of(dir)} because that's the edge of the board"
      tile_at(tile.x, tile.y).cant_point!(dir)
    else
      adj = n.is?(opposite_of(dir))
      if adj == true
        puts "#{tile.position} must point #{name_of(dir)} because #{n.position} must point #{name_of(opposite_of(dir))}"
        tile_at(tile.x, tile.y).must_point!(dir)
      elsif adj == false
        puts "#{tile.position} cant point #{name_of(dir)} because #{n.position} cant point #{name_of(opposite_of(dir))}"
        tile_at(tile.x, tile.y).cant_point!(dir)
      end
    end
  end

  def check_pipes
    check_mismatches
    check_closed_subgraph
  end

  def check_closed_subgraph
    return if solved?
    found_list = []
    height.times do |y|
      width.times do |x|
        tile = tile_at(x,y)
        next unless tile.solved? && !found_list.include?(tile)
        # puts "Closed subgraph: starting at #{tile.position}"
        found_list += incomplete_helper(tile)
      end
    end
  end

  def incomplete_helper(tile)
    found_list = []
    work_list = [tile]

    while true
      this_tile = work_list.pop
      break if this_tile.nil?
      # puts "Found: #{found_list.map(&:position)} This: #{this_tile.position} Work: #{work_list.map(&:position)}"
      found_list.push(this_tile)

      Tile::ALL_DIRS.each do |dir|
        if this_tile.is?(dir) == true
          n = neighbor_of(this_tile, dir)
          return found_list unless n.solved?
          if work_list.include?(n)
            # loop detected
            raise IllegalBoardStateError
          end
          work_list.push(n) unless found_list.include?(n)
        end
      end
    end

    # we traversed a series of solved tiles, flooding out through their neighbors, and never
    # came across an unsolved tile. that implies there is a closed subgraph somewhere that does not
    # encompass the entire board
    puts "Error: illegal closed subgraph #{found_list.map(&:position)}"
    write_image("/tmp/error#{@step}.pgm")
    raise IllegalBoardStateError
  end

  def check_mismatches
    height.times do |y|
      width.times do |x|
        tile = tile_at(x,y)
        Tile::ALL_DIRS.each do |dir|
          if tile.is?(dir) == true
            neighbor = neighbor_of(tile, dir)
            if neighbor.is?(opposite_of(dir)) == false
              puts "Error: #{tile.position} points at #{neighbor.position} but that cant be"
              write_image("/tmp/error#{@step}.pgm")
              raise IllegalBoardStateError
            end
          end
        end
      end
    end
  end

  def log_step
    puts "*** Step #{@step}"
    @step += 1
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
end
