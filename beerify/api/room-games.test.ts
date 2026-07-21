import test from 'node:test'
import assert from 'node:assert/strict'

process.env.BEERIFY_LOCAL_DEV = '1'

const host = { memberId: '11111111-1111-4111-8111-111111111111', memberToken: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' }
const guest1 = { memberId: '22222222-2222-4222-8222-222222222222', memberToken: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' }
const guest2 = { memberId: '33333333-3333-4333-8333-333333333333', memberToken: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' }

function member(id: string, name: string) {
  return { id, name, bac: 0, units: 0, drinks: 0, distinctDrinks: 0, targetId: 'glow', status: 'sober', inSession: false }
}

test('room game protocol authorizes hosts, redacts secrets, handles revisions, and is idempotent', async () => {
  const api = await import('./room')
  const call = async (payload: Record<string, unknown>) => {
    const response = await api.POST(new Request('http://local/api/room', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload) }))
    return { response, body: await response.json() as Record<string, unknown> }
  }
  const act = (code: string, credentials: typeof host, gameId: string, revision: number, clientActionId: string, gameAction: Record<string, unknown>) => call({ action: 'game-action', code, ...credentials, gameId, expectedRevision: revision, clientActionId, gameAction })

  const created = await call({ action: 'create', name: 'Protocol Night', memberToken: host.memberToken, member: member(host.memberId, 'Host') })
  assert.equal(created.response.status, 200)
  const code = String(created.body.code)
  await call({ action: 'update', code, memberToken: guest1.memberToken, member: member(guest1.memberId, 'Guest One') })
  await call({ action: 'update', code, memberToken: guest2.memberToken, member: member(guest2.memberId, 'Guest Two') })

  const deniedStart = await call({ action: 'game-start', code, ...guest1, kind: 'psych', spiciness: 4 })
  assert.equal(deniedStart.response.status, 403)
  const started = await call({ action: 'game-start', code, ...host, kind: 'psych', spiciness: 4 })
  assert.equal(started.response.status, 200)
  const gameId = String(started.body.id)
  assert.equal(started.body.phase, 'lobby')

  const publicResponse = await api.GET(new Request(`http://local/api/room?code=${code}`))
  const publicRoom = await publicResponse.json() as Record<string, unknown>
  assert.deepEqual(Object.keys(publicRoom.activeGame as object).sort(), ['hostMemberId', 'id', 'kind', 'participantCount', 'phase', 'title', 'updatedAt'])
  assert.equal(JSON.stringify(publicRoom).includes('privateByMember'), false)

  const ready1 = await act(code, guest1, gameId, 0, '44444444-4444-4444-8444-444444444444', { type: 'ready' })
  assert.equal(ready1.response.status, 200)
  assert.equal(ready1.body.revision, 1)
  const duplicate = await act(code, guest1, gameId, 0, '44444444-4444-4444-8444-444444444444', { type: 'ready' })
  assert.equal(duplicate.response.status, 200)
  assert.equal(duplicate.body.revision, 1)

  const ready2 = await act(code, guest2, gameId, 1, '55555555-5555-4555-8555-555555555555', { type: 'ready' })
  assert.equal(ready2.body.revision, 2)
  const playing = await act(code, host, gameId, 2, '66666666-6666-4666-8666-666666666666', { type: 'start' })
  assert.equal(playing.body.phase, 'playing')
  const playRevision = Number(playing.body.revision)

  const hostSecret = await act(code, host, gameId, playRevision, '77777777-7777-4777-8777-777777777777', { type: 'submit', value: 'A convincing host lie' })
  assert.equal(hostSecret.response.status, 200)
  const guestState = await call({ action: 'game-state', code, ...guest1 })
  assert.equal(JSON.stringify(guestState.body).includes('A convincing host lie'), false)
  assert.equal((guestState.body.state as Record<string, unknown>).responseCount, 1)

  const guestSecret = await act(code, guest1, gameId, Number(guestState.body.revision), '88888888-8888-4888-8888-888888888888', { type: 'submit', value: 'Guest one secret' })
  assert.equal(guestSecret.response.status, 200)
  const stale = await act(code, guest2, gameId, Number(guestState.body.revision), '99999999-9999-4999-8999-999999999999', { type: 'submit', value: 'Too stale' })
  assert.equal(stale.response.status, 409)
  assert.ok((stale.body.game as Record<string, unknown>).revision)

  const guest2State = await call({ action: 'game-state', code, ...guest2 })
  const reveal = await act(code, guest2, gameId, Number(guest2State.body.revision), '12121212-1212-4212-8212-121212121212', { type: 'submit', value: 'Guest two secret' })
  assert.equal(reveal.body.phase, 'reveal')
  assert.equal(((reveal.body.state as Record<string, unknown>).submissions as unknown[]).length, 3)

  const invalidAdvance = await act(code, guest1, gameId, Number(reveal.body.revision), '13131313-1313-4313-8313-131313131313', { type: 'advance' })
  assert.equal(invalidAdvance.response.status, 403)
  const deniedEnd = await call({ action: 'game-end', code, ...guest1 })
  assert.equal(deniedEnd.response.status, 403)
  const ended = await call({ action: 'game-end', code, ...host })
  assert.equal(ended.response.status, 200)
  const scoredRoomResponse = await api.GET(new Request(`http://local/api/room?code=${code}`))
  const scoredRoom = await scoredRoomResponse.json() as { gameLeaderboard: Array<{ games: number }> }
  assert.ok(scoredRoom.gameLeaderboard.every((entry) => entry.games === 1))
  const afterEnd = await call({ action: 'game-state', code, ...host })
  assert.equal(afterEnd.response.status, 404)
})

test('room games pause for a lost host, promote spectators next round, and expire with the room', async () => {
  const api = await import('./room')
  const originalNow = Date.now
  let now = originalNow()
  Date.now = () => now
  try {
    const nextHost = { memberId: '14141414-1414-4414-8414-141414141414', memberToken: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd' }
    const player = { memberId: '15151515-1515-4515-8515-151515151515', memberToken: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' }
    const late = { memberId: '16161616-1616-4616-8616-161616161616', memberToken: 'ffffffff-ffff-4fff-8fff-ffffffffffff' }
    const call = async (payload: Record<string, unknown>) => {
      const response = await api.POST(new Request('http://local/api/room', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload) }))
      return { response, body: await response.json() as Record<string, unknown> }
    }
    const action = (code: string, credentials: typeof nextHost, gameId: string, revision: number, id: string, gameAction: Record<string, unknown>) => call({ action: 'game-action', code, ...credentials, gameId, expectedRevision: revision, clientActionId: id, gameAction })

    const created = await call({ action: 'create', name: 'Failover', memberToken: nextHost.memberToken, member: member(nextHost.memberId, 'Original Host') })
    const code = String(created.body.code)
    await call({ action: 'update', code, memberToken: player.memberToken, member: member(player.memberId, 'Oldest Player') })
    const started = await call({ action: 'game-start', code, ...nextHost, kind: 'flip-cup', spiciness: 2 })
    const gameId = String(started.body.id)
    const ready = await action(code, player, gameId, 0, '17171717-1717-4717-8717-171717171717', { type: 'ready' })
    const playing = await action(code, nextHost, gameId, Number(ready.body.revision), '18181818-1818-4818-8818-181818181818', { type: 'start' })
    assert.equal(playing.body.phase, 'playing')

    await call({ action: 'update', code, memberToken: late.memberToken, member: member(late.memberId, 'Late Player') })
    const spectatorView = await call({ action: 'game-state', code, ...late })
    const latePlayer = (spectatorView.body.players as Array<{ memberId: string; spectator?: boolean }>).find((entry) => entry.memberId === late.memberId)
    assert.equal(latePlayer?.spectator, true)
    const spectatorAction = await action(code, late, gameId, Number(spectatorView.body.revision), '19191919-1919-4919-8919-191919191919', { type: 'score', value: 1 })
    assert.equal(spectatorAction.response.status, 403)

    now += 61_000
    const paused = await call({ action: 'game-state', code, ...player })
    assert.equal(paused.body.phase, 'paused')
    const claimed = await action(code, player, gameId, Number(paused.body.revision), '20202020-2020-4020-8020-202020202020', { type: 'claim-host' })
    assert.equal(claimed.response.status, 200)
    assert.equal(claimed.body.phase, 'reveal')
    assert.equal(claimed.body.canControl, true)

    const advanced = await action(code, player, gameId, Number(claimed.body.revision), '21212121-2121-4121-8121-212121212121', { type: 'advance' })
    const rejoined = await call({ action: 'game-state', code, ...late })
    const promoted = (rejoined.body.players as Array<{ memberId: string; spectator?: boolean }>).find((entry) => entry.memberId === late.memberId)
    assert.equal(promoted?.spectator, false)

    const sameRevision = Number(rejoined.body.revision)
    const competing = await Promise.all([
      action(code, player, gameId, sameRevision, '22222222-2222-4222-8222-222222222223', { type: 'score', value: 1 }),
      action(code, late, gameId, sameRevision, '23232323-2323-4323-8323-232323232323', { type: 'score', value: 1 }),
    ])
    assert.deepEqual(competing.map((result) => result.response.status).sort(), [200, 409])

    const latest = await call({ action: 'game-state', code, ...player })
    const ended = await call({ action: 'game-end', code, ...player })
    assert.equal(ended.response.status, 200)
    assert.ok(Number(latest.body.revision) >= Number(advanced.body.revision))
    now += 25 * 60 * 60_000
    const expired = await api.GET(new Request(`http://local/api/room?code=${code}`))
    assert.equal(expired.status, 404)
  } finally {
    Date.now = originalNow
  }
})

test('Pub Bingo and Pub Golf share live progress and winner state', async () => {
  const api = await import('./room')
  const pubHost = { memberId: '24242424-2424-4424-8424-242424242424', memberToken: 'abababab-abab-4bab-8bab-abababababab' }
  const call = async (payload: Record<string, unknown>) => {
    const response = await api.POST(new Request('http://local/api/room', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload) }))
    return { response, body: await response.json() as Record<string, unknown> }
  }
  const created = await call({ action: 'create', name: 'Pub Games', memberToken: pubHost.memberToken, member: member(pubHost.memberId, 'Pub Host') })
  const code = String(created.body.code)
  const action = (gameId: string, revision: number, id: string, gameAction: Record<string, unknown>) => call({ action: 'game-action', code, ...pubHost, gameId, expectedRevision: revision, clientActionId: id, gameAction })

  const bingo = await call({ action: 'game-start', code, ...pubHost, kind: 'pub-bingo', spiciness: 3 })
  let view = await action(String(bingo.body.id), 0, '25252525-2525-4525-8525-252525252525', { type: 'start' })
  for (let cell = 0; cell < 25; cell++) {
    if (cell === 12) continue
    view = await action(String(bingo.body.id), Number(view.body.revision), `26262626-2626-4626-8626-${String(cell).padStart(12, '0')}`, { type: 'bingo-toggle', value: cell })
  }
  const bingoState = view.body.state as Record<string, unknown>
  assert.equal(bingoState.bingoWinner, pubHost.memberId)
  assert.equal(bingoState.fullHouseWinner, pubHost.memberId)
  assert.equal((view.body.players as Array<{ score: number }>)[0].score, 25)
  await call({ action: 'game-end', code, ...pubHost })

  const golf = await call({ action: 'game-start', code, ...pubHost, kind: 'pub-golf', spiciness: 3 })
  view = await action(String(golf.body.id), 0, '27272727-2727-4727-8727-272727272727', { type: 'start' })
  for (let hole = 0; hole < 3; hole++) view = await action(String(golf.body.id), Number(view.body.revision), `28282828-2828-4828-8828-${String(hole).padStart(12, '0')}`, { type: 'golf-score', value: { hole, strokes: 3 + hole, par: 4, drink: `Drink ${hole + 1}` } })
  const golfByMember = (view.body.state as Record<string, unknown>).golfByMember as Record<string, Record<string, unknown>>
  assert.equal(Object.keys(golfByMember[pubHost.memberId]).length, 3)
  assert.ok((view.body.players as Array<{ score: number }>)[0].score > 0)
  await call({ action: 'game-end', code, ...pubHost })
  const roomResponse = await api.GET(new Request(`http://local/api/room?code=${code}`))
  const room = await roomResponse.json() as { gameLeaderboard: Array<{ games: number }> }
  assert.equal(room.gameLeaderboard[0].games, 2)
})
