import { useState } from 'react'
import type { Profile, Sex } from '../types'

interface Props {
  onDone: (profile: Profile) => void
}

const SEX_OPTIONS: { id: Sex; label: string; note: string }[] = [
  { id: 'female', label: 'Female', note: '' },
  { id: 'male', label: 'Male', note: '' },
  { id: 'other', label: 'Prefer not to say', note: 'We’ll use an average' },
]

export default function Onboarding({ onDone }: Props) {
  const [step, setStep] = useState(0)
  const [name, setName] = useState('')
  const [weight, setWeight] = useState('')
  const [sex, setSex] = useState<Sex | null>(null)

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
            Beerify keeps you right where you want to be — no further.
          </p>
        </div>
        <ul className="onboarding__points">
          <li>🎯 Choose how merry you want to get</li>
          <li>👆 Log drinks with one giant tap</li>
          <li>🧠 Live coaching to hold your sweet spot</li>
          <li>☀️ A morning-after summary of your units</li>
        </ul>
        <button className="btn btn--primary" onClick={() => setStep(1)}>
          Let's set you up
        </button>
        <p className="fine-print">
          Estimates only — never a legal or medical measure. Never drink and drive.
        </p>
      </div>
    )
  }

  return (
    <div className="screen onboarding">
      <h2>About you</h2>
      <p className="lead">
        Alcohol hits everyone differently. Two quick facts make the estimates
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

      <button
        className="btn btn--primary"
        disabled={!name.trim() || !weightValid || sex === null}
        onClick={() =>
          onDone({ name: name.trim(), weightKg, sex: sex!, createdAt: Date.now() })
        }
      >
        Done — take me in 🍻
      </button>
    </div>
  )
}
