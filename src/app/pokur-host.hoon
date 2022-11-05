/-  *pokur
/+  default-agent, dbug, *pokur
|%
+$  card  card:agent:gall
+$  versioned-state  $%(state-0)
+$  state-0
  $:  %0
      my-info=(unit host-info)
      lobbies=(map @da table)
      games=(map @da host-game-state)
  ==
--
%-  agent:dbug
=|  state=state-0
^-  agent:gall
=<
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
    hc    ~(. +> bowl)
::
++  on-init
  ^-  (quip card _this)
  `this(state [%0 ~ ~ ~])
++  on-save
  ^-  vase
  !>(state)
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  `this(state !<(versioned-state old))
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  =^  cards  state
    ?+    mark  (on-poke:def mark vase)
        %pokur-player-action
      ::  starting lobbies, games, etc
      (handle-player-action:hc !<(player-action vase))
        %pokur-game-action
      ::  checks, bets, folds inside game
      (handle-game-action:hc !<(game-action vase))
        %pokur-host-action
      ::  internal pokes and host management
      (handle-host-action:hc !<(host-action vase))
    ==
  [cards this]
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-watch:def path)
      [%lobby-updates ~]
    ::  new player using us as host; poke them with our escrow info
    ~&  >  "new player {<src.bowl>} joined lobby, sending tables available"
    :_  this
    :~  :^  %give  %fact  ~
        :-  %pokur-host-update
        !>(`host-update`[%lobby ~(val by lobbies.state)])
      ::
        :*  %pass  /share-escrow-poke
            %agent  [src.bowl %pokur]
            %poke  %pokur-host-action
            !>(`host-action`[%escrow-info (need my-info.state)])
        ==
    ==
  ::
      [%table-updates @ ~]
    ::  updates about a specific table
    =/  table-id  (slav %da i.t.path)
    ?~  table=(~(get by lobbies.state) table-id)
      !!
    :_  this  :_  ~
    :^  %give  %fact  ~
    [%pokur-host-update !>(`host-update`[%table u.table])]
  ::
      [%game-updates @ @ ~]
    ::  assert the player is in game and on their path
    =/  game-id  (slav %da i.t.path)
    =/  player  (slav %p i.t.t.path)
    ?>  =(player src.bowl)
    ?~  host-game=(~(get by games.state) game-id)
      :_  this
      =/  err  "invalid game id {<game-id>}"
      :~  [%give %watch-ack `~[leaf+err]]
      ==
    ?~  (find [src.bowl]~ players.game.u.host-game)
      ?.  spectators-allowed.game.u.host-game
        :_  this
        =/  err  "player not in this game"
        :~  [%give %watch-ack `~[leaf+err]]
        ==
      ::  give game state to a spectator
      =.  spectators.game.u.host-game
        (~(put in spectators.game.u.host-game) src.bowl)
      :_  this(games.state (~(put by games.state) game-id u.host-game))
      :_  ~
      :^  %give  %fact  ~
      [%pokur-host-update !>(`host-update`[%game game.u.host-game])]
    ::  give game state to a player
    =.  my-hand.game.u.host-game
      (fall (~(get by hands.u.host-game) src.bowl) ~)
    :_  this  :_  ~
    :^  %give  %fact  ~
    [%pokur-host-update !>(`host-update`[%game game.u.host-game])]
  ==
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+    wire  (on-arvo:def wire sign-arvo)
      [%timer @ %round-timer ~]
    :: ROUND TIMER wire (for tournaments)
    =/  game-id  (slav %da i.t.wire)
    ?~  host-game=(~(get by games.state) game-id)
      `this
    =*  game  game.u.host-game
    :: if no players left in game, end it
    ?:  %+  levy  players.game
        |=([ship @ud @ud ? ? left=?] left)
      =^  cards  state
        (end-game u.host-game)
      [cards this]
    =.  u.host-game
      ~(increment-current-round modify-game-state u.host-game)
    :_  this(games.state (~(put by games.state) game-id u.host-game))
    %+  snoc
      (send-game-updates u.host-game)
    ::  set new round timer
    ?>  ?=(%tournament -.game-type.game)
    :*  %pass  /timer/(scot %da game-id)/round-timer
        %arvo  %b  %wait
        (add now.bowl round-duration.game-type.game)
    ==
  ::
      [%timer @ ~]
    :: TURN TIMER wire
    :: the timer ran out.. a player didn't make a move in time
    =/  game-id  (slav %da i.t.wire)
    ~&  >>>
    "%pokur-host: player timed out on game {<game-id>} at {<now.bowl>}"
    ::  find whose turn it is
    ?~  host-game=(~(get by games.state) game-id)
      `this
    =*  game  game.u.host-game
    ::  if no players left in game, end it
    ?:  %+  levy  players.game
        |=([ship @ud @ud ? ? left=?] left)
      =^  cards  state
        (end-game u.host-game)
      [cards this]
    :: reset that game's turn timer
    =.  turn-timer.u.host-game  *@da
    =.  update-message.game
      [(crip "{<whose-turn.game>} timed out.") ~]
    :_  this(games.state (~(put by games.state) game-id u.host-game))
    :_  ~
    :*  %pass  /self-poke-wire
        %agent  [our.bowl %pokur-host]
        %poke  %pokur-game-action
        !>([%fold game-id])
    ==
  ==
++  on-peek
  ::  TODO add scries
  on-peek:def
++  on-agent  on-agent:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
::  start helper core
|_  bowl=bowl:gall
++  handle-host-action
  |=  action=host-action
  ^-  (quip card _state)
  ?-    -.action
      %escrow-info
    `state(my-info `+.action)
  ==
::
++  handle-game-action
  |=  action=game-action
  ^-  (quip card _state)
  ?~  host-game=(~(get by games.state) game-id.action)
    :_  state
    ~[[%give %poke-ack `~[leaf+"error: host could not find game"]]]
  =*  game  game.u.host-game
  :: validate that move is from right player
  =/  from=ship
    ?:  =(src.bowl our.bowl)
      :: automatic fold from timeout!
      whose-turn.game
    src.bowl
  ?.  =(whose-turn.game from)
    :_  state
    ~[[%give %poke-ack `~[leaf+"error: playing out of turn!"]]]
  :: poke ourself to set a turn timer
  =/  new-timer  (add now.bowl turn-time-limit.game)
  =.  turn-timer.u.host-game  new-timer
  =.  u.host-game
    =+  (~(process-player-action modify-game-state u.host-game) from action)
    ?~  -  !!  u.-
  =.  games.state  (~(put by games.state) id.game u.host-game)
  =^  cards  state
    ?.  game-is-over.game
      ?.  hand-is-over.u.host-game
        (send-game-updates u.host-game)^state
      (initialize-new-hand u.host-game)
    (end-game u.host-game)
  :_  state
  %+  weld  cards
  ^-  (list card)
  :-  :*  %pass  /timer/(scot %da id.game)
          %arvo  %b  %wait
          new-timer
      ==
  ?~  turn-timer.u.host-game
    :: there's no ongoing timer to cancel, just set new
    ~
  :: there's an ongoing turn timer, cancel it and set fresh one
  :_  ~
  :*  %pass  /timer/(scot %da id.game)
      %arvo  %b  %rest
      turn-timer.u.host-game
  ==
::
++  handle-player-action
  |=  action=player-action
  ^-  (quip card _state)
  ?+    -.action  !!
      %new-table
    ?<  (~(has by lobbies.state) id.action)
    =/  =table
      :*  id.action
          src.bowl
          (silt ~[src.bowl])
          min-players.action
          max-players.action
          game-type.action
          tokenized.action
          ~  ::  TODO bond id
          spectators-allowed.action
          turn-time-limit.action
      ==
    =+  (~(put by lobbies.state) id.action table)
    :_  state(lobbies -)
    :_  ~
    :^  %give  %fact  ~[/lobby-updates]
    [%pokur-host-update !>(`host-update`[%lobby ~(val by -)])]
  ::
      %join-table
    ::  add player to existing table
    ?~  table=(~(get by lobbies.state) id.action)
      !!
    ::  table must not be full
    ?<  =(max-players.u.table ~(wyt in players.u.table))
    =.  players.u.table
      (~(put in players.u.table) src.bowl)
    :_  state(lobbies (~(put by lobbies.state) id.action u.table))
    :_  ~
    :^  %give  %fact  ~[/table-updates/(scot %da id.u.table)]
    [%pokur-host-update !>(`host-update`[%table u.table])]
  ::
      %leave-table
    ::  remove player from existing table
    ?~  table=(~(get by lobbies.state) id.action)
      !!
    ?.  (~(has in players.u.table) src.bowl)
      `state
    =.  players.u.table
      (~(del in players.u.table) src.bowl)
    :_  state(lobbies (~(put by lobbies.state) id.action u.table))
    :_  ~
    :^  %give  %fact  ~[/table-updates/(scot %da id.u.table)]
    [%pokur-host-update !>(`host-update`[%table u.table])]
  ::
      %start-game
    ::  table creator starts game
    ?~  table=(~(get by lobbies.state) id.action)
      !!
    ?>  =(leader.u.table src.bowl)
    ?>  (gte ~(wyt in players.u.table) min-players.u.table)
    ~&  >  "%pokur-host: starting new game {<id.action>}"
    =?    game-type.u.table
        ?=(%tournament -.game-type.u.table)
      %=  game-type.u.table
        current-round  0
        round-is-over  %.n
      ==
    =/  =game
      :*  id.u.table
          game-is-over=%.n
          game-type.u.table
          turn-time-limit.u.table
          %+  turn  ~(tap in players.u.table)
          |=  =ship
          [ship starting-stack.game-type.u.table 0 %.n %.n %.n]
          pots=~[[0 ~(tap in players.u.table)]]
          current-bet=0
          last-bet=0
          board=~
          my-hand=~
          whose-turn=*ship
          dealer=*ship
          small-blind=*ship
          big-blind=*ship
          spectators-allowed.u.table
          spectators=~
          hands-played=0
          [(crip "Pokur game started, hosted by {<our.bowl>}") ~]
      ==
    =/  =host-game-state
      :*  hands=~
          deck=(shuffle-deck generate-deck eny.bowl)
          hand-is-over=%.y
          turn-timer=(add now.bowl turn-time-limit.u.table)
          game
      ==
    =^  cards  state
      (initialize-new-hand host-game-state)
    ^-  (quip card _state)
    :_  state(lobbies (~(del by lobbies.state) id.action))
    %+  welp  cards
    %+  welp
      :~  :*  %pass  /timer/(scot %da id.game)
              %arvo  %b  %wait
              turn-timer.host-game-state
          ==
          :^  %give  %fact  ~[/table-updates/(scot %da id.action)]
          [%pokur-host-update !>(`host-update`[%game-starting id.action])]
      ==
    ?.  ?=(%tournament -.game-type.u.table)  ~
    :~  :*  %pass  /timer/(scot %da id.game)/round-timer
            %arvo  %b  %wait
            (add now.bowl round-duration.game-type.u.table)
    ==  ==
  ::
      %leave-game
    ::  player leaves game
    ?~  host-game=(~(get by games.state) id.action)
      !!
    :: remove sender from their game
    =.  u.host-game
      (~(remove-player modify-game-state u.host-game) src.bowl)
    =*  game  game.u.host-game
    :: remove spectator if they were one
    =.  spectators.game
      (~(del in spectators.game) src.bowl)
    :-  (send-game-updates u.host-game)
    state(games (~(put by games.state) id.action u.host-game))
  ::
      %kick-player
    ::  src must be table leader
    ?~  table=(~(get by lobbies.state) id.action)
      !!
    ?>  =(leader.u.table src.bowl)
    =.  players.u.table
      (~(del in players.u.table) who.action)
    :_  state(lobbies (~(put by lobbies.state) id.action u.table))
    :_  ~
    :^  %give  %fact  ~[/table-updates/(scot %da id.u.table)]
    [%pokur-host-update !>(`host-update`[%table u.table])]
  ==
::
::  +send-game-updates: make update cards for players and spectators
::
++  send-game-updates
  |=  host-game=host-game-state
  ^-  (list card)
  =*  game  game.host-game
  %+  weld
    %+  turn  ~(tap by hands.host-game)
    |=  [=ship hand=pokur-deck]
    ^-  card
    :^  %give  %fact  ~[/game-updates/(scot %da id.game)/(scot %p ship)]
    [%pokur-host-update !>(`host-update`[%game game(my-hand hand)])]
  %+  turn  ~(tap in spectators.game)
  |=  =ship
  ^-  card
  :^  %give  %fact  ~[/game-updates/(scot %da id.game)/(scot %p ship)]
  [%pokur-host-update !>(`host-update`[%game game])]
::
++  initialize-new-hand
  |=  host-game=host-game-state
  ^-  (quip card _state)
  =.  deck.host-game
    (shuffle-deck deck.host-game eny.bowl)
  =.  host-game
    %-  ~(initialize-hand modify-game-state host-game)
    dealer.game.host-game
  :-  (send-game-updates host-game)
  state(games (~(put by games.state) id.game.host-game host-game))
::
++  end-game
  |=  host-game=host-game-state
  ^-  (quip card _state)
  :_  state(games (~(del by games.state) id.game.host-game))
  :_  ~
  :*  %pass  /timer/(scot %da id.game.host-game)
      %arvo  %b  %rest
      turn-timer.host-game
  ==
--
