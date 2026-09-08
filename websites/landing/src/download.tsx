import { StrictMode, useEffect, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { brand } from './brand'
import './index.css'

type Release = { version: string; fileName: string; sha256: string; size: number }
type Manifest = { available: boolean; testFlightURL?: string; current?: Release }
function Download() {
  const [release, setRelease] = useState<Manifest>({ available: false })
  useEffect(() => {
    const controller = new AbortController()
    fetch('/downloads/latest.json', { cache: 'no-cache', signal: controller.signal })
      .then(r => { if (!r.ok) throw new Error('Unavailable'); return r.json() })
      .then((value: Manifest) => {
        if (value.available && /^https:\/\/testflight.apple.com\/join\/[A-Za-z0-9]+$/.test(value.testFlightURL ?? '') && /^[A-Za-z0-9._-]+\.dmg$/.test(value.current?.fileName ?? '')) setRelease(value)
      }).catch(() => { /* Keep prerelease copy when no verified release exists. */ })
    return () => controller.abort()
  }, [])
  return <main className="mx-auto max-w-5xl px-6 py-9 sm:py-14">
    <nav className="flex items-center justify-between"><a href="/" className="flex items-center gap-3 font-semibold tracking-widest"><img src={brand.duoAppIcon} alt="" className="h-10 w-10 rounded-full" />CAOCAP</a><span className="rounded-full bg-white px-4 py-2 text-sm">iPhone + Mac beta</span></nav>
    <section className="max-w-3xl py-16 sm:py-24"><p className="mb-4 text-sm font-semibold uppercase tracking-widest text-muted">Your phone. Your Mac. One task.</p><h1 className="text-4xl font-semibold leading-tight sm:text-6xl">Ask on iPhone.<br />Watch it happen on Mac.</h1><p className="mt-6 max-w-2xl text-lg leading-relaxed text-muted">Approve a short writing task on your phone. CAOCAP types and saves a TextEdit document on your Mac, then sends the filename and saved text preview back to you. The file stays on your Mac.</p></section>
    <section className="grid gap-5 sm:grid-cols-2" aria-label="Downloads">
      <article className="rounded-3xl border border-navy/10 bg-white p-8"><p className="text-sm text-muted">01 · iPhone</p><h2 className="mt-3 text-2xl font-semibold">Take the conversation with you.</h2><p className="my-5 text-muted">Requires iOS 26 or later and Apple’s TestFlight app.</p>{release.available ? <a className="inline-block rounded-full bg-navy px-6 py-3 font-medium text-white" href={release.testFlightURL}>Join the iPhone beta</a> : <p className="font-medium">Public TestFlight enrollment is coming soon.</p>}</article>
      <article className="rounded-3xl border border-navy/10 bg-white p-8"><p className="text-sm text-muted">02 · Mac</p><h2 className="mt-3 text-2xl font-semibold">Give your task a place to land.</h2><p className="my-5 text-muted">Requires macOS 26.5 or later. The computer-use driver is included.</p>{release.available && release.current ? <><a className="inline-block rounded-full bg-navy px-6 py-3 font-medium text-white" href={`/downloads/${release.current.fileName}`}>Download for Mac</a><p className="mt-4 text-sm text-muted">Version {release.current.version} · {(release.current.size / 1048576).toFixed(1)} MB</p><details className="mt-3 text-sm"><summary>Verify SHA-256 checksum</summary><code className="mt-2 block break-all">{release.current.sha256}</code></details></> : <p className="font-medium">The signed Mac download is being prepared.</p>}</article>
    </section>
    <section className="py-16"><h2 className="text-2xl font-semibold">A few minutes to get ready.</h2><ol className="mt-7 grid gap-7 sm:grid-cols-2">{[
      ['Sign in to both apps', 'Use the same Apple, Google, or GitHub account, then confirm your Mac appears in linked devices.'],
      ['Set up your Mac', 'Open CAOCAP’s account window. Allow Accessibility and Screen Recording, choose a folder for documents, and enable requests from iPhone.'],
      ['Approve a writing task', 'In Agent mode on iPhone, ask for a short TextEdit document. Review the exact task and tap Apply. You can keep chatting while it runs.'],
      ['Read what was saved', 'Watch progress and read the saved text on iPhone. Previews show up to 8,000 characters. Use Stop on your Mac whenever you need to.'],
    ].map(([title, copy], i) => <li key={title} className="flex gap-4"><span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-cyan/25 font-medium">{i + 1}</span><div><h3 className="font-semibold">{title}</h3><p className="mt-2 leading-relaxed text-muted">{copy}</p></div></li>)}</ol><p className="mt-9 rounded-2xl bg-white p-5 text-sm leading-relaxed text-muted">Your Mac must be awake, running CAOCAP, connected to the internet, and signed in. CAOCAP sends screenshots of the task’s TextEdit window to its model service during execution. This beta supports short TextEdit documents; desktop access is limited to that prepared document.</p></section>
    <footer className="border-t border-navy/10 py-6 text-sm text-muted"><a href="/">Back to CAOCAP</a></footer>
  </main>
}
createRoot(document.getElementById('root')!).render(<StrictMode><Download /></StrictMode>)
