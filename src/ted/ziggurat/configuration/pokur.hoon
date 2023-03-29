/-  pokur,
    spider,
    zig=zig-ziggurat
/+  mip,
    strandio,
    ziggurat-threads=zig-ziggurat-threads
::
=*  strand  strand:spider
=*  scry    scry:strandio
::
=/  m  (strand ,vase)
=|  project-name=@t
=|  desk-name=@tas
=|  ship-to-address=(map @p @ux)
=*  zig-threads
  ~(. ziggurat-threads project-name desk-name ship-to-address)
|^  ted
::
+$  arg-mold
  $:  $:  project-name=@t
          desk-name=@tas
          request-id=(unit @t)
      ==
  ==
::
++  make-config
  ^-  config:zig
  ~
::
++  make-state-views
  ^-  state-views:zig
  ::  app=~ -> chain view, not an agent view
  =/  pfix  (cury welp `path`/zig/state-views)
  :~  [~nec ~ (pfix /chain/transactions/hoon)]
      [~nec ~ (pfix /chain/chain/hoon)]
      [~nec ~ (pfix /chain/holder-our/hoon)]
      [~nec ~ (pfix /chain/source-zigs/hoon)]
  ::
      [~nec `%wallet (pfix /agent/wallet-metadata-store/hoon)]
      [~nec `%wallet (pfix /agent/wallet-our-items/hoon)]
      [~wes `%pokur (pfix /agent/pokur-bud-players/hoon)]
  ==
::
++  make-virtualships-to-sync
  ^-  (list @p)
  ~[~nec ~bud ~wes]
::
++  make-install
  ^-  ?
  %.y
::
++  make-start-apps
  ^-  (list @tas)
  ~
::
++  make-service-host
  ^-  @p
  ~nec
::
++  run-setup-desk
  |=  request-id=(unit @t)
  =/  m  (strand ,vase)
  ^-  form:m
  ~&  ship-to-address
  %:  setup-desk:zig-threads
      project-name
      desk-name
      request-id
      !>(~)
      make-config
      make-state-views
      make-virtualships-to-sync
      make-install
      make-start-apps
  ==
::
++  setup-virtualship-state
  =/  m  (strand ,vase)
  ^-  form:m
  ;<  state=state-0:zig  bind:m  get-state:zig-threads
  =*  configs  configs.state
  |^
  ;<  contract-hash=@ux  bind:m  setup-nec
  ;<  ~  bind:m  (setup-bud project-name contract-hash)
  ;<  ~  bind:m  setup-wes
  (pure:m !>(~))
  ::
  ++  setup-nec
    =/  m  (strand ,@ux)
    ^-  form:m
    =/  who=@p  ~nec
    ;<  contract-hash-vase=vase  bind:m
      %-  send-wallet-transaction:zig-threads
      :-  project-name
      :^  who  make-service-host
        !>(deploy-contract:zig-threads)
      [who make-escrow-jam-path %.n ~]
    =*  contract-hash  !<(@ux contract-hash-vase)
    ;<  empty-vase=vase  bind:m
      %-  send-discrete-pyro-poke:zig-threads
      :-  project-name
      :^  who  who  %pokur-host
      :-  %pokur-host-action
      !>  ^-  host-action:pokur
      :^  %host-info  who  (get-address who)
      [contract-hash make-town-id]
    ;<  ~  bind:m  (make-find-host who)
    ;<  ~  bind:m  (make-set-our-address who)
    (pure:m contract-hash)
  ::
  ++  setup-bud
    |=  [project-name=@t contract-hash=@ux]
    =/  m  (strand ,~)
    ^-  form:m
    =/  who=@p  ~bud
    ;<  ~  bind:m  (make-find-host who)
    ;<  ~  bind:m  (make-set-our-address who)
    ;<  empty-vase=vase  bind:m
      %-  send-wallet-transaction:zig-threads
      :-  project-name
      :^  who  make-service-host
        !>(send-discrete-pyro-poke:zig-threads)
      :-  project-name
      :^  who  who  %pokur
      :-  %pokur-player-action
      !>  ^-  player-action:pokur
      :*  %new-table
          *@da
          make-service-host
      ::
          :-  ~
          :^  `@ux`'zigs-metadata'  'ZIG'
          1.000.000.000.000.000.000  0x0
      ::
          2
          2
          [%sng 1.000 ~m60 ~[[1 2] [2 4] [4 8]] 0 %.n ~[100]]
          %.y
          %.y
          ~m10
      ==
    (pure:m ~)
  ::
  ++  setup-wes
    =/  m  (strand ,~)
    ^-  form:m
    =/  who=@p  ~wes
    ;<  ~  bind:m  (make-find-host who)
    ;<  ~  bind:m  (make-set-our-address who)
    (pure:m ~)
  ::
  ++  make-find-host
    |=  who=@p
    =/  m  (strand ,~)
    ^-  form:m
    ;<  empty-vase=vase  bind:m
      %-  send-discrete-pyro-poke:zig-threads
      :-  project-name
      :^  who  who  %pokur
      :-  %pokur-player-action
      !>  ^-  player-action:pokur
      [%find-host make-service-host]
    (pure:m ~)
  ::
  ++  make-set-our-address
    |=  who=@p
    =/  m  (strand ,~)
    ^-  form:m
    ;<  empty-vase=vase  bind:m
      %-  send-discrete-pyro-poke:zig-threads
      :-  project-name
      :^  who  who  %pokur
      :-  %pokur-player-action
      !>  ^-  player-action:pokur
      [%set-our-address (get-address who)]
    (pure:m ~)
  ::
  ++  make-town-id
    ^-  @ux
    0x0
  ::
  ++  service-host
    ^-  @p
    ~nec
  ::
  ++  make-escrow-jam-path
    ^-  path
    /con/compiled/escrow/jam
  ::
  ++  get-address
    |=  who=@p
    ^-  @ux
    (~(got by ship-to-address) who)
  --
::
++  ted
  ^-  thread:spider
  |=  args-vase=vase
  ^-  form:m
  =/  args  !<((unit arg-mold) args-vase)
  ?~  args
    ~&  >>>  "Usage:"
    ~&  >>>  "-pokur!ziggurat-configuration-pokur project-name=@t desk-name=@tas request-id=(unit @t)"
    (pure:m !>(~))
  =.  project-name  project-name.u.args
  =.  desk-name     desk-name.u.args
  =*  request-id    request-id.u.args
  ::
  ~&  %zcp^%top^%0
  ;<  =update:zig  bind:m
    %+  scry  update:zig
    /gx/ziggurat/get-ship-to-address-map/[project-name]/noun
  =.  ship-to-address
    ?>  ?=(^ update)
    ?>  ?=(%ship-to-address-map -.update)
    ?>  ?=(%& -.payload.update)
    p.payload.update
  ;<  setup-desk-result=vase  bind:m
    (run-setup-desk request-id)
  ~&  %zcp^%top^%1
  ;<  setup-ships-result=vase  bind:m  setup-virtualship-state
  ~&  %zcp^%top^%2
  (pure:m !>(`(each ~ @t)`[%.y ~]))
--
