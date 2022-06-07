require_relative 'tile'
require_relative 'image'
require_relative 'illegal_board_state_error'

class Board
  SIZE_PATTERN = Regexp.compile /(\d+)x(\d+)(w?)/

  protected

  private ###############################################################

  attr_reader :width, :height, :tiles, :saved_tiles

  def initialize(width, height, is_wrapped, tiles)
    @width = width
    @height = height
    @wrapped = is_wrapped
    @tiles = tiles
    @step = 0
    @saved_tiles = []

    index = 0
    height.times do |y|
      width.times do |x|
        @tiles[index].x = x
        @tiles[index].y = y
        index += 1
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

    tile_set = tines.map { |t| Tile.like(t) }
    new(width, height, wrapping, tile_set)
  end

  def copy_tiles
    @tiles.map(&:dup)
  end

  def is_wrapping?
    @wrapped
  end

  def solve
    solve_once

    solve_deterministic
    if solved?
      write_image("/tmp/solved.pgm")
      return true
    end

    solve_speculative
    if solved?
      write_image("/tmp/solved.pgm")
      return true
    end

    write_image("/tmp/failed.pgm")
    false
  end

  def solved?
    tiles.map(&:solved?).reduce(&:&)
  end

  def tile_at(x, y)
    index = x + (y * width)
    tiles[index]
  end

  def write_image(filename)
    Image.from(tiles, width, height).write(filename)
  end

  private ###############################################################

  def solve_once
    tiles.each do |this_tile|
      if this_tile.is_node?
        Tile::ALL_DIRS.each do |d|
          next unless this_tile.is?(d).nil?
          check_adjacent_nodes(this_tile, d)
        end
      end
    end
  end

  def solve_deterministic
    changes = true
    while changes
      changes = false
      work_list = tiles.dup.reject(&:solved?).shuffle
      while true
        tile = work_list.pop
        break if tile.nil?
        # next if tile.solved?

        p = tile.possibles.dup

        Tile::ALL_DIRS.each do |d|
          next unless tile.is?(d).nil?
          check_neighbor(tile, d)
        end

        if tile.solved?
          Tile::ALL_DIRS.each do |d|
            n = neighbor_of(tile, d)
            next unless n&.solved?
            if tile.is?(d) != n.is?(opposite_of(d))
              log_step "Error: #{tile.position} conflicts with #{n.position}"
              raise IllegalBoardStateError
            end
          end
        end

        if tile.possibles != p
          changes = true

          Tile::ALL_DIRS.each do |d|
            n = neighbor_of(tile, d)
            # Even if the node is already on the worklist, bump it up to the top so changes
            # propagate out to neighbors faster.
            work_list.delete(n)
            work_list.push(n) unless n.nil? || n.solved?
          end
        end
      end
      check_pipes
    end
  end

  def solve_speculative(depth = 0)
    until solved?
      # puts "[Speculative #{depth}]"
      speculative_tile = tiles.reject(&:solved?).shuffle.first
      speculative_poss = speculative_tile.possibles.shuffle.first

      save_speculative_state
      tile_at(speculative_tile.x, speculative_tile.y).must_be!(speculative_poss)
      log_step "Speculatively assigning #{speculative_tile.position} to #{speculative_poss}"

      begin
        solve_deterministic
        if solved?
          write_image("/tmp/solved.pgm")
          return true
        end

        solve_speculative(depth+1)
        check_pipes
        # puts "[Speculative return #{depth}]"
      rescue IllegalBoardStateError
        restore_speculative_state
        tile_at(speculative_tile.x, speculative_tile.y).cant_be!(speculative_poss)
        log_step "Unwinding speculative assignment; #{speculative_tile.position} cant be #{speculative_poss}"
        solve_deterministic if speculative_tile.solved?
      end
    end
  end

  def save_speculative_state
    saved_tiles.push(copy_tiles)
  end

  def restore_speculative_state
    raise unless saved_tiles.any?
    @tiles = saved_tiles.pop
  end

  def check_adjacent_nodes(tile, dir)
    changes = false
    n = neighbor_of(tile, dir)
    if n&.is_node?
      tile.cant_point!(dir)
      log_step "#{tile.position} cant point #{name_of(dir)} because #{n.position} is also a node"
      changes = true
    end
    changes
  end

  def check_neighbor(tile, dir)
    n = neighbor_of(tile, dir)
    if n.nil?
      tile_at(tile.x, tile.y).cant_point!(dir)
      log_step "#{tile.position} cant point #{name_of(dir)} because that's the edge of the board"
    else
      adj = n.is?(opposite_of(dir))
      if adj == true
        tile_at(tile.x, tile.y).must_point!(dir)
        log_step "#{tile.position} must point #{name_of(dir)} because #{n.position} must point #{name_of(opposite_of(dir))}"
      elsif adj == false
        tile_at(tile.x, tile.y).cant_point!(dir)
        log_step "#{tile.position} cant point #{name_of(dir)} because #{n.position} cant point #{name_of(opposite_of(dir))}"
      end
    end
  end

  def check_pipes
    check_mismatches
    check_closed_subgraph
  end

  def check_closed_subgraph
    found_list = []
    tiles.each do |tile|
      next unless tile.solved? && !found_list.include?(tile)
      # puts "Closed subgraph: starting at #{tile.position}"
      found_list += incomplete_helper(tile)
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
            log_step("Error: loop detected")
            raise IllegalBoardStateError
          end
          work_list.push(n) unless found_list.include?(n)
        end
      end
    end

    # we traversed a series of solved tiles, flooding out through their neighbors, and never
    # came across an unsolved tile. that implies there is a closed subgraph somewhere that does not
    # encompass the entire board
    return found_list if solved?
    log_step "Error: illegal closed subgraph" # + " #{found_list.map(&:position)}"
    raise IllegalBoardStateError
  end

  def check_mismatches
    tiles.each do |tile|
      Tile::ALL_DIRS.each do |dir|
        if tile.is?(dir) == true
          neighbor = neighbor_of(tile, dir)
          if neighbor.is?(opposite_of(dir)) == false
            log_step "Error: #{tile.position} points at #{neighbor.position} but that cant be"
            raise IllegalBoardStateError
          end
        end
      end
    end
  end

  def log_step(string)
    # puts "*** Step #{@step}"
    # puts string
    # write_image("/tmp/step#{@step}.pgm")
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
