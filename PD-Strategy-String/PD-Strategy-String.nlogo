;;
;; BREEDS
;;
breed [players player]

turtles-own [
  name ;; the name of the player, unused for now, to be used in the hubnet version of this simulation
  game-score ;; the score of a player in a given game of PD
  cumulative-score ;; the cumulative score of a player in this simulation
  has-played? ;; boolean variable to keep track of whether a player has played this turn
  last-opponent ;; the player's last opponent
  my-opponent ;; the player's current opponent
  partnered? ;; boolean variable to keep track of whether a player is partnered? with another player. Used during matchmaking procedures
  strategy-string ;; A string representation of the player's intended moves for the simulation. Valid characters include T (cooperate), F (defect), C (copy), O (oppose)
  move-history ;; A string representation of the player's move history. Different from the strategy string in that it only includes T's and F's
  num-wins ;; The number of wins a player has in this simulation
  num-losses ;; the number of losses a player has in this simulation
]

players-own [

]

links-own [
  players-ready ;; boolean variable to keep track of whether both players at the ends of this link are ready
  turn-played? ;; boolean variable to keep track of whether this link has played out the current turn
  ;;game-string ;; A string representation of this game's results so far [Not needed anymore]
  game-results ;; A list of all turn results in this game in the form of strings
]


;;
;; GLOBALS
;;
globals [
  curr-turn ;; the current turn of the simulation in integer form
  curr-game ;; the current game of the simulation in integer form
  data-string ;; A string representation of this simulation's results so far [Not needed anymore]
  simulation-data ;; a list of all the game-results from all the links
  player-data ;; a list of all the game-results from links that they player has been part of

  ;; Payoff Matrix
  TT-val ;; What both players get on a TT scenario
  TF-loser-val ;; What the loser of a TF scenario gets (i.e. the one who cooperates)
  TF-winner-val ;; What the winner of a TF scenario gets (i.e. the one who defects)
  FF-val ;; What both players get on an FF scenario

  ;; Game State
  STATE ;; variable to store the state
  SIM-NOT-READY ;; indicates that the simulation hasn't been initialized (i.e. setup hasn't been run)
  SIM-READY ;; indicates that the simulation has been initialized (i.e. setup has been run)
  SIM-IN-PROGRESS ;; inidicates that the simulation has started running (i.e. the go button has been hit)
  SIM-ENDED ;; indicates that the simulation has reached the end (i.e. all games have been played)

  ;; Strategies for Androids
  ;; These can be expanded upon later
  ALWAYS-COOPERATE
  ALWAYS-DEFECT
  TIT-FOR-TAT
  SUS-TIT-FOR-TAT
  COPYCAT
  CONTRARIAN
  STRATEGIES

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
  set SIM-NOT-READY "Simulation Not Ready"
  set SIM-READY "Simulation Ready"
  set SIM-IN-PROGRESS "Simulation in Progress"
  set SIM-ENDED "Simulation Ended"

  ;; set state to uninitialized
  set STATE SIM-NOT-READY
end

;;
;; SETUP PROCEDURES
;;

to setup-global-vars
  set-default-shape turtles "computer workstation"
  set curr-turn 1
  set curr-game 1
  set data-string ""
  set player-data []
  set simulation-data []
end

;; create payoff matrix for this simulation
;; these can be changed to reference a slider that the user/organizer has access to
;; referencing the sliders and setting a global according to them on setup will prevent users from accidentally changing the payoff matrix mid-simulation
to setup-payoff-matrix
  set TT-val TT-payoff
  set TF-loser-val TF-loser-payoff
  set TF-winner-val TF-winner-payoff
  set FF-val FF-payoff
end

;; define the different strategies and put them in a list
to setup-strategies
  set ALWAYS-COOPERATE "T"
  set ALWAYS-DEFECT "F"
  set TIT-FOR-TAT "TC"
  set SUS-TIT-FOR-TAT "FC"
  set COPYCAT "C"
  set CONTRARIAN "O"

  set STRATEGIES (list ALWAYS-COOPERATE ALWAYS-DEFECT TIT-FOR-TAT SUS-TIT-FOR-TAT COPYCAT CONTRARIAN)
end

to setup
  if STATE = SIM-IN-PROGRESS [stop]

  ;;clear-all
  cp
  cd
  ct ;; this may cause problems in hubnet
  clear-output
  reset-ticks

  setup-global-vars
  setup-payoff-matrix
  setup-strategies


  create-players 1 [
    set shape "person"
    set size (30 / (num-androids + 1)) ;; replace this with a value based on the number of agents in the simulation
    set name "player"
    set game-score 0
    set cumulative-score 0
    set has-played? FALSE
    set last-opponent ""
    set partnered? FALSE
    set strategy-string player-strategy-string
    set move-history ""
    set my-opponent ""
    set label cumulative-score
  ]

  create-turtles num-androids [
    set name "ai"
    set size (30 / (num-androids + 1)) ;; replace this with a value based on the number of agents in the simulation
    set game-score 0
    set cumulative-score 0
    set has-played? FALSE
    set last-opponent ""
    set partnered? FALSE

    set strategy-string one-of STRATEGIES
    set move-history ""
    set my-opponent ""
    set label cumulative-score
  ]

  layout-circle turtles (world-width / 3)

  match-prisoners

  ;; set state to ready
  set STATE SIM-READY
end

;;
;; GO
;;

to go
  ;; If simulation has ended stop
  if (STATE = SIM-ENDED) [stop]

  ;; Set state if this is the first iteration of go
  if (STATE != SIM-IN-PROGRESS) [set STATE SIM-IN-PROGRESS]

  ;; ask all links to check their results for the current turn
  ask links [
    check-turn-results
  ]

  ;; if all links have played their turn, tick, and increment the turn and game counters as needed
  if not (any? links with [turn-played? = FALSE]) [
    ;; ask links to reset their state
    ask links [ reset-link-state ]
    tick
    advance-game-state
  ]
end

;; helper observer procedure to increment the turn and game counter according to game state
to advance-game-state
  ;; if the current game is the last game, stop the simulation
  if (curr-game = num-games and curr-turn = num-turns) [
    ask links [
        ;;set data-string (word data-string game-string) ;; make the links commit their game data to the data string
        assign-wins
    ]
    output-show "The simulation has ended, all games have been played"
    set STATE SIM-ENDED
    stop
  ]

  ;; if the current turn is the last turn in a game, increment the game counter and set the turn counter to 1
  if-else (curr-turn = num-turns) [
    ask links [
      ;;set data-string (word data-string game-string) ;; make the links commit their game data to the data string
      set simulation-data (lput (game-results) (simulation-data))
      assign-wins ;; make the links assign wins and losses to their ends
    ]
    set curr-game curr-game + 1
    set curr-turn 1

    ;; now that we've started a new game, clear all the old matches and make new ones
    clear-matches
    match-prisoners
  ] [
    set curr-turn curr-turn + 1 ;; if none of the above cases are true, just increment the turn counter
    ]
end

;; helper link procedure to reset link state at the end of a turn
to reset-link-state
  set turn-played? FALSE ;; turn played is false
  set players-ready 0 ;; no players are ready this turn
  ask both-ends [
    set has-played? FALSE ;; both ends have not played this turn
  ]
end

;;
;; MATCHMAKING PROCEDURES
;;

;; This procedure is done in a very un-netlogo way. In reality I should ask all the turtles to find another turtle and make a link with them instead of looping through the agentset of all turtles with partnered? = false.
;; I leave this here as a reminder of the progress I've made in understanding the language while working on this assignment.
to match-prisoners
  while [any? turtles with [partnered? = FALSE]] [
    ask one-of turtles with [partnered? = FALSE] [
      let me self
      let myID [who] of me
      let other-turtle one-of other turtles with [last-opponent != (word myID) and partnered? = FALSE]

      create-link-with other-turtle [
        set players-ready 0
        set turn-played? FALSE
        ;;set game-string "(Turn N, Game N) | (One-turtle-ID: Move, Other-turtle-ID: Move) | Results: (+One-turtle-gain, +Other-turtle-gain)" ;; the format of the game string
        set game-results []
      ]

      set partnered? TRUE
      set last-opponent [who] of other-turtle
      set my-opponent other-turtle
      ask other-turtle [
        set partnered? TRUE
        set last-opponent myID
        set my-opponent me
      ]
    ]
  ]
end

;; procedure that is called when all the turns of a given game have been played.
;; since games are maintained by links, this procedure resets relevant player variables and kills all links
to clear-matches
  ask links [
    ask both-ends [
      set partnered? FALSE
      set move-history ""
      set game-score 0
      set has-played? FALSE
      set my-opponent ""
      ;;if ([breed] of self = players) [set strategy-string ""]
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
to handle-user-input [action]
  if (STATE != SIM-IN-PROGRESS) [stop]

  ask turtles with [who = 0] [ ;; in this simulation, this is the player, in hubnet activities this should refer to the turtle with the name that matches the player's UI
    if has-played? [stop] ;; if the player has already played this turn, then stop

    let new-strat-string (word strategy-string action) ;; create new strategy string based on action
    set strategy-string new-strat-string ;; update player's strategy string
    set has-played? TRUE ;; indicate that we've made a move this turn

    ;; !! this only works under the assumption that a turtle is only ever part of one link !!
    ask one-of my-links [
      set players-ready players-ready + 1
      check-turn-results
    ]
  ]
end

;; procedure that is called to calculate the results of a given turn in a given game of PD
;; used by the links that are maintaining the game
to check-turn-results
  ;;if (players-ready != count both-ends with [breed = players]) or (turn-played? = TRUE) [ stop ] ;; if not all players are ready or if this link has played this turn, don't check results

  ;; if all players are ready, then proceed to compute the turn results.

  let one-turtle end1
  let other-turtle end2

  ;; pre-process the command of each turtle for this turn (i.e. turn any copy or opposite moves into cooperate or defects)
  let one-turtle-eval eval-move-string one-turtle other-turtle
  let other-turtle-eval eval-move-string other-turtle one-turtle

  let one-turtle-gain 0
  let other-turtle-gain 0

  ;; calculate the results of the turn given one-turtle's and other-turtle's moves using the payoff matrix, update the game score, cumulative score, and move history
  (ifelse
    (one-turtle-eval = "T") and (other-turtle-eval = "T") [ ;; TT Scenario
      ask one-turtle [ update-turtle-results "T" TT-val ]
      ask other-turtle [ update-turtle-results "T" TT-val ]
      set one-turtle-gain TT-val
      set other-turtle-gain TT-val
    ]
    (one-turtle-eval = "T") and (other-turtle-eval = "F") [ ;; TF Scenario
      ask one-turtle [ update-turtle-results "T" TF-loser-val ]
      ask other-turtle [ update-turtle-results "F" TF-winner-val ]
      set one-turtle-gain TF-loser-val
      set other-turtle-gain TF-winner-val
    ]
    (one-turtle-eval = "F") and (other-turtle-eval = "T") [ ;; FT Scenario
      ask one-turtle [ update-turtle-results "F" TF-winner-val ]
      ask other-turtle [ update-turtle-results "T" TF-loser-val ]
      set one-turtle-gain TF-winner-val
      set other-turtle-gain TF-loser-val
    ]
    (one-turtle-eval = "F") and (other-turtle-eval = "F") [ ;; FF Scenario
      ask one-turtle [ update-turtle-results "F" FF-val ]
      ask other-turtle [ update-turtle-results "F" FF-val ]
      set one-turtle-gain FF-val
      set other-turtle-gain FF-val
    ])

;;  if (one-turtle-eval = "T") and (other-turtle-eval = "T") [ ;; TT Scenario
;;    ask one-turtle [ update-turtle-results "T" TT-val ]
;;    ask other-turtle [ update-turtle-results "T" TT-val ]
;;    set one-turtle-gain TT-val
;;    set other-turtle-gain TT-val
;;  ]
;;  if (one-turtle-eval = "T") and (other-turtle-eval = "F") [ ;; TF Scenario
;;    ask one-turtle [ update-turtle-results "T" TF-loser-val ]
;;    ask other-turtle [ update-turtle-results "F" TF-winner-val ]
;;    set one-turtle-gain TF-loser-val
;;    set other-turtle-gain TF-winner-val
;;  ]
;;  if (one-turtle-eval = "F") and (other-turtle-eval = "T") [ ;; FT Scenario
;;    ask one-turtle [ update-turtle-results "F" TF-winner-val ]
;;    ask other-turtle [ update-turtle-results "T" TF-loser-val ]
;;    set one-turtle-gain TF-winner-val
;;    set other-turtle-gain TF-loser-val
;;  ]
;;  if (one-turtle-eval = "F") and (other-turtle-eval = "F") [ ;; FF Scenario
;;    ask one-turtle [ update-turtle-results "F" FF-val ]
;;    ask other-turtle [ update-turtle-results "F" FF-val ]
;;    set one-turtle-gain FF-val
;;    set other-turtle-gain FF-val
;;  ]

  ;; ask both turtles to update their labels with the new scores we just computed
  ask one-turtle [set label cumulative-score]
  ask other-turtle [set label cumulative-score]

  ;; create the output string for this game
  ;; output string has the form:
  ;; (Turn N, Game N) | (One-turtle-ID: Move, Other-turtle-ID: Move) | Results: (+One-turtle-gain, +Other-turtle-gain)
  let output-string ""
  set output-string (word ("(Turn ") (curr-turn) (" , ") ("Game ") (curr-game) (") | (") ([who] of one-turtle) (": ") (one-turtle-eval) (", ") ([who] of other-turtle) (": ") (other-turtle-eval) (") | (") ("Result: (+") (one-turtle-gain) (", +") (other-turtle-gain) (")"))

  ;; if a player is part of this link, then output the result
  if count both-ends with [breed = players] > 0 [
    output-show output-string
    set player-data (lput (output-string) (player-data))
  ]

  ;; update this link's game results list
  ;;set (game-string) (word (game-string) (output-string))
  set game-results (lput (output-string) (game-results))

  ;; indicate that our turn has been played so the observer can pass us over
  set turn-played? TRUE
end

;; procedure to evaluate a strategy string and report the move that should be taken during this turn
;; In order to handle C and O as moves (copy and oppose), the procedure takes as input two turtles; the one that makes the move and its opponent
to-report eval-move-string [moving-turtle opponent-turtle]
  let temp-move "T" ;; if there's no valid move to copy or oppose, then copy and oppose will evaluate to cooperate

  ;; retrieve the appropriate item from the strategy string based on wrap or no-wrap
  let desired-move get-desired-move moving-turtle

  ;; in case we want to copy our opponents last move
  if desired-move = "C" [
    if (curr-turn - 2 >= 0) and ([move-history] of opponent-turtle != "") [ ;; check to see whether we're copying too early in the game first.
      set temp-move item (curr-turn - 2) ([move-history] of opponent-turtle) ;; evaluate temp-move
    ]
  ]
  ;; in case we want to make the opposite move of our opponents last move
  if desired-move = "O" [
    if (curr-turn - 2 >= 0) and ([move-history] of opponent-turtle != "") [ ;; check to see whether we're copying too early in the game first.
      ;; evaluate temp-move
      let opp-previous-move item (curr-turn - 2) ([move-history] of opponent-turtle)
      if-else opp-previous-move = "T" [ set temp-move "F" ] [ set temp-move "T" ]
    ]
  ]
  ;; in case we either cooperated or defected directly
  if desired-move = "F" [
    set temp-move "F"
  ]

  report temp-move
end

;; helper turtle procedure to update the relevant variables during the calculate-results link procedure
;; takes in a move string (i.e. "T") and a payoff value and updates this turtle's move history and score variables.
to update-turtle-results [move-string payoff-value]
  set game-score game-score + payoff-value
  set cumulative-score cumulative-score + payoff-value
  set move-history (word move-history move-string)
end

;; helper link procedure used when evaluating turtle move strings
;; computes and returns the index of the desired move based on wrap vs no-wrap as set by the organizer
;; takes in the turtle whose move index we are computing
to-report get-desired-move [target-turtle]
  let pointer (curr-turn - 1)
  let ss-length length ([strategy-string] of target-turtle)
  let move ""

  if-else strategy-wrap [
    set move item ((pointer) mod (ss-length)) ([strategy-string] of target-turtle) ;; if wrap, mod the pointer value with the length of the string
  ][
    let temp-list (list (pointer) (ss-length - 1)) ;; if no-wrap, pick the minimum between the pointer value and the length of the string (i.e. when pointer > ss-length we pick ss-length)
    let index min temp-list
    set move item (index) ([strategy-string] of target-turtle)
  ]

  report move
end

;; helper link procedure to assign wins and losses properly to the turtles at the end of this link
to assign-wins
  ;; get references to both turtles on the ends of this link
  let one-turtle end1
  let other-turtle end2

  let output-string ""
  set output-string (word ("Game ") (curr-game) (" | ") (one-turtle) (": ") ([game-score] of one-turtle) (", ") (other-turtle) (": ") ([game-score] of other-turtle) (" | Result: "))

  if [game-score] of one-turtle > [game-score] of other-turtle [
    ask one-turtle [set num-wins num-wins + 1]
    ask other-turtle [set num-losses num-losses + 1]
    set output-string (word (output-string) (one-turtle) (" wins"))
  ]
  if [game-score] of one-turtle < [game-score] of other-turtle [
    ask one-turtle [set num-losses num-losses + 1]
    ask other-turtle [set num-wins num-wins + 1]
    set output-string (word (output-string) (other-turtle) (" wins"))
  ]
  if [game-score] of one-turtle = [game-score] of other-turtle [
    ask one-turtle [set num-wins num-wins + 1]
    ask other-turtle [set num-wins num-wins + 1]
    set output-string (word (output-string) ("Draw"))
  ]

  ;; if a player is part of this link, then output the result
  if count both-ends with [breed = players] > 0 [
    output-show output-string
    set player-data (lput (output-string) (player-data))
  ]

  ;; update this link's game string
  ;;set game-string (word (game-string) (output-string))
  set game-results (lput (output-string) (game-results))
end

;;
;; RESULTS
;;

to download-player-results
  if (STATE != SIM-ENDED) [
    user-message "Downloading results is only accessible after the simulation has ended"
    stop
  ]

  file-open "player-results.txt"
  foreach player-data file-print
  file-close-all
  output-show "Player results downloaded"
end

to download-sim-results
  if (STATE != SIM-ENDED) [
    user-message "Downloading results is only accessible after the simulation has ended"
    stop
  ]

  file-open "simulation-results.txt"
  foreach simulation-data [x -> foreach x file-print]
  file-close-all
  output-show "Simulation results downloaded"
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
num-turns
num-turns
1
20
20.0
1
1
turns
HORIZONTAL

SLIDER
10
147
182
180
num-games
num-games
1
20
20.0
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
item 0 [game-score] of turtles with [who = 0]
17
1
14

MONITOR
1542
203
1733
260
Opponent's Score
[game-score] of (item 0 [my-opponent] of turtles with [who = 0])
17
1
14

MONITOR
1127
100
1318
157
Current Turn
curr-turn
17
1
14

MONITOR
1339
100
1530
157
Current Game
curr-game
17
1
14

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
num-androids
num-androids
1
100
29.0
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
strategy-wrap
strategy-wrap
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
TT-payoff
TT-payoff
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
TF-winner-payoff
TF-winner-payoff
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
TF-loser-payoff
TF-loser-payoff
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
FF-payoff
FF-payoff
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
120
573
335
629
Download Simulation Results
download-sim-results
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
item 0 [num-wins] of turtles with [who = 0]
17
1
14

MONITOR
1128
205
1320
262
Your Opponent
item 0 [my-opponent] of turtles with [who = 0]
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
item 0 [cumulative-score] of turtles with [who = 0]
17
1
14

MONITOR
1541
308
1732
365
Your Losses
item 0 [num-losses] of turtles with [who = 0]
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
"clear-plot\nask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n set-plot-pen-mode 1\n]" "clear-plot\nask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n set-plot-pen-mode 1\n plotxy who cumulative-score\n]"
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
"clear-plot\nask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n set-plot-pen-mode 1\n]" "clear-plot\nask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n set-plot-pen-mode 1\n plotxy who num-wins\n]"
PENS

BUTTON
120
640
335
696
Download Player Results
download-player-results
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
219
172
435
228
Go Once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
641
705
946
765
player-strategy-string
TC
1
0
String

@#$#@#$#@
## WHAT IS IT?

This model allows users to run simulations of prisoner???s dilemma tournaments. The user embodies an agent in the tournament and plays games against other AI participants. In this version of the model, the user programs their own AI that will participate in the simulation for them, as opposed to PD-Basic where they play each game manually.

## HOW IT WORKS

The simulation is made up of the player (a turtle of the breed ???player???), and an odd number of AI participants that each represent the prisoners of the simulation. Each simulation lasts for a set number of games, each of which lasts for a set number of turns that are played sequentially before moving on to the next turn. Each participant???s moves are represented by a strategy string which is a string representation of the moves that they intend to take in the coming turns. The string is composed of a combination of the characters T, F, C, and O which represent the actions Cooperate, Defect, Copy, and Oppose with the latter two indicating that the participant intends to copy or oppose their opponent???s last move respectively. The player specifies their strategy string in advance using the input widget below the canvas, while the android participants have a pre-set strategy string that represents one of the popular strategies used in PD games (e.g. always defects, tit for tat etc.).
During the simulation, participants are matched with each other by the observer in order to play their games against each other, and each game is maintained by a link that is responsible for reading the player???s strategy strings and keeping track of any relevant information pertaining to the game it represents. Once every turn in a given game has been played by all the active links in the simulation, the links will commit their data to the observer, update the player???s scores, wins, and other relevant variables, and then die. The observer will then match up the turtles anew to prepare for the next game in the simulation. The simulation is considered complete, once all the games have been completed and the winner of the tournament is the player with the highest cumulative score. At the end of each simulation, the player has the option of downloading text data of the results recorded from the simulation in a .txt file where each line represents a turn of a game played in the tournament. Additionally, the player can download a subset of the simulation data that represents only the games that they took part of, if they choose to do so.

## HOW TO USE IT

After loading up the model, use the controls provided on the left-hand side of the interface (labeled ???Simulation Parameters???) to set the specific variables of the simulation. Here, you can set the number of games the simulation will last, the number of turns each game will last, the number of android participants in the simulation, how the strategy strings are read, and the individual values of the payoff matrix for the simulation. Also, take the time to consider your strategy for the duration of the simulation and specify it using the input widget below the canvas. It???s worth noting that once a simulation has started, changing the values mentioned will not affect the simulation - this includes your strategy string. Regardless, after setting the values the simulation is ready to be initialized by using the ???Setup??? button which will generate all the agents, assign a randomly-picked preset strategy string to the AI participants, and create the matchups for the first game of the simulation.
Once you hit the ???Go??? or ???Go Once??? button you???ll notice the state of the simulation indicated on top of the canvas changing from ???Simulation Ready??? to ???Simulation in Progress??? and the simulation will run its course in accordance with the strategy strings specified. While the simulation is running, pay attention to the canvas, and the output of the simulation on the right part of the user interface. Here, you???ll be able to keep track of the current turn and game of the simulation, your opponent, your scores, and you???re able to get an overall macro view of the simulation via the ???Cumulative Score??? and ???Number of Wins??? plots. Finally, pay special attention to the output monitor which will give you detailed results about each turn of any games you???re part of. Once the simulation is finished, the download buttons on the lower-left hand side of the interface become usable so you can study the results of the simulations in depth.

## THINGS TO NOTICE & THINGS TO TRY

As you are playing through the simulation, try to notice what happens when you adopt different strategies and who the top players in each tournament are. Using the inspector window, what do you notice about the top performers of the tournament?  If you???ve been matched up against the top agents, scroll through your output monitor and see how your strategy interacted with theirs. Given the parameters of the simulation you created, what strategy did you think would be effective? What strategy ended up being effective in the end? How does that affect any ideas you had about maximizing your score in the simulation?

## EXTENDING THE MODEL

When extending the model, try to think of any additional strategies that you can design for the AI participants. The current collection of strategy strings don???t actually allow for many of the popular strategies that are discussed in the literature so try to see what strategies you can come up with using the primitives provided and add them to the ???STRATEGIES??? list in the model???s global variables.
 Related to this point, the language currently provided for setting the strategy strings is fairly basic in that it only takes into account the history of the game as far as the previous turn, and doesn???t allow for certain moves. Thus, a good way to extend the model would be to look into ways of making the strategy string language richer.
Finally, the model currently only allows for one simulation to be run at a time which can be a hindrance when trying to collect large amounts of data on a specific strategy. As such, try to see if you can get the model to run multiple simulations at once and see if you can get it to output the data in a form that???s useful to you.

## NETLOGO FEATURES

Note the use of links to maintain the games between prisoners, and to log the data for each game. Also note the use and processing of the strategy strings that describe each participant???s intended moves. Finally, note how the results of each turn and game are output onto the screen and written into a file using netlogo???s output methods.

## RELATED MODELS

PD-Basic
PD-Basic-Hubnet
PD-Strategy-String-Hubnet

## CREDITS AND REFERENCES

Alexandros Nikolaos Lotsos
<alexandroslotsos2026@u.northwestern.edu>

Stanford CS Material on the Prisoner???s Dilemma: https://cs.stanford.edu/people/eroberts/courses/soco/projects/1998-99/game-theory/prisoner.html

Repository with the source code for this model and its related models: https://github.com/alexlo94/LS426_PD-Activities
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
