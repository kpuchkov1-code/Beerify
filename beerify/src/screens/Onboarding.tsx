import { useState } from 'react'
import { DRINKER_LEVELS, type DrinkerLevel, type Profile, type Sex } from '../types'

interface Props { onDone: (profile: Profile) => void }

const SEX_OPTIONS: { id: Sex; label: string }[] = [
  { id: 'female', label: 'Female' },
  { id: 'male', label: 'Male' },
  { id: 'other', label: 'Prefer not to say' },
]

export default function Onboarding({ onDone }: Props) {
  const [step, setStep] = useState(0)
  const [name, setName] = useState('')
  const [weight, setWeight] = useState('')
  const [sex, setSex] = useState<Sex | null>(null)
  const [drinkerLevel, setDrinkerLevel] = useState<DrinkerLevel | null>(null)
  const weightKg = Number(weight)
  const weightValid = Number.isFinite(weightKg) && weightKg >= 35 && weightKg <= 250

  if (step === 0) {
    return (
      <main className="screen onboarding onboarding--welcome">
        <div className="brand-lockup">
          <span className="brand-lockup__mark" aria-hidden="true">B</span>
          <span>BEERIFY</span>
        </div>
        <div className="onboarding__hero">
          <p className="display-copy">The night out group chat, but useful.</p>
          <p className="lead">Open a room, log the order, sort the next round and find out how battered everyone is.</p>
        </div>
        <div className="onboarding__ticker" aria-label="Beerify features">
          <span>LIVE ROOMS</span><span>ROUND ROTA</span><span>DRINK MOMENTS</span><span>NIGHT RECAPS</span>
        </div>
        <button className="btn btn--primary btn--big" onClick={() => setStep(1)}>Set up my night</button>
        <p className="fine-print">Estimates are for the story, not a breathalyser.</p>
      </main>
    )
  }

  if (step === 2) {
    return (
      <main className="screen onboarding onboarding--persona">
        <header className="page-header">
          <button className="icon-btn" aria-label="Back" onClick={() => setStep(1)}>←</button>
          <div><span className="page-kicker">2 OF 2</span><h1>Be honest-ish</h1><p>What kind of shift are you usually working?</p></div>
        </header>
        <fieldset className="field fieldset-reset">
          <legend className="field__label">Your pub experience</legend>
          <div className="drinker-grid">
            {DRINKER_LEVELS.map((option) => (
              <button
                key={option.id}
                className={drinkerLevel === option.id ? 'drinker-card drinker-card--active' : 'drinker-card'}
                aria-pressed={drinkerLevel === option.id}
                onClick={() => setDrinkerLevel(option.id)}
              >
                <strong>{option.label}</strong><span>{option.detail}</span>
              </button>
            ))}
          </div>
        </fieldset>
        <p className="persona-note">This changes the banter and shortcuts, not the BAC maths.</p>
        <button
          className="btn btn--primary btn--big"
          disabled={!drinkerLevel}
          onClick={() => {
            const now = Date.now()
            onDone({ name: name.trim(), weightKg, sex: sex!, drinkerLevel: drinkerLevel!, createdAt: now, updatedAt: now })
          }}
        >Enter Beerify</button>
      </main>
    )
  }

  const nameError = name.length > 0 && !name.trim()
  return (
    <main className="screen onboarding">
      <header className="page-header">
        <button className="icon-btn" aria-label="Back" onClick={() => setStep(0)}>←</button>
        <div><span className="page-kicker">1 OF 2</span><h1>Your pub profile</h1><p>The useful bits first. Your dignity comes next.</p></div>
      </header>

      <label className="field" htmlFor="profile-name">
        <span className="field__label">What do your mates call you?</span>
        <input id="profile-name" value={name} maxLength={30} autoComplete="given-name" placeholder="Name or nickname" aria-invalid={nameError} onChange={(event) => setName(event.target.value)} />
      </label>

      <label className="field" htmlFor="profile-weight">
        <span className="field__label">Weight in kilograms</span>
        <input id="profile-weight" type="number" inputMode="decimal" min={35} max={250} value={weight} placeholder="72" aria-invalid={weight !== '' && !weightValid} aria-describedby="weight-hint" onChange={(event) => setWeight(event.target.value)} />
        <span id="weight-hint" className={weight !== '' && !weightValid ? 'field__error' : 'field__hint'}>Use a number from 35 to 250.</span>
      </label>

      <fieldset className="field fieldset-reset">
        <legend className="field__label">Body type used by the estimate</legend>
        <div className="choice-row">
          {SEX_OPTIONS.map((option) => (
            <button key={option.id} className={sex === option.id ? 'chip chip--active' : 'chip'} aria-pressed={sex === option.id} onClick={() => setSex(option.id)}>{option.label}</button>
          ))}
        </div>
      </fieldset>

      <button className="btn btn--primary btn--big" disabled={!name.trim() || !weightValid || !sex} onClick={() => setStep(2)}>Next: pub credentials</button>
    </main>
  )
}
