import test from 'node:test'
import assert from 'node:assert/strict'
import { createLocalGame, GAME_DEFINITIONS, promptFor, promptsFor, reduceLocalGame } from './games'

test('ships every Kirill game as a local reducer-driven game', () => {
  assert.equal(GAME_DEFINITIONS.length, 22)
  assert.deepEqual(GAME_DEFINITIONS.map((game) => game.kind), [
    'heads-up', 'psych', 'hot-takes', 'bomb-pass', 'medusa', 'bus-driver', 'dare-ladder', 'flip-cup', 'who-said-it', 'id-game', 'higher-lower', 'kings-cup', 'would-you-rather', 'most-likely-to', 'never-have-i-ever', 'truth-or-dare', 'trivia', 'two-truths-lie', 'categories', 'emoji-charades', 'roulette', 'guess-bac',
  ])
  for (const game of GAME_DEFINITIONS) {
    const lobby = createLocalGame(game.kind, 3, 100)
    const playing = reduceLocalGame(lobby, { type: 'start' }, 200)
    assert.equal(playing.phase, 'playing', game.kind)
    const next = reduceLocalGame(playing, { type: 'advance' }, 300)
    assert.equal(next.round, 1, game.kind)
    assert.ok(promptFor(game.kind, 3, 123, 0).text, game.kind)
  }
})

test('spiciness excludes prompts above the chosen level', () => {
  assert.ok(promptsFor('truth-or-dare', 1).every((prompt) => prompt.level <= 1))
  assert.ok(promptsFor('truth-or-dare', 5).some((prompt) => prompt.level === 5))
  assert.ok(promptsFor('never-have-i-ever', 5).length >= 190)
  assert.ok(promptsFor('id-game', 5).length >= 220)
  assert.ok(promptsFor('would-you-rather', 5).length >= 150)
})

test('seeds produce stable prompt order', () => {
  assert.deepEqual(promptFor('heads-up', 5, 9182, 4), promptFor('heads-up', 5, 9182, 4))
})

test('local reducers record answers and scores without mutating input', () => {
  const initial = reduceLocalGame(createLocalGame('trivia', 3, 100), { type: 'start' }, 200)
  const answered = reduceLocalGame(initial, { type: 'choose', value: 'Rum' }, 300)
  assert.equal(answered.phase, 'reveal')
  assert.equal(answered.votes.Rum, 1)
  assert.equal(initial.votes.Rum, undefined)
  assert.equal(reduceLocalGame(initial, { type: 'score', value: 2 }, 300).score, 2)
  const voting = reduceLocalGame(createLocalGame('hot-takes', 3, 100), { type: 'start' }, 200)
  const voted = reduceLocalGame(voting, { type: 'choose', value: 'Agree' }, 300)
  assert.equal(reduceLocalGame(voted, { type: 'advance' }, 400).phase, 'reveal')
})
