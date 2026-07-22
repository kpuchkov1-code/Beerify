import { useState } from 'react'
import { DRINKER_LEVELS, type DrinkerLevel, type Profile, type Sex } from '../types'
import { newId } from '../lib/storage'
import AppIcon from '../components/AppIcon'

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
  const [age, setAge] = useState('')
  const [height, setHeight] = useState('')
  const [legalAge, setLegalAge] = useState(false)
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
          <p className="display-copy">Make a good night easier.</p>
          <p className="lead">Track drinks, plan the crawl and keep the whole squad on the same page.</p>
        </div>
        <div className="onboarding-features" aria-label="Beerify features">
          <div><span><AppIcon name="beer" /></span><p><strong>Track as you go</strong><small>Log favourites with one tap and keep an eye on your estimate.</small></p></div>
          <div><span><AppIcon name="users" /></span><p><strong>Bring the squad</strong><small>Share games, reactions and a single crawl across your phones.</small></p></div>
          <div><span><AppIcon name="receipt" /></span><p><strong>Keep the recap</strong><small>Every drink, record and award lands in Your nights.</small></p></div>
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
          <button className="icon-btn" aria-label="Back" onClick={() => setStep(1)}><AppIcon name="arrow-left" /></button>
          <div><span className="page-kicker">2 OF 2</span><h1>Your usual pace</h1><p>This helps Beerify tune the shortcuts and coaching.</p></div>
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
                <span><strong>{option.label}</strong><small>{option.detail}</small></span><AppIcon name="check" size={20} />
              </button>
            ))}
          </div>
        </fieldset>
        <p className="persona-note">This changes the shortcuts and coaching, not the BAC maths.</p>
        <label className="legal-age-confirm">
          <input type="checkbox" checked={legalAge} onChange={(event) => setLegalAge(event.target.checked)} />
          <span><strong>I am at least 18</strong><small>I confirm I am also of legal drinking age where I live.</small></span>
        </label>
        <button
          className="btn btn--primary btn--big"
          disabled={!drinkerLevel || !legalAge}
          onClick={() => {
            const now = Date.now()
            onDone({ id: newId(), name: name.trim(), weightKg, sex: sex!, drinkerLevel: drinkerLevel!, age: age ? Number(age) : undefined, heightCm: height ? Number(height) : undefined, legalAgeConfirmedAt: now, avatarEmoji: '🙂', createdAt: now, updatedAt: now })
          }}
        >Enter Beerify</button>
      </main>
    )
  }

  const nameError = name.length > 0 && !name.trim()
  return (
    <main className="screen onboarding">
      <header className="page-header">
        <button className="icon-btn" aria-label="Back" onClick={() => setStep(0)}><AppIcon name="arrow-left" /></button>
        <div><span className="page-kicker">1 OF 2</span><h1>Your profile</h1><p>A few details make the estimate more useful.</p></div>
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

      <details className="accuracy-details">
        <summary>Improve estimate accuracy <span>Optional</span></summary>
        <p>Age and height let Beerify estimate total body water instead of using a broad average.</p>
        <div>
          <label className="field"><span className="field__label">Age</span><input type="number" inputMode="numeric" min="18" max="100" value={age} placeholder="28" onChange={(event) => setAge(event.target.value)} /></label>
          <label className="field"><span className="field__label">Height in cm</span><input type="number" inputMode="decimal" min="120" max="230" value={height} placeholder="175" onChange={(event) => setHeight(event.target.value)} /></label>
        </div>
      </details>

      <button className="btn btn--primary btn--big" disabled={!name.trim() || !weightValid || !sex || (age !== '' && (Number(age) < 18 || Number(age) > 100)) || (height !== '' && (Number(height) < 120 || Number(height) > 230))} onClick={() => setStep(2)}>Continue</button>
    </main>
  )
}
