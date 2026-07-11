import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'

const root = new URL('../', import.meta.url)
const read = (path) => readFileSync(new URL(path, root), 'utf8')
const swift = read('ios/App/CapApp-SPM/Package.swift')
const plist = read('ios/App/App/Info.plist')
const nativeConfig = JSON.parse(read('ios/App/App/capacitor.config.json'))
const icon = readFileSync(new URL('ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png', root))
const bundleDir = new URL('ios/App/App/public/assets/', root)
const bundleHasApi = readdirSync(bundleDir).filter((file) => file.endsWith('.js'))
  .some((file) => readFileSync(new URL(file, bundleDir), 'utf8').includes('https://beerify-lime.vercel.app'))

assert.equal(nativeConfig.appId, 'app.beerify.mobile')
assert.equal(nativeConfig.ios.contentInset, 'never')
assert.ok(plist.includes('<string>beerify</string>'))
assert.ok(!swift.includes('\\'), 'Swift package paths must use forward slashes')
assert.equal(icon.readUInt32BE(16), 1024)
assert.equal(icon.readUInt32BE(20), 1024)
assert.ok(bundleHasApi, 'Native bundle must contain the deployed API origin')
console.log('iOS project configuration is valid')
