import { readFileSync, writeFileSync } from 'node:fs'

const file = new URL('../ios/App/CapApp-SPM/Package.swift', import.meta.url)
const source = readFileSync(file, 'utf8')
const fixed = source.replaceAll('\\', '/')
if (fixed !== source) writeFileSync(file, fixed)
console.log('iOS Swift package paths are portable')
