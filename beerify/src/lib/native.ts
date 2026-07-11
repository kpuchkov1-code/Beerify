import { App as NativeApp } from '@capacitor/app'
import { Haptics, ImpactStyle } from '@capacitor/haptics'
import { Share } from '@capacitor/share'
import { StatusBar, Style } from '@capacitor/status-bar'
import { isNative } from './platform'
import { initPushNotifications } from './notifications'

export async function initNative(): Promise<void> {
  if (!isNative) return
  await StatusBar.setStyle({ style: Style.Light }).catch(() => {})
  await StatusBar.setOverlaysWebView({ overlay: true }).catch(() => {})
  await NativeApp.addListener('appUrlOpen', async ({ url }) => {
    try {
      const opened = new URL(url)
      if (opened.host === 'auth') {
        const tokens = new URLSearchParams(opened.hash.slice(1) || opened.search)
        const accessToken = tokens.get('access_token')
        const refreshToken = tokens.get('refresh_token')
        if (accessToken && refreshToken) {
          const { supabase } = await import('./account')
          await supabase()?.auth.setSession({ access_token: accessToken, refresh_token: refreshToken })
        }
        location.assign('/')
        return
      }
      const room = opened.searchParams.get('room')?.toUpperCase()
      if (/^[A-Z2-9]{6}$/.test(room ?? '')) location.assign(`/?room=${room}&via=invite`)
    } catch { /* Ignore malformed external links. */ }
  })
  await NativeApp.addListener('appStateChange', ({ isActive }) => {
    if (isActive) window.dispatchEvent(new Event('beerify:resume'))
  })
  await initPushNotifications()
}

export function nativeTap(strength: 'light' | 'medium' = 'light'): void {
  if (!isNative) return
  Haptics.impact({ style: strength === 'medium' ? ImpactStyle.Medium : ImpactStyle.Light }).catch(() => {})
}

export async function nativeShare(title: string, text: string, url?: string): Promise<boolean> {
  if (!isNative) return false
  await Share.share({ title, text, url, dialogTitle: title })
  return true
}
