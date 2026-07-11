import { PushNotifications } from '@capacitor/push-notifications'
import { isNative } from './platform'

export type PushStatus = 'unsupported' | 'checking' | 'prompt' | 'granted' | 'denied' | 'error'
export interface PushState { status: PushStatus; token: string | null; error: string | null }

let state: PushState = { status: isNative ? 'checking' : 'unsupported', token: null, error: null }
let installed = false
const subscribers = new Set<() => void>()

export const apnsEnvironment: 'sandbox' | 'production' = import.meta.env.VITE_APNS_ENVIRONMENT === 'sandbox'
  ? 'sandbox'
  : 'production'

export function getPushState(): PushState { return state }
export function subscribePushState(listener: () => void): () => void {
  subscribers.add(listener)
  return () => { subscribers.delete(listener) }
}

export function reportPushRegistrationError(error: string | null): void {
  update({ error })
}

function update(values: Partial<PushState>): void {
  state = { ...state, ...values }
  subscribers.forEach((listener) => listener())
}

async function requestAndRegister(): Promise<void> {
  if (!isNative) return
  try {
    let permission = await PushNotifications.checkPermissions()
    if (permission.receive === 'prompt') permission = await PushNotifications.requestPermissions()
    if (permission.receive !== 'granted') {
      update({ status: permission.receive === 'denied' ? 'denied' : 'prompt', token: null, error: null })
      return
    }
    update({ status: 'granted', error: null })
    await PushNotifications.register()
  } catch (error) {
    update({ status: 'error', error: error instanceof Error ? error.message : 'Could not enable room alerts' })
  }
}

export async function initPushNotifications(): Promise<void> {
  if (!isNative || installed) return
  installed = true
  await PushNotifications.addListener('registration', ({ value }) => update({ status: 'granted', token: value, error: null }))
  await PushNotifications.addListener('registrationError', (error) => update({ status: 'error', token: null, error: error.error }))
  await PushNotifications.addListener('pushNotificationReceived', (notification) => {
    window.dispatchEvent(new CustomEvent('beerify:room-push', { detail: notification.data }))
  })
  await PushNotifications.addListener('pushNotificationActionPerformed', ({ notification }) => {
    const code = typeof notification.data?.room === 'string' ? notification.data.room.toUpperCase() : ''
    if (/^[A-Z2-9]{6}$/.test(code)) location.assign(`/?room=${code}&via=push`)
  })
  await requestAndRegister()
}

export async function retryPushNotifications(): Promise<void> {
  update({ status: 'checking', error: null })
  await requestAndRegister()
}
