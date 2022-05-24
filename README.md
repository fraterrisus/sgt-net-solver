# sgt-net-solver

A little toy that solves `net` puzzles from [Simon Tatham's Portable Puzzle Collection](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/).

### License
You're welcome to read and reuse this code as you like, subject to the official terms; see `LICENSE`.

### Requirements
* The `pnm` gem, which is used to generate images. A successful run will produce `/tmp/initial.pgm`
and `/tmp/solved.pgm`, greyscale images of the puzzle as-given and as-solved.
* An installation of `sgt-puzzles`, to generate the game IDs this solver uses. Technically this
isn't required, but you'll have a hard time crafting legal puzzles without it.

### Running
```
gem install pnm
sgt-net --generate 1 11x11w | bin/solve.rb
```
Replace `11x11w` with the game type you want; see the manual for `sgt-net` for more information.

If you already have a game ID, you can also pass it in as an argument instead of on `STDIN`:
```
bin/solve.rb 5x5w:7548c283a5a3bbb8cd411ad56
```

### Performance
The solver is inherently nondeterministic; most of its solution steps are speculative, and even the
deterministic parts generally use `shuffle` when iterating over the list of tiles. So if you solve
the same puzzle multiple times, each run will likely take different amounts of time.

The only deterministic solving step simply matches up known answers from adjacent tiles (i.e. if
this tile must face North, then the tile to our North must also face South, etc). The only heuristic
I programmed is that two adjacent Nodes (tiles with degree 1) can't face each other, and that only
runs once per solve. Everything else is done by guess-and-check, which probably means that we spend
"too much" time running algorithms to detect loops and illegal neighbors.

### Debugging
The method `Board.log_step` has a bunch of commented-out lines that suppress the logging. If you
uncomment everything there, the solver will output a PGM file every time it does _anything_, so
you can watch it work in exquisite detail. That's gonna slow you way down, though.
