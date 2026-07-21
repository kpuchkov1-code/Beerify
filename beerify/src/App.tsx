import { lazy, Suspense, useCallback, useEffect, useState } from 'react'
import type { AppData, DrinkPreset, LoggedDrink, MealState, NightMode, NightSession, ParticipationMode, Profile, PubCrawlStop, RoomMembership, RoomState, TargetId } from './types'
import { logFromPreset, presetById, TARGETS } from './lib/drinks'
import { loadData, newId, saveData } from './lib/storage'
import { leaveRoom as disconnectRoom, registerRoomPush, setRoomCrawl, trackMetric } from './lib/room'
import { apnsEnvironment, getPushState, reportPushRegistrationError, subscribePushState } from './lib/notifications'
import Onboarding from './screens/Onboarding'
import Home from './screens/Home'
import NightOut from './screens/NightOut'
import Crew from './screens/Crew'
import AgeConfirm from './screens/AgeConfirm'
import AppNav, { type AppTab } from './components/AppNav'
import ActiveNightNav from './components/ActiveNightNav'

const Summary = lazy(() => import('./screens/Summary'))
const History = lazy(() => import('./screens/History'))
const ProfileScreen = lazy(() => import('./screens/Profile'))
const Games = lazy(() => import('./screens/Games'))
const Pubs = lazy(() => import('./screens/Pubs'))
const Stats = lazy(() => import('./screens/Stats'))

const INITIAL_PARAMS = new URLSearchParams(location.search)
const INITIAL_ROOM_CODE = /^[A-Z2-9]{6}$/.test(INITIAL_PARAMS.get('room')?.toUpperCase() ?? '')
  ? INITIAL_PARAMS.get('room')!.toUpperCase()
  : ''
const OPENED_INVITE = INITIAL_PARAMS.get('via') === 'invite'
const ACCOUNT_SYNC_CONFIGURED = Boolean(import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY)

export default function App() {
  const [data, setData] = useState<AppData>(loadData)
  const [viewingSummary, setViewingSummary] = useState<NightSession | null>(null)
  const invitedCode = INITIAL_ROOM_CODE
  const [tab, setTab] = useState<AppTab>('tonight')
  const screenKey = !data.profile ? 'setup' : !data.profile.legalAgeConfirmedAt ? 'age' : viewingSummary?.id ?? (data.session ? `night-${tab}` : tab)

  useEffect(() => saveData(data), [data])

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0 })
  }, [screenKey])

  useEffect(() => {
    if (OPENED_INVITE) trackMetric('invite_opened')
  }, [])

  useEffect(() => {
    const clearRejectedRoom = (event: Event) => {
      const detail = (event as CustomEvent<{ code?: string; memberId?: string }>).detail
      setData((current) => current.room && (!detail?.code || current.room.code === detail.code) && (!detail?.memberId || current.room.memberId === detail.memberId)
        ? { ...current, room: null }
        : current)
    }
    window.addEventListener('beerify:room-invalid', clearRejectedRoom)
    return () => window.removeEventListener('beerify:room-invalid', clearRejectedRoom)
  }, [])

  useEffect(() => {
    if (!ACCOUNT_SYNC_CONFIGURED) return
    let cancelled = false
    const timeout = setTimeout(async () => {
      const { accountEnabled, currentSession, syncAccountData } = await import('./lib/account')
      if (!accountEnabled() || !(await currentSession())) return
      try {
        const merged = await syncAccountData(data)
        if (!cancelled && JSON.stringify(merged) !== JSON.stringify(data)) setData(merged)
      } catch {
        // Local data remains authoritative when optional sync is offline.
      }
    }, 1_200)
    return () => { cancelled = true; clearTimeout(timeout) }
  }, [data])

  useEffect(() => {
    if (!data.room) return
    let registeredToken = ''
    const sync = async () => {
      const push = getPushState()
      if (!push.token || push.token === registeredToken) return
      try {
        await registerRoomPush(data.room!, push.token, apnsEnvironment)
        registeredToken = push.token
        reportPushRegistrationError(null)
      } catch (error) {
        reportPushRegistrationError(error instanceof Error ? `Room alerts could not connect: ${error.message}` : 'Room alerts could not connect')
      }
    }
    void sync()
    const unsubscribe = subscribePushState(() => { void sync() })
    const resume = () => { registeredToken = ''; void sync() }
    window.addEventListener('beerify:resume', resume)
    return () => { unsubscribe(); window.removeEventListener('beerify:resume', resume) }
  }, [data.room])

  useEffect(() => {
    const warm = () => { void import('./screens/History'); void import('./screens/Summary') }
    if (typeof window.requestIdleCallback === 'function') {
      const idle = window.requestIdleCallback(warm, { timeout: 4_000 })
      return () => window.cancelIdleCallback(idle)
    }
    const timeout = globalThis.setTimeout(warm, 2_000)
    return () => globalThis.clearTimeout(timeout)
  }, [])

  function setProfile(profile: Profile) {
    setData((current) => ({ ...current, profile }))
  }

  function updateProfile(profile: Profile) {
    setData((current) => ({ ...current, profile: { ...profile, updatedAt: Date.now() } }))
  }

  async function startNight(targetId: TargetId, mealState: MealState, participationMode: ParticipationMode, nightMode: NightMode) {
    const now = Date.now()
    const target = TARGETS[targetId]
    if (nightMode === 'group' && !data.room) return
    if (nightMode === 'solo' && data.room) void disconnectRoom(data.room).catch(() => {})
    const draftStops = data.pubCrawlDraft?.stops ?? []
    let initialCrawl = nightMode === 'solo' ? draftStops : []
    const hostImportsDraft = nightMode === 'group' && data.room?.isHost && draftStops.length > 0
    if (hostImportsDraft && data.room) {
      const room = await setRoomCrawl(data.room, draftStops)
      initialCrawl = room.crawl
    }
    setTab('tonight')
    setData((current) => ({
      ...current,
      room: nightMode === 'group' ? current.room : null,
      pubCrawlDraft: nightMode === 'solo' || hostImportsDraft ? null : current.pubCrawlDraft,
      session: { id: newId(), startedAt: now, updatedAt: now, targetId, targetSnapshot: { id: target.id, label: target.label, emoji: target.emoji, minBac: target.minBac, maxBac: target.maxBac }, mealState, participationMode, nightMode, roomCode: nightMode === 'group' ? current.room?.code : undefined, drinks: [], waters: [], pubCrawl: initialCrawl },
      preferences: { ...current.preferences, lastTargetId: targetId, lastParticipationMode: participationMode, updatedAt: now },
    }))
  }

  function logDrink(presetId: string): LoggedDrink | null {
    if (!data.session || data.session.participationMode !== 'drinking') return null
    const preset = presetById(presetId, data.preferences.customPresets)
    if (!preset) return null
    const now = Date.now()
    const logged = logFromPreset(preset, newId(), now)
    const first = data.session.drinks.length === 0
    setData((current) => {
      if (!current.session) return current
      return {
        ...current,
        session: {
          ...current.session,
          updatedAt: now,
          drinks: [...current.session.drinks, logged],
        },
        preferences: {
          ...current.preferences,
          recentPresetIds: [presetId, ...current.preferences.recentPresetIds.filter((id) => id !== presetId)].slice(0, 8),
          updatedAt: now,
        },
      }
    })
    if (first) trackMetric('first_drink')
    return logged
  }

  function logWater() {
    const now = Date.now()
    setData((current) => current.session ? {
      ...current,
      session: { ...current.session, updatedAt: now, waters: [...current.session.waters, now] },
    } : current)
  }

  function undoDrink() {
    setData((current) => current.session ? {
      ...current,
      session: { ...current.session, updatedAt: Date.now(), drinks: current.session.drinks.slice(0, -1) },
    } : current)
  }

  function updateDrink(drink: LoggedDrink) {
    setData((current) => current.session ? {
      ...current,
      session: { ...current.session, updatedAt: Date.now(), drinks: current.session.drinks.map((item) => item.id === drink.id ? drink : item) },
    } : current)
  }

  function endNight(room?: RoomState | null) {
    if (data.room) void disconnectRoom(data.room).catch(() => {})
    setData((current) => {
      if (!current.session) return current
      const now = Date.now()
      const ended = {
        ...current.session,
        roomName: room?.name,
        roomEvents: room?.events,
        roomMembers: room?.members.map(({ id, name }) => ({ id, name })),
        roomLeaderboard: room?.leaderboard,
        roomConfig: room ? { name: room.name, theme: room.theme, labels: room.labels, leaderboardMode: room.leaderboardMode } : undefined,
        endedAt: now,
        updatedAt: now,
      }
      return { ...current, room: null, session: null, history: [...current.history, ended] }
    })
    setTab('history')
  }

  function joinRoom(room: RoomMembership) {
    setData((current) => ({
      ...current,
      room,
      session: current.session?.nightMode === 'group' ? { ...current.session, roomCode: room.code, updatedAt: Date.now() } : current.session,
    }))
  }

  function clearRoom() {
    setData((current) => ({ ...current, room: null }))
    if (data.session) setTab('tonight')
  }

  function discardRoom() {
    if (data.room) void disconnectRoom(data.room).catch(() => {})
    clearRoom()
  }

  const updateCrawl = useCallback((pubCrawl: PubCrawlStop[]) => {
    setData((current) => current.session ? {
      ...current,
      session: { ...current.session, pubCrawl, updatedAt: Date.now() },
    } : current)
  }, [])

  const updateDraftCrawl = useCallback((stops: PubCrawlStop[]) => {
    setData((current) => ({
      ...current,
      pubCrawlDraft: stops.length ? { stops, updatedAt: Date.now() } : null,
    }))
  }, [])

  function updatePreset(preset: DrinkPreset) {
    setData((current) => {
      const customPresets = [preset, ...current.preferences.customPresets.filter((item) => item.id !== preset.id)]
      return { ...current, preferences: { ...current.preferences, customPresets, updatedAt: Date.now() } }
    })
  }

  function toggleFavorite(presetId: string) {
    setData((current) => {
      const favorites = current.preferences.favoritePresetIds.includes(presetId)
        ? current.preferences.favoritePresetIds.filter((id) => id !== presetId)
        : [presetId, ...current.preferences.favoritePresetIds].slice(0, 8)
      return { ...current, preferences: { ...current.preferences, favoritePresetIds: favorites, updatedAt: Date.now() } }
    })
  }

  function updatePreferences(values: Partial<AppData['preferences']>) {
    setData((current) => ({
      ...current,
      preferences: { ...current.preferences, ...values, updatedAt: Date.now() },
    }))
  }

  function openSummary(session: NightSession) {
    setViewingSummary(session)
    if (!session.reviewedAt) {
      setData((current) => ({
        ...current,
        history: current.history.map((item) => item.id === session.id
          ? { ...item, reviewedAt: Date.now(), updatedAt: Date.now() }
          : item),
      }))
    }
  }

  if (!data.profile) return <Onboarding onDone={setProfile} />

  if (!data.profile.legalAgeConfirmedAt) return <AgeConfirm profile={data.profile} onConfirm={updateProfile} />

  if (viewingSummary) {
    return <Suspense fallback={<main className="screen"><p className="empty-copy">Opening your recap…</p></main>}><Summary session={viewingSummary} history={data.history} profile={data.profile} onClose={() => setViewingSummary(null)} /></Suspense>
  }

  const activeMembership = data.session?.nightMode === 'group' ? data.room : null
  const content = tab === 'tonight'
    ? data.session
      ? <NightOut session={data.session} profile={data.profile} preferences={data.preferences} membership={activeMembership} onLogDrink={logDrink} onLogWater={logWater} onUndo={undoDrink} onUpdateDrink={updateDrink} onEndNight={endNight} onToggleFavorite={toggleFavorite} onSavePreset={updatePreset} onOpenCrew={() => setTab('crew')} />
      : <Home profile={data.profile} history={data.history} preferences={data.preferences} membership={data.room} plannedStops={data.pubCrawlDraft?.stops.length ?? 0} initialCode={invitedCode} onStartNight={startNight} onOpenSummary={openSummary} onRoomJoin={joinRoom} onRoomLeave={discardRoom} />
    : tab === 'crew'
      ? <Crew profile={data.profile} membership={activeMembership} session={data.session} initialCode={data.session?.roomCode ?? invitedCode} onJoin={joinRoom} onLeave={clearRoom} onOpenTonight={() => setTab('tonight')} />
      : tab === 'games'
        ? <Games nightMode={data.session?.nightMode ?? 'solo'} membership={activeMembership} room={null} spiciness={data.preferences.spiciness} onSpiciness={(spiciness) => updatePreferences({ spiciness })} onOpenCrew={() => setTab('crew')} />
        : tab === 'pubs'
          ? <Pubs session={data.session} membership={activeMembership} draft={data.pubCrawlDraft} reducedMotion={data.preferences.reducedMotion} onDraftChange={updateDraftCrawl} onCrawlChange={updateCrawl} onOpenCrew={() => setTab('crew')} />
          : tab === 'stats'
            ? <Stats history={data.history} profile={data.profile} />
      : tab === 'history'
        ? <History history={data.history} onOpenSummary={openSummary} />
        : <ProfileScreen data={data} onUpdateProfile={updateProfile} onUpdatePreferences={updatePreferences} onSavePreset={updatePreset} onReplaceData={setData} />

  return (
    <div data-theme={data.preferences.themedNight} className={`${data.session ? 'active-night-shell' : 'app-shell'}${data.preferences.bigThumbMode ? ' big-thumb-mode' : ''}`}>
      <Suspense fallback={<main className="screen"><p className="empty-copy">Opening…</p></main>}>{content}</Suspense>
      {data.session
        ? <ActiveNightNav active={tab} onChange={setTab} nightMode={data.session.nightMode} roomActive={Boolean(activeMembership)} />
        : <AppNav active={tab} onChange={setTab} roomActive={Boolean(data.room)} />}
    </div>
  )
}
