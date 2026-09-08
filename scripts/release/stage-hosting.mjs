import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'
import { execFileSync } from 'node:child_process'
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const config = JSON.parse(fs.readFileSync(path.join(root, 'scripts/release/public-release.json'), 'utf8'))
const store = process.env.CAOCAP_RELEASE_STORE
const bucket = process.env.CAOCAP_RELEASE_BUCKET
if (config.available && (!config.current || !/^https:\/\/testflight.apple.com\/join\/[A-Za-z0-9]+$/.test(config.testFlightURL ?? ''))) throw new Error('Public availability requires the approved TestFlight link and current Mac release')
execFileSync('npm', ['--prefix', path.join(root, 'websites/landing'), 'run', 'build'], { stdio: 'inherit' })
const staging = fs.mkdtempSync(path.join(root, 'firebase/.hosting-stage-'))
try {
  fs.cpSync(path.join(root, 'websites/landing/dist'), staging, { recursive: true })
  const downloads = path.join(staging, 'downloads')
  fs.mkdirSync(downloads, { recursive: true })
  for (const release of [config.current, config.previous].filter(Boolean)) {
    if (!/^[A-Za-z0-9._-]+\.dmg$/.test(release.fileName) || !/^[a-f0-9]{64}$/.test(release.sha256) || !Number.isSafeInteger(release.size) || release.size <= 0 || typeof release.version !== 'string') throw new Error('Invalid immutable release metadata')
    const destination = path.join(downloads, release.fileName)
    if (store) fs.copyFileSync(path.join(store, release.fileName), destination)
    else if (bucket && /^gs:\/\/[A-Za-z0-9._/-]+$/.test(bucket)) execFileSync('gcloud', ['storage', 'cp', `${bucket.replace(/\/$/, '')}/${release.fileName}`, destination], { stdio: 'inherit' })
    else throw new Error('Set CAOCAP_RELEASE_STORE to private mounted release storage or CAOCAP_RELEASE_BUCKET to its gs:// prefix')
    const bytes = fs.readFileSync(destination)
    if (bytes.length !== release.size || createHash('sha256').update(bytes).digest('hex') !== release.sha256) throw new Error(`Release checksum/size mismatch: ${release.fileName}`)
  }
  fs.writeFileSync(path.join(downloads, 'latest.json'), JSON.stringify(config, null, 2) + '\n')
  // A failed assembly leaves the previous local staging intact and aborts deployment.
  const output = path.join(root, 'firebase/hosting-public')
  fs.rmSync(output, { recursive: true, force: true })
  fs.renameSync(staging, output)
  console.log('Complete Hosting release staged and verified.')
} finally { fs.rmSync(staging, { recursive: true, force: true }) }
