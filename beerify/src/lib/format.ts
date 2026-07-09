export function formatTime(epoch: number): string {
  return new Date(epoch).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}

export function formatNightDate(epoch: number): string {
  return new Date(epoch).toLocaleDateString([], {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
  })
}

export function formatUnits(units: number): string {
  const rounded = Math.round(units * 10) / 10
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1)
}
