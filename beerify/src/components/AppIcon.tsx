export type IconName =
  | 'moon' | 'beer' | 'gamepad' | 'map' | 'receipt' | 'users' | 'user'
  | 'arrow-left' | 'close' | 'chevron-down' | 'location' | 'share'
  | 'chart' | 'history' | 'check' | 'plus' | 'minus' | 'arrow-up'
  | 'arrow-down' | 'trash' | 'external' | 'water' | 'repeat' | 'undo'
  | 'edit' | 'trophy' | 'settings' | 'qr'
  | 'star' | 'chevron-right'

interface Props {
  name: IconName
  size?: number
  className?: string
}

const paths: Record<IconName, ReactNode> = {
  moon: <path d="M20.5 14.2A8.2 8.2 0 0 1 9.8 3.5 8.7 8.7 0 1 0 20.5 14.2Z" />,
  beer: <><path d="M5 7h10v12H7a2 2 0 0 1-2-2V7Z" /><path d="M15 10h2.5a2.5 2.5 0 0 1 0 5H15M7 4.5c.5 1 1.5 1 2 0s1.5-1 2 0 1.5 1 2 0" /></>,
  gamepad: <><path d="M7.5 8h9a4.5 4.5 0 0 1 4.2 6.1l-1.1 3a2 2 0 0 1-3.2.8L14.5 16h-5l-1.9 1.9a2 2 0 0 1-3.2-.8l-1.1-3A4.5 4.5 0 0 1 7.5 8Z" /><path d="M7 11v4M5 13h4M16.5 12h.01M18.5 14h.01" /></>,
  map: <><path d="m3.5 6 5-2 7 2 5-2v14l-5 2-7-2-5 2V6Z" /><path d="M8.5 4v14M15.5 6v14" /></>,
  receipt: <><path d="M6 3h12v18l-3-2-3 2-3-2-3 2V3Z" /><path d="M9 8h6M9 12h6M9 16h3" /></>,
  users: <><path d="M16 20v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 18.5V20" /><circle cx="10" cy="8" r="3" /><path d="M16 5.3a3 3 0 0 1 0 5.4M18 15a3.5 3.5 0 0 1 2 3.2V20" /></>,
  user: <><circle cx="12" cy="8" r="4" /><path d="M4.5 21a7.5 7.5 0 0 1 15 0" /></>,
  'arrow-left': <><path d="m15 18-6-6 6-6" /><path d="M9 12h11" /></>,
  close: <><path d="m6 6 12 12M18 6 6 18" /></>,
  'chevron-down': <path d="m7 10 5 5 5-5" />,
  location: <><circle cx="12" cy="12" r="3" /><circle cx="12" cy="12" r="7" /><path d="M12 2v3M12 19v3M2 12h3M19 12h3" /></>,
  share: <><circle cx="18" cy="5" r="2" /><circle cx="6" cy="12" r="2" /><circle cx="18" cy="19" r="2" /><path d="m8 11 8-5M8 13l8 5" /></>,
  chart: <><path d="M4 20V10M10 20V4M16 20v-7M22 20H2" /></>,
  history: <><path d="M3 12a9 9 0 1 0 3-6.7L3 8" /><path d="M3 3v5h5M12 7v5l3 2" /></>,
  check: <path d="m5 12 4 4L19 6" />,
  plus: <path d="M12 5v14M5 12h14" />,
  minus: <path d="M5 12h14" />,
  'arrow-up': <><path d="m7 10 5-5 5 5M12 5v14" /></>,
  'arrow-down': <><path d="m7 14 5 5 5-5M12 5v14" /></>,
  trash: <><path d="M4 7h16M9 3h6l1 4H8l1-4ZM7 7l1 14h8l1-14M10 11v6M14 11v6" /></>,
  external: <><path d="M14 5h5v5M19 5l-8 8" /><path d="M18 13v6H5V6h6" /></>,
  water: <path d="M12 3s6 6.4 6 11a6 6 0 0 1-12 0c0-4.6 6-11 6-11Z" />,
  repeat: <><path d="M17 2l3 3-3 3" /><path d="M20 5H9a6 6 0 0 0-6 6v1M7 22l-3-3 3-3" /><path d="M4 19h11a6 6 0 0 0 6-6v-1" /></>,
  undo: <><path d="m9 7-5 5 5 5" /><path d="M4 12h10a6 6 0 0 1 6 6" /></>,
  edit: <><path d="m14 5 5 5M4 20l3.5-.7L19 7.8a2.1 2.1 0 0 0-3-3L4.7 16.2 4 20Z" /></>,
  trophy: <><path d="M8 4h8v4a4 4 0 0 1-8 0V4ZM10 12v4M14 12v4M8 20h8M10 16h4" /><path d="M8 6H4v1a4 4 0 0 0 4 4M16 6h4v1a4 4 0 0 1-4 4" /></>,
  settings: <><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.6v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z" /></>,
  qr: <><path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM15 14h2M20 14v3M14 18h3v2M20 20h.01" /></>,
  star: <path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9L12 3Z" />,
  'chevron-right': <path d="m10 7 5 5-5 5" />,
}

export default function AppIcon({ name, size = 24, className }: Props) {
  return <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name]}</svg>
}
import type { ReactNode } from 'react'
