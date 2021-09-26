/-  pokur :: import types from sur/pokur.hoon
=,  pokur
|%
++  modify-state
  |_  state=server-game-state
::  modifies game-state with hand from 
::  server-state to send copy to given player
  ++  make-player-cards 
    |=  hand=[ship poker-deck]
    =.  my-hand.game.state
      (tail hand)
    :^  %give 
        %fact 
        ~[/game/(scot %da game-id.game.state)/(scot %p (head hand))]
        [%pokur-game-state !>(game.state)]
::  checks if all players have acted or folded, and 
::  committed the same amount of chips, OR,
::  if a player is all-in, i.e. has 0 in stack
  ++  is-betting-over
    ^-  ?
    =/  acted-check
      |=  [who=ship n=@ud c=@ud acted=? folded=? left=?]
      ?|  =(acted %.y)
          =(folded %.y)
      ==
    ?.  (levy chips.game.state acted-check)
      %.n
    =/  f
      |=  [who=ship n=@ud c=@ud acted=? folded=? left=?]
      ?|  =(c current-bet.game.state)
          =(n 0)
          =(folded %.y)
      ==
    (levy chips.game.state f)
::  checks cards on table and either initiates flop, 
::  turn, river, or determine-winner
  ++  next-round
    ^-  server-game-state
    =/  n  (lent board.game.state)
    ?:  |(=(3 n) =(4 n))
      turn-river
    ?:  =(5 n)
      (process-win determine-winner)
    poker-flop
::  **takes in a shuffled deck**
::  assign dealer, assign blinds, assign first action 
::  to person left of BB (which is dealer in heads-up)
::  make sure to shuffle deck from outside with eny!!!
::  check for players who have left, remove them
  ++  initialize-hand
    |=  dealer=ship
    ^-  server-game-state
    =.  players.game.state
      %+  skip
        players.game.state
      |=  s=ship
        left:(get-player-chips s chips.game.state)
    =.  chips.game.state
      %+  skip
        chips.game.state
      |=  [ship @ud @ud ? ? left=?]
        left
    =.  dealer.game.state   
      %+  get-next-unfolded-player 
        dealer 
      players.game.state
    =.  state
      assign-blinds
    =.  state
      deal-hands
    =.  whose-turn.game.state   
      %+  get-next-unfolded-player 
        big-blind.game.state 
      players.game.state
    =.  hand-is-over.state  
      %.n
    state
::  deals 2 cards from deck to each player in game
  ++  deal-hands
    ^-  server-game-state
    =/  dealt-count  (lent players.game.state)
    |-
    ?:  =(dealt-count 0)
      state
    =/  new  
    (draw 2 deck.state)
    =/  player  
    (snag (dec dealt-count) players.game.state)
    %=  $
      hands.state    [player hand:new]^hands.state
      deck.state     rest:new
      dealt-count  (dec dealt-count)
    ==
  ++  poker-flop
    ^-  server-game-state
    =.  state
      committed-chips-to-pot
    (deal-to-board 3)
  ++  turn-river
    ^-  server-game-state
    =.  state
      committed-chips-to-pot
    (deal-to-board 1)
::  draws n cards (after burning 1) from deck, 
::  appends them to board state, and sets action 
::  to the next unfolded player left of dealer
  ++  deal-to-board
    |=  n=@ud
    ^-  server-game-state
    =/  burn  (draw 1 deck.state)
    =/  turn  (draw n rest:burn)
    =.  deck.state
      rest:turn
    =.  board.game.state
      %+  weld
        hand:turn
      board.game.state
    :: setting who goes first in betting round here
    =.  whose-turn.game.state
      dealer.game.state 
    next-player-turn
::  sets whose-turn to next player in list **who hasn't folded**
::  if all players are folded, this means that everyone left..
  ++  next-player-turn
    ^-  server-game-state
    =.  whose-turn.game.state
      (get-next-unfolded-player whose-turn.game.state players.game.state)
    state
  ++  get-next-unfolded-player
    |=  [player=ship players=(list ship)]
    ^-  ship
    =/  unfolded-players
      %+  turn
        %+  skip
          chips.game.state
        |=  [s=ship @ud @ud ? folded=? ?]
          folded
      |=  [s=ship @ud @ud ? ? ?]
        s
    ?~  unfolded-players
      :: everyone left, just return something so server can delete
      player
    =/  whose-turn  player 
    |-
    =/  next-player
      %+  get-next-player 
        whose-turn 
      players.game.state
    :: if next hasn't folded, set turn to them and return
    ?^  (find [next-player]~ unfolded-players)
      next-player
    :: otherwise recurse to find next unfolded player
    $(whose-turn next-player)
  ::  returns name of ship that's to the left of given ship
  ++  get-next-player
    |=  [player=ship players=(list ship)]
    ^-  ship
    =/  player-position
      (find [player]~ players)
    (snag (mod +(u.+.player-position) (lent players)) players)
  ::  given a ship in game, returns their chip count [name stack committed]
  ++  get-player-chips
    |=  [who=ship chips=(list [ship in-stack=@ud committed=@ud ? ? ?])]
    ^-  [who=ship in-stack=@ud committed=@ud acted=? folded=? left=?]
    =/  f
      |=  [p=ship n=@ud c=@ud ? ? ?]
      =(p who)
    (head (skim chips f))
::  sends chips from player's 'stack' to their 
::  'committed' pile. used after a bet, call, raise
::  is made. committed chips don't go to pot until 
::  round of betting is complete
  ++  commit-chips
    |=  [who=ship amount=@ud]
    ^-  server-game-state
    =/  f
      |=  [p=ship n=@ud c=@ud acted=? folded=? left=?]
      ?:  =(p who)
        [p (sub n amount) (add c amount) acted folded left]
      [p n c acted folded left] 
    =.  chips.game.state  (turn chips.game.state f)
    state
  ++  set-player-as-acted
    |=  who=ship
    ^-  server-game-state
    =/  f
      |=  [p=ship n=@ud c=@ud acted=? folded=? left=?]
      ?:  =(p who)
        [p n c %.y folded left]
      [p n c acted folded left] 
    =.  chips.game.state  (turn chips.game.state f)
    state
  ++  set-player-as-folded
    |=  who=ship
    ^-  server-game-state
    =/  f
      |=  [p=ship n=@ud c=@ud acted=? folded=? left=?]
      ?:  =(p who)
        [p n c acted %.y left]
      [p n c acted folded left] 
    =.  chips.game.state  (turn chips.game.state f)
    state
  ++  set-player-as-left
    |=  who=ship
    ^-  server-game-state
    =/  f
      |=  [p=ship n=@ud c=@ud acted=? folded=? left=?]
      ?:  =(p who)
        [p n c %.y %.y %.y]
      [p n c acted folded left] 
    =.  chips.game.state  (turn chips.game.state f)
    state
  ++  committed-chips-to-pot
    ^-  server-game-state 
    =/  f
      |=  [[p=ship n=@ud c=@ud acted=? folded=? left=?] pot=@ud]
        =.  pot  
          (add c pot)
        [[p n 0 %.n folded left] pot]
    =/  new  (spin chips.game.state pot.game.state f)
    =.  pot.game.state          q.new
    =.  chips.game.state        p.new
    =.  current-bet.game.state  0
    =.  last-bet.game.state     0
    state
::  takes blinds from the two unfolded players left of dealer
::  (big blind is calculated as min-bet, small blind is 1/2 min. could change..)
::  (in heads up, dealer is small blind)
  ++  assign-blinds
    ^-  server-game-state
    =.  small-blind.game.state  
      ?:  =((lent players.game.state) 2)
        dealer.game.state
      (get-next-unfolded-player dealer.game.state players.game.state)
    =.  big-blind.game.state   
      (get-next-unfolded-player small-blind.game.state players.game.state)
    =.  state
      %+  commit-chips 
        small-blind.game.state 
      (div min-bet.game.state 2)
    =.  state
      %+  commit-chips
        big-blind.game.state
      min-bet.game.state
    =.  current-bet.game.state
      min-bet.game.state
    =.  last-bet.game.state
      min-bet.game.state
    state
::  given [winner [rank hand]], send them the pot. prepare for next hand by
::  clearing board, hands and bets, reset fold status, increment hands-played.
::  TODO in future, should manage raising of blinds and other things...
  ++  process-win
    |=  [winner=ship [rank=@ud hand=poker-deck]]
    ^-  server-game-state
    =/  f
      |=  [p=ship n=@ud c=@ud acted=? folded=? left=?]
      ?:  =(p winner) 
        [p (add n (add c pot.game.state)) 0 %.n %.n left]
      [p n 0 %.n %.n left] 
    :: sends any extra committed chips to pot
    =.  state                    committed-chips-to-pot
    :: give pot to winner 
    =.  chips.game.state         (turn chips.game.state f)
    =.  pot.game.state           0
    :: take hands away, clear board, clear bet
    =.  board.game.state         ~
    =.  current-bet.game.state   0
    =.  last-bet.game.state      0
    =.  hands.state              ~
    :: inc hands-played
    =.  hands-played.game.state  +(hands-played.game.state)
    :: set fresh deck
    =.  deck.state               generate-deck
    :: set any players with stack of 0 to folded
    =.  chips.game.state
      %+  turn
        chips.game.state
      |=  [s=ship stack=@ud c=@ud acted=? folded=? left=?]
        ?:  =(stack 0)
          [s stack c %.y %.y %.n]
        [s stack c acted folded left]
    :: set hand to over to trigger next hand on server
    =.  hand-is-over.state       %.y
    :: update game message to inform clients
    =.  update-message.game.state
      ?:  =(rank 10)
        "{<winner>} wins hand"
      "{<winner>} wins hand with {<(hierarchy-to-rank rank)>}"
    :: TODO: BLINDS UP/DOWN etc should be here?
    state
::  given a player and a poker-action, handles the action.
::  currently checks for being given the wrong player (not their turn),
::  bad bet (2x existing bet, >BB, or matches current bet (call)),
::  and trying to check when there's a bet to respond to.
::  * if betting is complete, go right into flop/turn/river/determine-winner
::  * folds trigger win for other player (assumes heads-up)
  ++  process-player-action
    :: what type should rule violating actions return?
    :: or can !! be handled by gall app?
    |=  [who=ship action=game-action]
    ^-  server-game-state
    ?.  =(who whose-turn.game.state)
      :: error, wrong player making move
      !!
    ?-  -.action
      %check
    =/  committed
    committed:(get-player-chips who chips.game.state)
    ?:  (gth current-bet.game.state committed)
      :: error, player must match current bet
      !!
    ::  set checking player to 'acted'
    =.  state
      (set-player-as-acted who)
    ?.  is-betting-over
      next-player-turn
    next-round
      %bet
    =/  stack  
      in-stack:(get-player-chips who chips.game.state)
    =/  bet-plus-committed  
      %+  add 
        amount.action 
      committed:(get-player-chips who chips.game.state)
    :: ALL-IN logic here
    ?:  ?|  =(amount.action stack)
            (gth amount.action stack)
        ==
      :: if someone tries to bet more than their stack, count it as an all-in
      =.  last-bet.game.state
        :: same with last-bet, only update if raise
        ?:  (gth bet-plus-committed current-bet.game.state)
          (sub bet-plus-committed current-bet.game.state)
        last-bet.game.state
      =.  current-bet.game.state
        :: only update current bet if the all-in is a raise
        ?:  (gth bet-plus-committed current-bet.game.state)
          bet-plus-committed
        current-bet.game.state
      =.  state
        (commit-chips who stack)
      =.  state
        (set-player-as-acted who)
      =.  update-message.game.state
        "{<who>} is all-in."
      ?.  is-betting-over
        next-player-turn
      next-round  
    :: resume logic for not-all-in
    ?:  ?&  
          =(current-bet.game.state 0)
          (lth bet-plus-committed min-bet.game.state)
        ==
      !!  :: this is a starting bet below min-bet
    ?:  =(bet-plus-committed current-bet.game.state)
      :: this is a call
      =.  state
      %+  commit-chips
        who
      amount.action
      =.  state
      (set-player-as-acted who)
      ?.  is-betting-over
        next-player-turn
      next-round
    ?.  ?&
          (gte amount.action last-bet.game.state)
          (gte bet-plus-committed (add last-bet.game.state current-bet.game.state))
        ==
      :: error, raise must be >= amount of previous bet/raise
      !!
    :: process raise 
    :: do this before updating current-bet
    =.  last-bet.game.state
      (sub bet-plus-committed current-bet.game.state)
    =.  current-bet.game.state
      bet-plus-committed
    =.  state
      (commit-chips who amount.action)
    =.  state
      (set-player-as-acted who)
    ?.  is-betting-over
      next-player-turn
    next-round
      %fold
    =.  state
      (set-player-as-acted who)
    =.  state
      (set-player-as-folded who)
    :: if only one player hasn't folded, process win for them
    =/  players-left
      %+  turn
        %+  skip
          chips.game.state
        |=  [ship @ud @ud ? folded=? ?]
          folded
      |=  [s=ship @ud @ud ? ? ?]
        s
    ?:  =((lent players-left) 1)
      %-  process-win
      [-.players-left [10 ~]]
    :: otherwise continue game
    ?.  is-betting-over
      next-player-turn
    next-round
    ==
  ++  determine-winner
    ^-  [ship [@ud poker-deck]]
    =/  eval-each-hand
      |=  [who=ship hand=poker-deck]
      =/  hand  
        (weld hand board.game.state)  
      [who (evaluate-hand hand)]
    =/  hand-ranks  (turn hands.state eval-each-hand)
    :: return player with highest hand rank
    =/  player-ranks  
      %+  sort 
        hand-ranks 
      |=  [a=[p=ship [r=@ud h=poker-deck]] b=[p=ship [r=@ud h=poker-deck]]]
      (gth r.a r.b)
    :: check for tie(s) and break before returning winner
    ?:  =(-.+.-.player-ranks -.+.+<.player-ranks)
      =/  player-ranks
        %+  sort  player-ranks
          |=  [a=[p=ship [r=@ud h=poker-deck]] b=[p=ship [r=@ud h=poker-deck]]]
          ^-  ?
          (break-ties +.a +.b)
      (head player-ranks)
    (head player-ranks)
  ++  remove-player
    |=  who=ship
    ^-  server-game-state
    :: set player to folded/acted/left
    :: if it was their turn, go to next player's turn
    =.  state
      (set-player-as-left who)
    ?:  =(whose-turn.game.state who)
      ?.  is-betting-over
        next-player-turn
      next-round
    state
  --
::
::  Hand evaluation and sorted helper arms
::
:: **returns a cell of [hierarchy-number hand]
++  evaluate-hand
  |=  hand=poker-deck
  ^-  [@ud poker-deck]
  =/  get-sub-hand
    |=  [c=@ud h=poker-deck]
    ::  generate a hand without card c
    [(oust [c 1] h) h]
  =/  possible-6-hands  
    %+  turn 
      p:(spin (gulf 0 6) hand get-sub-hand)
    |=(h=poker-deck [(eval-6-cards h) h])
  =.  possible-6-hands
    %+  sort 
      possible-6-hands 
    |=  [a=[r=@ud h=poker-deck] b=[r=@ud h=poker-deck]]
    (gth r.a r.b)
  ::  need to break ties between equally-ranked hands here
  =/  best-6-hand-rank
    -.-.possible-6-hands
  =.  possible-6-hands
    %+  skim
      possible-6-hands
    |=  [r=@ud h=poker-deck]
    ^-  ?
    =(r best-6-hand-rank)
  =/  best-6-hand
    ?:  (gth (lent possible-6-hands) 1) 
      %-  head
      %+  sort
        possible-6-hands
      break-ties
    (head possible-6-hands)
  =/  possible-5-hands
    %+  turn
      p:(spin (gulf 0 5) +.best-6-hand get-sub-hand)
    |=(h=poker-deck [(eval-5-cards h) h])
  =.  possible-5-hands
    %+  sort
      possible-5-hands 
    |=  [a=[r=@ud h=poker-deck] b=[r=@ud h=poker-deck]]
    (gth r.a r.b)
  ::  elimate any hand without a score that matches top hand
  ::  if there are multiple, sort them by break-ties
  =/  best-hand-rank
    -.-.possible-5-hands
  =.  possible-5-hands
    %+  skim
      possible-5-hands
    |=  [r=@ud h=poker-deck]
    ^-  ?
    =(r best-hand-rank)
  ?:  (gth (lent possible-5-hands) 1)
    =.  possible-5-hands
      %+  sort
        possible-5-hands
      break-ties
    (head possible-5-hands)
  (head possible-5-hands)
++  eval-6-cards
  |=  hand=poker-deck
  ^-  @ud
  :: check for pairs 
  =/  make-histogram
    |=  [c=[@ud @ud] h=(list @ud)]
      =/  new-hist  (snap h -.c (add 1 (snag -.c h)))
      [c new-hist]
  =/  r  (spin (turn hand card-to-raw) (reap 13 0) make-histogram) 
  =/  raw-hand  p.r
  =/  histogram  (sort (skip q.r |=(x=@ud =(x 0))) gth)
  ?:  |(=(histogram ~[4 1 1]) =(histogram ~[4 2]))
    7
  ?:  |(=(histogram ~[3 2 1]) =(histogram ~[3 3]))
    6
  ?:  =(histogram ~[3 1 1 1])
    3
  ?:  |(=(histogram ~[2 2 1 1]) =(histogram ~[2 2 2]))
    2
  =/  is-pair  =(histogram ~[2 1 1 1 1])
  :: at this point, must sort hand
  =.  raw-hand  (sort raw-hand |=([a=[@ud @ud] b=[@ud @ud]] (gth -.a -.b)))
  :: check for flush
  =/  is-flush  (check-6-hand-flush raw-hand)
  :: check for straight
  =/  is-straight  (check-6-hand-straight raw-hand)
  ?:  &(is-straight is-flush !is-pair)
    8
  ?:  is-flush
    5
  ?:  &(is-straight !is-pair)
    4
  :: check down here cause this can possibly contain flush
  ?:  is-pair
    1
  0
++  eval-5-cards
  |=  hand=poker-deck
  ^-  @ud 
  :: check for pairs 
  =/  make-histogram
    |=  [c=[@ud @ud] h=(list @ud)]
      =/  new-hist  (snap h -.c (add 1 (snag -.c h)))
      [c new-hist]
  =/  r  (spin (turn hand card-to-raw) (reap 13 0) make-histogram) 
  =/  raw-hand  p.r
  =/  histogram  (sort (skip q.r |=(x=@ud =(x 0))) gth)
  ?:  =(histogram ~[4 1])
    7
  ?:  =(histogram ~[3 2])
    6
  ?:  =(histogram ~[3 1 1])
    3
  ?:  =(histogram ~[2 2 1])
    2
  ?:  =(histogram ~[2 1 1 1])
    1
  :: at this point, must sort hand
  =.  raw-hand  (sort raw-hand |=([a=[@ud @ud] b=[@ud @ud]] (gth -.a -.b)))
  :: check for flush
  =/  is-flush  (check-5-hand-flush raw-hand)
  :: check for straight
  =/  is-straight  (check-5-hand-straight raw-hand)
  :: check for royal flush
  ?:  &(is-straight is-flush)
    ?:  &(=(-.-.raw-hand 12) =(-.+>+>-.raw-hand 8))
      :: if this code ever executes i will smile
      :: ~&  >  "someone just got a royal flush!"
      9
    8
  ?:  is-flush
    5
  ?:  is-straight
    4
  0
++  check-6-hand-flush
  |=  raw-hand=(list [@ud @ud])
  ^-  ?
  =/  f
    |=  [c=@ud h=(list [@ud @ud])]
    ::  generate a hand without card c
    [(oust [c 1] h) h]
  (lien (turn p:(spin (gulf 0 5) raw-hand f) check-5-hand-flush) |=(a=? a))
++  check-5-hand-flush
  |=  raw-hand=(list [@ud @ud])
  ^-  ?
  =/  first-card-suit  +:(head raw-hand)
  =/  suit-check
    |=  c=[@ud @ud]
      =(+.c first-card-suit)
  (levy raw-hand suit-check)
:: **hand must be sorted before using this
++  check-6-hand-straight
  |=  raw-hand=(list [@ud @ud])
  ^-  ?
  =/  f
    |=  [c=@ud h=(list [@ud @ud])]
    ::  generate a hand without card c
    [(oust [c 1] h) h]
  (lien (turn p:(spin (gulf 0 5) raw-hand f) check-5-hand-straight) |=(a=? a))
:: **hand must be sorted before using this
++  check-5-hand-straight
  |=  raw-hand=(list [@ud @ud])
  ^-  ?
  ?:  =(4 (sub -.-.raw-hand -.+>+>-.raw-hand))
    %.y
  :: also need to check for wheel straight
  ?:  &(=(-.-.raw-hand 12) =(-.+<.raw-hand 3))
    %.y
  %.n
:: given two hands, returns %.y if 1 is better than 2 (like gth)
:: use in a sort function to sort hands with more granularity to find true winner
++  break-ties
  |=  [hand1=[r=@ud h=poker-deck] hand2=[r=@ud h=poker-deck]]
  ^-  ?
  ::  if ranks are strictly better, just return that
  ::  otherwise break equally-ranked hands
  ?.  =(r.hand1 r.hand2)
    (gth r.hand1 r.hand2)
  ::  sort whole hands to start
  =/  sorter
   |=  [a=poker-card b=poker-card]
     (gth (card-val-to-atom -.a) (card-val-to-atom -.b))
  =.  h.hand1  (sort h.hand1 sorter)
  =.  h.hand2  (sort h.hand2 sorter)
  ::  match tie-breaking strategy to type of hand
  ?:  ?|  =(r.hand1 8)
          =(r.hand1 5)
          =(r.hand1 4)
          =(r.hand1 0)
        ==
    (find-high-card-recursive h.hand1 h.hand2)
  ?:  ?|  =(r.hand1 7)
          =(r.hand1 6)
          =(r.hand1 3)
          =(r.hand1 2)
          =(r.hand1 1)
        ==
    =.  h.hand1
      %-  sort-hand-by-frequency 
        h.hand1
    =.  h.hand2
      %-  sort-hand-by-frequency 
        h.hand2
    %+  find-high-card-recursive 
      h.hand1 
    h.hand2
  :: if we get here we were given a wrong hand rank or a royal flush (can't tie those)
  %.n
:: **this assumes it is getting a rank-sorted hand**
++  sort-hand-by-frequency
  |=  hand=poker-deck
  ^-  poker-deck
  ::  need to preserve sorting, other than moving pairs/sets to top
  ::  this is n^2 complexity and can/should be better... 
  =/  get-frequency
    |=  c=poker-card
    ^-  @ud
    %-  lent
      %+  skim
        hand
      |=  [d=poker-card]
        =(-.d -.c)  
  =/  sorted-cards-with-frequencies
    %+  sort
      %+  turn
        hand
      |=  [c=poker-card]
        [c (get-frequency c)]
    |=  [a=[c=poker-card f=@ud] b=[c=poker-card f=@ud]]
      ?:  =(f.a f.b)
        (gth -.c.a -.c.b)
      (gth f.a f.b)
  :: get rid of freq counts for final return
  %+  turn
    sorted-cards-with-frequencies
  |=  [c=poker-card f=@ud]
    c
:: %.y if hand1 has higher card, %.n if hand2 does  
++  find-high-card-recursive
  |=  [hand1=poker-deck hand2=poker-deck]
  ^-  ?
  =/  top-card-1
    (card-val-to-atom -:(head hand1)) 
  =/  top-card-2
    (card-val-to-atom -:(head hand2))
  ?:  =(top-card-1 top-card-2)
    ?:  &(=((lent hand1) 1) =((lent hand2) 1))
      %.n  
    $(hand1 (tail hand1), hand2 (tail hand2))
  ?:  %+  gth   
        top-card-1
      top-card-2
    %.y
  %.n
::  not actually using this anywhere
++  rank-to-hierarchy
  |=  rank=poker-hand-rank
  ^-  @ud
  ?-  rank
    %royal-flush      9
    %straight-flush   8
    %four-of-a-kind   7
    %full-house       6
    %flush            5
    %straight         4
    %three-of-a-kind  3
    %two-pair         2
    %pair             1
    %high-card        0
  ==
++  hierarchy-to-rank
  |=  h=@ud
  ^-  tape
  ?+  h  "-"
    %9  "Royal Flush"  
    %8  "Straight Flush"   
    %7  "Four of a Kind"   
    %6  "Full House"  
    %5  "Flush"      
    %4  "Straight"         
    %3  "Three of a Kind"  
    %2  "Two Pair"         
    %1  "Pair"             
    %0  "High Card"        
  ==
++  card-to-raw
  |=  c=poker-card
  ^-  [@ud @ud]
  [(card-val-to-atom -.c) (suit-to-atom +.c)]
++  card-val-to-atom
  |=  c=card-val
  ^-  @ud
  ?-  c
    %2      0 
    %3      1
    %4      2
    %5      3
    %6      4
    %7      5
    %8      6
    %9      7
    %10     8
    %jack   9
    %queen  10
    %king   11
    %ace    12
  ==
++  suit-to-atom
  |=  s=suit
  ^-  @ud
  ?-  s
    %hearts    0
    %spades    1
    %clubs     2
    %diamonds  3
  ==
++  atom-to-card-val
  |=  n=@ud
  ^-  card-val
  ?+  n  !! :: ^-(card-val `@tas`n) :: if non-face card just use number?? need to coerce type
    %0   %2
    %1   %3
    %2   %4
    %3   %5
    %4   %6
    %5   %7
    %6   %8
    %7   %9
    %8   %10
    %9   %jack
    %10  %queen
    %11  %king
    %12  %ace
  ==
++  atom-to-suit
  |=  val=@ud
  ^-  suit
  ?+  val  !!
    %0  %hearts
    %1  %spades
    %2  %clubs
    %3  %diamonds
  ==
++  generate-deck
  ^-  poker-deck
  =|  new-deck=poker-deck
  =/  i  0
  |-
  ?:  (gth i 3)
    new-deck
  =/  j  0
  |-
  ?.  (lte j 12)
    ^$(i +(i))
  %=  $
    j         +(j)
    new-deck  [(atom-to-card-val j) (atom-to-suit i)]^new-deck
  ==
::  given a deck and entropy, return shuffled deck
::  TODO: this could be better... not sure it's robust enough for real play
++  shuffle-deck
  |=  [unshuffled=poker-deck entropy=@]
  ^-  poker-deck
  =|  shuffled=poker-deck
  =/  random  ~(. og entropy)
  =/  remaining  (lent unshuffled)
  |-
  ?:  =(remaining 1)
    :_  shuffled
    (snag 0 unshuffled)
  =^  index  random  (rads:random remaining)
  %=  $
    shuffled      (snag index unshuffled)^shuffled
    remaining     (dec remaining)
    unshuffled    (oust [index 1] unshuffled)
  ==
::  gives back [hand rest] where hand is n cards from top of deck, rest is rest
++  draw
  |=  [n=@ud d=poker-deck]
  ^-  [hand=poker-deck rest=poker-deck]
  :-  (scag n d)
  (slag n d)
--
