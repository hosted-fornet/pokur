/-  poker
/+  poker
=,  poker
:-  %say
|=  [[* eny=@uv *] *]
=/  new-game-state
  [
    game-id=1
    host=~zod
    type=%cash
    players=~[~zod ~bus]
    paused=%.n
    hands-played=0 
    chips=(turn ~[~zod ~bus] |=(a=ship [a 1.000 0]))
    pot=0
    current-bet=0
    min-bet=40
    board=~
    my-hand=~
    whose-turn=~bus
    dealer=~bus
    small-blind=~bus
    big-blind=~zod
  ]
=/  state
  [
    game=new-game-state
    hands=~
    deck=(shuffle-deck generate-deck eny)
    hand-is-over=%.n
  ]
::  ~&  state
:: start of hand
=.  deck.state
  (shuffle-deck deck.state eny)
=/  state
  (~(initialize-hand modify-state state) ~bus)
:: pre-flop ROUND
=/  state
  (~(process-player-action modify-state state) ~bus [%bet 1 20])
=/  state
  ~(poker-flop modify-state state)
:: flop ROUND
=/  state
  (~(process-player-action modify-state state) ~zod [%bet 1 60])
~&  state
=/  state
  (~(process-player-action modify-state state) ~bus [%bet 1 120])
=/  state
  (~(process-player-action modify-state state) ~zod [%bet 1 60])
=/  state
  ~(turn-river modify-state state)
:: turn ROUND
=/  state
  (~(process-player-action modify-state state) ~zod [%check 1])
=/  state
  (~(process-player-action modify-state state) ~bus [%check 1])
=/  state
  ~(turn-river modify-state state)
:: river ROUND
=/  state
  (~(process-player-action modify-state state) ~zod [%check 1])
=/  state
  (~(process-player-action modify-state state) ~bus [%bet 1 100])
=/  state
  (~(process-player-action modify-state state) ~zod [%bet 1 100])
:: HAND EVALUATION
::  =/  state   (~(committed-chips-to-pot modify-state state))
=/  winner  ~(determine-winner modify-state state)
=/  state   (~(process-win modify-state state) winner)
:-  %noun
state