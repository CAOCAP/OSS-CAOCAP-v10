import type { ReactNode } from 'react'
import {
  MiniCanvas,
  MiniCollab,
  MiniHome,
  ProductStage,
} from './ProductStage.tsx'
import { WaitlistForm } from './WaitlistForm.tsx'
import { Wordmark } from './Wordmark.tsx'

export function Landing() {
  return (
    <div id="top" className="min-h-dvh bg-page text-navy">
      <header className="sticky top-4 z-40 flex justify-center px-4">
        <nav className="flex w-full max-w-4xl items-center justify-between rounded-full bg-white/90 px-4 py-2 shadow-[0_10px_40px_rgba(26,36,51,0.08)] backdrop-blur">
          <Wordmark />
          <a
            href="#waitlist"
            className="rounded-full bg-cyan px-4 py-2 text-sm font-medium text-white hover:bg-[#3aa8f2]"
          >
            Join waitlist
          </a>
        </nav>
      </header>

      <section className="mx-auto max-w-3xl px-6 pb-6 pt-20 text-center">
        <h1 className="text-4xl font-semibold leading-[1.15] tracking-tight sm:text-5xl">
          Explore and build agents.{' '}
          <span className="text-cyan">Collaborate before you publish.</span>
        </h1>
        <p className="mx-auto mt-5 max-w-md text-[15px] leading-relaxed text-muted">
          Discover useful agents, shape how they think on a canvas, and release
          a version you have actually tested.
        </p>
        <div id="waitlist" className="mx-auto mt-8 flex scroll-mt-28 justify-center">
          <WaitlistForm id="waitlist-email" />
        </div>
      </section>

      <ProductStage />
      <p className="px-6 pb-6 text-center text-xs text-muted">
        Concept preview of the planned building experience.
      </p>

      <section className="mx-auto flex max-w-3xl flex-col items-center gap-3 px-6 pb-16 text-center sm:flex-row sm:justify-center sm:gap-16">
        <p className="text-sm text-muted">iOS and macOS · coming soon</p>
        <p className="text-sm text-muted">Waitlist only. Nothing to download yet.</p>
      </section>

      <section className="px-6 pb-24">
        <h2 className="mx-auto max-w-xl text-center text-3xl font-semibold tracking-tight">
          A library, a canvas, and a shared review.
        </h2>
        <div className="mx-auto mt-12 grid max-w-5xl gap-4 md:grid-cols-3">
          <FeatureCard
            kicker="Explore"
            title="Find an agent that fits the work."
            body="See what it does, where it fails, and try it before you depend on it."
          >
            <MiniHome />
          </FeatureCard>
          <FeatureCard
            kicker="Build"
            title="Map the knowledge. Draw the logic."
            body="Mindmaps hold context. Flowcharts hold conditions. Test before anyone else has to trust it."
          >
            <MiniCanvas />
          </FeatureCard>
          <FeatureCard
            kicker="Collaborate"
            title="Ship the version you tested together."
            body="Contribute, review, and publish with a clear record of who did what."
          >
            <MiniCollab />
          </FeatureCard>
        </div>
      </section>

      <footer className="border-t border-navy/5 px-6 py-10 text-center">
        <p className="text-sm text-muted">
          We’ll write when iOS and macOS are ready to try.
        </p>
        <p className="mt-3 text-xs text-muted/80">CAOCAP</p>
      </footer>
    </div>
  )
}

function FeatureCard({
  kicker,
  title,
  body,
  children,
}: {
  kicker: string
  title: string
  body: string
  children: ReactNode
}) {
  return (
    <article className="rounded-[1.6rem] bg-white p-6 shadow-[0_16px_40px_rgba(26,36,51,0.06)]">
      <div className="mb-4">{children}</div>
      <p className="text-xs font-medium uppercase tracking-[0.16em] text-cyan">
        {kicker}
      </p>
      <h3 className="mt-3 text-lg font-semibold tracking-tight">{title}</h3>
      <p className="mt-2 text-sm leading-relaxed text-muted">{body}</p>
    </article>
  )
}
