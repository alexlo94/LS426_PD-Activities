;;
;; EXTENSIONS
;;
extensions [
  array
]

;;
;; BREEDS
;;
breed [players player]

turtles-own [
  name
  game_score
  cumulative_score
  has_played
  last_opponent
  my_opponent
  partnered
  strategy_string
  move_history
  num_wins
  num_losses
]

players-own [

]

links-own [
  players_ready
  turn_played
  game_string
]


;;
;; GLOBALS
;;
globals [
  curr_turn
  curr_game
  player_score
  ai_score
  data_string
  player_moves

  ;; Payoff Matrix
  TT_val ;; What both players get on a TT scenario
  TF_loser_val ;; What the loser of a TF scenario gets (i.e. the one who cooperates)
  TF_winner_val ;; What the winner of a TF scenario gets (i.e. the one who defects)
  FF_val ;; What both players get on an FF scenario

  ;; Game State
  STATE
  SIM_NOT_READY
  SIM_READY
  SIM_IN_PROGRESS
  SIM_ENDED

  ;; Strategies for Androids
  ;; These can be expanded upon later
  ALWAYS_COOPERATE
  ALWAYS_DEFECT
  TIT_FOR_TAT
  SUS_TIT_FOR_TAT
  COPYCAT
  CONTRARIAN

  ;; Shapes
  shape-names            ;; list of names of the non-sick shapes a client's turtle can have
  colors                 ;; list of colors used for clients' turtles
  color-names            ;; list of names of colors used for students' turtles
  used-shape-colors      ;; list of shape-color pairs that are in use
  max-possible-codes     ;; total number of unique shape/color combinations
]

;;
;; STARTUP
;;

to startup
  ;; define state strings
  set SIM_NOT_READY "Simulation Not Ready"
  set SIM_READY "Simulation Ready"
  set SIM_IN_PROGRESS "Simulation in Progress"
  set SIM_ENDED "Simulation Ended"

  ;; set state to uninitialized
  set STATE SIM_NOT_READY
end

;;
;; SETUP PROCEDURES
;;
to setup
  if STATE = SIM_IN_PROGRESS [stop]

  ;;clear-all
  cp
  cd
  ct ;; this may cause problems in hubnet
  clear-output
  reset-ticks
  set-default-shape turtles "computer workstation"
  set curr_turn 1
  set curr_game 1
  set player_score 0
  set ai_score 0
  set data_string ""


  ;; create payoff matrix for this simulation
  ;; these can be changed to reference a slider that the user/organizer has access to
  ;; referencing the sliders and setting a global according to them on setup will prevent users from accidentally changing the payoff matrix mid-simulation
  set TT_val TT_payoff
  set TF_loser_val TF_loser_payoff
  set TF_winner_val TF_winner_payoff
  set FF_val FF_payoff

  ;; define the different strategies and put them in a list
  set ALWAYS_COOPERATE "T"
  set ALWAYS_DEFECT "F"
  set TIT_FOR_TAT "TC"
  set SUS_TIT_FOR_TAT "FC"
  set COPYCAT "C"
  set CONTRARIAN "O"


  create-players 1 [
    set shape "person"
    set size (30 / (num_androids + 1)) ;; replace this with a value based on the number of agents in the simulation
    set name "player"
    set game_score 0
    set cumulative_score 0
    set has_played FALSE
    set last_opponent ""
    set partnered FALSE
    set strategy_string ""
    set move_history ""
    set my_opponent ""
    set label cumulative_score
  ]

  create-turtles num_androids [
    set name "ai"
    set size (30 / (num_androids + 1)) ;; replace this with a value based on the number of agents in the simulation
    set game_score 0
    set cumulative_score 0
    set has_played FALSE
    set last_opponent ""
    set partnered FALSE

    set strategy_string one-of (list (ALWAYS_COOPERATE) (ALWAYS_DEFECT) (TIT_FOR_TAT) (COPYCAT) (CONTRARIAN))
    set move_history ""
    set my_opponent ""
    set label cumulative_score
  ]

  layout-circle turtles (world-width / 3)

  match_prisoners

  ;; set state to ready
  set STATE SIM_READY
end

;;
;; GO
;;

to go
  ;; If simulation has ended stop
  if (STATE = SIM_ENDED) [stop]

  ;; Set state if this is the first iteration of go
  if (STATE != SIM_IN_PROGRESS) [set STATE SIM_IN_PROGRESS]

  ask links [
    check_turn_results
  ]

  if not (any? links with [turn_played = FALSE]) [
    ask links [
      set turn_played FALSE ;; turn played is false
      set players_ready 0 ;; no players are ready this turn
      ask both-ends [
        set has_played FALSE ;; both ends have not played this turn
      ]
    ]

    ;; increment turn and game counter
    if (curr_game = num_games and curr_turn = num_turns) [ ;; if the current game is the last game, stop the simulation

      ask links [
        set data_string (word data_string game_string) ;; make the links commit their game data to the data string
        assign_wins
      ]

      output-show "The simulation has ended, all games have been played"
      set STATE SIM_ENDED
      stop
    ]

    if-else (curr_turn = num_turns) [ ;; if the current turn is the last turn in a game, increment the game counter and set the turn counter to 0

      ask links [
        set data_string (word data_string game_string) ;; make the links commit their game data to the data string
        assign_wins
      ]

      set curr_game curr_game + 1
      set curr_turn 1

      clear_matches
      ;; match all the prisoners
      match_prisoners
    ] [
      set curr_turn curr_turn + 1 ;; if none of the above cases are true, just increment the turn counter
    ]
    tick
  ]
end

;;
;; MATCHMAKING PROCEDURES
;;

to match_prisoners
  while [any? turtles with [partnered = FALSE]] [
    ask one-of turtles with [partnered = FALSE] [
      let me self
      let myID [who] of me
      let other_turtle one-of other turtles with [last_opponent != (word myID) and partnered = FALSE]

      create-link-with other_turtle [
        set players_ready 0
        set turn_played FALSE
        set game_string "(Turn N, Game N) | (One_turtle_ID: Move, Other_turtle_ID: Move) | Results: (+One_turtle_gain, +Other_turtle_gain)\r" ;; the format of the game string
      ]

      set partnered TRUE
      set last_opponent [who] of other_turtle
      set my_opponent other_turtle
      ask other_turtle [
        set partnered TRUE
        set last_opponent myID
        set my_opponent me
      ]
    ]
  ]
end

;; procedure that is called when all the turns of a given game have been played.
;; since games are maintained by links, this procedure resets relevant player variables and kills all links
to clear_matches
  ask links [
    ask both-ends [
      set partnered FALSE
      set move_history ""
      set game_score 0
      set has_played FALSE
      set my_opponent ""
      if ([breed] of self = players) [set strategy_string ""]
    ]
    die
  ]
end

;;
;; GAMEPLAY PROCEDURES
;;

;; procedure to handle user input from "cooperate" and "defect" buttons
;; asks the player turtle to update its strategy string based on the button pressed
;; the turtle then asks the link it's part of to check this turn's results.
to handle_user_input [action]
  if (STATE != SIM_IN_PROGRESS) [stop]

  ask turtles with [who = 0] [ ;; in this simulation, this is the player, in hubnet activities this should refer to the turtle with the name that matches the player's UI
    if has_played [stop] ;; if the player has already played this turn, then stop

    let new_strat_string (word strategy_string action) ;; create new strategy string based on action
    set strategy_string new_strat_string ;; update player's strategy string
    set has_played TRUE ;; indicate that we've made a move this turn

    ;; if there's no easier way to reference links that this turtle is part of, this language is a joke lmao
    ;; !! this only works under the assumption that a turtle is only ever part of one link !!
    let neighbor_turtle one-of other in-link-neighbors ;; get the opponent so we can call the link we're part of
    let my_link link who [who] of neighbor_turtle ;; get the link we're part of

    ask my_link [
      set players_ready players_ready + 1
      check_turn_results
    ]
  ]
end

;; procedure that is called to calculate the results of a given turn in a given game of PD
;; used by the links that are maintaining the game
to check_turn_results
  if (players_ready != count both-ends with [breed = players]) or (turn_played = TRUE) [ stop ] ;; if not all players are ready or if this link has played this turn, don't check results

  ;; if all players are ready, then proceed to compute the turn results.

  ;; get references to both turtles on the ends of this link
  let one_turtle one-of sort both-ends ;; get one of the two turtles in this link
  let other_turtle one-of sort both-ends with [who != [who] of one_turtle] ;; get the other turtle that isn't the one we got earlier

  ;; pre-process the command of each turtle for this turn (i.e. turn any copy or opposite moves into cooperate or defects)
  let one_turtle_eval eval_move_string one_turtle other_turtle
  let other_turtle_eval eval_move_string other_turtle one_turtle

  let one_turtle_gain 0
  let other_turtle_gain 0

  ;; calculate the results of the turn given one_turtle's and other_turtle's moves using the payoff matrix, update the game score, cumulative score, and move history
  ;; this really should be removed to a separate procedure but I can't figure out how to keep a mapping the evals to the turtles without being in this context so this procedure is bloated
  if (one_turtle_eval = "T") and (other_turtle_eval = "T") [ ;; TT Scenario
    ask one_turtle [ ;; The fact that a command like set (([game_score]) of (one_turtle)) (TT_val) isn't possible for these lines is preposterous
      set game_score game_score + TT_val
      set cumulative_score cumulative_score + TT_val
      set move_history (word move_history "T")
    ]
    ask other_turtle [
      set game_score game_score + TT_val
      set cumulative_score cumulative_score + TT_val
      set move_history (word move_history "T")
    ]

    set one_turtle_gain TT_val
    set other_turtle_gain TT_val
  ]
  if (one_turtle_eval = "T") and (other_turtle_eval = "F") [ ;; TF Scenario
    ask one_turtle [
      set game_score game_score + TF_loser_val
      set cumulative_score cumulative_score + TF_loser_val
      set move_history (word move_history "T")
    ]
    ask other_turtle [
      set game_score game_score + TF_winner_val
      set cumulative_score cumulative_score + TF_winner_val
      set move_history (word move_history "F")
    ]

    set one_turtle_gain TF_loser_val
    set other_turtle_gain TF_winner_val
  ]
  if (one_turtle_eval = "F") and (other_turtle_eval = "T") [ ;; FT Scenario
    ask one_turtle [
      set game_score game_score + TF_winner_val
      set cumulative_score cumulative_score + TF_winner_val
      set move_history (word move_history "F")
    ]
    ask other_turtle [
      set game_score game_score + TF_loser_val
      set cumulative_score cumulative_score + TF_loser_val
      set move_history (word move_history "T")
    ]

    set one_turtle_gain TF_winner_val
    set other_turtle_gain TF_loser_val
  ]
  if (one_turtle_eval = "F") and (other_turtle_eval = "F") [ ;; FF Scenario
    ask one_turtle [
      set game_score game_score + FF_val
      set cumulative_score cumulative_score + FF_val
      set move_history (word move_history "F")
    ]
    ask other_turtle [
      set game_score game_score + FF_val
      set cumulative_score cumulative_score + FF_val
      set move_history (word move_history "F")
    ]

    set one_turtle_gain FF_val
    set other_turtle_gain FF_val
  ]

  ask one_turtle [set label cumulative_score]
  ask other_turtle [set label cumulative_score]

  ;; create the output string for this game
  ;; output string has the form:
  ;; (Turn N, Game N) | (One_turtle_ID: Move, Other_turtle_ID: Move) | Results: (+One_turtle_gain, +Other_turtle_gain)\r
  let output_string ""
  set output_string (word ("(Turn ") (curr_turn) (" , ") ("Game ") (curr_game) (") | (") ([who] of one_turtle) (": ") (one_turtle_eval) (", ") ([who] of other_turtle) (": ") (other_turtle_eval) (") | (") ("Result: (+") (one_turtle_gain) (", +") (other_turtle_gain) (")\r"))

  ;; if a player is part of this link, then output the result
  if count both-ends with [breed = players] > 0 [output-show output_string]

  ;; update this link's game string
  set (game_string) (word (game_string) (output_string))

  ;; indicate that our turn has been played so the observer can pass us over
  set turn_played TRUE
end

;; procedure to evaluate a strategy string and report the move that should be taken during this turn
;; In order to handle C and O as moves (copy and oppose), the procedure takes as input two turtles; the one that makes the move and its opponent
to-report eval_move_string [moving_turtle opponent_turtle]
  let temp_move "T" ;; if there's no valid move to copy or oppose, then copy and oppose will evaluate to cooperate

  ;; retrieve the appropriate item from the strategy string based on wrap or no-wrap
  let pointer (curr_turn - 1)
  let ss_length length ([strategy_string] of moving_turtle)
  let desired_move ""

  if-else strategy_wrap [
    set desired_move item ((pointer) mod (length ([strategy_string] of moving_turtle))) ([strategy_string] of moving_turtle)
  ][
    let temp_list (list (pointer) (length ([strategy_string] of moving_turtle) - 1))
    let index min temp_list
    set desired_move item (index) ([strategy_string] of moving_turtle)
  ]

  ;; in case we want to copy our opponents last move
  if desired_move = "C" [
    if (curr_turn - 2 >= 0) and ([move_history] of opponent_turtle != "") [ ;; check to see whether we're copying too early in the game first.
      set temp_move item (curr_turn - 2) ([move_history] of opponent_turtle) ;; evaluate temp_move
    ]
  ]
  ;; in case we want to make the opposite move of our opponents last move
  if desired_move = "O" [
    if (curr_turn - 2 >= 0) and ([move_history] of opponent_turtle != "") [ ;; check to see whether we're copying too early in the game first.
      ;; evaluate temp_move
      let opp_previous_move item (curr_turn - 2) ([move_history] of opponent_turtle)
      if-else opp_previous_move = "T" [ set temp_move "F" ] [ set temp_move "T" ]
    ]
  ]
  ;; in case we either cooperated or defected directly
  if desired_move = "F" [
    set temp_move "F"
  ]

  report temp_move
end

to assign_wins
  ;; get references to both turtles on the ends of this link
  let one_turtle one-of sort both-ends ;; get one of the two turtles in this link
  let other_turtle one-of sort both-ends with [who != [who] of one_turtle] ;; get the other turtle that isn't the one we got earlier

  let output_string ""
  set output_string (word ("Game ") (curr_game) (" | ") (one_turtle) (": ") ([game_score] of one_turtle) (", ") (other_turtle) (": ") ([game_score] of other_turtle) (" | Result: "))

  if [game_score] of one_turtle > [game_score] of other_turtle [
    ask one_turtle [set num_wins num_wins + 1]
    ask other_turtle [set num_losses num_losses + 1]
    set output_string (word (output_string) (one_turtle) (" wins"))
  ]
  if [game_score] of one_turtle < [game_score] of other_turtle [
    ask one_turtle [set num_losses num_losses + 1]
    ask other_turtle [set num_wins num_wins + 1]
    set output_string (word (output_string) (other_turtle) (" wins"))
  ]
  if [game_score] of one_turtle = [game_score] of other_turtle [
    ask one_turtle [set num_wins num_wins + 1]
    ask other_turtle [set num_wins num_wins + 1]
    set output_string (word (output_string) ("Draw"))
  ]

  ;; if a player is part of this link, then output the result
  if count both-ends with [breed = players] > 0 [output-show output_string]

  ;; update this link's game string
  set (game_string) (word (game_string) (output_string))

end

;;
;; RESULTS
;;

to download_results
  if (STATE != SIM_ENDED) [stop]

  file-open "results.txt"
  file-write data_string
  file-close-all
  output-show "Results downloaded"
end
@#$#@#$#@
GRAPHICS-WINDOW
481
100
1074
694
-1
-1
17.73
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
10
102
182
135
num_turns
num_turns
1
20
5.0
1
1
turns
HORIZONTAL

SLIDER
10
147
182
180
num_games
num_games
1
20
5.0
1
1
games
HORIZONTAL

MONITOR
1336
204
1527
261
Your Score
item 0 [game_score] of turtles with [who = 0]
17
1
14

MONITOR
1542
203
1733
260
Opponent's Score
[game_score] of (item 0 [my_opponent] of turtles with [who = 0])
17
1
14

MONITOR
1127
100
1318
157
Current Turn
curr_turn
17
1
14

MONITOR
1339
100
1530
157
Current Game
curr_game
17
1
14

BUTTON
573
719
765
776
Cooperate
handle_user_input \"T\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
785
719
978
776
Defect
handle_user_input \"F\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

OUTPUT
1128
563
1738
772
12

BUTTON
219
103
317
159
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
217
183
250
num_androids
num_androids
1
100
5.0
2
1
androids
HORIZONTAL

BUTTON
337
103
434
160
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
12
289
182
322
strategy_wrap
strategy_wrap
1
1
-1000

TEXTBOX
149
25
425
66
Simulation Parameters
24
0.0
1

TEXTBOX
1337
24
1583
61
Simulation Output
24
0.0
1

TEXTBOX
13
80
163
98
Number of turns and games
11
0.0
1

TEXTBOX
12
196
162
214
Number of AI players
11
0.0
1

TEXTBOX
15
264
165
282
How strategy strings are read
11
0.0
1

TEXTBOX
15
350
165
370
Payoff Matrix Values
16
0.0
1

SLIDER
14
402
221
435
TT_payoff
TT_payoff
0
10
2.0
1
1
Points
HORIZONTAL

SLIDER
235
403
439
436
TF_winner_payoff
TF_winner_payoff
0
10
3.0
1
1
Points
HORIZONTAL

SLIDER
13
481
220
514
TF_loser_payoff
TF_loser_payoff
0
10
0.0
1
1
Points
HORIZONTAL

SLIDER
234
480
442
513
FF_payoff
FF_payoff
0
10
0.0
1
1
Points
HORIZONTAL

TEXTBOX
15
378
265
396
Payoff when both players cooperate
11
0.0
1

TEXTBOX
239
378
439
396
Payoff to the defector of a TF scenario
11
0.0
1

TEXTBOX
14
455
225
473
Payoff to the cooperator of a TF scenario
11
0.0
1

TEXTBOX
238
454
443
472
Payoff when both players defect
11
0.0
1

MONITOR
651
16
911
81
Simulation State
STATE
17
1
16

BUTTON
219
173
434
229
Download Simulation Results
download_results
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1129
309
1317
366
Your Wins
item 0 [num_wins] of turtles with [who = 0]
17
1
14

MONITOR
1128
205
1320
262
Your Opponent
item 0 [my_opponent] of turtles with [who = 0]
17
1
14

TEXTBOX
1128
171
1278
191
This Game
16
0.0
1

TEXTBOX
1129
278
1279
298
This Simulation
16
0.0
1

MONITOR
1335
308
1523
365
Cumulative Score
item 0 [cumulative_score] of turtles with [who = 0]
17
1
14

MONITOR
1541
308
1732
365
Your Losses
item 0 [num_losses] of turtles with [who = 0]
17
1
14

PLOT
1130
394
1418
544
Cumulative Score
NIL
Score
0.0
10.0
0.0
10.0
true
true
"clear-plot\nask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n]" "ask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n plot cumulative_score\n]"
PENS

MONITOR
1545
99
1732
156
You Are
one-of turtles with [who = 0]
17
1
14

PLOT
1438
393
1732
543
Number of Wins
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"clear-plot\nask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n]" "ask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n plot num_wins\n]"
PENS

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

computer workstation
false
0
Rectangle -7500403 true true 60 45 240 180
Polygon -7500403 true true 90 180 105 195 135 195 135 210 165 210 165 195 195 195 210 180
Rectangle -16777216 true false 75 60 225 165
Rectangle -7500403 true true 45 210 255 255
Rectangle -10899396 true false 249 223 237 217
Line -16777216 false 60 225 120 225

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

crown
false
0
Rectangle -7500403 true true 45 165 255 240
Polygon -7500403 true true 45 165 30 60 90 165 90 60 132 166 150 60 169 166 210 60 210 165 270 60 255 165
Circle -16777216 true false 222 192 22
Circle -16777216 true false 56 192 22
Circle -16777216 true false 99 192 22
Circle -16777216 true false 180 192 22
Circle -16777216 true false 139 192 22

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
