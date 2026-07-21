import { execFileSync } from 'node:child_process'
import { writeFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const sources = {
  Games: execFileSync('git', ['show', 'origin/kirills-version:Games.swift'], { cwd: resolve(root, '..'), encoding: 'utf8' }),
  Spicy: execFileSync('git', ['show', 'origin/kirills-version:SpicyGames.swift'], { cwd: resolve(root, '..'), encoding: 'utf8' }),
  New: execFileSync('git', ['show', 'origin/kirills-version:Beerify/NewGames.swift'], { cwd: resolve(root, '..'), encoding: 'utf8' }),
}

const targets = [
  ['Games', 'NeverHaveIEverGame', 'never-have-i-ever'],
  ['Games', 'HigherLowerGame', 'higher-lower'],
  ['Games', 'CategoriesGame', 'categories'],
  ['Spicy', 'RankedGame', 'id-game'],
  ['Spicy', 'MostLikelyToGame', 'most-likely-to'],
  ['New', 'HotTakesGame', 'hot-takes'],
  ['New', 'BombPassGame', 'bomb-pass'],
  ['New', 'WhoSaidItGame', 'who-said-it'],
  ['New', 'DareLadderGame', 'dare-ladder'],
]

function segment(source, structName) {
  const start = source.indexOf(`struct ${structName}:`)
  if (start < 0) throw new Error(`Missing ${structName}`)
  const end = source.indexOf('\nstruct ', start + 10)
  return source.slice(start, end < 0 ? source.length : end)
}

function decodeSwift(value) {
  return value.replace(/\\"/g, '"').replace(/\\n/g, '\n').replace(/\\\\/g, '\\')
}

function prompts(source) {
  return [...source.matchAll(/\.init\(text:\s*"((?:\\.|[^"\\])*)",\s*level:\s*([1-5])\)/g)].map((match) => ({ text: decodeSwift(match[1]), level: Number(match[2]) }))
}

const data = {}
for (const [sourceName, structName, kind] of targets) data[kind] = prompts(segment(sources[sourceName], structName))

data['would-you-rather'] = [...segment(sources.Spicy, 'WouldYouRatherGame').matchAll(/\.init\(a:\s*"((?:\\.|[^"\\])*)",\s*b:\s*"((?:\\.|[^"\\])*)",\s*level:\s*([1-5])\)/g)]
  .map((match) => ({ text: `${decodeSwift(match[1])} OR ${decodeSwift(match[2])}`, level: Number(match[3]) }))

const truthDare = segment(sources.Games, 'TruthOrDareGame')
const truthsStart = truthDare.indexOf('private static let truths:')
const daresStart = truthDare.indexOf('private static let dares:')
const bodyStart = truthDare.indexOf('\n    var body:', daresStart)
const truths = prompts(truthDare.slice(truthsStart, daresStart))
const dares = prompts(truthDare.slice(daresStart, bodyStart))
const byLevel = (items, level) => items.filter((item) => item.level === level)
data['truth-or-dare'] = []
for (let level = 1; level <= 5; level++) {
  const levelTruths = byLevel(truths, level)
  const levelDares = byLevel(dares, level)
  const count = Math.max(levelTruths.length, levelDares.length)
  for (let index = 0; index < count; index++) data['truth-or-dare'].push({ text: `Truth: ${levelTruths[index % levelTruths.length]?.text ?? 'Answer honestly.'} Dare: ${levelDares[index % levelDares.length]?.text ?? 'Take a dare from the group.'}`, level })
}

for (const [kind, entries] of Object.entries(data)) {
  if (!entries.length) throw new Error(`No prompts extracted for ${kind}`)
}

const output = `// Generated from the merged origin/kirills-version Swift decks by scripts/extract-kirill-prompts.mjs.\nimport type { GameKind } from '../types'\n\nexport interface KirillPrompt { text: string; level: number }\n\nexport const KIRILL_PROMPTS: Partial<Record<GameKind, KirillPrompt[]>> = ${JSON.stringify(data, null, 2)}\n`
writeFileSync(resolve(root, 'src/lib/kirill-prompts.ts'), output)
console.log(Object.fromEntries(Object.entries(data).map(([kind, entries]) => [kind, entries.length])))
