import type { NightSession } from '../types'
import { TARGETS } from '../lib/drinks'
import { formatNightDate, formatUnits } from '../lib/format'

interface Props { history: NightSession[]; onOpenSummary: (session: NightSession) => void }

export default function History({ history, onOpenSummary }: Props) {
  const nights = [...history].sort((a, b) => b.startedAt - a.startedAt)
  return (
    <main className="screen history-screen">
      <header className="page-header page-header--stacked"><span className="page-kicker">THE ARCHIVES</span><h1>Receipts from previous chaos</h1></header>
      {nights.length === 0 ? (
        <div className="empty-state"><span aria-hidden="true">▤</span><h2>No receipts yet</h2><p>Finish a night and its full tab lands here.</p></div>
      ) : (
        <ol className="receipt-list">
          {nights.map((session, index) => {
            const units = session.drinks.reduce((sum, drink) => sum + drink.units, 0)
            return (
              <li key={session.id}>
                <button onClick={() => onOpenSummary(session)}>
                  <span className="receipt-list__number">{String(nights.length - index).padStart(2, '0')}</span>
                  <span><strong>{formatNightDate(session.startedAt)}</strong><small>{TARGETS[session.targetId].label} · {session.drinks.length} drinks</small></span>
                  <span>{formatUnits(units)}u</span>
                </button>
              </li>
            )
          })}
        </ol>
      )}
    </main>
  )
}
