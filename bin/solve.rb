#!/usr/bin/env ruby

require_relative '../lib/board'

game_id = if ARGV.count == 0
  STDIN.readline.chomp
else
  ARGV.shift
end

raise "You must specify a descriptive game ID (ex: '3x3w:874573294')" unless game_id
Board.from_id(game_id).solve
