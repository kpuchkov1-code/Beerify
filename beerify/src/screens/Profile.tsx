import { useEffect, useRef, useState, useSyncExternalStore } from 'react'
import type { Session } from '@supabase/supabase-js'
import { DRINKER_LEVELS, type AppData, type DrinkCategory, type DrinkIconId, type DrinkPreset, type DrinkerLevel, type Profile } from '../types'
import { accountEnabled, currentSession, deleteCloudAccount, sendMagicLink, signOut, supabase, syncAccountData } from '../lib/account'
import { newId } from '../lib/storage'
import DrinkIcon from '../components/DrinkIcon'
import { getPushState, retryPushNotifications, subscribePushState } from '../lib/notifications'

interface Props {
  data: AppData
  onUpdateProfile: (profile: Profile) => void
  onUpdatePreferences: (values: Partial<AppData['preferences']>) => void
  onSavePreset: (preset: DrinkPreset) => void
  onReplaceData: (data: AppData) => void
}

const CATEGORIES: { id: DrinkCategory; label: string; icon: DrinkIconId }[] = [
  { id: 'beer', label: 'Beer', icon: 'can' },
  { id: 'cider', label: 'Cider', icon: 'cider' },
  { id: 'wine', label: 'Wine', icon: 'wine-red' },
  { id: 'spirit', label: 'Spirit', icon: 'spirit' },
  { id: 'cocktail', label: 'Cocktail', icon: 'cocktail' },
  { id: 'shot', label: 'Shot', icon: 'shot' },
  { id: 'soft', label: 'Low / no', icon: 'zero' },
]

export default function ProfileScreen({ data, onUpdateProfile, onUpdatePreferences, onSavePreset, onReplaceData }: Props) {
  const [session, setSession] = useState<Session | null>(null)
  const [email, setEmail] = useState('')
  const [accountMessage, setAccountMessage] = useState('')
  const [showPreset, setShowPreset] = useState(false)
  const [preset, setPreset] = useState({ name: '', brand: '', category: 'beer' as DrinkCategory, volume: '440', abv: '4.5' })
  const deleteDialog = useRef<HTMLDialogElement>(null)
  const push = useSyncExternalStore(subscribePushState, getPushState, getPushState)

  useEffect(() => {
    currentSession().then(setSession)
    const listener = supabase()?.auth.onAuthStateChange((_event, next) => setSession(next))
    return () => listener?.data.subscription.unsubscribe()
  }, [])

  async function syncNow() {
    setAccountMessage('Syncing your nights…')
    try {
      const merged = await syncAccountData(data)
      onReplaceData(merged)
      setAccountMessage('Everything is synced.')
    } catch (cause) {
      setAccountMessage(cause instanceof Error ? cause.message : 'Sync did not work')
    }
  }

  function saveCustomPreset() {
    const volumeMl = Number(preset.volume)
    const abv = Number(preset.abv) / 100
    const category = CATEGORIES.find((item) => item.id === preset.category)!
    if (!preset.name.trim() || !Number.isFinite(volumeMl) || volumeMl < 5 || volumeMl > 5000 || !Number.isFinite(abv) || abv < 0 || abv > 1) return
    onSavePreset({
      id: `custom-${newId()}`,
      name: preset.name.trim(),
      brand: preset.brand.trim() || undefined,
      category: preset.category,
      icon: category.icon,
      volumeMl,
      abv,
      absorptionMin: preset.category === 'shot' ? 12 : preset.category === 'spirit' ? 20 : 30,
      detail: `${volumeMl}ml · ${Number((abv * 100).toFixed(1))}%`,
      source: 'custom',
    })
    setPreset({ name: '', brand: '', category: 'beer', volume: '440', abv: '4.5' })
    setShowPreset(false)
  }

  function exportData() {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = `beerify-${new Date().toISOString().slice(0, 10)}.json`
    anchor.click()
    URL.revokeObjectURL(url)
  }

  return (
    <main className="screen profile-screen">
      <header className="page-header page-header--stacked"><span className="page-kicker">YOUR TAB</span><h1>{data.profile?.name}</h1><p>Local by default. Sync only when you ask.</p></header>

      <section className="settings-section">
        <div className="section-heading"><h2>Pub profile</h2></div>
        <label className="field" htmlFor="profile-edit-name"><span className="field__label">Display name</span><input id="profile-edit-name" value={data.profile?.name ?? ''} onChange={(event) => data.profile && onUpdateProfile({ ...data.profile, name: event.target.value.slice(0, 30) })} /></label>
        <div className="preset-form__measure">
          <label className="field"><span className="field__label">Age (optional)</span><input type="number" min="18" max="100" value={data.profile?.age ?? ''} placeholder="28" onChange={(event) => data.profile && onUpdateProfile({ ...data.profile, age: event.target.value ? Number(event.target.value) : undefined })} /></label>
          <label className="field"><span className="field__label">Height cm (optional)</span><input type="number" min="120" max="230" value={data.profile?.heightCm ?? ''} placeholder="175" onChange={(event) => data.profile && onUpdateProfile({ ...data.profile, heightCm: event.target.value ? Number(event.target.value) : undefined })} /></label>
        </div>
        <label className="field" htmlFor="profile-drinker-level"><span className="field__label">Pub experience</span><select id="profile-drinker-level" value={data.profile?.drinkerLevel ?? 'weekend'} onChange={(event) => data.profile && onUpdateProfile({ ...data.profile, drinkerLevel: event.target.value as DrinkerLevel })}>{DRINKER_LEVELS.map((level) => <option key={level.id} value={level.id}>{level.label}</option>)}</select></label>
        <div className="settings-row"><span><strong>Haptic taps</strong><small>Feel each drink land</small></span><input type="checkbox" role="switch" checked={data.preferences.haptics} onChange={(event) => onUpdatePreferences({ haptics: event.target.checked })} /></div>
        <div className="settings-row"><span><strong>Reduce motion</strong><small>Quieter countdowns and reactions</small></span><input type="checkbox" role="switch" checked={data.preferences.reducedMotion} onChange={(event) => onUpdatePreferences({ reducedMotion: event.target.checked })} /></div>
      </section>

      <section className="settings-section">
        <div className="section-heading"><h2>Room alerts</h2><span className={push.status === 'granted' ? 'status-badge status-badge--on' : 'status-badge'}>{push.status === 'granted' ? 'Enabled' : push.status === 'unsupported' ? 'iOS only' : 'Off'}</span></div>
        {push.status === 'unsupported' ? <p>Push alerts are available in the installed iOS app. Live room countdowns still appear while this app is open.</p>
          : push.status === 'denied' ? <p>Notifications are blocked. Open iOS Settings → Beerify → Notifications to enable Drink up and round alerts.</p>
          : push.status === 'granted' ? <p>{push.error || 'Drink up countdowns and important round updates can reach you while Beerify is in the background.'}</p>
          : <p>{push.error || 'Beerify is checking whether room alerts are available.'}</p>}
        {(push.status === 'prompt' || push.status === 'error' || Boolean(push.error)) && <button className="btn btn--secondary" onClick={() => void retryPushNotifications()}>{push.status === 'granted' ? 'Retry room alerts' : 'Enable room alerts'}</button>}
      </section>

      <section className="settings-section">
        <div className="section-heading"><h2>Your drinks</h2><button className="text-action" onClick={() => setShowPreset((value) => !value)}>{showPreset ? 'Close' : 'Add preset'}</button></div>
        {showPreset && (
          <div className="preset-form">
            <label className="field"><span className="field__label">Drink name</span><input value={preset.name} placeholder="House lager" onChange={(event) => setPreset({ ...preset, name: event.target.value })} /></label>
            <label className="field"><span className="field__label">Brand (optional)</span><input value={preset.brand} placeholder="Brand on the label" onChange={(event) => setPreset({ ...preset, brand: event.target.value })} /></label>
            <div className="preset-form__measure">
              <label className="field"><span className="field__label">Millilitres</span><input type="number" min="5" max="5000" value={preset.volume} onChange={(event) => setPreset({ ...preset, volume: event.target.value })} /></label>
              <label className="field"><span className="field__label">ABV %</span><input type="number" min="0" max="100" step="0.1" value={preset.abv} onChange={(event) => setPreset({ ...preset, abv: event.target.value })} /></label>
            </div>
            <div className="category-picker" aria-label="Drink category">
              {CATEGORIES.map((item) => <button key={item.id} aria-pressed={preset.category === item.id} className={preset.category === item.id ? 'category-picker__item category-picker__item--active' : 'category-picker__item'} onClick={() => setPreset({ ...preset, category: item.id })}><DrinkIcon icon={item.icon} size={28} /><span>{item.label}</span></button>)}
            </div>
            <button className="btn btn--primary" disabled={!preset.name.trim()} onClick={saveCustomPreset}>Save drink preset</button>
          </div>
        )}
        {data.preferences.customPresets.length > 0 && <ul className="custom-drinks">{data.preferences.customPresets.map((item) => <li key={item.id}><DrinkIcon icon={item.icon} size={32} /><span><strong>{item.brand || item.name}</strong><small>{item.detail}</small></span></li>)}</ul>}
      </section>

      <section className="settings-section account-panel">
        <div className="section-heading"><h2>Account sync</h2><span className={session ? 'status-badge status-badge--on' : 'status-badge'}>{session ? 'Synced' : 'Guest'}</span></div>
        {!accountEnabled() ? <p>Supabase is not configured on this deployment. Your data remains on this device.</p> : session ? (
          <>
            <p>Signed in as <strong>{session.user.email}</strong>.</p>
            <div className="button-row"><button className="btn btn--secondary" onClick={syncNow}>Sync now</button><button className="btn btn--quiet" onClick={() => signOut()}>Sign out</button></div>
            <button className="danger-link" onClick={() => deleteDialog.current?.showModal()}>Delete cloud account</button>
          </>
        ) : (
          <form onSubmit={async (event) => { event.preventDefault(); setAccountMessage('Sending link…'); try { await sendMagicLink(email); setAccountMessage('Check your email for the sign-in link.') } catch (cause) { setAccountMessage(cause instanceof Error ? cause.message : 'Could not send the link') } }}>
            <label className="field" htmlFor="sync-email"><span className="field__label">Email address</span><input id="sync-email" type="email" required autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} /></label>
            <button className="btn btn--primary" type="submit">Email me a sign-in link</button>
          </form>
        )}
        {accountMessage && <p className="status-message" role="status">{accountMessage}</p>}
      </section>

      <section className="settings-section"><div className="section-heading"><h2>Your data</h2></div><button className="settings-action" onClick={exportData}>Export Beerify data <span>↓</span></button></section>

      <dialog className="native-dialog" ref={deleteDialog} aria-labelledby="delete-account-title">
        <div className="dialog-sheet">
          <h2 id="delete-account-title">Delete cloud account?</h2>
          <p>This deletes your synced profile and nights. Local data on this device remains.</p>
          <button className="btn btn--danger" onClick={async () => { try { await deleteCloudAccount(); setSession(null); setAccountMessage('Cloud account deleted.'); deleteDialog.current?.close() } catch (cause) { setAccountMessage(cause instanceof Error ? cause.message : 'Could not delete the account'); deleteDialog.current?.close() } }}>Delete cloud account</button>
          <button className="btn btn--quiet" autoFocus onClick={() => deleteDialog.current?.close()}>Keep account</button>
        </div>
      </dialog>
    </main>
  )
}
