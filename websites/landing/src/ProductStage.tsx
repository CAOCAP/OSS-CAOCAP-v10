import { brand } from './brand.ts'

export function ProductStage() {
  return (
    <div className="relative mx-auto flex min-h-[36rem] max-w-5xl items-center justify-center px-4 py-10 lg:min-h-[42rem]">
      <div
        className="pointer-events-none absolute left-1/2 top-1/2 h-[34rem] w-[34rem] -translate-x-1/2 -translate-y-1/2 rounded-full border border-cyan/15 lg:h-[42rem] lg:w-[42rem]"
        aria-hidden="true"
      />
      <div
        className="pointer-events-none absolute left-1/2 top-1/2 h-[24rem] w-[24rem] -translate-x-1/2 -translate-y-1/2 rounded-full border border-purple/15 lg:h-[30rem] lg:w-[30rem]"
        aria-hidden="true"
      />

      <PhoneHome />

      <div className="absolute left-[4%] top-[18%] hidden w-56 lg:block">
        <ChatCard />
      </div>
      <div className="absolute right-[2%] top-[14%] hidden w-52 lg:block">
        <CanvasCard />
      </div>
      <div className="absolute bottom-[12%] right-[8%] hidden w-48 lg:block">
        <CollabCard />
      </div>
    </div>
  )
}

function PhoneHome() {
  return (
    <div className="relative z-10 w-[280px] rounded-[2.4rem] border border-black/10 bg-[#1c1c1e] p-[10px] shadow-[0_40px_80px_rgba(26,36,51,0.18)] sm:w-[300px]">
      <div className="overflow-hidden rounded-[1.9rem] bg-[#f2f2f7]">
        <div className="flex items-center justify-between px-5 pt-3 text-[10px] font-medium text-navy/70">
          <span>9:41</span>
          <span className="h-3.5 w-20 rounded-full bg-black/80" />
          <span className="flex items-center gap-0.5">
            <span className="h-1.5 w-3.5 rounded-sm bg-navy/40" />
          </span>
        </div>
        <div className="px-5 pb-4 pt-6">
          <p className="text-[11px] text-muted">Home</p>
          <div className="mt-1 flex items-end justify-between">
            <h3 className="text-xl font-semibold tracking-tight">Your agents</h3>
            <span className="rounded-full bg-cyan px-2.5 py-1 text-[10px] font-medium text-white">
              Create
            </span>
          </div>
          <div className="mt-4 grid grid-cols-2 gap-2.5">
            <AgentTile name="CoCaptain" src={brand.cocaptainAvatar} />
            <AgentTile name="CoStar" src={brand.costarAvatar} />
          </div>
        </div>
        <div className="flex items-center justify-around border-t border-black/5 bg-white/70 px-6 py-2.5 text-[9px] text-muted">
          <span>Explore</span>
          <span className="font-semibold text-cyan">Home</span>
          <span>Communities</span>
        </div>
      </div>
    </div>
  )
}

function AgentTile({ name, src }: { name: string; src: string }) {
  return (
    <div className="rounded-2xl bg-white px-2 pb-4 pt-2 shadow-sm">
      <div className="flex justify-end">
        <span className="text-[10px] text-muted">···</span>
      </div>
      <div className="mx-auto h-16 w-16 overflow-hidden rounded-full bg-[#eef6ff]">
        <img src={src} alt="" className="h-full w-full object-cover object-top" />
      </div>
      <p className="mt-2 text-center text-[12px] font-semibold">{name}</p>
    </div>
  )
}

function ChatCard() {
  return (
    <div className="rounded-2xl bg-white/90 p-4 shadow-[0_18px_50px_rgba(26,36,51,0.1)] backdrop-blur">
      <div className="flex items-center gap-2">
        <div className="h-8 w-8 overflow-hidden rounded-full bg-[#eef6ff]">
          <img
            src={brand.cocaptainAvatar}
            alt=""
            className="h-full w-full object-cover object-top"
          />
        </div>
        <p className="text-xs font-medium">CoCaptain</p>
      </div>
      <p className="mt-3 rounded-2xl rounded-tl-sm bg-[#f2f2f7] px-3 py-2 text-[12px] leading-snug text-navy/80">
        Ready when you are. What should this agent do first?
      </p>
    </div>
  )
}

function CanvasCard() {
  return (
    <div className="rounded-2xl bg-white/90 p-4 shadow-[0_18px_50px_rgba(26,36,51,0.1)] backdrop-blur">
      <p className="text-[10px] font-medium uppercase tracking-[0.14em] text-muted">
        Canvas
      </p>
      <div className="relative mt-4 h-24">
        <span className="absolute left-2 top-1 rounded-full bg-cyan/20 px-2.5 py-1 text-[11px] font-medium text-navy">
          Knowledge
        </span>
        <span className="absolute right-1 top-10 rounded-full bg-purple/20 px-2.5 py-1 text-[11px] font-medium text-navy">
          Action
        </span>
        <span className="absolute bottom-0 left-8 rounded-full bg-gold/30 px-2.5 py-1 text-[11px] font-medium text-navy">
          Condition
        </span>
      </div>
    </div>
  )
}

function CollabCard() {
  return (
    <div className="rounded-2xl bg-white/90 p-4 shadow-[0_18px_50px_rgba(26,36,51,0.1)] backdrop-blur">
      <p className="text-[10px] font-medium uppercase tracking-[0.14em] text-muted">
        Together
      </p>
      <div className="mt-3 flex -space-x-2">
        <div className="h-9 w-9 overflow-hidden rounded-full border-2 border-white bg-[#eef6ff]">
          <img
            src={brand.cocaptainAvatar}
            alt=""
            className="h-full w-full object-cover object-top"
          />
        </div>
        <div className="h-9 w-9 overflow-hidden rounded-full border-2 border-white bg-[#f4eefe]">
          <img
            src={brand.costarAvatar}
            alt=""
            className="h-full w-full object-cover object-top"
          />
        </div>
      </div>
      <p className="mt-2 text-[12px] text-muted">Review before you publish.</p>
    </div>
  )
}
