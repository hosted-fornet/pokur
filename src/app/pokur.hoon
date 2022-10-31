/-  *pokur
/+  default-agent, dbug, *pokur
|%
+$  versioned-state
    $%  state-0
    ==
+$  state-0
    $:  %0
        game=(unit game-state)
        challenge-sent=(unit pokur-challenge) :: can only send 1 active challenge
        challenges-received=(map @da pokur-challenge)
        game-msgs-received=(list [from=ship msg=tape])
    ==
::
+$  card  card:agent:gall
::
--
%-  agent:dbug
=|  state=state-0
^-  agent:gall
=<
|_  =bowl:gall
+*  this      .
    def      ~(. (default-agent this %|) bowl)
    hc       ~(. +> bowl)
::
++  on-init
  ^-  (quip card _this)
  `this(state [%0 ~ ~ ~ ~])
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
  ?+    mark  (on-poke:def mark vase)
      %pokur-client-action
    =^  cards  state
      (handle-client-action:hc !<(client-action vase))
    [cards this]
  ::
      %pokur-game-action
    =^  cards  state
      (handle-game-action:hc !<(game-action vase))
    [cards this]
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-watch:def path)
    [%challenge-updates ~]
    =/  cards
      %+  turn
        %+  weld
          ~(val by challenges-received.state)
        (drop challenge-sent.state)
      |=  item=pokur-challenge
      :^    %give
          %fact
        ~[/challenge-updates]
      [%challenge-update !>([%open-challenge item])]
    [cards this]
    ::
    [%game ~]
    ?~  game.state
      `this
    :_  this
      ~[[%give %fact ~[/game] [%game-update !>([%update u.game.state "-"])]]]
    [%game-msgs ~]
    ?~  game.state
      `this
    :_  this
      ~[[%give %fact ~[/game-msgs] [%game-update !>([%msgs game-msgs-received.state])]]]
  ==
:: Receives responses from pokes or subscriptions to other Gall agents
:: This is where updates are handled from the pokur-server to which we've subscribed.
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+    wire  (on-agent:def wire sign)
      [%game-updates @ta ~]
    ?+  -.sign  (on-agent:def wire sign)
      %fact
      =/  new-state=game-state
        !<(game-state q.cage.sign)
      =/  my-hand-eval
        =/  full-hand  (weld my-hand.new-state board.new-state)
        ?+  (lent full-hand)  100 :: fake rank number to induce "-"
          %5  (eval-5-cards full-hand)
          %6  (eval-6-cards full-hand)
          %7  -:(evaluate-hand full-hand)
        ==
      =.  game.state
        %-  some  new-state
      :_  this
        ~[[%give %fact ~[/game] [%game-update !>([%update new-state (hierarchy-to-rank my-hand-eval)])]]]
    ==
  ==
++  on-arvo  on-arvo:def
++  on-fail  on-fail:def
++  on-leave  on-leave:def
++  on-peek   on-peek:def
--
::
::  start helper cores
::
|_  bowl=bowl:gall
++  handle-game-action
  |=  action=game-action
  ^-  (quip card _state)
  ?~  game.state
    :_  state
      ~[[%give %poke-ack `~[leaf+"Error: can't process action, not in game yet."]]]
  ?-  -.action
    %check
  ?>  (team:title [our src]:bowl)
  :_  state
    :~  :*  %pass  /poke-wire  %agent
            [host.u.game.state %pokur-server]
            %poke  %pokur-game-action
            !>([%check game-id=game-id.u.game.state])
        ==
    ==
    %bet
  ?>  (team:title [our src]:bowl)
  :_  state
    :~  :*  %pass  /poke-wire  %agent
            [host.u.game.state %pokur-server]
            %poke  %pokur-game-action
            !>([%bet game-id=game-id.u.game.state amount=amount.action])
        ==
    ==
    %fold
  ?>  (team:title [our src]:bowl)
  :_  state
    :~  :*  %pass  /poke-wire  %agent
            [host.u.game.state %pokur-server]
            %poke  %pokur-game-action
            !>([%fold game-id=game-id.u.game.state])
        ==
    ==
    %send-msg
  ?>  (team:title [our src]:bowl)
  :: poke should fail if we're not in a game
  =/  game  (need game.state)
  =/  send-to
  %+  weld
    players.game
  spectators.game
  =/  cards
    %+  turn
      send-to
    |=  player=ship
    :*  %pass
        /poke-wire
        %agent
        [player %pokur]
        %poke
        %pokur-game-action
        !>([%receive-msg msg=msg.action])
    ==
  :_  state
    cards
    %receive-msg
  :: poke should fail if we're not in a game
  =/  game  (need game.state)
  :: this, but title matches a player in players.game.state???
  :: ?>  (team:title [our src]:bowl)
  =.  game-msgs-received.state
  %+  weld
    ~[[src.bowl msg.action]]
  game-msgs-received.state

  :: add it to our state (from: src.bowl)
  :: and update our subscribers
  :_  state
    :~  :*  %give
            %fact
            ~[/game-msgs]
            :-  %game-update
            !>([%msgs game-msgs-received.state])
        ==
    ==
  ==
++  handle-client-action
  |=  =client-action
  ^-  (quip card _state)
  ?-  -.client-action
  ::
  ::  Send challenges from our ship to others
    %issue-challenge
  ?>  (team:title [our src]:bowl)
  =/  player-list
  %+  turn
    %+  weld
      to.client-action
    ~[our.bowl]
  |=  s=ship
  ?:  =(s our.bowl)
    :: [@p / accepted? / declined?]
    [s %.y %.n]
  [s %.n %.n]
  =/  challenge
    [ id=now.bowl
      challenger=our.bowl
      players=player-list
      host.client-action
      spectators.client-action
      min-bet.client-action
      starting-stack.client-action
      type.client-action
      turn-time-limit.client-action
    ]
  =.  challenge-sent.state
    %-  some  challenge
  :_  state
    ::  tell our frontend that we've opened a challenge
    %+  welp
      :~  :*  %give  %fact
              ~[/challenge-updates]
              [%challenge-update !>([%open-challenge challenge])]
      ==  ==
    :: poke every ship invited with the challenge
    %+  turn
      to.client-action
    |=  player=ship
    :*  %pass  /poke-wire  %agent  [player %pokur]
        %poke  %pokur-client-action  !>([%receive-challenge challenge=challenge])
    ==
  ::
  ::  Cancel a challenge that we initiated
    %cancel-challenge
  ?>  (team:title [our src]:bowl)
  ?:  =(~ challenge-sent.state)
    :_  state
      ~[[%give %poke-ack `~[leaf+"error: you haven't issued a challenge yet."]]]
  =/  challenge
    (need challenge-sent.state)
  ?.  =(id.challenge id.client-action)
    :_  state
      ~[[%give %poke-ack `~[leaf+"error: no challenge found with ID {<id.client-action>} to cancel."]]]
  =.  challenge-sent.state  ~
  :_  state
    :: tell our frontend we're closing a challenge
    %+  welp
      :~  :*  %give  %fact
              ~[/challenge-updates]
              [%challenge-update !>([%close-challenge id.challenge])]
          ==
      ==
    :: poke every invited ship with an alert that the challenge has been closed
    :: unless they've already declined.
    %+  turn
      %+  skip
        players.challenge
      |=  [player=ship accepted=? declined=?]
      ?|  =(player our.bowl)
          declined
        ==
    |=  [player=ship accepted=? declined=?]
    :*  %pass  /poke-wire  %agent  [player %pokur]
        %poke  %pokur-client-action  !>([%challenge-cancelled id=id.challenge])
    ==
  ::
  ::  Challenge cancelled: a ship that previously challenged us is cancelling it
    %challenge-cancelled
  ?.  (~(has by challenges-received.state) id.client-action)
    :_  state
      ~[[%give %poke-ack `~[leaf+"error: got a cancellation for a challenge from {<src.bowl>} that does not exist"]]]
  =.  challenges-received.state
    (~(del by challenges-received.state) id.client-action)
  :_  state
    :: alert the frontend of the update
    :~  :*  %give  %fact
            ~[/challenge-updates]
            [%challenge-update !>([%close-challenge id.client-action])]
        ==
    ==
  ::
  ::  We've received a challenge from another ship
    %receive-challenge
  =.  challenges-received.state
    (~(put by challenges-received.state) [id.challenge.client-action challenge.client-action])
  :_  state
    :: alert the frontend of the new challenge
    :~  :*  %give  %fact
            ~[/challenge-updates]
            [%challenge-update !>([%open-challenge challenge.client-action])]
        ==
    ==
  ::  We've received a challenge UPDATE regarding a challenge
  ::  that we had previously received but not yet declined.
    %challenge-update
  =/  challenge  challenge.client-action
  ?:  (~(has by challenges-received.state) id.challenge)
    :: just need to replace our stored version of the challenge with this update
    =.  challenges-received.state
      (~(put by challenges-received.state) [id.challenge challenge])
    :_  state
    :: alert the frontend of the update
    :~  :*  %give  %fact
            ~[/challenge-updates]
            [%challenge-update !>([%challenge-update challenge])]
        ==
    ==
  ?~  challenge-sent.state
    :_  state
      ~[[%give %poke-ack `~[leaf+"error: got an update for a challenge from {<src.bowl>} that you don't have."]]]
  ?.  =(id.challenge id.u.challenge-sent.state)
    :_  state
      ~[[%give %poke-ack `~[leaf+"error: got an update for a non-existent challenge that you didn't make."]]]
  =.  challenge-sent.state
    (some challenge)
  :: if not all have either accepted or declined, don't start game
  :: also, notify others in the challenge that peer has accepted
  ?.  %+  levy
        players.challenge
      |=  [s=ship accepted=? declined=?]
      |(accepted declined)
    :_  state
    :: just alert the frontend of the update
    :~  :*  %give  %fact
            ~[/challenge-updates]
            [%challenge-update !>([%challenge-update challenge])]
        ==
    ==
  :: if all players have responded, automatically initialize game
  :: give server the list of players which accepted and will be playing
  =.  players.challenge
    %+  skim
        players.challenge
      |=  [ship accepted=? ?]
      accepted
  :_  state
    %+  welp
      :: register game with server
      :~
        :*
          %pass  /poke-wire  %agent  [host.challenge %pokur-server]
          %poke  %pokur-server-action  !>([%register-game challenge=challenge])
        ==
      ==
    :: notify all players that the game is registered
    %+  turn
      players.challenge
    |=  [player=ship ? ?]
      :*
        %pass  /poke-wire  %agent  [player %pokur]
        %poke  %pokur-client-action  !>([%game-registered challenge=challenge])
      ==
  ::
  ::  Accept a specific challenge that we've received
    %accept-challenge
  ?>  (team:title [our src]:bowl)
  =/  challenge
    (~(get by challenges-received.state) id.client-action)
  ?~  challenge
    :_  state
      ~[[%give %poke-ack `~[leaf+"error: no challenge with that ID exists"]]]
  :_  state
    :: notify challenger that we've accepted
    :: they'll notify the other ships in the lobby of this
    :~  :*
          %pass  /poke-wire  %agent  [challenger.u.challenge %pokur]
          %poke  %pokur-client-action  !>([%challenge-accepted id=id.client-action])
        ==
    ==
  ::
  ::  Decline a specific challenge that we've received
    %decline-challenge
  ?>  (team:title [our src]:bowl)
  =/  challenge
    (~(get by challenges-received.state) id.client-action)
  ?~  challenge
    :_  state
      ~[[%give %poke-ack `~[leaf+"error: no challenge with that ID exists"]]]
  =.  challenges-received.state
    (~(del by challenges-received.state) id.client-action)
  :_  state
    :: notify challenger that we've declined
    :: they'll notify the other ships in the lobby of this
    :~  :*
          %pass  /poke-wire  %agent  [challenger.u.challenge %pokur]
          %poke  %pokur-client-action  !>([%challenge-declined id=id.client-action])
        ==
    ==
  ::
  ::  Poke from a ship we've challenged, notifying us that they've DECLINED
    %challenge-declined
  ?~  challenge-sent.state
    :_  state
      ~[[%give %poke-ack `~[leaf+"error: someone declined an invite to a challenge you didn't send."]]]
  =/  challenge  u.challenge-sent.state
  =.  players.challenge
    %+  turn
      players.challenge
    |=  [s=ship accepted=? declined=?]
    ?:  =(src.bowl s)
      [s %.n %.y]
    [s accepted declined]
  :_  state
      :: poke every non-declined ship with update
      %+  turn
        %+  skip
          players.challenge
        |=  [ship ? declined=?]
          declined
      |=  [player=ship ? ?]
      :*  %pass  /poke-wire  %agent  [player %pokur]
          %poke  %pokur-client-action  !>([%challenge-update challenge])
      ==
  ::
  ::  Poke from a ship we've challenged, notifying us that they've ACCEPTED
    %challenge-accepted
  ?~  challenge-sent.state
    :_  state
      ~[[%give %poke-ack `~[leaf+"error: someone accepted an invite to a challenge you didn't send."]]]
  =/  challenge  u.challenge-sent.state
  =.  players.challenge
    %+  turn
      players.challenge
    |=  [s=ship accepted=? declined=?]
    ?:  =(src.bowl s)
      [s %.y %.n]
    [s accepted declined]
  :_  state
    :: poke every non-declined ship with update
    %+  turn
      %+  skip
        players.challenge
      |=  [player=ship accepted=? declined=?]
      declined
    |=  [player=ship accepted=? declined=?]
    :*  %pass  /poke-wire  %agent  [player %pokur]
        %poke  %pokur-client-action  !>([%challenge-update challenge])
    ==
  ::
  ::
    %game-registered
  =.  challenges-received.state
    (~(del by challenges-received.state) id.challenge.client-action)
  :: remove challenge from our received-list
  :_  state
    :: subscribe to path which game will be served from
    :~  :*
          %pass  /poke-wire  %agent  [our.bowl %pokur]
          %poke  %pokur-client-action
          !>([%subscribe id=id.challenge.client-action host=host.challenge.client-action])
        ==
    ==
    %subscribe
  ?>  (team:title [our src]:bowl)
  :: TODO if we're already in a game, we need to leave it?
  ?~  game.state
    :_  state
      :~  :*  %pass  /game-updates/(scot %da id.client-action)
              %agent  [host.client-action %pokur-server]
              %watch  /game/(scot %da id.client-action)/(scot %p our.bowl)
            ==
          :*  %give  %fact
              ~[/challenge-updates]
              [%challenge-update !>([%close-challenge id.client-action])]
          ==
      ==
  :_  state
    ~[[%give %poke-ack `~[leaf+"error: leave current game before joining new one"]]]
    ::
    %leave-game
  ?>  (team:title [our src]:bowl)
  :: TODO fix this.
  :: can't set game.state to ~ after using ?~
  :: how to do?
  :: ?~  game.state
  ::   :_  state
  ::     ~[[%give %poke-ack `~[leaf+"Error: can't leave game, not in game yet."]]]
  =/  old-game     (need game.state)
  =/  old-host     host.old-game
  =/  old-game-id  game-id.old-game
  =:
      game.state                ~
      challenge-sent.state      ~
      game-msgs-received.state  ~
    ==
  :_  state
    :~  :: unsub from game's path
        :*  %pass  /game-updates/(scot %da id.client-action)
            %agent  [old-host %pokur-server]
            %leave  ~
        ==
        :: tell server we're leaving game
        :*  %pass  /poke-wire  %agent
            [old-host %pokur-server]
            %poke  %pokur-server-action
            !>([%leave-game old-game-id])
        ==
        :: tell frontend we left a game
        :*  %give  %fact
            ~[/game]
            %game-update  !>([%left-game %.n])
        ==
    ==
  ==
--
