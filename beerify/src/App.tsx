import { useEffect, useState } from 'react'
import type { AppData, DrinkTypeId, NightSession, Profile, TargetId } from './types'
import { DRINK_TYPES, gramsOfAlcohol, unitsOfAlcohol } from './lib/drinks'
import { loadData, newId, saveData } from './lib/storage'
import Onboarding from './screens/Onboarding'
import Home from './screens/Home'
import NightOut from './screens/NightOut'
import Summary from './screens/Summary'

export default function App() {
  const [data, setData] = useState<AppData>(loadData)
  const [viewingSummary, setViewingSummary] = useState<NightSession | null>(null)

  useEffect(() => {
    saveData(data)
  }, [data])

  function setProfile(profile: Profile) {
    setData((d) => ({ ...d, profile }))
  }

  function startNight(targetId: TargetId) {
    setData((d) => ({
      ...d,
      session: {
        id: newId(),
        startedAt: Date.now(),
        targetId,
        drinks: [],
        waters: [],
      },
    }))
  }

  function logDrink(type: DrinkTypeId) {
    const def = DRINK_TYPES[type]
    setData((d) => {
      if (!d.session) return d
      return {
        ...d,
        session: {
          ...d.session,
          drinks: [
            ...d.session.drinks,
            {
              id: newId(),
              type,
              at: Date.now(),
              units: unitsOfAlcohol(def),
              grams: gramsOfAlcohol(def),
            },
          ],
        },
      }
    })
  }

  function logWater() {
    setData((d) =>
      d.session ? { ...d, session: { ...d.session, waters: [...d.session.waters, Date.now()] } } : d,
    )
  }

  function undoDrink() {
    setData((d) =>
      d.session
        ? { ...d, session: { ...d.session, drinks: d.session.drinks.slice(0, -1) } }
        : d,
    )
  }

  function endNight() {
    setData((d) => {
      if (!d.session) return d
      const ended = { ...d.session, endedAt: Date.now() }
      return { ...d, session: null, history: [...d.history, ended] }
    })
  }

  function openSummary(session: NightSession) {
    setViewingSummary(session)
    if (!session.reviewedAt) {
      setData((d) => ({
        ...d,
        history: d.history.map((s) => (s.id === session.id ? { ...s, reviewedAt: Date.now() } : s)),
      }))
    }
  }

  if (!data.profile) {
    return <Onboarding onDone={setProfile} />
  }

  if (viewingSummary) {
    return (
      <Summary session={viewingSummary} profile={data.profile} onClose={() => setViewingSummary(null)} />
    )
  }

  if (data.session) {
    return (
      <NightOut
        session={data.session}
        profile={data.profile}
        onLogDrink={logDrink}
        onLogWater={logWater}
        onUndo={undoDrink}
        onEndNight={endNight}
      />
    )
  }

  const unreviewed =
    [...data.history].sort((a, b) => b.startedAt - a.startedAt).find((s) => !s.reviewedAt) ?? null

  return (
    <Home
      profile={data.profile}
      history={data.history}
      unreviewed={unreviewed}
      onStartNight={startNight}
      onOpenSummary={openSummary}
    />
  )
}
