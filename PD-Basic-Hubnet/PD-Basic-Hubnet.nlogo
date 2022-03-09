;;
;; BREEDS
;;
breed [players player]

turtles-own [
  name ;; the name of the player, unused for now, to be used in the hubnet version of this simulation
  game_score ;; the score of a player in a given game of PD
  cumulative_score ;; the cumulative score of a player in this simulation
  has_played ;; boolean variable to keep track of whether a player has played this turn
  last_opponent ;; the player's last opponent
  my_opponent ;; the player's current opponent
  partnered ;; boolean variable to keep track of whether a player is partnered with another player. Used during matchmaking procedures
  strategy_string ;; A string representation of the player's intended moves for the simulation. Valid characters include T (cooperate), F (defect), C (copy), O (oppose)
  move_history ;; A string representation of the player's move history. Different from the strategy string in that it only includes T's and F's
  num_wins ;; The number of wins a player has in this simulation
  num_losses ;; the number of losses a player has in this simulation
  base_shape ;; the base shape of the player, used to refer to the player in the UI along with the string representation of their color
]

players-own [
  user-id ;; hubnet user-id
  move_to_play ;; move to be played this turn
]

links-own [
  players_ready ;; boolean variable to keep track of whether both players at the ends of this link are ready
  turn_played ;; boolean variable to keep track of whether this link has played out the current turn
  game_string ;; A string representation of this game's results so far [Not needed anymore]
  game_results ;; A list of all turn results in this game in the form of strings
]


;;
;; GLOBALS
;;
globals [
  curr_turn ;; the current turn of the simulation in integer form
  curr_game ;; the current game of the simulation in integer form
  data_string ;; A string representation of this simulation's results so far [Not needed anymore]
  simulation_data ;; a list of all the game_results from all the links
  player_data ;; a list of all the game_results from links that they player has been part of

  ;; Payoff Matrix
  TT_val ;; What both players get on a TT scenario
  TF_loser_val ;; What the loser of a TF scenario gets (i.e. the one who cooperates)
  TF_winner_val ;; What the winner of a TF scenario gets (i.e. the one who defects)
  FF_val ;; What both players get on an FF scenario

  ;; Game State
  STATE ;; variable to store the state
  SIM_NOT_READY ;; indicates that the simulation hasn't been initialized (i.e. setup hasn't been run)
  SIM_READY ;; indicates that the simulation has been initialized (i.e. setup has been run)
  SIM_IN_PROGRESS ;; inidicates that the simulation has started running (i.e. the go button has been hit)
  SIM_ENDED ;; indicates that the simulation has reached the end (i.e. all games have been played)

  ;; Strategies for Androids
  ;; These can be expanded upon later
  ALWAYS_COOPERATE
  ALWAYS_DEFECT
  TIT_FOR_TAT
  SUS_TIT_FOR_TAT
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
;; STARTUP PROCEDURES
;;

to startup
  hubnet-reset

  ;; define state strings
  set SIM_NOT_READY "Simulation Not Ready"
  set SIM_READY "Simulation Ready"
  set SIM_IN_PROGRESS "Simulation in Progress"
  set SIM_ENDED "Simulation Ended"

  ;; set state to uninitialized
  set STATE SIM_NOT_READY

  listen-clients
end

;;
;; SETUP PROCEDURES
;;

to setup_global_vars
  set-default-shape turtles "computer workstation"
  set curr_turn 1
  set curr_game 1
  set data_string ""
  set player_data []
  set simulation_data []
end

;; create payoff matrix for this simulation
;; these can be changed to reference a slider that the user/organizer has access to
;; referencing the sliders and setting a global according to them on setup will prevent users from accidentally changing the payoff matrix mid-simulation
to setup_payoff_matrix
  set TT_val TT_payoff
  set TF_loser_val TF_loser_payoff
  set TF_winner_val TF_winner_payoff
  set FF_val FF_payoff
end

;; define the different strategies and put them in a list
to setup_strategies
  set ALWAYS_COOPERATE "T"
  set ALWAYS_DEFECT "F"
  set TIT_FOR_TAT "TC"
  set SUS_TIT_FOR_TAT "FC"
  set COPYCAT "C"
  set CONTRARIAN "O"

  set STRATEGIES (list ALWAYS_COOPERATE ALWAYS_DEFECT TIT_FOR_TAT SUS_TIT_FOR_TAT COPYCAT CONTRARIAN)
end

to setup-vars
  set shape-names ["box" "star" "wheel" "target" "cat" "dog"
                   "butterfly" "leaf" "car" "airplane"
                   "monster" "key" "cow skull" "ghost"
                   "cactus" "moon" "heart"]
  ;; these colors were chosen with the goal of having colors
  ;; that are readily distinguishable from each other, and that
  ;; have names that everyone knows (e.g. no "cyan"!), and that
  ;; contrast sufficiently with the red infection dots and the
  ;; gray androids
  set colors      (list white brown green yellow
                        (violet + 1) (sky + 1))
  set color-names ["white" "brown" "green" "yellow"
                   "purple" "blue"]
  set max-possible-codes (length colors * length shape-names)
  set used-shape-colors []

end

;; pick a base-shape and color for the turtle
to set-unique-shape-and-color
  let code random max-possible-codes
  show code
  while [(member? (code) (used-shape-colors)) and (count players < max-possible-codes)]
  [
    set code random max-possible-codes
  ]
  set used-shape-colors (lput code used-shape-colors)
  set base_shape item (code mod length shape-names) shape-names
  set shape base_shape
  set color item (code / length shape-names) colors
end

to setup
  ;;if STATE = SIM_IN_PROGRESS [stop]

  setup-vars
  listen-clients

  clear-patches
  clear-drawing
  clear-output

  ask turtles with [breed != players] [ die ]
  ask players [reset_player_state]

  reset-ticks

  setup_global_vars
  setup_payoff_matrix
  setup_strategies

  create-turtles num_androids [
    set name "ai"
    set size (30 / (num_androids + 1)) ;; replace this with a value based on the number of agents in the simulation
    set game_score 0
    set cumulative_score 0
    set has_played FALSE
    set last_opponent ""
    set partnered FALSE

    set strategy_string one-of strategies
    set move_history ""
    set my_opponent ""
    set-unique-shape-and-color
    set label cumulative_score
  ]

  listen-clients

  layout-circle turtles (world-width / 3)

  match_prisoners

  ;; set state to ready
  set STATE SIM_READY

  ask players [ send-info-to-clients ]
end

;;
;; GO
;;

to go
  ;; If simulation has ended stop
  if (STATE = SIM_ENDED) [stop]
  ;; Set state if this is the first iteration of go
  if (STATE != SIM_IN_PROGRESS) [set STATE SIM_IN_PROGRESS]

  listen-clients
  ask players [
      show "send info block has been reached"
      send-info-to-clients ;; TODO: make sure we really need this
    ]

  ask links [
    check_turn_results
  ]

  ;; if all links have played their turn, tick, and increment the turn and game counters as needed
  if not (any? links with [turn_played = FALSE]) [
    ;; ask links to reset their state
    ask links [ reset_link_state ]
    advance_game_state
    tick
    ask players [
      show "send info block has been reached"
      send-info-to-clients
    ]
  ]
end

;; helper observer procedure to increment the turn and game counter according to game state
to advance_game_state
  ;; reset the chosen move on the client's screen
  ask players [hubnet-send user-id "Your Move This Turn Will Be:" ""]

  ;; if the current game is the last game, stop the simulation
  if (curr_game = num_games and curr_turn = num_turns) [
    ask links [
        ;;set data_string (word data_string game_string) ;; make the links commit their game data to the data string
        assign_wins
    ]
    output-show "The simulation has ended, all games have been played"
    set STATE SIM_ENDED
    stop
  ]

  ;; if the current turn is the last turn in a game, increment the game counter and set the turn counter to 1
  if-else (curr_turn = num_turns) [
    ask links [
      ;;set data_string (word data_string game_string) ;; make the links commit their game data to the data string
      set simulation_data (lput (game_results) (simulation_data))
      assign_wins ;; make the links assign wins and losses to their ends
    ]
    set curr_game curr_game + 1
    set curr_turn 1

    ;; now that we've started a new game, clear all the old matches and make new ones
    clear_matches
    match_prisoners
  ] [
    set curr_turn curr_turn + 1 ;; if none of the above cases are true, just increment the turn counter
    ]
end

;; helper link procedure to reset link state at the end of a turn
to reset_link_state
  set turn_played FALSE ;; turn played is false
  set players_ready 0 ;; no players are ready this turn
  ask both-ends [
    set has_played FALSE ;; both ends have not played this turn
  ]
end

;;
;; MATCHMAKING PROCEDURES
;;

;; This procedure is done in a very un-netlogo way. In reality I should ask all the turtles to find another turtle and make a link with them instead of looping through the agentset of all turtles with partnered = false.
;; I leave this here as a reminder of the progress I've made in understanding the language while working on this assignment.
to match_prisoners

  ;; Before we match prisoners, if there isn't an even number of
  if ((count turtles) mod (2)) != 0 [
    create-new-turtles 1
    layout-circle turtles (world-width / 3)
  ]

  while [any? turtles with [partnered = FALSE]] [
    ask one-of turtles with [partnered = FALSE] [
      let me self
      let myID [who] of me
      let other_turtle one-of other turtles with [last_opponent != (word myID) and partnered = FALSE]

      create-link-with other_turtle [
        set players_ready 0
        set turn_played FALSE
        set game_string "(Turn N, Game N) | (One_turtle_ID: Move, Other_turtle_ID: Move) | Results: (+One_turtle_gain, +Other_turtle_gain)\r" ;; the format of the game string
        set game_results []
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

  ask players with [user-id = hubnet-message-source] [ ;; in this simulation, this is the player, in hubnet activities this should refer to the turtle with the name that matches the player's UI
    if has_played [stop] ;; if the player has already played this turn, then stop

    let new_strat_string (word strategy_string action) ;; create new strategy string based on action
    set strategy_string new_strat_string ;; update player's strategy string
    set has_played TRUE ;; indicate that we've made a move this turn

    send-info-to-clients
    hubnet-send user-id "Your Move This Turn Will Be:" action

    ask one-of my-links [
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

  let one_turtle end1
  let other_turtle end2

  ;; pre-process the command of each turtle for this turn (i.e. turn any copy or opposite moves into cooperate or defects)
  let one_turtle_eval eval_move_string one_turtle other_turtle
  let other_turtle_eval eval_move_string other_turtle one_turtle

  let one_turtle_gain 0
  let other_turtle_gain 0

  ;; calculate the results of the turn given one_turtle's and other_turtle's moves using the payoff matrix, update the game score, cumulative score, and move history
  ;; this really should be removed to a separate procedure but I can't figure out how to keep a mapping the evals to the turtles without being in this context so this procedure is bloated
  ;; this also could be a switch statement but I'm not sure how to do those in netlogo
  if (one_turtle_eval = "T") and (other_turtle_eval = "T") [ ;; TT Scenario
    ask one_turtle [ update_turtle_results "T" TT_val ]
    ask other_turtle [ update_turtle_results "T" TT_val ]
    set one_turtle_gain TT_val
    set other_turtle_gain TT_val
  ]
  if (one_turtle_eval = "T") and (other_turtle_eval = "F") [ ;; TF Scenario
    ask one_turtle [ update_turtle_results "T" TF_loser_val ]
    ask other_turtle [ update_turtle_results "F" TF_winner_val ]
    set one_turtle_gain TF_loser_val
    set other_turtle_gain TF_winner_val
  ]
  if (one_turtle_eval = "F") and (other_turtle_eval = "T") [ ;; FT Scenario
    ask one_turtle [ update_turtle_results "F" TF_winner_val ]
    ask other_turtle [ update_turtle_results "T" TF_loser_val ]
    set one_turtle_gain TF_winner_val
    set other_turtle_gain TF_loser_val
  ]
  if (one_turtle_eval = "F") and (other_turtle_eval = "F") [ ;; FF Scenario
    ask one_turtle [ update_turtle_results "F" FF_val ]
    ask other_turtle [ update_turtle_results "F" FF_val ]
    set one_turtle_gain FF_val
    set other_turtle_gain FF_val
  ]

  ;; ask both turtles to update their labels with the new scores we just computed
  ask one_turtle [set label cumulative_score]
  ask other_turtle [set label cumulative_score]

  ;; create the output string for this game
  ;; output string has the form:
  ;; (Turn N, Game N) | (One_turtle_ID: Move, Other_turtle_ID: Move) | Results: (+One_turtle_gain, +Other_turtle_gain)
  let output_string ""
  set output_string (word ("(Turn ") (curr_turn) (" , ") ("Game ") (curr_game) (") | (") (color-string [color] of one_turtle) (" ") ([base_shape] of one_turtle) (": ") (one_turtle_eval) (", ") (color-string [color] of other_turtle) (" ") ([base_shape] of other_turtle) (": ") (other_turtle_eval) (") | (") ("Result: (+") (one_turtle_gain) (", +") (other_turtle_gain) (")"))

  ;; if a player is part of this link, then output the result
  if count both-ends with [breed = players] > 0 [
    output-show output_string
    set player_data (lput (output_string) (player_data))
  ]

  ;; update this link's game results list
  ;;set (game_string) (word (game_string) (output_string))
  set game_results (lput (output_string) (game_results))

  ;; indicate that our turn has been played so the observer can pass us over
  set turn_played TRUE
end

;; procedure to evaluate a strategy string and report the move that should be taken during this turn
;; In order to handle C and O as moves (copy and oppose), the procedure takes as input two turtles; the one that makes the move and its opponent
to-report eval_move_string [moving_turtle opponent_turtle]
  let temp_move "T" ;; if there's no valid move to copy or oppose, then copy and oppose will evaluate to cooperate

  ;; retrieve the appropriate item from the strategy string based on wrap or no-wrap
  let desired_move get_desired_move moving_turtle

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

;; helper turtle procedure to update the relevant variables during the calculate_results link procedure
;; takes in a move string (i.e. "T") and a payoff value and updates this turtle's move history and score variables.
to update_turtle_results [move_string payoff_value]
  set game_score game_score + payoff_value
  set cumulative_score cumulative_score + payoff_value
  set move_history (word move_history move_string)
end

;; helper link procedure used when evaluating turtle move strings
;; computes and returns the index of the desired move based on wrap vs no-wrap as set by the organizer
;; takes in the turtle whose move index we are computing
to-report get_desired_move [target_turtle]
  let pointer (curr_turn - 1)
  let ss_length length ([strategy_string] of target_turtle)
  let move ""

  if-else strategy_wrap [
    set move item ((pointer) mod (ss_length)) ([strategy_string] of target_turtle) ;; if wrap, mod the pointer value with the length of the string
  ][
    let temp_list (list (pointer) (ss_length - 1)) ;; if no-wrap, pick the minimum between the pointer value and the length of the string (i.e. when pointer > ss_length we pick ss_length)
    let index min temp_list
    set move item (index) ([strategy_string] of target_turtle)
  ]

  report move
end

;; helper link procedure to assign wins and losses properly to the turtles at the end of this link
to assign_wins
  ;; get references to both turtles on the ends of this link
  let one_turtle end1
  let other_turtle end2

  let output_string ""
  set output_string (word ("Game ") (curr_game) (" | ") (color-string [color] of one_turtle) (" ") ([base_shape] of one_turtle) (": ") ([game_score] of one_turtle) (", ") (color-string [color] of other_turtle) (" ") ([base_shape] of other_turtle) (": ") ([game_score] of other_turtle) (" | Result: "))

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
  if count both-ends with [breed = players] > 0 [
    output-show output_string
    set player_data (lput (output_string) (player_data))
  ]

  ;; update this link's game string
  ;;set game_string (word (game_string) (output_string))
  set game_results (lput (output_string) (game_results))
end

;;
;; RESULTS
;;

to download_player_results
  if (STATE != SIM_ENDED) [
    user-message "Downloading results is only accessible after the simulation has ended"
    stop
  ]

  file-open "player_results.txt"
  foreach player_data file-print
  file-close-all
  output-show "Player results downloaded"
end

to download_sim_results
  if (STATE != SIM_ENDED) [
    user-message "Downloading results is only accessible after the simulation has ended"
    stop
  ]

  file-open "simulation_results.txt"
  foreach simulation_data [x -> foreach x file-print]
  file-close-all
  output-show "Simulation results downloaded"
end

;;
;; HUBNET STUFF
;;

to listen-clients
  ;; as long as there are more messages from the clients
  ;; keep processing them.
  while [ hubnet-message-waiting? ]
  [
    ;; get the first message in the queue
    hubnet-fetch-message
    ifelse hubnet-enter-message? ;; when clients enter we get a special message
    [
      create-new-player
      show "A player has exited"
      layout-circle turtles (world-width / 3)
    ]
    [
      ifelse hubnet-exit-message? ;; when clients exit we get a special message
      [
        remove-player
        show "A player has left"
      ]
      [ ask players with [user-id = hubnet-message-source]
        [ execute-command hubnet-message-tag ] ;; otherwise the message means that the user has
      ]                                        ;; done something in the interface hubnet-message-tag
                                               ;; is the name of the widget that was changed
    ]
  ]
end

;; when a new user logs in create a player turtle
;; this turtle will store any state on the client
;; values of sliders, etc.
to create-new-player
  create-players 1
  [
    ;; store the message-source in user-id now
    ;; so when you get messages from this client
    ;; later you will know which turtle it affects
    set user-id hubnet-message-source

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
    set label (word user-id (" | ") cumulative_score)

    show label

    set-unique-shape-and-color

    ;; update the clients with any information you have set
    ;;send-info-to-clients
  ]
end

;; procedure to create a number of new turtles
to create-new-turtles [num]
  create-turtles num [
    set name "ai"
    set size (30 / (num_androids + 1)) ;; replace this with a value based on the number of agents in the simulation
    set game_score 0
    set cumulative_score 0
    set has_played FALSE
    set last_opponent ""
    set partnered FALSE

    set strategy_string one-of STRATEGIES
    set move_history ""
    set my_opponent ""
    set label cumulative_score
  ]
end

;; turtle procedure used by players to reset the state at the end of the simulation without having to reconnect
to reset_player_state
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
    set num_wins 0
    set num_losses 0
    set label (word user-id (" | ") cumulative_score)
end

;; when a user logs out make sure to clean up the turtle
;; that was associated with that user (so you don't try to
;; send messages to it after it is gone) also if any other
;; turtles of variables reference this turtle make sure to clean
;; up those references too.
to remove-player
  ask players with [user-id = hubnet-message-source] [
    ;; if a player leaves the simulation, they just get their breed changed to a regular turtle
    set name "ai"
    set size (30 / (num_androids + 1)) ;; replace this with a value based on the number of agents in the simulation
    set game_score 0
    set cumulative_score 0
    set has_played FALSE
    set last_opponent ""
    set partnered FALSE

    set move_history ""
    set my_opponent ""
    set label cumulative_score

    set strategy_string one-of (list (ALWAYS_COOPERATE) (ALWAYS_DEFECT) (TIT_FOR_TAT) (COPYCAT) (CONTRARIAN))
    set breed turtles
  ]
end

to execute-command [command]
  if command = "Cooperate" [handle_user_input "T"]
  if command = "Defect" [handle_user_input "F"]
end

;; whenever something in world changes that should be displayed in
;; a monitor on the client send the information back to the client
to send-info-to-clients ;; turtle procedure
  hubnet-send user-id "Simulation State:" STATE
  hubnet-send user-id "Current Turn:" curr_turn
  hubnet-send user-id "Current Game:" curr_game
  hubnet-send user-id "Number of Games This Simulation Will Last" num_games
  hubnet-send user-id "Strategy Wrap Enabled?" strategy_wrap
  hubnet-send user-id "Number of AI Players" num_androids
  hubnet-send user-id "TT Payoff" TT_val
  hubnet-send user-id "TF Winner Payoff" TF_winner_val
  hubnet-send user-id "TF Loser Payoff" TF_loser_val
  hubnet-send user-id "FF Payoff" FF_val

  hubnet-send user-id "You are a:" (word (color-string color) " " base_shape)
  hubnet-send user-id "Your Opponent is a:" (word (color-string [color] of my_opponent) " " ([base_shape] of my_opponent))
  hubnet-send user-id "Your Score is:" game_score
  hubnet-send user-id "Your Opponent's Score is:" [game_score] of my_opponent
  hubnet-send user-id "Your Move History:" move_history
  hubnet-send user-id "Your Opponent's Move History:" [move_history] of my_opponent

  if not(empty? [game_results] of one-of my-links) [hubnet-send user-id "Last Game Results:" [last game_results] of one-of my-links]

  hubnet-send user-id "Your Cumulative Score is:" cumulative_score
  hubnet-send user-id "Your Wins:" num_wins
  hubnet-send user-id "Your Losses:" num_losses

  ;;hubnet-send user-id "Your Move This Turn Will Be:" "" ;;reset what their chosen move is
end

;; report the string version of the turtle's color
to-report color-string [color-value]
  report item (position color-value colors) color-names
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
3.0
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
3.0
1
1
games
HORIZONTAL

MONITOR
1235
95
1426
152
Current Turn
curr_turn
17
1
14

MONITOR
1444
95
1635
152
Current Game
curr_game
17
1
14

BUTTON
223
102
321
158
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
7.0
2
1
androids
HORIZONTAL

BUTTON
341
102
438
159
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
125
570
340
626
Download Simulation Results
download_sim_results
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1105
185
1426
335
Cumulative Score
NIL
Score
0.0
10.0
0.0
10.0
true
true
"clear-plot\nask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n set-plot-pen-mode 1\n]" "clear-plot\nask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n set-plot-pen-mode 1\n plotxy who cumulative_score\n]"
PENS

PLOT
1443
184
1766
334
Number of Wins
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"clear-plot\nask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n set-plot-pen-mode 1\n]" "clear-plot\nask turtles [\n create-temporary-plot-pen (word self)\n set-current-plot-pen (word self)\n set-plot-pen-color color\n set-plot-pen-mode 1\n plotxy who num_wins\n]"
PENS

OUTPUT
1105
369
1769
692
12

BUTTON
223
170
439
225
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

android
false
0
Polygon -7500403 true true 210 90 240 195 210 210 165 90
Circle -7500403 true true 110 3 80
Polygon -7500403 true true 105 88 120 193 105 240 105 298 135 300 150 210 165 300 195 298 195 240 180 193 195 88
Rectangle -7500403 true true 127 81 172 96
Rectangle -16777216 true false 135 33 165 60
Polygon -7500403 true true 90 90 60 195 90 210 135 90

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
false
0
Rectangle -7500403 true true 92 135 207 224
Circle -7500403 true true 158 53 134
Circle -7500403 true true 165 180 90
Circle -7500403 true true 45 180 90
Circle -7500403 true true 8 53 134
Line -16777216 false 43 189 253 189
Rectangle -7500403 true true 135 60 165 285
Circle -7500403 true true 165 15 30
Circle -7500403 true true 105 15 30
Line -7500403 true 120 30 135 60
Line -7500403 true 165 60 180 30
Line -16777216 false 135 60 135 285
Line -16777216 false 165 285 165 60

cactus
false
0
Rectangle -7500403 true true 135 30 175 177
Rectangle -7500403 true true 67 105 100 214
Rectangle -7500403 true true 217 89 251 167
Rectangle -7500403 true true 157 151 220 185
Rectangle -7500403 true true 94 189 148 233
Rectangle -7500403 true true 135 162 184 297
Circle -7500403 true true 219 76 28
Circle -7500403 true true 138 7 34
Circle -7500403 true true 67 93 30
Circle -7500403 true true 201 145 40
Circle -7500403 true true 69 193 40

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

cat
false
0
Line -7500403 true 285 240 210 240
Line -7500403 true 195 300 165 255
Line -7500403 true 15 240 90 240
Line -7500403 true 285 285 195 240
Line -7500403 true 105 300 135 255
Line -16777216 false 150 270 150 285
Line -16777216 false 15 75 15 120
Polygon -7500403 true true 300 15 285 30 255 30 225 75 195 60 255 15
Polygon -7500403 true true 285 135 210 135 180 150 180 45 285 90
Polygon -7500403 true true 120 45 120 210 180 210 180 45
Polygon -7500403 true true 180 195 165 300 240 285 255 225 285 195
Polygon -7500403 true true 180 225 195 285 165 300 150 300 150 255 165 225
Polygon -7500403 true true 195 195 195 165 225 150 255 135 285 135 285 195
Polygon -7500403 true true 15 135 90 135 120 150 120 45 15 90
Polygon -7500403 true true 120 195 135 300 60 285 45 225 15 195
Polygon -7500403 true true 120 225 105 285 135 300 150 300 150 255 135 225
Polygon -7500403 true true 105 195 105 165 75 150 45 135 15 135 15 195
Polygon -7500403 true true 285 120 270 90 285 15 300 15
Line -7500403 true 15 285 105 240
Polygon -7500403 true true 15 120 30 90 15 15 0 15
Polygon -7500403 true true 0 15 15 30 45 30 75 75 105 60 45 15
Line -16777216 false 164 262 209 262
Line -16777216 false 223 231 208 261
Line -16777216 false 136 262 91 262
Line -16777216 false 77 231 92 261

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

cow skull
false
0
Polygon -7500403 true true 150 90 75 105 60 150 75 210 105 285 195 285 225 210 240 150 225 105
Polygon -16777216 true false 150 150 90 195 90 150
Polygon -16777216 true false 150 150 210 195 210 150
Polygon -16777216 true false 105 285 135 270 150 285 165 270 195 285
Polygon -7500403 true true 240 150 263 143 278 126 287 102 287 79 280 53 273 38 261 25 246 15 227 8 241 26 253 46 258 68 257 96 246 116 229 126
Polygon -7500403 true true 60 150 37 143 22 126 13 102 13 79 20 53 27 38 39 25 54 15 73 8 59 26 47 46 42 68 43 96 54 116 71 126

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

dog
false
0
Polygon -7500403 true true 300 165 300 195 270 210 183 204 180 240 165 270 165 300 120 300 0 240 45 165 75 90 75 45 105 15 135 45 165 45 180 15 225 15 255 30 225 30 210 60 225 90 225 105
Polygon -16777216 true false 0 240 120 300 165 300 165 285 120 285 10 221
Line -16777216 false 210 60 180 45
Line -16777216 false 90 45 90 90
Line -16777216 false 90 90 105 105
Line -16777216 false 105 105 135 60
Line -16777216 false 90 45 135 60
Line -16777216 false 135 60 135 45
Line -16777216 false 181 203 151 203
Line -16777216 false 150 201 105 171
Circle -16777216 true false 171 88 34
Circle -16777216 false false 261 162 30

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

ghost
false
0
Polygon -7500403 true true 30 165 13 164 -2 149 0 135 -2 119 0 105 15 75 30 75 58 104 43 119 43 134 58 134 73 134 88 104 73 44 78 14 103 -1 193 -1 223 29 208 89 208 119 238 134 253 119 240 105 238 89 240 75 255 60 270 60 283 74 300 90 298 104 298 119 300 135 285 135 285 150 268 164 238 179 208 164 208 194 238 209 253 224 268 239 268 269 238 299 178 299 148 284 103 269 58 284 43 299 58 269 103 254 148 254 193 254 163 239 118 209 88 179 73 179 58 164
Line -16777216 false 189 253 215 253
Circle -16777216 true false 102 30 30
Polygon -16777216 true false 165 105 135 105 120 120 105 105 135 75 165 75 195 105 180 120
Circle -16777216 true false 160 30 30

heart
false
0
Circle -7500403 true true 152 19 134
Polygon -7500403 true true 150 105 240 105 270 135 150 270
Polygon -7500403 true true 150 105 60 105 30 135 150 270
Line -7500403 true 150 270 150 135
Rectangle -7500403 true true 135 90 180 135
Circle -7500403 true true 14 19 134

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

key
false
0
Rectangle -7500403 true true 90 120 300 150
Rectangle -7500403 true true 270 135 300 195
Rectangle -7500403 true true 195 135 225 195
Circle -7500403 true true 0 60 150
Circle -16777216 true false 30 90 90

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

monster
false
0
Polygon -7500403 true true 75 150 90 195 210 195 225 150 255 120 255 45 180 0 120 0 45 45 45 120
Circle -16777216 true false 165 60 60
Circle -16777216 true false 75 60 60
Polygon -7500403 true true 225 150 285 195 285 285 255 300 255 210 180 165
Polygon -7500403 true true 75 150 15 195 15 285 45 300 45 210 120 165
Polygon -7500403 true true 210 210 225 285 195 285 165 165
Polygon -7500403 true true 90 210 75 285 105 285 135 165
Rectangle -7500403 true true 135 165 165 270

moon
false
0
Polygon -7500403 true true 175 7 83 36 25 108 27 186 79 250 134 271 205 274 281 239 207 233 152 216 113 185 104 132 110 77 132 51

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
VIEW
457
99
1042
684
0
0
0
1
1
1
1
1
0
1
1
1
-16
16
-16
16

TEXTBOX
1264
22
1477
53
Simulation Output
24
0.0
1

TEXTBOX
104
24
356
56
Simulation Parameters
24
0.0
1

MONITOR
627
21
870
70
Simulation State:
NIL
3
1

BUTTON
541
706
733
739
Cooperate
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
757
705
949
738
Defect
NIL
NIL
1
T
OBSERVER
NIL
NIL

MONITOR
1065
99
1233
148
Current Turn:
NIL
3
1

MONITOR
1253
98
1421
147
Current Game:
NIL
3
1

MONITOR
1442
98
1617
147
You are a:
NIL
3
1

MONITOR
1064
207
1231
256
Your Opponent is a:
NIL
3
1

TEXTBOX
1063
176
1213
196
This Game
16
0.0
1

MONITOR
1253
206
1417
255
Your Score is:
NIL
3
1

MONITOR
1442
205
1620
254
Your Opponent's Score is:
NIL
3
1

TEXTBOX
1061
442
1211
462
This Simulation
16
0.0
1

MONITOR
1251
475
1415
524
Your Wins:
NIL
3
1

MONITOR
1061
476
1227
525
Your Cumulative Score is:
NIL
3
1

MONITOR
1440
474
1619
523
Your Losses:
NIL
3
1

TEXTBOX
145
309
295
329
Payoff Matrix Values
16
0.0
1

TEXTBOX
19
354
238
372
Payoff when both players cooperate
11
0.0
1

TEXTBOX
234
354
432
372
Payoff to the defector of a TF scenario
11
0.0
1

TEXTBOX
17
445
227
463
Payoff to the cooperator of a TF scenario
11
0.0
1

TEXTBOX
235
446
416
464
Payoff when both players defect
11
0.0
1

MONITOR
17
376
225
425
TT Payoff
NIL
3
1

MONITOR
233
376
442
425
TF Winner Payoff
NIL
3
1

MONITOR
16
467
226
516
TF Loser Payoff
NIL
3
1

MONITOR
234
468
443
517
FF Payoff
NIL
3
1

MONITOR
105
168
349
217
Strategy Wrap Enabled?
NIL
3
1

MONITOR
105
232
349
281
Number of AI Players
NIL
3
1

MONITOR
106
101
349
150
Number of Games This Simulation Will Last
NIL
3
1

MONITOR
1062
285
1325
334
Your Opponent's Move History:
NIL
3
1

MONITOR
1345
285
1620
334
Your Move History:
NIL
3
1

MONITOR
540
770
950
819
Your Move This Turn Will Be:
NIL
3
1

MONITOR
1063
360
1620
409
Last Game Results:
NIL
3
1

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
