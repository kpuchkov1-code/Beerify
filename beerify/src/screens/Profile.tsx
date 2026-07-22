import { useEffect, useRef, useState, useSyncExternalStore } from 'react'
import type { ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { DRINKER_LEVELS, type AppData, type CoachPersonality, type DrinkCategory, type DrinkIconId, type DrinkPreset, type DrinkerLevel, type Profile, type ThemedNight } from '../types'
import { accountEnabled, currentSession, deleteCloudAccount, sendMagicLink, signOut, supabase, syncAccountData } from '../lib/account'
import { newId } from '../lib/storage'
import DrinkIcon from '../components/DrinkIcon'
import { getPushState, retryPushNotifications, subscribePushState } from '../lib/notifications'
import AppIcon from '../components/AppIcon'

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

const AVATARS = ['🍺', '🍻', '🍸', '🍷', '🕺', '💃', '🪩', '🫡']

async function compressAvatar(file: File): Promise<string> {
  if (!file.type.startsWith('image/')) throw new Error('Choose an image file')
  const bitmap = await createImageBitmap(file)
  const scale = Math.min(1, 384 / Math.max(bitmap.width, bitmap.height))
  const canvas = document.createElement('canvas')
  canvas.width = Math.max(1, Math.round(bitmap.width * scale))
  canvas.height = Math.max(1, Math.round(bitmap.height * scale))
  canvas.getContext('2d')?.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
  bitmap.close()
  return canvas.toDataURL('image/webp', .76)
}

function SettingsDisclosure({ title, badge, open, children, className = '' }: { title: string; badge?: ReactNode; open?: boolean; children: ReactNode; className?: string }) {
  return <details className={`settings-disclosure ${className}`} open={open}>
    <summary><span>{title}</span><span>{badge}<AppIcon name="chevron-down" size={19} /></span></summary>
    <div className="settings-disclosure__body">{children}</div>
  </details>
}

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
      <header className="page-header page-header--stacked"><span className="page-kicker">YOU</span><h1>Your profile</h1><p>{data.profile?.name}, your identity and night settings live here. Data stays local unless you enable sync.</p></header>

      <section className="settings-section">
        <div className="section-heading"><h2>Identity</h2></div>
        <div className="avatar-editor">
          <div className="profile-avatar" aria-label="Current avatar">{data.profile?.avatarImageData ? <img src={data.profile.avatarImageData} alt="Your profile" /> : <span>{data.profile?.avatarEmoji || '🍺'}</span>}</div>
          <div><div className="avatar-picker" aria-label="Choose an avatar emoji">{AVATARS.map((emoji) => <button key={emoji} aria-label={`Use ${emoji} as your avatar`} aria-pressed={data.profile?.avatarEmoji === emoji && !data.profile.avatarImageData} onClick={() => data.profile && onUpdateProfile({ ...data.profile, avatarEmoji: emoji, avatarImageData: undefined })}>{emoji}</button>)}</div><label className="text-action avatar-upload">Use a photo<input className="visually-hidden" type="file" accept="image/*" onChange={async (event) => { const file = event.target.files?.[0]; if (!file || !data.profile) return; try { onUpdateProfile({ ...data.profile, avatarImageData: await compressAvatar(file) }) } catch { setAccountMessage('That photo could not be prepared.') } }} /></label></div>
        </div>
        <label className="field" htmlFor="profile-edit-name"><span className="field__label">Display name</span><input id="profile-edit-name" value={data.profile?.name ?? ''} onChange={(event) => data.profile && onUpdateProfile({ ...data.profile, name: event.target.value.slice(0, 30) })} /></label>
        <div className="preset-form__measure">
          <label className="field"><span className="field__label">Age (optional)</span><input type="number" min="18" max="100" value={data.profile?.age ?? ''} placeholder="28" onChange={(event) => data.profile && onUpdateProfile({ ...data.profile, age: event.target.value ? Number(event.target.value) : undefined })} /></label>
          <label className="field"><span className="field__label">Height cm (optional)</span><input type="number" min="120" max="230" value={data.profile?.heightCm ?? ''} placeholder="175" onChange={(event) => data.profile && onUpdateProfile({ ...data.profile, heightCm: event.target.value ? Number(event.target.value) : undefined })} /></label>
        </div>
        <label className="field" htmlFor="profile-drinker-level"><span className="field__label">Pub experience</span><select id="profile-drinker-level" value={data.profile?.drinkerLevel ?? 'weekend'} onChange={(event) => data.profile && onUpdateProfile({ ...data.profile, drinkerLevel: event.target.value as DrinkerLevel })}>{DRINKER_LEVELS.map((level) => <option key={level.id} value={level.id}>{level.label}</option>)}</select></label>
        <div className="settings-row"><span><strong>Haptic taps</strong><small>Feel each drink land</small></span><input aria-label="Haptic taps" type="checkbox" role="switch" checked={data.preferences.haptics} onChange={(event) => onUpdatePreferences({ haptics: event.target.checked })} /></div>
        <div className="settings-row"><span><strong>Reduce motion</strong><small>Quieter countdowns and reactions</small></span><input aria-label="Reduce motion" type="checkbox" role="switch" checked={data.preferences.reducedMotion} onChange={(event) => onUpdatePreferences({ reducedMotion: event.target.checked })} /></div>
        <div className="settings-row"><span><strong>Big-thumb mode</strong><small>Larger drink and game controls</small></span><input aria-label="Big-thumb mode" type="checkbox" role="switch" checked={data.preferences.bigThumbMode} onChange={(event) => onUpdatePreferences({ bigThumbMode: event.target.checked })} /></div>
      </section>

      <SettingsDisclosure title="Night preferences" open>
        <label className="field"><span className="field__label">Coach voice</span><select value={data.preferences.coachPersonality} onChange={(event) => onUpdatePreferences({ coachPersonality: event.target.value as CoachPersonality })}><option value="friend">Supportive friend</option><option value="elder">Wise pub elder</option><option value="gremlin">Chaotic gremlin</option></select></label>
        <label className="field"><span className="field__label">Night accent</span><select value={data.preferences.themedNight} onChange={(event) => onUpdatePreferences({ themedNight: event.target.value as ThemedNight })}><option value="classic">Bottle green</option><option value="halloween">Halloween</option><option value="new-year">New Year</option><option value="birthday">Birthday</option><option value="st-patrick">St Patrick’s</option></select></label>
        <label className="field"><span className="field__label">Default game spice · {data.preferences.spiciness}/5</span><input type="range" min="1" max="5" step="1" value={data.preferences.spiciness} onChange={(event) => onUpdatePreferences({ spiciness: Number(event.target.value) as 1 | 2 | 3 | 4 | 5 })} /></label>
      </SettingsDisclosure>

      <SettingsDisclosure title="Ride home">
        <label className="field"><span className="field__label">Ride provider URL</span><input type="url" inputMode="url" value={data.preferences.rideHomeUrl} placeholder="https://m.uber.com/ul/" onChange={(event) => onUpdatePreferences({ rideHomeUrl: event.target.value.slice(0, 500) })} /></label>
        <label className="field"><span className="field__label">Home address</span><textarea rows={2} value={data.preferences.homeAddress} placeholder="Used only to build the ride link on this device" onChange={(event) => onUpdatePreferences({ homeAddress: event.target.value.slice(0, 240) })} /></label>
        <p>Your address stays in this device’s Beerify storage and is only handed to your ride provider when you tap the link.</p>
      </SettingsDisclosure>

      <SettingsDisclosure title="Room alerts" badge={<span className={push.status === 'granted' ? 'status-badge status-badge--on' : 'status-badge'}>{push.status === 'granted' ? 'Enabled' : push.status === 'unsupported' ? 'iOS only' : 'Off'}</span>}>
        {push.status === 'unsupported' ? <p>Push alerts are available in the installed iOS app. Live room countdowns still appear while this app is open.</p>
          : push.status === 'denied' ? <p>Notifications are blocked. Open iOS Settings → Beerify → Notifications to enable Drink up and round alerts.</p>
          : push.status === 'granted' ? <p>{push.error || 'Drink up countdowns and important round updates can reach you while Beerify is in the background.'}</p>
          : <p>{push.error || 'Beerify is checking whether room alerts are available.'}</p>}
        {(push.status === 'prompt' || push.status === 'error' || Boolean(push.error)) && <button className="btn btn--secondary" onClick={() => void retryPushNotifications()}>{push.status === 'granted' ? 'Retry room alerts' : 'Enable room alerts'}</button>}
      </SettingsDisclosure>

      <SettingsDisclosure title="Your drinks">
        <button className="text-action" onClick={() => setShowPreset((value) => !value)}>{showPreset ? 'Close preset form' : 'Add a drink preset'}</button>
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
      </SettingsDisclosure>

      <SettingsDisclosure title="Account sync" className="account-panel" badge={<span className={session ? 'status-badge status-badge--on' : 'status-badge'}>{session ? 'Synced' : 'Guest'}</span>}>
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
      </SettingsDisclosure>

      <SettingsDisclosure title="Data, help & legal">
        <button className="settings-action" onClick={exportData}>Export Beerify data <AppIcon name="share" size={20} /></button>
        <a className="settings-action" href="/support.html" target="_blank">Support <AppIcon name="external" size={20} /></a>
        <a className="settings-action" href="/privacy.html" target="_blank">Privacy & safety <AppIcon name="external" size={20} /></a>
        <p>Beerify estimates are not medical advice and never determine whether you can drive. If in doubt, do not drive.</p>
      </SettingsDisclosure>

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
