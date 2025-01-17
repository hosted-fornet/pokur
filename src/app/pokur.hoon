/-  *pokur, indexer=zig-indexer, wallet=zig-wallet
/+  default-agent, dbug, io=agentio, verb,
    engine=zig-sys-engine, *pokur-game-logic, pokur-json
|%
+$  card  card:agent:gall
+$  state-0
  $:  %0
      known-hosts=(map ship host-info)
      our-address=(unit @ux)
      lobby-source=ship
      lobby=(map @da table)
      our-table=(unit @da)
      game=(unit game)
      game-host=(unit ship)
      messages=(list [=ship msg=@t])
      muted-players=(set ship)
      ::  used for delaying tokenized actions until we get txn confirmation
      pending-poke=(unit player-action)
  ==
--
^-  agent:gall
%+  verb  &
%-  agent:dbug
=|  state=state-0
=<
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
    hc    ~(. +> bowl)
::
++  on-init
  ^-  (quip card _this)
  =/  host=@p  fixed-lobby-source
  :_  this(state [%0 ~ ~ host ~ ~ ~ ~ ~ ~ ~])
  [%pass /link-handler %arvo %e %connect `/apps/pokur/invites %pokur]^~
::
++  on-save  ^-  vase  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  old-state=state-0
    ::  if the old versioned state does not match what we expect, just
    ::  bunt for a fresh new state.
    ?~  new=((soft state-0) q.old)
      [%0 ~ ~ fixed-lobby-source ~ ~ ~ ~ ~ ~ ~]
    u.new(lobby-source fixed-lobby-source)
  :_  this(state old-state)
  [%pass /link-handler %arvo %e %connect `/apps/pokur/invites %pokur]^~
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  =^  cards  state
    ?+    mark  (on-poke:def mark vase)
        %pokur-player-action
      (handle-player-action:hc !<(player-action vase))
        %pokur-message-action
      (handle-message-action:hc !<(message-action vase))
        %pokur-game-action
      (handle-game-action:hc !<(game-action vase))
        %pokur-host-action
      (handle-host-action:hc !<(host-action vase))
        %pokur-host-update
      (handle-host-update:hc !<(host-update vase))
        %wallet-update
      (handle-wallet-update:hc !<(wallet-update:wallet vase))
        %handle-http-request
      (handle-link:hc vase)
    ==
  [cards this]
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ::
  ::  all subscriptions are from our frontend
  ::
  ?>  =(src.bowl our.bowl)
  ?+    path  (on-watch:def path)
      [%lobby-updates ~]
    ::  forward available tables from host here
    ::  start watching host lobby
    :_  this
    :~  lobby-update-card
        %+  ~(poke pass:io /lobby-updates)
          [fixed-lobby-source %pokur-host]
        pokur-player-action+!>(`player-action`[%watch-lobby ~])
    ==
  ::
      [%game-updates ~]
    ?~  game.state  `this
    :_  this  :_  ~
    :^  %give  %fact  ~[/game-updates]
    [%pokur-update !>(`update`[%game u.game.state '-' ~])]
  ::
      [%messages ~]
    ::  don't send all messages, rather scry for those and
    ::  send subsequent messages along this path
    `this
  ::
      [%http-response *]
    ::  handling game invites/links
    `this
  ==
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ::
  ::  all updates are from our subscription(s) to host ship
  ::  receive updates about lobbies and active game here
  ::
  ?+    wire  (on-agent:def wire sign)
      [%start-table-poke @ ~]
    ?.  ?=(%poke-ack -.sign)  (on-agent:def wire sign)
    ?^  p.sign  ~|(p.sign !!)  ::  TODO new table poke failed!
    `this(our-table.state `(slav %da i.t.wire))
  ::
      [%join-table-poke @ ~]
    ?.  ?=(%poke-ack -.sign)  (on-agent:def wire sign)
    ?^  p.sign  ~|(p.sign !!)  ::  TODO join table poke failed!
    ::  join table was successful -- if table is active, we must now
    ::  subscribe to the game updates path
    =/  table-id=@da  (slav %da i.t.wire)
    =/  =table  (~(got by lobby.state) table-id)
    `this(our-table.state `table-id)
    ::  XX is this necessary? host will just poke table members
    ::  ?.  is-active.table  ~
    ::  (watch-game-updates ship.host-info.table id.table)
      [%new-table-thread ~]
    ::  receive eth block from thread, generate escrow transaction
    ?+    -.sign  (on-agent:def wire sign)
        %fact
      ?+    p.cage.sign  (on-agent:def wire sign)
          %thread-fail
        =/  err  !<  (pair term tang)  q.cage.sign
        %.  `this
        %+  slog
          leaf+"%pokur: get-eth-block thread failed: {(trip p.err)}"
        q.err
      ::
          %thread-done
        ?~  pending-poke.state  !!
        ?>  ?=(%new-table -.u.pending-poke.state)
        ?~  tokenized.u.pending-poke.state  !!
        =/  height=@ud  !<(@ud q.cage.sign)
        ?~  host-info=(~(get by known-hosts.state) host.u.pending-poke.state)
          !!
        ?~  our-address.state  !!
        =/  default-timelock=@ud  ::  roughly 48 hours
          (add height 14.400)
        ::  generate ID of our token account
        =/  [token-contract=@ux our-account-id=@ux]
          %:  get-token-contract-and-account-id
              metadata.u.tokenized.u.pending-poke.state
              u.our-address.state
              town.contract.u.host-info
              [our now]:bowl
          ==
        ::  we'll get a pokeback from %wallet when this transaction goes through
        :_  this  :_  ~
        :*  %pass  /pokur-wallet-poke
            %agent  [our.bowl %uqbar]
            %poke  %wallet-poke
            !>
            :*  %transaction
                origin=`[%pokur /new-bond-confirmation]
                from=u.our-address.state
                contract=token-contract
                town=town.contract.u.host-info
                :-  %noun
                :*  %push
                    to=id.contract.u.host-info
                    amount=amount.u.tokenized.u.pending-poke.state
                    from-account=our-account-id
                    ^-  action:escrow
                    :*  %new-bond-with-deposit
                        address.u.host-info
                        default-timelock
                        metadata.u.tokenized.u.pending-poke.state
                        our.bowl
                        amount.u.tokenized.u.pending-poke.state
                        our-account-id
        ==  ==  ==  ==
      ==
    ==
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?.  =(%x -.path)  ~
  ?+    +.path  (on-peek:def path)
      [%known-hosts ~]
    ``json+!>((enjs-hosts:pokur-json known-hosts.state))
      [%game-id ~]
    ``noun+!>(?~(game.state ~ `id.u.game.state))
      [%our-table ~]
    ``json+!>(?~(our-table.state ~ s+(scot %da u.our-table.state)))
      [%game ~]
    ``json+!>(?~(game.state ~ (enjs-game:pokur-json u.game.state)))
      [%messages ~]
    ``json+!>((enjs-messages:pokur-json messages.state))
      [%muted-players ~]
    ``json+!>(a+(turn ~(tap in muted-players.state) ship:enjs:format))
      [%lobby ~]
    ``pokur-update+!>(`update`[%lobby lobby.state])
  ::
      [%table @ ~]
    :^  ~  ~  %json
    !>  %-  enjs-table:pokur-json
        (~(got by lobby.state) (slav %da i.t.t.path))
  ==
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+    wire  (on-arvo:def wire sign-arvo)
      [%link-handler ~]
    `this
  ==
::
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
::
::  start helper cores
::
|_  bowl=bowl:gall
++  handle-host-action
  |=  action=host-action
  ^-  (quip card _state)
  ?+    -.action  !!
      %host-info
    ::  receive host-info from host
    ?>  =(src.bowl ship.host-info.action)
    `state(known-hosts (~(put by known-hosts.state) src.bowl +.action))
  ==
::
++  handle-player-action
  |=  action=player-action
  ^-  (quip card _state)
  ::  all other pokes can only be sent from FE
  ?:  ?=(%invite -.action)
    ::  got invite from another player for a private table.
    ::  only accept invites from ships you trust.
    ::  integrate invite-tables into our lobby state
    ~&  >>  "%pokur: got invite to game {<id.table.action>}"
    :_  state(lobby (~(put by lobby.state) id.table.action table.action))
    :_  ~
    :^  %give  %fact  ~[/lobby-updates]
    [%pokur-update !>(`update`[%new-invite src.bowl table.action])]
  ?>  =(src.bowl our.bowl)
  ?+    -.action  ~|("%pokur: unexpected action from frontend" !!)
      %new-table
    ::  start a table in our current host, and if game is to be
    ::  tokenized, create a transaction to start a new escrow
    ::  bond with host as custodian of funds
    ?^  our-table.state
      ~|("%pokur: error: can't join table, already in one" !!)
    ?^  game.state
      ~|("%pokur: error: can't join table, already in game" !!)
    ?.  (~(has by known-hosts.state) host.action)
      ~|("%pokur: error: need to %find-host first" !!)
    =.  id.action  now.bowl
    ?~  tokenized.action
      :_  state  :_  ~
      :*  %pass  /start-table-poke/(scot %da id.action)
          %agent  [host.action %pokur-host]
          %poke  %pokur-player-action  !>(action)
      ==
    ::  generate new escrow bond with host
    ::  [%new-bond custodian=address timelock=@ud asset-metadata=id]
    ::  fetch latest ETH block height to produce timelock
    =/  tid          `@ta`(cat 3 'thread_' (scot %uv (sham eny.bowl)))
    =/  ta-now       (scot %da now.bowl)
    =/  start-args  [~ `tid byk.bowl(r da+now.bowl) %get-eth-block !>(~)]
    ::  set pending poke
    :_  state(pending-poke `action)
    :~  :*  %pass  /new-table-thread
            %agent  [our.bowl %spider]
            %watch  /thread-result/[tid]
        ==
        :*  %pass  /thread/[ta-now]
            %agent  [our.bowl %spider]
            %poke  %spider-start  !>(start-args)
        ==
    ==
  ::
      %join-table
    ?^  our-table.state
      ~|("%pokur: error: can't join table, already in one" !!)
    ?^  game.state
      ~|("%pokur: error: can't join table, already in game" !!)
    =/  =table  (~(got by lobby.state) id.action)
    ::  if we're not already familiar with table host, familiarize ourself
    =/  join-host-card
      ?:  (~(has by known-hosts.state) ship.host-info.table)  ~
      :_  ~
      %+  ~(poke pass:io /lobby-updates)
        [ship.host-info.table %pokur-host]
      pokur-player-action+!>(`player-action`[%watch-lobby ~])
    ::  if table is tokenized, generate escrow transaction,
    ::  otherwise just join. host will not allow us to enter
    ::  table if tokenized until transaction is received
    ?~  tokenized.table
      ::  if table is already active, set game host
      :_  ?:  is-active.table
            state(game-host `ship.host-info.table)
          state(our-table `id.action)
      (poke-pass-through ship.host-info.table action)^join-host-card
    ::  escrow work -- set pending join poke
    :_  state(pending-poke `action)
    ?~  our-address.state
      ~|("%pokur: error: can't add escrow, missing a wallet address" !!)
    ::  scry indexer for token metadata so we can find our token account
    =/  [token-contract=@ux our-account-id=@ux]
      %:  get-token-contract-and-account-id
          metadata.u.tokenized.table
          (need our-address.state)
          town.contract.host-info.table
          [our now]:bowl
      ==
    =/  host-ta  (scot %p ship.host-info.table)
    =/  tokens=@ud
      ?-  -.game-type.table
        %sng   amount.u.tokenized.table
        %cash  buy-in.action
      ==
    :_  join-host-card
    :*  %pass  /pokur-wallet-poke
        %agent  [our.bowl %uqbar]
        %poke  %wallet-poke
        !>
        :*  %transaction
            origin=`[%pokur /deposit-confirmation/[host-ta]]
            from=u.our-address.state
            contract=token-contract
            town=town.contract.host-info.table
            :-  %noun
            :*  %push
                to=id.contract.host-info.table
                amount=tokens
                from-account=our-account-id
                ^-  action:escrow
                :*  %deposit
                    bond-id.u.tokenized.table
                    our.bowl
                    tokens
                    our-account-id
        ==  ==  ==
    ==
  ::
      %leave-table
    ?~  our-table.state
      ~|("%pokur: error: can't leave table, not in one" !!)
    =/  =table  (~(got by lobby.state) u.our-table.state)
    :_  state(our-table ~, messages ~)
    (poke-pass-through ship.host-info.table action)^~
  ::
      %start-game
    ?~  our-table.state
      ~|("%pokur: error: can't start game, not in a table" !!)
    ?^  game.state
      ~|("%pokur: error: can't start game, already in one" !!)
    =/  =table  (~(got by lobby.state) u.our-table.state)
    :_  state(messages ~)
    (poke-pass-through ship.host-info.table action)^~
  ::
      %leave-game
    ?~  game.state
      ~|("%pokur: error: can't leave game, not in one" !!)
    ?~  game-host.state
      `state(game ~, messages ~)
    :_  state(game ~, game-host ~, messages ~)
    (poke-pass-through u.game-host.state action)^~
  ::
      %kick-player
    ?~  our-table.state
      ~|("%pokur: error: can't edit table, not in one" !!)
    =/  =table  (~(got by lobby.state) u.our-table.state)
    ?.  &(=(our.bowl leader.table) !public.table)
      ~|("%pokur: error: can't edit table, not table leader/not private" !!)
    :_  state
    (poke-pass-through ship.host-info.table action)^~
  ::
      %set-our-address
    `state(our-address `address.action)
  ::
      %find-host
    :_  state  :_  ~
    %+  ~(poke pass:io /lobby-updates)
      [who.action %pokur-host]
    pokur-player-action+!>(`player-action`[%watch-lobby ~])
  ::
      %remove-host
    :_  state(known-hosts (~(del by known-hosts.state) who.action))
    :_  ~
    %+  ~(poke pass:io /lobby-updates)
      [who.action %pokur-host]
    pokur-player-action+!>(`player-action`[%stop-watching-lobby ~])
  ::
      %send-invite
    ::  produce an invite for a player
    ::  must invite to table we're currently in
    =/  =table  (~(got by lobby.state) (need our-table.state))
    :_  state  :_  ~
    :*  %pass  /invite-poke
        %agent  [to.action %pokur]
        %poke  %pokur-player-action
        !>(`player-action`[%invite table])
    ==
  ::
      %spectate-game
    ?^  game.state
      ~|("%pokur: error: can't join table, already in game" !!)
    ::  if we're not already familiar with table host, familiarize ourself
    =/  join-host-card
      ?:  (~(has by known-hosts.state) host.action)  ~
      :_  ~
      %+  ~(poke pass:io /lobby-updates)
        [host.action %pokur-host]
      pokur-player-action+!>(`player-action`[%watch-lobby ~])
    :_  state(game-host `host.action)
    (poke-pass-through host.action action)^join-host-card
  ==
::
++  handle-message-action  ::  TODO replace with pongo?
  |=  action=message-action
  ^-  (quip card _state)
  ?-    -.action
      %mute
    ?>  =(src.bowl our.bowl)
    `state(muted-players (~(put in muted-players.state) who.action))
  ::
      %unmute
    ?>  =(src.bowl our.bowl)
    `state(muted-players (~(del in muted-players.state) who.action))
  ::
      %send-message
    ?>  =(src.bowl our.bowl)
    ::  if in table, send to everyone in table
    ::  if in game, send to everyone in game
    :_  state
    %+  turn
      ?~  game.state
        ?~  our-table.state
          !!
        =/  =table  (~(got by lobby.state) u.our-table.state)
        ~(tap in players.table)
      %+  weld
        (turn players.u.game.state head)
      ~(tap in spectators.u.game.state)
    |=  =ship
    ^-  card
    :*  %pass  /message-poke  %agent  [ship %pokur]
        %poke  %pokur-message-action
        !>(`message-action`[%receive-message msg.action])
    ==
  ::
      %receive-message
    ::  add to our message store and forward to frontend
    ::  if in table, only accept messages from players in table
    ::  if in game, only accept from players in game
    ?>  ?~  game.state
          ?~  our-table.state
            %.n
          =/  =table  (~(got by lobby.state) u.our-table.state)
          (~(has in players.table) src.bowl)
        ?|  ?=(^ (find [src.bowl]~ (turn players.u.game.state head)))
            (~(has in spectators.u.game.state) src.bowl)
        ==
    ::  skip messages from muted players
    ?:  (~(has in muted-players.state) src.bowl)  `state
    :_  state(messages [[src.bowl msg.action] messages.state])
    :_  ~
    :^  %give  %fact  ~[/messages]
    [%pokur-update !>(`update`[%new-message src.bowl msg.action])]
  ==
::
++  handle-game-action
  |=  action=game-action
  ^-  (quip card _state)
  ?>  =(src.bowl our.bowl)
  ?~  game.state  !!
  :_  state  :_  ~
  :^  %pass  /poke-wire  %agent
  :^  [(need game-host.state) %pokur-host]
    %poke  %pokur-game-action
  ?-  -.action
    %check  !>(`game-action`[%check id.u.game.state ~])
    %fold   !>(`game-action`[%fold id.u.game.state ~])
    %bet    !>(`game-action`[%bet id.u.game.state amount.action])
  ==
::
++  handle-host-update
  |=  upd=host-update
  ^-  (quip card _state)
  ::  incoroporate update poke from host into our state
  ?-    -.upd
      %lobby
    ?>  (~(has by known-hosts.state) src.bowl)
    =.  lobby.state
      (~(uni by lobby.state) tables.upd)
    [lobby-update-card^~ state]
  ::
      %new-table
    ::  add table to our lobby state
    ?>  (~(has by known-hosts.state) src.bowl)
    =.  lobby.state
      (~(put by lobby.state) id.table.upd table.upd)
    [lobby-update-card^~ state]
  ::
      %table-closed
    ?>  (~(has by known-hosts.state) src.bowl)
    =.  lobby.state
      (~(del by lobby.state) table-id.upd)
    ?~  our-table.state
      [lobby-update-card^~ state]
    ?.  =(u.our-table.state table-id.upd)
      [lobby-update-card^~ state]
    ::  if our table closed, clear
    :_  state(our-table ~, messages ~)
    :~  lobby-update-card
        :^  %give  %fact  ~[/lobby-updates]
        [%pokur-update !>(`update`[%table-closed table-id.upd])]
    ==
  ::
      %game-starting
    ?>  (~(has by known-hosts.state) src.bowl)
    ::  check if it's our game, if so, sub to path and notify FE
    ?~  table=(~(get by lobby.state) game-id.upd)
      `state
    ::  remove table from lobby if tournament, leave it there otherwise
    =?    lobby.state
        ?=(%sng -.game-type.u.table)
      (~(del by lobby.state) game-id.upd)
    ?~  our-table.state
      [lobby-update-card^~ state]
    ?.  =(game-id.upd u.our-table.state)
      [lobby-update-card^~ state]
    ?.  =(src.bowl ship.host-info.u.table)
      [lobby-update-card^~ state]
    :_  state(our-table ~, game-host `ship.host-info.u.table)
    :_  ~
    :^  %give  %fact
      ~[/lobby-updates]
    pokur-update+!>(`update`upd)
  ::
      %game
    ::  ignore updates if we've left
    ?~  game-host.state  `state
    ?>  =(src.bowl u.game-host.state)
    ::  ~&  >  "new game state:"
    ::  ~&  >  game.upd
    =/  my-hand-rank=@t
      %-  hierarchy-to-rank
      =/  full-hand  (weld my-hand.game.upd board.game.upd)
      ?+  (lent full-hand)  100
        %5  (evaluate-5-card-hand full-hand)
        %6  -:(evaluate-6-card-hand full-hand)
        %7  -:(evaluate-7-card-hand full-hand)
      ==
    :_  state(game `game.upd)
    :_  ~
    :^  %give  %fact  ~[/game-updates]
    pokur-update+!>(`update`[%game game.upd my-hand-rank last-board.upd])
  ::
      %game-over
    ::  ignore updates if we've left
    ?~  game-host.state  `state
    ?>  =(src.bowl u.game-host.state)
    ::  player must now %leave-game to clear state and messages
    :_  state(game `game.upd)
    :_  ~
    :^  %give  %fact  ~[/game-updates]
    pokur-update+!>(`update`upd)
  ==
::
++  handle-wallet-update
  |=  update=wallet-update:wallet
  ^-  (quip card _state)
  ?+    -.update  `state  ::  ignore other notifs from wallet
  ::  handling optimistic receipts only
      %sequencer-receipt
    ::  wallet announcing that either our %new-bond has been started,
    ::  meaning we've successfully created a tokenized table, or that
    ::  our %deposit has gone through, meaning we've joined a tokenized table
    ?>  ?=(^ origin.update)
    ?~  pending-poke.state  ~|("got receipt for missing txn" !!)
    ?+    q.u.origin.update  ~|("got receipt from weird origin" !!)
        [%new-bond-confirmation ~]
      ::  send bond info to host with a %new-table poke, finally
      ?>  ?=(%new-table -.u.pending-poke.state)
      ?~  tokenized.u.pending-poke.state  !!
      ::  make sure txn succeeded
      ~|  "%pokur: transaction failed!!"
      ?>  =(%0 errorcode.output.update)
      ::  modify bond-id with txn output
      ::  should be in events.output.update
      =/  event=contract-event:eng:wallet
        (head events.output.update)
      ?>  ?=(@ux noun.event)
      :_  state(pending-poke ~)
      :_  ~
      :*  %pass   /start-table-poke/(scot %da id.u.pending-poke.state)
          %agent  [host.u.pending-poke.state %pokur-host]
          %poke   %pokur-txn-player-action
          !>  ^-  txn-player-action
          :+  %new-table-txn
            +>+.update  ::  receipt
          u.pending-poke.state(bond-id.u.tokenized noun.event)
      ==
    ::
        [%deposit-confirmation @ ~]
      ?>  ?=(%join-table -.u.pending-poke.state)
      ::  request to %join-table on host
      ::  don't need any data other than the fact that the txn succeeded
      ~|  "%pokur: transaction failed!!"
      ?>  =(%0 errorcode.output.update)
      =/  host=ship  (slav %p i.t.q.u.origin.update)
      :_  state(pending-poke ~, game-host `host)
      :_  ~
      :*  %pass   /join-table-poke/(scot %da id.u.pending-poke.state)
          %agent  [host %pokur-host]
          %poke   %pokur-txn-player-action
          !>  ^-  txn-player-action
          [%join-table-txn +>+.update u.pending-poke.state]
      ==
    ==
  ==
::
++  handle-link
  |=  =vase
  ^-  (quip card _state)
  ::  mark = %handle-http-request
  =/  load  !<((pair @ta inbound-request:eyre) vase)
  ?+    method.request.q.load
    =/  data=octs
      (as-octs:mimes:html '<h1>405 Method Not Allowed</h1>')
    =/  content-length=@t
      (crip ((d-co:co 1) p.data))
    =/  =response-header:http
      :-  405
      :~  ['Content-Length' content-length]
          ['Content-Type' 'text/html']
          ['Allow' 'GET']
      ==
    :_  state
    :~  [%give %fact [/http-response/[p.load]]~ %http-response-header !>(response-header)]
        [%give %fact [/http-response/[p.load]]~ %http-response-data !>(`data)]
        [%give %kick [/http-response/[p.load]]~ ~]
    ==
  ::
      %'GET'
    =/  url=path  (stab url.request.q.load)
    ?.  ?=([@ @ @ @ @ @ ~] url)  !!
    ::  url should be /apps/pokur/invites/[host]/[public or private]/[game-id]
    =/  host=ship     (slav %p i.t.t.t.url)
    =/  public=?      =('public' i.t.t.t.t.url)
    =/  table-id=@da  (slav %da i.t.t.t.t.t.url)
    =/  =response-header:http
      [301 ['Location' '/apps/pokur']~]
    :_  state
    :~  %+  ~(poke pass:io /lobby-updates)
          [host %pokur-host]
        pokur-player-action+!>(`player-action`[%watch-lobby ~])
    ::
        :^  %give  %fact
          [/http-response/[p.load]]~
        http-response-header+!>(response-header)
    ::
        [%give %kick [/http-response/[p.load]]~ ~]
    ::  don't join right away, but select somehow on FE
    ::  if table is private, sub to its path on host??
    ==
  ==
::
++  lobby-update-card
  ^-  card
  :^  %give  %fact  ~[/lobby-updates]
  [%pokur-update !>(`update`[%lobby lobby.state])]
::
++  poke-pass-through
  |=  [host=ship action=player-action]
  ^-  card
  =/  =wire
    ?+  -.action  /table-poke
      %join-table  /join-table-poke/(scot %da id.action)
      %new-table  /start-table-poke/(scot %da id.action)
    ==
  ::  give a poke from frontend to host
  :*  %pass   /table-poke
      %agent  [host %pokur-host]
      %poke   %pokur-player-action  !>(action)
  ==
::
++  get-token-contract-and-account-id
  |=  [metadata=@ux our-addr=@ux town=@ux our=@p now=@da]
  ^-  [contract=@ux account=@ux]
  ~|  "%pokur: error: can't find metadata for escrow token"
  =/  found=wallet-update:wallet
    .^  wallet-update:wallet  %gx
        /(scot %p our)/wallet/(scot %da now)/metadata/(scot %ux metadata)/noun
    ==
  ?:  ?=(~ found)  !!
  ?>  ?=(%metadata -.found)
  ?>  ?=(%token -.+.found)
  :-  contract.found
  ::  generate ID of our token account
  %:  hash-data:engine
      contract.found
      our-addr
      town
      salt.found
  ==
--
