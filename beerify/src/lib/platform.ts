import { Capacitor } from '@capacitor/core'

const configuredApiOrigin = (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(/\/$/, '')
const configuredAppOrigin = (import.meta.env.VITE_PUBLIC_APP_URL as string | undefined)?.replace(/\/$/, '')
const nativeOrigin = configuredApiOrigin || 'https://beerify-lime.vercel.app'

export const isNative = Capacitor.isNativePlatform()

export function apiUrl(path: string): string {
  return `${isNative ? nativeOrigin : configuredApiOrigin ?? ''}${path}`
}

export function publicAppOrigin(): string {
  return configuredAppOrigin || (isNative ? nativeOrigin : location.origin)
}
