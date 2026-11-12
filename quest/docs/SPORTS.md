# The sports hall and the board game

## The hall
Through the gate in the arcade's back-left corner (under "THE SHACK EXTRA") is a second hall, 8 m by 14 m:

* **Darts** (left wall): two regulation boards, throw line 2.37 m away. 501 or 301 (double out), or Cricket. One to four players take turns of three darts.
* **Axe throwing** (far end): three lanes, targets 3.66 m (12 ft) away. Rings 1-5, bullseye 5, two clutch dots worth 7. Modes: Classic and Bullseye Blitz.
* **Bowling** (right): two lanes, real rigid-body physics (6 kg ball, ten pins), gutters, ten frames scored properly. One to four players.

Pick something up by closing your fingers (grip or trigger) with your hand on it; let go to throw. It leaves at your hand's speed, direction and turn.
Point at MODE / PLAYERS / START on each game's panel and pull the trigger.

Files: `annex.gd` (the hall), `throw_games.gd` (hands, grabbing), `darts_game.gd`, `axe_game.gd`, `bowling_game.gd`, `bowling_score.gd`, `hand_track.gd`, `throwable.gd`, `sport_game.gd`.
Art: `tools/make_sports_art.py` makes the dartboard, axe target and lane pictures. Tests: `tests/sports_test.gd`, `tests/sports_throw_test.gd`, `tests/gate_test.gd` (run with `--fixed-fps 60`), pictures from `tests/annex_view.gd` and `tests/gate_view.gd`.

Not done yet: scores and throws are not shared with other players in a room (they can see you throw, but each lane's score is on your own headset).

## Frustration / Trouble
The lounge board game. Four pegs each, roll a 6 to bring a peg out (and roll again), landing on another player's peg sends it home, you cannot land on your own peg, exact roll to finish in your home lane. The server (`server/board.mjs`) runs the game in a room and `quest/scripts/board_game.gd` runs it on your own; the rules are the same in both. **The room server must be redeployed for rooms to use the new rules.**
