/**
 * Generates public/icon.png (512x512) without any dependencies:
 * a warm amber "beer glass" tile with a foam cap and rising bubbles.
 * Run with: node scripts/gen-icon.mjs
 */
import { deflateSync } from 'node:zlib'
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const SIZE = 512
const px = new Uint8Array(SIZE * SIZE * 4)

const BG_TOP = [255, 214, 121]
const BG_BOTTOM = [232, 137, 12]
const FOAM = [255, 250, 240]
const BUBBLE = [255, 236, 179]

function roundedRectMask(x, y, size, radius) {
  const r = radius
  const cx = Math.min(Math.max(x, r), size - r)
  const cy = Math.min(Math.max(y, r), size - r)
  if ((x < r && y < r) || (x > size - r && y < r) || (x < r && y > size - r) || (x > size - r && y > size - r)) {
    const dx = x - cx
    const dy = y - cy
    return dx * dx + dy * dy <= r * r
  }
  return true
}

const foamCircles = []
for (let i = 0; i <= 8; i++) {
  foamCircles.push({ x: (i / 8) * SIZE, y: 118 + (i % 2) * 26, r: 58 + (i % 3) * 10 })
}

const bubbles = [
  { x: 150, y: 300, r: 16 },
  { x: 340, y: 260, r: 12 },
  { x: 250, y: 380, r: 20 },
  { x: 400, y: 400, r: 14 },
  { x: 110, y: 430, r: 11 },
]

for (let y = 0; y < SIZE; y++) {
  for (let x = 0; x < SIZE; x++) {
    const i = (y * SIZE + x) * 4
    if (!roundedRectMask(x, y, SIZE, 110)) {
      px[i + 3] = 0
      continue
    }
    const t = y / SIZE
    let r = BG_TOP[0] + (BG_BOTTOM[0] - BG_TOP[0]) * t
    let g = BG_TOP[1] + (BG_BOTTOM[1] - BG_TOP[1]) * t
    let b = BG_TOP[2] + (BG_BOTTOM[2] - BG_TOP[2]) * t

    const inFoam = y < 96 || foamCircles.some((c) => (x - c.x) ** 2 + (y - c.y) ** 2 <= c.r ** 2)
    if (inFoam) {
      ;[r, g, b] = FOAM
    } else {
      for (const c of bubbles) {
        const d2 = (x - c.x) ** 2 + (y - c.y) ** 2
        if (d2 <= c.r ** 2) {
          ;[r, g, b] = BUBBLE
          break
        }
      }
    }

    px[i] = r
    px[i + 1] = g
    px[i + 2] = b
    px[i + 3] = 255
  }
}

// --- minimal PNG encoder ---
const crcTable = new Uint32Array(256).map((_, n) => {
  let c = n
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
  return c >>> 0
})

function crc32(buf) {
  let c = 0xffffffff
  for (const byte of buf) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8)
  return (c ^ 0xffffffff) >>> 0
}

function chunk(type, data) {
  const len = Buffer.alloc(4)
  len.writeUInt32BE(data.length)
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(body))
  return Buffer.concat([len, body, crc])
}

const ihdr = Buffer.alloc(13)
ihdr.writeUInt32BE(SIZE, 0)
ihdr.writeUInt32BE(SIZE, 4)
ihdr[8] = 8 // bit depth
ihdr[9] = 6 // color type RGBA

const raw = Buffer.alloc(SIZE * (SIZE * 4 + 1))
for (let y = 0; y < SIZE; y++) {
  raw[y * (SIZE * 4 + 1)] = 0 // filter: none
  Buffer.from(px.buffer, y * SIZE * 4, SIZE * 4).copy(raw, y * (SIZE * 4 + 1) + 1)
}

const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
])

const out = join(dirname(fileURLToPath(import.meta.url)), '..', 'public', 'icon.png')
mkdirSync(dirname(out), { recursive: true })
writeFileSync(out, png)
console.log(`wrote ${out} (${png.length} bytes)`)
