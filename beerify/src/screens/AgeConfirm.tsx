import type { Profile } from '../types'

interface Props { profile: Profile; onConfirm: (profile: Profile) => void }

export default function AgeConfirm({ profile, onConfirm }: Props) {
  return (
    <main className="screen onboarding onboarding--welcome age-confirm-screen">
      <div className="brand-lockup"><span className="brand-lockup__mark" aria-hidden="true">B</span><span>BEERIFY</span></div>
      <div className="onboarding__hero">
        <p className="display-copy">One grown-up bit.</p>
        <p className="lead">Beerify is made for adults. Confirm your age to keep your existing profile and nights.</p>
      </div>
      <button className="btn btn--primary btn--big" onClick={() => onConfirm({ ...profile, legalAgeConfirmedAt: Date.now(), updatedAt: Date.now() })}>I am at least 18 and of legal drinking age</button>
      <p className="fine-print">No date of birth is collected. BAC figures are rough estimates, never a medical or legal measurement.</p>
    </main>
  )
}
