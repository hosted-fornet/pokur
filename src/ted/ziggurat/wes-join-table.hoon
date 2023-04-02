/-  pokur,
    spider,
    w=zig-wallet,
    zig=zig-ziggurat
/+  strandio,
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
  $:  project-name=@t
      desk-name=@tas
      request-id=(unit @t)
  ==
::
++  town-id
  ^-  @ux
  0x0
::
++  sequencer-host
  ^-  @p
  ~nec
::
++  who
  ^-  @p
  ~wes
::
++  to
  ^-  @p
  ~wes
::
++  zigs-contract-address
  ^-  @ux
  0x74.6361.7274.6e6f.632d.7367.697a
::
++  item
  ^-  @ux
  0x9c5a.605c.54a6.d30d.bdb7.0d6d.1b3d.d92e.5a38.6903.639e.06c6.9128.9b52.5358.b741
::
++  get-ship-to-address
  =/  m  (strand ,(map @p @ux))
  ^-  form:m
  ;<  =update:zig  bind:m
    %+  scry  update:zig
    /gx/ziggurat/get-ship-to-address-map/[project-name]/noun
  ?>  ?=(^ update)
  ?>  ?=(%ship-to-address-map -.update)
  ?>  ?=(%& -.payload.update)
  (pure:m p.payload.update)
::
++  ted
  ^-  thread:spider
  |=  args-vase=vase
  ^-  form:m
  =/  args  !<((unit arg-mold) args-vase)
  ?~  args
    ~&  >>>  "Usage:"
    ~&  >>>  "-zig!ziggurat-send-bud project-name=@t desk-name=@tas request-id=(unit @t)"
    (pure:m !>(~))
  =.  project-name  project-name.u.args
  =.  desk-name     desk-name.u.args
  =*  request-id    request-id.u.args
  ;<  new-ship-to-address=(map @p @ux)  bind:m
    get-ship-to-address
  =.  ship-to-address  new-ship-to-address
  ::
  ~&  %zsb^%top^%0
  ;<  =update:pokur  bind:m
    %^  send-pyro-scry:zig-threads  who  update:pokur
    :+  %gx  %pokur  /lobby/noun/noun
  ?>  ?=(%lobby -.update)
  =/  table-ids=(list @da)
    ~(tap in ~(key by tables.update))
  ?>  ?=([@ ~] table-ids)
  =*  table-id  i.table-ids
  ;<  empty-vase=vase  bind:m
    %-  send-wallet-transaction:zig-threads
    :-  project-name
    :^  who  sequencer-host
      !>(send-discrete-pyro-poke:zig-threads)
    :-  project-name
    :^  who  who  %pokur
    :-  %pokur-player-action
    !>  ^-  player-action:pokur
    :^  %join-table  id=table-id
    buy-in=1.000.000.000.000.000.000  public=%.y
  (pure:m !>(`(each ~ @t)`[%.y ~]))
--
