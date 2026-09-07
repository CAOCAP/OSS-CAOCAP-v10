import { brand } from './brand.ts'

export function ProductStage() {
  return (
    <div className="relative mx-auto flex max-w-5xl flex-col items-center justify-center gap-8 px-4 py-8 lg:min-h-[40rem] lg:flex-row lg:items-center lg:gap-10">
      <div
        className="pointer-events-none absolute left-1/2 top-1/2 hidden h-[36rem] w-[36rem] -translate-x-1/2 -translate-y-1/2 rounded-full border border-cyan/15 lg:block"
        aria-hidden="true"
      />
      <PhoneWorkspace />
      <NodeZoom />
    </div>
  )
}

function PhoneWorkspace() {
  return (
    <div className="relative z-10 w-[280px] rounded-[2.55rem] bg-[#1c1c1e] p-[9px] shadow-[0_40px_80px_rgba(26,36,51,0.18)] sm:w-[300px]">
      <div className="relative overflow-hidden rounded-[2.05rem] bg-[#eef1f6]">
        <StatusBar />
        <WorkspaceHUD />
        <div className="dotted-canvas relative h-[420px]">
          <ConnectionLines />
          <CanvasNode
            className="left-[18%] top-[10%]"
            tone="cyan"
            label="Purpose"
            title="Research brief"
          />
          <CanvasNode
            className="left-[8%] top-[42%]"
            tone="cyan"
            label="Knowledge"
            title="Sources"
          />
          <CanvasNode
            className="right-[8%] top-[38%]"
            tone="purple"
            label="Action"
            title="Draft reply"
          />
          <CanvasNode
            className="top-[54%] left-[22%]"
            tone="gold"
            label="Condition"
            title="If sources conflict"
          />
          <button
            type="button"
            tabIndex={-1}
            aria-hidden="true"
            className="absolute bottom-[7.6rem] right-3 flex h-11 w-11 items-center justify-center overflow-hidden rounded-full bg-navy shadow-[0_8px_20px_rgba(26,36,51,0.28)]"
          >
            <img
              src={brand.cocaptainAvatar}
              alt=""
              className="h-full w-full object-cover object-top"
            />
          </button>
          <ChatSheet />
        </div>
      </div>
    </div>
  )
}

function StatusBar() {
  return (
    <div className="relative z-20 flex items-center justify-between px-6 pt-2.5 text-[11px] font-semibold text-navy/80">
      <span>9:41</span>
      <span className="absolute left-1/2 top-1.5 h-6 w-[7.25rem] -translate-x-1/2 rounded-full bg-black" />
      <span className="flex items-end gap-0.5">
        <span className="h-1.5 w-1 rounded-[1px] bg-navy/50" />
        <span className="h-2 w-1 rounded-[1px] bg-navy/50" />
        <span className="h-2.5 w-1 rounded-[1px] bg-navy/70" />
        <span className="ml-1 h-2.5 w-5 rounded-[3px] border border-navy/40">
          <span className="ml-[1px] mt-[1px] block h-1.5 w-3.5 rounded-[1px] bg-navy/70" />
        </span>
      </span>
    </div>
  )
}

function WorkspaceHUD() {
  return (
    <div className="relative z-20 flex items-center justify-between px-3 pb-1 pt-2">
      <span className="flex h-8 w-8 items-center justify-center rounded-full bg-white/70 text-sm text-navy/70 shadow-sm backdrop-blur">
        ‹
      </span>
      <span className="rounded-full bg-white/75 px-3 py-1 text-[11px] font-semibold tracking-wide text-navy shadow-sm backdrop-blur">
        CoCaptain
      </span>
      <span className="h-8 w-8" />
    </div>
  )
}

function ConnectionLines() {
  return (
    <svg
      className="pointer-events-none absolute inset-0 h-full w-full"
      viewBox="0 0 280 420"
      fill="none"
      aria-hidden="true"
    >
      <path
        d="M118 78 C 90 120, 78 160, 78 210"
        stroke="#4db6ff"
        strokeWidth="1.5"
        strokeLinecap="round"
        opacity="0.7"
      />
      <path
        className="draw-link"
        d="M162 78 C 198 120, 214 150, 214 198"
        stroke="#a78bfa"
        strokeWidth="1.5"
        strokeLinecap="round"
        opacity="0.75"
      />
      <path
        d="M100 248 C 118 250, 130 252, 148 255"
        stroke="#ffc83d"
        strokeWidth="1.5"
        strokeLinecap="round"
        opacity="0.75"
      />
      <path
        d="M200 248 C 180 252, 168 254, 158 255"
        stroke="#a78bfa"
        strokeWidth="1.5"
        strokeLinecap="round"
        opacity="0.45"
      />
    </svg>
  )
}

function CanvasNode({
  className,
  tone,
  label,
  title,
}: {
  className: string
  tone: 'cyan' | 'purple' | 'gold'
  label: string
  title: string
}) {
  const dot =
    tone === 'cyan'
      ? 'bg-cyan'
      : tone === 'purple'
        ? 'bg-purple'
        : 'bg-gold'

  return (
    <div
      className={`absolute w-[7.4rem] rounded-2xl border border-white/80 bg-white/80 p-2.5 shadow-[0_8px_24px_rgba(26,36,51,0.08)] backdrop-blur ${className}`}
    >
      <div className="flex items-center gap-1.5">
        <span className={`h-2 w-2 rounded-full ${dot}`} />
        <p className="text-[9px] font-medium uppercase tracking-[0.12em] text-muted">
          {label}
        </p>
      </div>
      <p className="mt-1 text-[12px] font-semibold leading-tight">{title}</p>
    </div>
  )
}

function ChatSheet() {
  return (
    <div className="chat-enter absolute inset-x-0 bottom-0 rounded-t-2xl border-t border-white/60 bg-white/95 px-3 pb-3 pt-2.5 shadow-[0_-8px_24px_rgba(26,36,51,0.08)] backdrop-blur">
      <div className="mb-2 flex items-center gap-2">
        <div className="h-6 w-6 overflow-hidden rounded-full bg-[#eef6ff]">
          <img
            src={brand.cocaptainAvatar}
            alt=""
            className="h-full w-full object-cover object-top"
          />
        </div>
        <p className="text-[11px] font-semibold">CoCaptain</p>
      </div>
      <p className="ml-8 rounded-2xl rounded-tr-sm bg-cyan/15 px-2.5 py-1.5 text-[11px] leading-snug text-navy">
        Map how this agent should research a topic.
      </p>
      <p className="mt-1.5 mr-2 rounded-2xl rounded-tl-sm bg-[#f2f2f7] px-2.5 py-1.5 text-[11px] leading-snug text-navy/80">
        Sources stay in Knowledge. Draft only if they agree.
      </p>
    </div>
  )
}

function NodeZoom() {
  return (
    <div className="relative z-10 w-full max-w-[16rem] rounded-3xl border border-white/80 bg-white/90 p-4 shadow-[0_18px_50px_rgba(26,36,51,0.1)] backdrop-blur">
      <p className="text-[10px] font-medium uppercase tracking-[0.14em] text-muted">
        Knowledge
      </p>
      <div className="mt-3 flex items-start gap-3">
        <span className="mt-1 h-8 w-8 shrink-0 rounded-full bg-cyan/20" />
        <div>
          <p className="text-sm font-semibold">Sources</p>
          <p className="mt-1 text-[12px] leading-relaxed text-muted">
            Notes and links the agent may use before it writes.
          </p>
        </div>
      </div>
    </div>
  )
}

export function MiniHome() {
  return (
    <div className="grid grid-cols-2 gap-2">
      <MiniAgent name="CoCaptain" src={brand.cocaptainAvatar} />
      <MiniAgent name="CoStar" src={brand.costarAvatar} />
    </div>
  )
}

function MiniAgent({ name, src }: { name: string; src: string }) {
  return (
    <div className="rounded-xl bg-[#f2f2f7] px-2 py-3">
      <div className="mx-auto h-10 w-10 overflow-hidden rounded-full bg-white">
        <img src={src} alt="" className="h-full w-full object-cover object-top" />
      </div>
      <p className="mt-1.5 text-center text-[10px] font-semibold">{name}</p>
    </div>
  )
}

export function MiniCanvas() {
  return (
    <div className="relative h-20">
      <svg className="absolute inset-0 h-full w-full" aria-hidden="true">
        <line
          x1="28%"
          y1="38%"
          x2="72%"
          y2="62%"
          stroke="#a78bfa"
          strokeWidth="1.5"
        />
      </svg>
      <span className="absolute left-1 top-2 rounded-full bg-cyan/20 px-2 py-0.5 text-[10px] font-medium">
        Knowledge
      </span>
      <span className="absolute bottom-1 right-1 rounded-full bg-gold/30 px-2 py-0.5 text-[10px] font-medium">
        Condition
      </span>
    </div>
  )
}

export function MiniCollab() {
  return (
    <div>
      <div className="flex -space-x-2">
        <div className="h-8 w-8 overflow-hidden rounded-full border-2 border-white bg-[#eef6ff]">
          <img
            src={brand.cocaptainAvatar}
            alt=""
            className="h-full w-full object-cover object-top"
          />
        </div>
        <div className="h-8 w-8 overflow-hidden rounded-full border-2 border-white bg-[#f4eefe]">
          <img
            src={brand.costarAvatar}
            alt=""
            className="h-full w-full object-cover object-top"
          />
        </div>
      </div>
      <p className="mt-2 text-[11px] text-muted">Review before you publish.</p>
    </div>
  )
}
