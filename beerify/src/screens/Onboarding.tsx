import { useState } from 'react'
import type { Profile, Sex, Tolerance } from '../types'

interface Props {
  onDone: (profile: Profile) => void
}

const SEX_OPTIONS: { id: Sex; label: string }[] = [
  { id: 'female', label: 'Female' },
  { id: 'male', label: 'Male' },
  { id: 'other', label: 'Prefer not to say' },
]

const TOLERANCE_OPTIONS: { id: Tolerance; label: string; note: string }[] = [
  { id: 'rare', label: 'Rarely', note: 'A few times a year' },
  { id: 'monthly', label: 'Sometimes', note: 'Once or twice a month' },
  { id: 'weekly', label: 'Most weeks', note: 'One night a week' },
  { id: 'frequent', label: 'Often', note: 'Several nights a week' },
]

export default function Onboarding({ onDone }: Props) {
  const [step, setStep] = useState(0)
  const [name, setName] = useState('')
  const [weight, setWeight] = useState('')
  const [sex, setSex] = useState<Sex | null>(null)
  const [tolerance, setTolerance] = useState<Tolerance | null>(null)

  const weightKg = Number(weight)
  const weightValid = Number.isFinite(weightKg) && weightKg >= 35 && weightKg <= 250

  if (step === 0) {
    return (
      <div className="screen onboarding">
        <div className="onboarding__hero">
          <span className="onboarding__logo">🍺</span>
          <h1>Beerify</h1>
          <p className="lead">
            Your friendly AI drinking buddy. Pick your vibe, tap your drinks, and
            Beerify keeps you right where you want to be, and no further.
          </p>
        </div>
        <ul className="onboarding__points">
          <li>🎯 Choose how merry you want to get</li>
          <li>👆 Log drinks with one giant tap</li>
          <li>🧠 Live coaching to hold your sweet spot</li>
          <li>👯 Rooms to keep an eye on your friends</li>
          <li>☀️ A morning-after summary of your units</li>
        </ul>
        <button className="btn btn--primary" onClick={() => setStep(1)}>
          Let's set you up
        </button>
        <p className="fine-print">
          Estimates only, never a legal or medical measure. Never drink and drive.
        </p>
      </div>
    )
  }

  return (
    <div className="screen onboarding">
      <h2>About you</h2>
      <p className="lead">
        Alcohol hits everyone differently. Three quick facts make the estimates
        actually useful. It all stays on your phone.
      </p>

      <label className="field">
        <span className="field__label">What should we call you?</span>
        <input
          type="text"
          value={name}
          placeholder="Your name"
          autoComplete="given-name"
          maxLength={30}
          onChange={(e) => setName(e.target.value)}
        />
      </label>

      <label className="field">
        <span className="field__label">Your weight (kg)</span>
        <input
          type="number"
          inputMode="decimal"
          value={weight}
          placeholder="e.g. 72"
          min={35}
          max={250}
          onChange={(e) => setWeight(e.target.value)}
        />
        {weight !== '' && !weightValid && (
          <span className="field__error">Enter a weight between 35 and 250 kg</span>
        )}
      </label>

      <div className="field">
        <span className="field__label">Body type for the estimate</span>
        <div className="choice-row">
          {SEX_OPTIONS.map((opt) => (
            <button
              key={opt.id}
              className={`chip ${sex === opt.id ? 'chip--active' : ''}`}
              onClick={() => setSex(opt.id)}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>

      <div className="field">
        <span className="field__label">How often do you drink?</span>
        <span className="field__hint">
          Regular drinkers process alcohol faster. This tunes your curve.
        </span>
        <div className="choice-grid">
          {TOLERANCE_OPTIONS.map((opt) => (
            <button
              key={opt.id}
              className={`chip chip--stacked ${tolerance === opt.id ? 'chip--active' : ''}`}
              onClick={() => setTolerance(opt.id)}
            >
              <strong>{opt.label}</strong>
              <small>{opt.note}</small>
            </button>
          ))}
        </div>
      </div>

      <button
        className="btn btn--primary"
        disabled={!name.trim() || !weightValid || sex === null || tolerance === null}
        onClick={() =>
          onDone({
            name: name.trim(),
            weightKg,
            sex: sex!,
            tolerance: tolerance!,
            createdAt: Date.now(),
          })
        }
      >
        Done, take me in 🍻
      </button>
    </div>
  )
}
