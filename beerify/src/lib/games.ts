import type { GameAction, GameKind, GamePhase } from '../types'
import { KIRILL_PROMPTS } from './kirill-prompts'

export type GameMechanic = 'prompt' | 'choice' | 'submit' | 'timer' | 'trivia' | 'vote'

export interface GamePrompt {
  text: string
  level: number
  options?: string[]
  answer?: number
}

export interface GameDefinition {
  kind: GameKind
  title: string
  emoji: string
  subtitle: string
  mechanic: GameMechanic
  minPlayers: number
  seconds?: number
  prompts: GamePrompt[]
}

const p = (text: string, level = 1, options?: string[], answer?: number): GamePrompt => ({ text, level, options, answer })

export const GAME_DEFINITIONS: GameDefinition[] = [
  { kind: 'heads-up', title: 'Heads Up!', emoji: '📱', subtitle: 'Phone on forehead. Tilt or tap to score.', mechanic: 'timer', minPlayers: 2, seconds: 60, prompts: [p('Pub quiz'), p('Karaoke'), p('Last orders'), p('Beer garden'), p('Dance floor'), p('Walk of shame', 3), p('Drunk text', 4), p('One-night stand', 5)] },
  { kind: 'psych', title: 'Psych!', emoji: '🧠', subtitle: 'Write believable lies and spot the truth.', mechanic: 'submit', minPlayers: 3, prompts: [p('What is the collective noun for flamingos?'), p('What did the first vending machine dispense?'), p('Which animal cannot jump?'), p('What unusual item did Napoleon fear?'), p('What was once prescribed as medicine?', 3)] },
  { kind: 'hot-takes', title: 'Hot Takes', emoji: '🗳️', subtitle: 'Vote agree or disagree. Minority drinks.', mechanic: 'choice', minPlayers: 3, prompts: [p('Brunch is just breakfast with a booking.', 1, ['Agree', 'Disagree']), p('Karaoke should be mandatory after midnight.', 2, ['Agree', 'Disagree']), p('Exes can genuinely stay friends.', 3, ['Agree', 'Disagree']), p('Reading a partner’s messages is sometimes fair.', 4, ['Agree', 'Disagree']), p('A friend’s ex is always off limits.', 5, ['Agree', 'Disagree'])] },
  { kind: 'bomb-pass', title: 'Bomb Pass', emoji: '💣', subtitle: 'Do the challenge before the timer blows.', mechanic: 'timer', minPlayers: 2, seconds: 18, prompts: [p('Name three cocktails'), p('Do your best celebrity impression'), p('Say the alphabet backwards from M'), p('Reveal your last search', 3), p('Send a risky emoji to your crush', 5)] },
  { kind: 'medusa', title: 'Medusa', emoji: '🐍', subtitle: 'Secretly pick someone. Mutual picks drink.', mechanic: 'vote', minPlayers: 3, prompts: [p('Look down, choose your target, then reveal.') ] },
  { kind: 'bus-driver', title: 'Bus Driver', emoji: '🚌', subtitle: 'Four escalating card guesses.', mechanic: 'choice', minPlayers: 1, prompts: [p('Red or black?', 1, ['Red', 'Black']), p('Higher or lower?', 1, ['Higher', 'Lower']), p('Inside or outside?', 2, ['Inside', 'Outside']), p('Guess the suit.', 2, ['♥', '♦', '♣', '♠'])] },
  { kind: 'dare-ladder', title: 'Dare Ladder', emoji: '🪜', subtitle: 'Climb five escalating dares or drink double.', mechanic: 'choice', minPlayers: 2, prompts: [p('Speak in an accent until your next turn.', 1, ['Did it', 'Chicken out']), p('Let the group choose your profile photo for ten minutes.', 2, ['Did it', 'Chicken out']), p('Read your last sent message aloud.', 3, ['Did it', 'Chicken out']), p('Call someone and sing happy birthday.', 4, ['Did it', 'Chicken out']), p('Let the group send one harmless text.', 5, ['Did it', 'Chicken out'])] },
  { kind: 'flip-cup', title: 'Flip Cup', emoji: '⚡', subtitle: 'Wait for FLIP, then tap. Slowest drinks.', mechanic: 'timer', minPlayers: 2, seconds: 5, prompts: [p('Wait for the signal. Do not jump early.')] },
  { kind: 'who-said-it', title: 'Who Said It?', emoji: '🕵️', subtitle: 'Anonymous answers, then guess the author.', mechanic: 'submit', minPlayers: 3, prompts: [p('My most irrational fear is…'), p('The weirdest place I have fallen asleep is…', 2), p('My worst date involved…', 3), p('A secret talent nobody expects is…'), p('The person here I would trust with a body is…', 5)] },
  { kind: 'id-game', title: 'ID Game', emoji: '🪪', subtitle: 'Rank the squad; they guess your question.', mechanic: 'vote', minPlayers: 3, prompts: [p('Most likely to survive a zombie apocalypse'), p('Most likely to become famous'), p('Most likely to text an ex tonight', 3), p('Best person to take home to your parents', 3), p('Most chaotic dating history', 5)] },
  { kind: 'higher-lower', title: 'Higher or Lower', emoji: '📈', subtitle: 'Guess whether the next secret rating is higher.', mechanic: 'choice', minPlayers: 2, prompts: [p('Rate your flirting ability from 0–10.', 2, ['Higher', 'Lower']), p('Rate your cooking from 0–10.', 1, ['Higher', 'Lower']), p('Rate your jealousy from 0–10.', 4, ['Higher', 'Lower']), p('Rate your likelihood of texting an ex from 0–10.', 5, ['Higher', 'Lower'])] },
  { kind: 'kings-cup', title: 'Kings Cup', emoji: '👑', subtitle: 'Draw a card and follow the rule.', mechanic: 'prompt', minPlayers: 2, prompts: [p('Ace — waterfall.'), p('Two — choose someone to drink.'), p('Three — you drink.'), p('Four — touch the floor.'), p('Queen — question master.'), p('King — make a rule.', 2)] },
  { kind: 'would-you-rather', title: 'Would You Rather', emoji: '🤔', subtitle: 'Impossible dilemmas. Debate the split.', mechanic: 'choice', minPlayers: 2, prompts: [p('Always arrive an hour early or ten minutes late?', 1, ['Early', 'Late']), p('Lose your phone or your wallet?', 1, ['Phone', 'Wallet']), p('Text your ex or call your boss right now?', 3, ['Ex', 'Boss']), p('Reveal your search history or your DMs?', 5, ['Searches', 'DMs'])] },
  { kind: 'most-likely-to', title: 'Most Likely To', emoji: '👉', subtitle: 'Vote. The winner drinks.', mechanic: 'vote', minPlayers: 3, prompts: [p('Who is most likely to miss the last train?'), p('Who is most likely to start karaoke?'), p('Who is most likely to text an ex?', 3), p('Who has the wildest hidden side?', 4)] },
  { kind: 'never-have-i-ever', title: 'Never Have I Ever', emoji: '🙅', subtitle: 'Tap whether you have or haven’t.', mechanic: 'choice', minPlayers: 2, prompts: [p('Never have I ever missed a flight.', 1, ['I have', 'Never']), p('Never have I ever lied to get out of work.', 2, ['I have', 'Never']), p('Never have I ever kissed a friend’s ex.', 4, ['I have', 'Never']), p('Never have I ever sent a nude.', 5, ['I have', 'Never'])] },
  { kind: 'truth-or-dare', title: 'Truth or Dare', emoji: '🎭', subtitle: 'Pick your poison.', mechanic: 'choice', minPlayers: 2, prompts: [p('Truth: what is your most embarrassing habit? Dare: narrate the next round like a sports commentator.', 1, ['Truth', 'Dare']), p('Truth: who was your last crush? Dare: show your last selfie.', 3, ['Truth', 'Dare']), p('Truth: biggest dating regret? Dare: let the group write your next dating bio.', 5, ['Truth', 'Dare'])] },
  { kind: 'trivia', title: 'Trivia Sprint', emoji: '⏱️', subtitle: 'Fast questions. Highest score wins.', mechanic: 'trivia', minPlayers: 1, prompts: [p('Which spirit is used in a mojito?', 1, ['Rum', 'Gin', 'Vodka', 'Tequila'], 0), p('How many millilitres are in a UK pint?', 1, ['440', '500', '568', '600'], 2), p('Which country created Guinness?', 1, ['Scotland', 'Ireland', 'Belgium', 'England'], 1), p('What does ABV stand for?', 1, ['Alcohol by volume', 'Average bar value', 'Alcohol beverage volume', 'Added bottle value'], 0)] },
  { kind: 'two-truths-lie', title: 'Two Truths & a Lie', emoji: '🕵️', subtitle: 'Write three claims; the squad spots the fake.', mechanic: 'submit', minPlayers: 2, prompts: [p('Submit two true things and one convincing lie about yourself.')] },
  { kind: 'categories', title: 'Categories', emoji: '🧠', subtitle: 'Name one, then pass fast.', mechanic: 'timer', minPlayers: 2, seconds: 12, prompts: [p('Cocktails'), p('Capital cities'), p('Things found in a pub'), p('Celebrities with one-word names'), p('Reasons to text an ex', 4)] },
  { kind: 'emoji-charades', title: 'Emoji Charades', emoji: '💬', subtitle: 'Decode the emoji phrase.', mechanic: 'trivia', minPlayers: 2, prompts: [p('🦁👑', 1, ['The Lion King', 'Tiger King', 'King Kong', 'Jungle Book'], 0), p('🚢🧊💔', 1, ['Titanic', 'Frozen', 'Jaws', 'Cast Away'], 0), p('👻🔫', 1, ['Ghostbusters', 'Top Gun', 'Casper', 'Scream'], 0)] },
  { kind: 'roulette', title: 'Roulette', emoji: '🎯', subtitle: 'Fate picks who is next.', mechanic: 'vote', minPlayers: 2, prompts: [p('Spin to choose the next player.')] },
  { kind: 'guess-bac', title: 'Guess My BAC', emoji: '🎲', subtitle: 'Guess a friend’s current estimate.', mechanic: 'submit', minPlayers: 2, prompts: [p('Enter your guess as a percentage, for example .045.')] },
]

export const gameByKind = (kind: GameKind): GameDefinition | undefined => GAME_DEFINITIONS.find((game) => game.kind === kind)

export function promptsFor(kind: GameKind, spiciness: number): GamePrompt[] {
  const original = KIRILL_PROMPTS[kind]?.map((prompt): GamePrompt => {
    if (kind === 'would-you-rather') {
      const [first, ...rest] = prompt.text.split(' OR ')
      return { text: 'Would you rather…', level: prompt.level, options: [first || 'Option A', rest.join(' OR ') || 'Option B'] }
    }
    if (kind === 'never-have-i-ever') return { ...prompt, options: ['I have', 'Never'] }
    if (kind === 'higher-lower') return { ...prompt, options: ['Higher', 'Lower'] }
    if (kind === 'hot-takes') return { ...prompt, options: ['Agree', 'Disagree'] }
    if (kind === 'truth-or-dare') return { ...prompt, options: ['Truth', 'Dare'] }
    if (kind === 'dare-ladder') return { ...prompt, options: ['Did it', 'Chicken out'] }
    return prompt
  })
  const prompts = original?.length ? original : gameByKind(kind)?.prompts ?? []
  const filtered = prompts.filter((prompt) => prompt.level <= Math.min(5, Math.max(1, spiciness)))
  return filtered.length ? filtered : prompts.slice(0, 1)
}

export function seededIndex(seed: number, round: number, length: number): number {
  if (!length) return 0
  let value = (seed ^ Math.imul(round + 1, 0x9e3779b1)) >>> 0
  value ^= value << 13; value ^= value >>> 17; value ^= value << 5
  return (value >>> 0) % length
}

export function promptFor(kind: GameKind, spiciness: number, seed: number, round: number): GamePrompt {
  const prompts = promptsFor(kind, spiciness)
  return prompts[seededIndex(seed, round, prompts.length)] ?? p('Take the next turn.')
}

export interface LocalGameState {
  kind: GameKind
  phase: GamePhase
  seed: number
  round: number
  spiciness: number
  score: number
  votes: Record<string, number>
  submissions: string[]
  endsAt?: number
  selected?: string
}

export function createLocalGame(kind: GameKind, spiciness: number, now = Date.now()): LocalGameState {
  return { kind, phase: 'lobby', seed: now & 0x7fffffff, round: 0, spiciness, score: 0, votes: {}, submissions: [] }
}

export function reduceLocalGame(state: LocalGameState, action: GameAction, now = Date.now()): LocalGameState {
  const definition = gameByKind(state.kind)
  if (!definition) return state
  if (action.type === 'start') return { ...state, phase: 'playing', endsAt: definition.seconds ? now + definition.seconds * 1000 : undefined }
  if (action.type === 'choose') {
    const choice = String(action.value ?? '')
    const prompt = promptFor(state.kind, state.spiciness, state.seed, state.round)
    const correct = definition.mechanic === 'trivia' && typeof prompt.answer === 'number' && prompt.options?.[prompt.answer] === choice
    return { ...state, selected: choice, score: state.score + Number(correct), votes: { ...state.votes, [choice]: (state.votes[choice] ?? 0) + 1 }, phase: definition.mechanic === 'trivia' ? 'reveal' : state.phase }
  }
  if (action.type === 'submit') {
    const value = String(action.value ?? '').trim().slice(0, 240)
    return value ? { ...state, submissions: [...state.submissions, value], phase: 'reveal' } : state
  }
  if (action.type === 'score') return { ...state, score: state.score + Number(action.value ?? 1) }
  if (action.type === 'advance' && state.phase === 'playing' && (definition.mechanic === 'choice' || definition.mechanic === 'vote') && Object.keys(state.votes).length) return { ...state, phase: 'reveal' }
  if (action.type === 'skip' || action.type === 'advance') return { ...state, phase: 'playing', round: state.round + 1, selected: undefined, votes: {}, submissions: [], endsAt: definition.seconds ? now + definition.seconds * 1000 : undefined }
  return state
}
