/-  *pokur
/+  default-agent, dbug, *pokur
|%
+$  versioned-state
    $%  state-zero
    ==
+$  state-zero
    $:  %0
        active-games=(map @da server-game-state) 
    ==
::
+$  card  card:agent:gall
::
--
%-  agent:dbug
=|  state=versioned-state
^-  agent:gall
=<
|_  =bowl:gall
+*  this      .
    def   ~(. (default-agent this %|) bowl)
    hc    ~(. +> bowl)
::
++  on-init
  ^-  (quip card _this)
  ~&  >  '%pokur-server initialized successfully'
  `this
++  on-save
  ^-  vase
  !>(state)
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  ~&  >  '%pokur-server recompiled successfully'
  `this(state !<(versioned-state old-state))
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
      %noun
    ?+    q.vase  (on-poke:def mark vase)
        %print-state
      ~&  >  state
      ~&  >>  bowl  `this
      ::
        %print-subs
      ~&  >>  &2.bowl  `this
    ==
    ::
    %pokur-server-action
    =^  cards  state
    (handle-server-action:hc !<(server-action:pokur vase))
    [cards this]
    ::
    %pokur-game-action
    =^  cards  state
    (handle-game-action:hc !<(game-action:pokur vase))
    [cards this]
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
    [%game @ta @ta ~]
  :: make sure the subscriber is in game and on their path, reject if not
  =/  game-id  `(unit @da)`(slaw %da i.t.path)
  ?~  game-id
    :_  this
      =/  err  "invalid game id {<game-id>}"
      :~  [%give %watch-ack `~[leaf+err]]
    == 
  =/  game  (~(get by active-games.state) u.game-id)
  ?~  game
    :_  this
      =/  err  "invalid game id {<u.game-id>}"
      :~  [%give %watch-ack `~[leaf+err]]
    ==
  =/  player  `(unit @p)`(slaw %p i.t.t.path)
  ?~  player
    :_  this
      =/  err  "invalid player"
      :~  [%give %watch-ack `~[leaf+err]]
    == 
  ?~  (find [u.player]~ players.game.u.game)
    :_  this
      =/  err  "player not in this game"
      :~  [%give %watch-ack `~[leaf+err]]
    ==
  ?>  =(src.bowl u.player)
    :: give a good subscriber their game state
    :: find their hand
    =.  my-hand.game.u.game
      +.-:(skim hands.u.game |=([s=ship h=poker-deck] =(s u.player)))
    :_  this
      :~  :*  
            %give 
            %fact 
            ~[/game/(scot %da u.game-id)/(scot %p u.player)]
            [%pokur-game-state !>(game.u.game)]
          ==
      ==
  ==
++  on-leave
  |=  =path
  ~&  "got leave request from {<src.bowl>}"
  `this
++  on-peek   on-peek:def
++  on-agent  on-agent:def
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+  wire  (on-arvo:def wire sign-arvo)
    [%timer @ta ~]
  :: the timer ran out.. a player didn't make a move in time
  =/  game-id  (need `(unit @da)`(slaw %da i.t.wire))
  ~&  >>>  "Player timed out on game {<game-id>}"
  :: find active player in that game
  =/  game
    (~(get by active-games.state) game-id)
  ?~  game
    ~&  >>>  "error: turn timeout on non-existent game."
    ~&  >>>  "this is fine if a game just ended and its last timer is expiring."
    :_  this  ~
  ~&  >>>  "current time: {<now.bowl>}"
  :: reset that game's turn timer
  =.  turn-timer.u.game  ~
  =.  active-games.state
  (~(put by active-games.state) [game-id u.game])
  =/  player-to-fold
    whose-turn.game.u.game
  =/  current-time  now.bowl
  =^  cards  state
  (perform-move current-time player-to-fold game-id %fold 0)
  [cards this]
  ==
++  on-fail   on-fail:def
--
::  start helper core
|_  bowl=bowl:gall
++  get-game-by-id
  |=  game-id=@da
  ^-  server-game-state
  ::  TODO obviously add error handling to this
  ::  actually just get rid of this and error handle at all 3 places this gets used.
  (~(got by active-games.state) game-id)
++  generate-update-cards
  |=  game=server-game-state
  ^-  (list card)
  ?.  hand-is-over.game
    ~[[%pass /poke-wire %agent [our.bowl %pokur-server] %poke %pokur-server-action !>([%send-game-updates game])]]
  ?.  =(0 (lent players.game.game))
    :: initialize new hand, update message to clients
    ~[[%pass /poke-wire %agent [our.bowl %pokur-server] %poke %pokur-server-action !>([%initialize-hand game-id.game.game])]]
  ~[[%pass /poke-wire %agent [our.bowl %pokur-server] %poke %pokur-server-action !>([%end-game game-id.game.game])]]
++  perform-move
  |=  [time=@da who=ship game-id=@da move-type=@tas amount=@ud]
  ^-  (quip card _state)
  =/  game  (get-game-by-id game-id)
  :: validate that move is from right player
  ?.  =(whose-turn.game.game who)
    :_  state
    ~[[%give %poke-ack `~[leaf+"error: playing out of turn!"]]]
  ::  set new turn timer
  =/  new-timer
    `@da`(add time ~s15)
  =/  timer-cards
  ::  if we had an active one, cancel old turn timer while setting new one
  ?.  =(turn-timer.game ~)
    :~
      [%pass /timer/(scot %da game-id.game.game) %arvo %b %rest `@da`turn-timer.game]
      [%pass /timer/(scot %da game-id.game.game) %arvo %b %wait new-timer]
    == 
    ~[[%pass /timer/(scot %da game-id.game.game) %arvo %b %wait new-timer]]
  ~&  >>  "timer cards: {<timer-cards>}"
  ::  hold current timer-time in game state
  =.  turn-timer.game  new-timer
  =.  game 
  :: this is lame, i am lame
  ?:  =(move-type %bet)
    (~(process-player-action modify-state game) who [%bet game-id amount])
  ?:  =(move-type %check)
    (~(process-player-action modify-state game) who [%check game-id])
  (~(process-player-action modify-state game) who [%fold game-id])
  =.  active-games.state
  (~(put by active-games.state) [game-id game])
  :_  state
    %+  weld
      timer-cards
    (generate-update-cards game)
++  handle-game-action
  |=  action=game-action:pokur
  ^-  (quip card _state)
  ~&  >  "recieving action at {<now.bowl>}"
  ?-  -.action
      %check
    (perform-move now.bowl src.bowl game-id.action %check 0)
      %bet
    (perform-move now.bowl src.bowl game-id.action %bet amount.action)
      %fold
    (perform-move now.bowl src.bowl game-id.action %fold 0)
  ==
++  handle-server-action
  |=  =server-action:pokur
  ^-  (quip card _state)
  ?-  -.server-action
    %register-game
  ~&  >>  "Game initiated with server {<our.bowl>}."
  =/  players
    %+  turn
      players.challenge.server-action
    |=  [player=ship ? ?]
    player
  =/  chips
    %+  turn 
      players
    |=  player=ship
    [player starting-stack.challenge.server-action 0 %.n %.n %.n]
  =/  new-game-state
    [
      game-id=id.challenge.server-action  
      host=host.challenge.server-action
      type=type.challenge.server-action
      players=players
      paused=%.n
      update-message="Pokur game started, served by {<our.bowl>}"
      hands-played=0
      chips=chips
      pot=0
      current-bet=0
      min-bet=min-bet.challenge.server-action
      last-bet=0
      board=~
      my-hand=~
      whose-turn=(snag 1 players)
      dealer=(snag 1 players)  :: TODO this should be random perhaps?
      small-blind=~zod :: these get re-assigned in hand initialization,
      big-blind=~zod   :: ~zod is placeholder.
    ]
  =/  new-server-state
    [
      game=new-game-state
      hands=~
      deck=(shuffle-deck generate-deck eny.bowl)
      hand-is-over=%.y
      turn-timer=~
    ]
  =.  active-games.state
    (~(put by active-games.state) [id.challenge.server-action new-server-state])
  :_  state
    :: init first hand here
    :~  :*  %pass  /poke-wire  %agent 
            [our.bowl %pokur-server] 
            %poke  %pokur-server-action 
            !>([%initialize-hand id.challenge.server-action])
        ==
    ==
    ::
    %leave-game
  =/  game  (get-game-by-id game-id.server-action)
  :: remove sender from their game
  =/  game
    (~(remove-player modify-state game) src.bowl)
  =.  active-games.state
    (~(put by active-games.state) [game-id.server-action game])
  :_  state
    (generate-update-cards game)
    ::
    %initialize-hand
  ?>  (team:title [our src]:bowl)
  =/  game  (get-game-by-id game-id.server-action)
    :: first, shuffle
  =.  deck.game
    (shuffle-deck deck.game eny.bowl)
  =/  game
    (~(initialize-hand modify-state game) dealer.game.game)
  =/  cards
    %+  turn 
        hands.game 
      |=  hand=[ship poker-deck]
      (~(make-player-cards modify-state game) hand) 
  =.  active-games.state
    (~(put by active-games.state) [game-id.server-action game])
  :_  state
    cards
    ::
    ::
    %send-game-updates
  ?>  (team:title [our src]:bowl)
  =/  cards
    %+  turn 
        hands.game.server-action 
      |=  hand=[ship poker-deck]
      (~(make-player-cards modify-state game.server-action) hand)  
  :_  state
    cards
    ::
    ::
    %kick
  ?>  (team:title [our src]:bowl)
  :_  state
    ~[[%give %kick paths.server-action `subscriber.server-action]]  
    ::
    ::
    %end-game
  ?>  (team:title [our src]:bowl)
  ~&  "a game has ended: {<game-id.server-action>}"
  =.  active-games.state
  (~(del by active-games.state) game-id.server-action)
  :_  state
    ~
    ::
    ::
    %wipe-all-games :: for debugging, mostly
  ?>  (team:title [our src]:bowl)
  =.  active-games.state
    ~  
  ~&  >>>  "server wiped"
  :_  state
    ~
  ==
--
