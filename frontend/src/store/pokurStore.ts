import { NavigateFunction } from "react-router-dom"
import create from "zustand"
import api from "../api"
import { Game } from "../types/Game"
import { Lobby } from "../types/Lobby"
import { Message } from "../types/Message"
import { CreateTableValues, Table } from "../types/Table"
import { SNG_BLINDS } from "../utils/constants"
import { numToUd } from "../utils/number"
import { getPayoutAmounts } from '../utils/game'
import { createSubscription, handleGameUpdate, handleLobbyUpdate, handleNewMessage, SubscriptionPath } from "./subscriptions"

export interface PokurStore {
  loadingText: string | null
  
  host?: string
  lobby: Lobby
  table?: Table
  game?: Game

  messages: Message[]
  mutedPlayers: string[]
  gameEndMessage?: string
  gameStartingIn?: number

  init: () => Promise<'/table' | '/game' | '/' | void>
  getMessages: () => Promise<void>
  getOurTable: () => Promise<Table | undefined>
  getTable: (id: string) => Promise<Table | undefined>
  getGame: () => Promise<Game | undefined>
  getMutedPlayers: () => Promise<void>
  subscribeToPath: (path: SubscriptionPath, nav?: NavigateFunction) => Promise<number>
  setLoading: (loadingText: string | null) => void

  // pokur-player-action
  joinHost: (host: string) => Promise<void>
  leaveHost: () => Promise<void>
  createTable: (values: CreateTableValues) => Promise<void> // [%new-lobby parse-lobby]
  joinTable: (table: string) => Promise<void>
  setTable: (table: Table) => void
  leaveTable: (table: string) => Promise<void>
  startGame: (table: string) => Promise<void>
  leaveGame: (table: string) => Promise<void>
  kickPlayer: (table: string, player: string) => Promise<void>
  addEscrow: (values: string) => Promise<void>
  setOurAddress: (address: string) => Promise<void>
  
  // pokur-message-action
  mutePlayer: (player: string) => Promise<void>
  sendMessage: (msg: string) => Promise<void>

  // pokur-game-action
  check: (table: string) => Promise<void>
  fold: (table: string) => Promise<void>
  bet: (table: string, amount: number) => Promise<void>

  // pokur-host-action: TODO
}

const usePokurStore = create<PokurStore>((set, get) => ({
  loadingText: 'Loading Pokur...',

  host: undefined,
  lobby: {},
  table: undefined,
  game: undefined,
  messages: [],
  mutedPlayers: [],

  init: async () => {
    set({ loadingText: 'Loading Pokur...' })
    const { subscribeToPath, getMessages, getMutedPlayers, getOurTable } = get()

    try {
      subscribeToPath('/messages')

      const [game, table] = await Promise.all([
        api.scry({ app: 'pokur', path: '/game' }),
        getOurTable(),
        getMessages(),
        getMutedPlayers(),
      ])

      set({ loadingText: null, game, table })

      if (game) {
        return '/game'
      } else if (table) {
        return '/table'
      } else {
        return '/'
      }

    } catch (err) {
      console.warn('INIT ERROR:', err)
      set({ loadingText: null })
    }
  },
  getMessages: async () => {
    const messages = await api.scry({ app: 'pokur', path: '/messages' })
    set({ messages })
  },
  getOurTable: async () => {
    const ourTable = await api.scry({ app: 'pokur', path: '/our-table' })

    if (ourTable) {
      const table = await get().getTable(ourTable)
      set({ table })
      return table
    }

    set({ table: undefined })
  },
  getTable: async (id: string) => {
    const table = await api.scry({ app: 'pokur', path: `/table/${id}` })
    set({ table })
    return table
  },
  getGame: async () => {
    const game = await api.scry<Game | undefined>({ app: 'pokur', path: '/game' })
    set({ game })
    return game
  },
  getMutedPlayers: async () => {
    const mutedPlayers = await api.scry({ app: 'pokur', path: '/muted-players' })
    set({ mutedPlayers })
  },
  subscribeToPath: (path: SubscriptionPath, nav?: NavigateFunction) => {
    switch (path) {
      case '/lobby-updates':
        return api.subscribe(createSubscription('pokur', path, handleLobbyUpdate(get, set, nav)))
      case '/game-updates':
        return api.subscribe(createSubscription('pokur', path, handleGameUpdate(get, set)))
      case '/messages':
        return api.subscribe(createSubscription('pokur', path, handleNewMessage(get, set)))
    }
  },
  setLoading: (loadingText: string | null) => set({ loadingText }),
  joinHost: async (host: string) => {
    const json = { 'join-host': { host } }
    await api.poke({ app: 'pokur', mark: 'pokur-player-action', json })
  },
  leaveHost: async () => {
    const json = { 'leave-host': null }
    await api.poke({ app: 'pokur', mark: 'pokur-player-action', json })
    set({ host: undefined })
  },
  createTable: async (values: CreateTableValues) => {
    set({ loadingText: 'Creating table...' })

    const tokenized = { ...values.tokenized, amount: numToUd(values.tokenized.amount) }
    const json: any = {
      'new-table': { ...values, tokenized, id: '~2000.1.1' }
    }

    if (values['game-type'] === 'cash') {
      json['new-table']['game-type'] = { cash: {...values, type: values['game-type'] } }
    } else {
      json['new-table']['game-type'] = { sng: {
        ...values,
        'blinds-schedule': values["starting-blinds"] === '10/20' ?
          [{ small: 10, big: 20 }, ...SNG_BLINDS] : SNG_BLINDS,
        type: values['game-type'],
        payouts: getPayoutAmounts(values["min-players"]),
        'current-round': 0,
        'round-is-over': false
      } }
    }

    console.log('CREATE TABLE:', json)
    await api.poke({ app: 'pokur', mark: 'pokur-player-action', json })
    setTimeout(async () => {
      get().getOurTable()
      setTimeout(() => set({ loadingText: null }), 200)
    }, 200)
  },
  joinTable: async (table: string) => {
    const json = { 'join-table': { id: table } }
    await api.poke({ app: 'pokur', mark: 'pokur-player-action', json })
  },
  setTable: (table: Table) => set({ table }),
  leaveTable: async (table: string) => {
    const json = { 'leave-table': { id: table } }
    await api.poke({ app: 'pokur', mark: 'pokur-player-action', json })
    set({ table: undefined })
  },
  startGame: async (table: string) => {
    const json = { 'start-game': { id: table } }
    await api.poke({ app: 'pokur', mark: 'pokur-player-action', json })
  },
  leaveGame: async (table: string) => {
    if (get().game?.id === table) {
      const json = { 'leave-game': { id: table } }
      await api.poke({ app: 'pokur', mark: 'pokur-player-action', json })
    }

    set({ game: undefined, messages: [] })
  },
  kickPlayer: async (table: string, player: string) => {
    const json = { 'kick-player': { id: table, who: player } }
    await api.poke({ app: 'pokur', mark: 'pokur-player-action', json })
  },
  addEscrow: async (values: string) => {
    const json = { 'add-escrow': values }
    await api.poke({ app: 'pokur', mark: 'pokur-player-action', json })
  },
  setOurAddress: async (address: string) => {
    const json = { 'set-our-address': { address } }
    await api.poke({ app: 'pokur', mark: 'pokur-player-action', json })
  },
  mutePlayer: async (player: string) => {
    const json = { 'mute-player': { who: player } }
    await api.poke({ app: 'pokur', mark: 'pokur-message-action', json })
  },
  sendMessage: async (msg: string) => {
    const json = { 'send-message': { msg } }
    await api.poke({ app: 'pokur', mark: 'pokur-message-action', json })
  },
  check: async (table: string) => {
    const json = { check: { 'game-id': table } }
    console.log('CHECK:', json)
    await api.poke({ app: 'pokur', mark: 'pokur-game-action', json })
  },
  fold: async (table: string) => {
    const json = { fold: { 'game-id': table } }
    console.log('FOLD:', json)
    await api.poke({ app: 'pokur', mark: 'pokur-game-action', json })
  },
  bet: async (table: string, amount: number) => {
    const json = { bet: { 'game-id': table, amount } }
    console.log('BET:', json)
    await api.poke({ app: 'pokur', mark: 'pokur-game-action', json })
  },
}))

export default usePokurStore
