import { createPrivateKey, sign } from 'node:crypto'
import { connect, type ClientHttp2Session } from 'node:http2'

export interface PushRegistration {
  token: string
  environment: 'sandbox' | 'production'
}

export interface PushEvent {
  id: string
  type: string
  actorId: string
  actorName: string
  text?: string
  startsAt?: number
}

export interface PlannedPush {
  memberId: string
  registration: PushRegistration
  payload: Record<string, unknown>
  expiration: number
  collapseId: string
}

interface PushResult { memberId: string; invalid: boolean }

let cachedJwt: { value: string; createdAt: number } | null = null
let warnedMissingCredentials = false

function base64url(value: string | Buffer): string {
  return Buffer.from(value).toString('base64url')
}

function providerToken(): string | null {
  const keyId = process.env.APNS_KEY_ID
  const teamId = process.env.APNS_TEAM_ID
  const privateKey = process.env.APNS_PRIVATE_KEY?.replace(/\\n/g, '\n')
  if (!keyId || !teamId || !privateKey) return null
  const now = Math.floor(Date.now() / 1000)
  if (cachedJwt && now - cachedJwt.createdAt < 50 * 60) return cachedJwt.value
  const header = base64url(JSON.stringify({ alg: 'ES256', kid: keyId }))
  const claims = base64url(JSON.stringify({ iss: teamId, iat: now }))
  const input = `${header}.${claims}`
  const signature = sign('sha256', Buffer.from(input), {
    key: createPrivateKey(privateKey),
    dsaEncoding: 'ieee-p1363',
  })
  cachedJwt = { value: `${input}.${base64url(signature)}`, createdAt: now }
  return cachedJwt.value
}

function messageFor(event: PushEvent): string | null {
  if (event.type === 'cheers-countdown') return `${event.actorName} called Drink up — cheers in 8 seconds.`
  if (event.type === 'round-invite') return `${event.actorName} opened the next round.`
  if (event.type === 'round-order') return `${event.actorName} ordered ${event.text || 'a drink'}.`
  if (event.type === 'round-bought') return `${event.actorName} marked the round bought.`
  return null
}

export function planRoomPushes(
  code: string,
  event: PushEvent,
  registrations: Record<string, PushRegistration>,
  buyerId?: string,
): PlannedPush[] {
  const body = messageFor(event)
  if (!body) return []
  const recipients = event.type === 'round-order'
    ? buyerId && buyerId !== event.actorId ? [buyerId] : []
    : Object.keys(registrations).filter((memberId) => memberId !== event.actorId)
  const expiration = event.type === 'cheers-countdown'
    ? Math.floor(((event.startsAt ?? Date.now()) + 2_000) / 1_000)
    : Math.floor((Date.now() + 15 * 60_000) / 1_000)
  return recipients.flatMap((memberId) => {
    const registration = registrations[memberId]
    if (!registration || !/^[a-f0-9]{32,256}$/i.test(registration.token)) return []
    return [{
      memberId,
      registration,
      expiration,
      collapseId: `room:${code}:${event.type}`,
      payload: {
        aps: { alert: { title: 'Beerify', body }, sound: 'default', 'thread-id': `room:${code}` },
        room: code,
        eventId: event.id,
        eventType: event.type,
      },
    }]
  })
}

function openSession(environment: PushRegistration['environment']): Promise<ClientHttp2Session> {
  const host = environment === 'sandbox' ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com'
  return new Promise((resolve, reject) => {
    const session = connect(host)
    const timeout = setTimeout(() => { session.destroy(); reject(new Error('APNs connection timed out')) }, 5_000)
    session.once('connect', () => { clearTimeout(timeout); session.setTimeout(5_000, () => session.destroy()); resolve(session) })
    session.once('error', reject)
  })
}

async function deliver(session: ClientHttp2Session, push: PlannedPush, jwt: string, topic: string): Promise<PushResult> {
  return await new Promise((resolve) => {
    const request = session.request({
      ':method': 'POST',
      ':path': `/3/device/${push.registration.token}`,
      authorization: `bearer ${jwt}`,
      'apns-topic': topic,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'apns-expiration': String(push.expiration),
      'apns-collapse-id': push.collapseId,
    })
    let status = 0
    let body = ''
    let settled = false
    const finish = (invalid: boolean) => { if (!settled) { settled = true; resolve({ memberId: push.memberId, invalid }) } }
    request.setEncoding('utf8')
    request.setTimeout(5_000, () => request.close())
    request.on('response', (headers) => { status = Number(headers[':status'] ?? 0) })
    request.on('data', (chunk: string) => { body += chunk })
    request.on('error', () => finish(false))
    request.on('close', () => finish(false))
    request.on('end', () => {
      let reason = ''
      try { reason = String((JSON.parse(body) as { reason?: string }).reason ?? '') } catch { /* Empty APNs response. */ }
      finish(status === 410 || reason === 'BadDeviceToken' || reason === 'DeviceTokenNotForTopic' || reason === 'Unregistered')
    })
    request.end(JSON.stringify(push.payload))
  })
}

export async function sendPlannedPushes(pushes: PlannedPush[]): Promise<string[]> {
  if (!pushes.length) return []
  const jwt = providerToken()
  const topic = process.env.APNS_TOPIC || 'app.beerify.mobile'
  if (!jwt) {
    if (!warnedMissingCredentials) { console.warn('APNs is disabled because provider credentials are not configured'); warnedMissingCredentials = true }
    return []
  }
  const invalid: string[] = []
  for (const environment of ['sandbox', 'production'] as const) {
    const batch = pushes.filter((push) => push.registration.environment === environment)
    if (!batch.length) continue
    let session: ClientHttp2Session | null = null
    try {
      session = await openSession(environment)
      const results = await Promise.all(batch.map((push) => deliver(session!, push, jwt, topic)))
      invalid.push(...results.filter((result) => result.invalid).map((result) => result.memberId))
    } catch (error) {
      console.error('APNs delivery failed', error instanceof Error ? error.message : 'unknown error')
    } finally {
      session?.close()
    }
  }
  return invalid
}
