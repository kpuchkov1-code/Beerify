import { useEffect, useState } from 'react'
import type { AppData, DrinkPreset, LoggedDrink, MealState, NightSession, Profile, RoomMembership, RoomState, TargetId } from './types'
import { logFromPreset, presetById, TARGETS } from './lib/drinks'
import { loadData, newId, saveData } from './lib/storage'
import { currentSession, supabase, syncAccountData } from './lib/account'
import { trackMetric } from './lib/room'
import Onboarding from './screens/Onboarding'
import Home from './screens/Home'
import NightOut from './screens/NightOut'
import Summary from './screens/Summary'
import Crew from './screens/Crew'
import History from './screens/History'
import ProfileScreen from './screens/Profile'
import AppNav, { type AppTab } from './components/AppNav'

const INITIAL_PARAMS = new URLSearchParams(location.search)
const INITIAL_ROOM_CODE = /^[A-Z2-9]{6}$/.test(INITIAL_PARAMS.get('room')?.toUpperCase() ?? '')
  ? INITIAL_PARAMS.get('room')!.toUpperCase()
  : ''
const OPENED_INVITE = INITIAL_PARAMS.get('via') === 'invite'

export default function App() {
  const [data, setData] = useState<AppData>(loadData)
  const [viewingSummary, setViewingSummary] = useState<NightSession | null>(null)
  const invitedCode = INITIAL_ROOM_CODE
  const [tab, setTab] = useState<AppTab>(invitedCode ? 'crew' : 'tonight')
  const screenKey = !data.profile ? 'setup' : viewingSummary?.id ?? (data.session ? 'night' : tab)

  useEffect(() => saveData(data), [data])

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0 })
  }, [screenKey])

  useEffect(() => {
    if (OPENED_INVITE) trackMetric('invite_opened')
  }, [])

  useEffect(() => {
    const db = supabase()
    if (!db) return
    let cancelled = false
    const timeout = setTimeout(async () => {
      if (!(await currentSession())) return
      try {
        const merged = await syncAccountData(data)
        if (!cancelled && JSON.stringify(merged) !== JSON.stringify(data)) setData(merged)
      } catch {
        // Local data remains authoritative when optional sync is offline.
      }
    }, 1_200)
    return () => { cancelled = true; clearTimeout(timeout) }
  }, [data])

  function setProfile(profile: Profile) {
    setData((current) => ({ ...current, profile }))
  }

  function updateProfile(profile: Profile) {
    setData((current) => ({ ...current, profile: { ...profile, updatedAt: Date.now() } }))
  }

  function startNight(targetId: TargetId, mealState: MealState) {
    const now = Date.now()
    const target = TARGETS[targetId]
    setData((current) => ({
      ...current,
      session: { id: newId(), startedAt: now, updatedAt: now, targetId, targetSnapshot: { id: target.id, label: target.label, emoji: target.emoji, minBac: target.minBac, maxBac: target.maxBac }, mealState, drinks: [], waters: [] },
      preferences: { ...current.preferences, lastTargetId: targetId, updatedAt: now },
    }))
  }

  function logDrink(presetId: string): LoggedDrink | null {
    if (!data.session) return null
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
      return { ...current, session: null, history: [...current.history, ended] }
    })
    setTab('history')
  }

  function joinRoom(room: RoomMembership) {
    setData((current) => ({ ...current, room }))
    setTab('tonight')
  }

  function leaveRoom() {
    setData((current) => ({ ...current, room: null }))
  }

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

  if (viewingSummary) {
    return <Summary session={viewingSummary} history={data.history} profile={data.profile} onClose={() => setViewingSummary(null)} />
  }

  if (data.session) {
    return (
      <NightOut
        session={data.session}
        profile={data.profile}
        preferences={data.preferences}
        membership={data.room}
        onLogDrink={logDrink}
        onLogWater={logWater}
        onUndo={undoDrink}
        onUpdateDrink={updateDrink}
        onEndNight={endNight}
        onToggleFavorite={toggleFavorite}
        onSavePreset={updatePreset}
      />
    )
  }

  const content = tab === 'tonight'
    ? <Home profile={data.profile} history={data.history} preferences={data.preferences} membership={data.room} onStartNight={startNight} onOpenSummary={openSummary} onOpenCrew={() => setTab('crew')} />
    : tab === 'crew'
      ? <Crew profile={data.profile} membership={data.room} initialCode={invitedCode} onJoin={joinRoom} onLeave={leaveRoom} onOpenTonight={() => setTab('tonight')} />
      : tab === 'history'
        ? <History history={data.history} onOpenSummary={openSummary} />
        : <ProfileScreen data={data} onUpdateProfile={updateProfile} onUpdatePreferences={updatePreferences} onSavePreset={updatePreset} onReplaceData={setData} />

  return (
    <div className="app-shell">
      {content}
      <AppNav active={tab} onChange={setTab} roomActive={Boolean(data.room)} />
    </div>
  )
}
