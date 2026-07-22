import { useMemo, useState } from 'react'
import type { NightSession, Profile, RoomEvent } from '../types'
import { bacTimeline, estimateBacRange, formatBac, fullyAbsorbedAt, minutesUntilBac } from '../lib/bac'
import { TARGETS } from '../lib/drinks'
import { morningVerdict } from '../lib/coach'
import { formatNightDate, formatTime, formatUnits } from '../lib/format'
import { trackMetric } from '../lib/room'
import DrinkIcon from '../components/DrinkIcon'
import AppIcon from '../components/AppIcon'

interface Props { session: NightSession; history: NightSession[]; profile: Profile; onClose: () => void }

function topActor(events: RoomEvent[], type: RoomEvent['type']): string | null {
  const counts = new Map<string, { name: string; count: number }>()
  for (const event of events.filter((item) => item.type === type)) {
    const current = counts.get(event.actorId) ?? { name: event.actorName, count: 0 }
    current.count += 1
    counts.set(event.actorId, current)
  }
  return [...counts.values()].sort((a, b) => b.count - a.count)[0]?.name ?? null
}

function awards(session: NightSession): { title: string; name: string; icon: string }[] {
  const events = session.roomEvents ?? []
  const result: { title: string; name: string; icon: string }[] = []
  const roundBoss = topActor(events, 'round-bought')
  const hype = topActor(events, 'reaction')
  if (roundBoss) result.push({ title: 'ROUND BOSS', name: roundBoss, icon: '💳' })
  if (hype) result.push({ title: 'HYPE MERCHANT', name: hype, icon: '📣' })
  const firstByActor = new Map<string, { name: string; at: number }>()
  for (const event of events) if (!firstByActor.has(event.actorId)) firstByActor.set(event.actorId, { name: event.actorName, at: event.at })
  const late = [...firstByActor.values()].sort((a, b) => b.at - a.at)[0]
  if (late && firstByActor.size > 1) result.push({ title: 'LATE ARRIVAL', name: late.name, icon: '⌛' })
  const distinct = new Set(session.drinks.map((drink) => drink.presetId)).size
  if (distinct >= 3) result.push({ title: 'MENU EXPLORER', name: `${distinct} different orders`, icon: '🗺️' })
  return result.slice(0, 4)
}

function drawHybridShare(context: CanvasRenderingContext2D, session: NightSession, targetLabel: string, verdict: string, drinks: { name: string; count: number; units: number }[], totalUnits: number, peak: number) {
  context.fillStyle = '#10241c'; context.fillRect(0, 0, 1080, 1350)
  context.fillStyle = '#ffb52d'; context.fillRect(72, 64, 104, 104)
  context.fillStyle = '#10241c'; context.font = '900 64px Archivo, sans-serif'; context.fillText('B', 98, 140)
  context.fillStyle = '#f7f7f1'; context.font = '800 40px Archivo, sans-serif'; context.fillText('BEERIFY NIGHT TAB', 208, 130)
  context.fillStyle = '#f7f7f1'; context.fillRect(58, 214, 964, 1060)
  context.fillStyle = '#173328'; context.font = '900 82px Archivo, sans-serif'; context.fillText(targetLabel.toUpperCase(), 96, 334)
  context.fillStyle = '#36594b'; context.font = '700 42px Archivo, sans-serif'; context.fillText(formatNightDate(session.startedAt), 96, 402)
  context.strokeStyle = '#173328'; context.lineWidth = 3; context.beginPath(); context.moveTo(96, 452); context.lineTo(984, 452); context.stroke()
  context.fillStyle = '#173328'; context.font = '800 47px Archivo, sans-serif'
  ;[`${session.drinks.length} DRINKS`, `${formatUnits(totalUnits)} UNITS`, `${formatBac(peak)} PEAK`].forEach((metric, index) => context.fillText(metric, 96, 545 + index * 70))
  context.fillStyle = '#36594b'; context.font = '600 32px Archivo, sans-serif'; context.fillText(session.roomName ? `SQUAD: ${session.roomName}` : verdict, 96, 785)
  context.fillStyle = '#173328'; context.font = '700 37px Archivo, sans-serif'
  drinks.slice(0, 5).forEach((drink, index) => context.fillText(`${drink.count}× ${drink.name}  ·  ${formatUnits(drink.units)}u`, 96, 880 + index * 60))
  context.fillStyle = '#ffb52d'; context.font = '800 29px Archivo, sans-serif'; context.fillText('BEERIFY · YOUR NIGHT, KEPT TOGETHER', 72, 1322)
}

export default function Summary({ session, history, profile, onClose }: Props) {
  const [shareStatus, setShareStatus] = useState('')
  const end = session.endedAt ?? Date.now()
  const stats = useMemo(() => {
    const analysisEnd = Math.max(end, fullyAbsorbedAt(session.drinks, end, session.mealState))
    const timeline = bacTimeline(session.drinks, profile, session.startedAt, analysisEnd, 1, session.mealState)
    const peakPoint = timeline.reduce((peak, point) => point.bac > peak.bac ? point : peak, { at: session.startedAt, bac: 0 })
    const soberInMin = minutesUntilBac(session.drinks, profile, end, 0.005, session.mealState)
    const peakRange = estimateBacRange(session.drinks, profile, peakPoint.at, session.mealState)
    const byDrink = new Map<string, { name: string; icon: typeof session.drinks[number]['icon']; logoUrl?: string; brand?: string; count: number; units: number }>()
    for (const drink of session.drinks) {
      const key = drink.brand || drink.name
      const item = byDrink.get(key) ?? { name: key, icon: drink.icon, logoUrl: drink.logoUrl, brand: drink.brand, count: 0, units: 0 }
      item.count += 1; item.units += drink.units; byDrink.set(key, item)
    }
    return {
      totalUnits: session.drinks.reduce((sum, drink) => sum + drink.units, 0),
      peak: peakPoint.bac,
      peakRange,
      peakAt: peakPoint.at,
      soberAt: end + soberInMin * 60_000,
      soberInMin,
      byDrink: [...byDrink.values()],
    }
  }, [session, profile, end])
  const verdict = morningVerdict(session, profile)
  const target = session.targetSnapshot ?? TARGETS[session.targetId]
  const nightAwards = awards(session)
  const sevenDaysAgo = end - 7 * 24 * 60 * 60_000
  const recentSessions = new Map([...history, session].map((item) => [item.id, item]))
  const weeklyUnits = [...recentSessions.values()].filter((item) => item.startedAt >= sevenDaysAgo && item.startedAt <= end)
    .flatMap((item) => item.drinks).reduce((sum, drink) => sum + drink.units, 0)

  async function shareRecap() {
    const canvas = document.createElement('canvas')
    canvas.width = 1080; canvas.height = 1350
    const context = canvas.getContext('2d')!
    drawHybridShare(context, session, target.label, verdict.headline, stats.byDrink, stats.totalUnits, stats.peak)
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/png'))
    if (!blob) return
    const file = new File([blob], 'beerify-night.png', { type: 'image/png' })
    try {
      if (navigator.canShare?.({ files: [file] })) await navigator.share({ files: [file], title: 'My Beerify night' })
      else if (navigator.clipboard?.write) { await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]); setShareStatus('Recap copied as an image.') }
      else throw new Error('download')
    } catch {
      const url = URL.createObjectURL(blob); const anchor = document.createElement('a'); anchor.href = url; anchor.download = file.name; anchor.click(); URL.revokeObjectURL(url); setShareStatus('Recap image saved.')
    }
    trackMetric('recap_shared')
  }

  return (
    <main className="screen summary">
      <header className="summary__masthead"><div className="brand-lockup brand-lockup--small"><span className="brand-lockup__mark">B</span><span>NIGHT TAB</span></div><span>{formatNightDate(session.startedAt)}</span></header>
      <div className="summary__sheet">
        <section className="summary__headline"><span>{target.emoji}</span><h1>{verdict.headline}</h1><p>{verdict.body}</p></section>
        <dl className="summary-metrics"><div><dt>Drinks</dt><dd>{session.drinks.length}</dd></div><div><dt>Units</dt><dd>{formatUnits(stats.totalUnits)}</dd></div><div><dt>Likely peak</dt><dd>{formatBac(stats.peak)}</dd><small>{formatBac(stats.peakRange.low)}–{formatBac(stats.peakRange.high)} plausible · {formatTime(stats.peakAt)}</small></div><div><dt>Water</dt><dd>{session.waters.length}</dd></div></dl>

        <section className="receipt-block"><div className="section-heading"><h2>The order</h2><span>{formatUnits(stats.totalUnits)}u</span></div><ol>{stats.byDrink.map((drink) => <li key={drink.name}><DrinkIcon icon={drink.icon} size={32} logoUrl={drink.logoUrl} brand={drink.brand} /><span><strong>{drink.count}× {drink.name}</strong><small>{formatUnits(drink.units)} units</small></span></li>)}</ol></section>

        {nightAwards.length > 0 && <section className="awards"><div className="section-heading"><h2>Pub awards</h2></div><div>{nightAwards.map((award) => <article key={award.title}><span>{award.icon}</span><small>{award.title}</small><strong>{award.name}</strong></article>)}</div></section>}

        <section className="summary-notes">
          <p><strong>{formatUnits(weeklyUnits)} units</strong><span>logged across the last 7 days</span></p>
          {session.drinks.length > 0 && <p><strong>{formatTime(stats.soberAt)}</strong><span>estimated below .005% BAC</span></p>}
        </section>
      </div>

      <div className="summary-actions"><button className="btn btn--primary btn--big" onClick={shareRecap}><AppIcon name="share" size={20} />Share recap</button><button className="btn btn--quiet" onClick={onClose}>Back to Beerify</button></div>
      {shareStatus && <p role="status" className="status-message">{shareStatus}</p>}
    </main>
  )
}
