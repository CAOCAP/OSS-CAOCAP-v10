import type { ReactNode } from 'react'
import { brand } from './brand.ts'

const shots = {
  home: '/app/home.png',
  workspace: '/app/workspace.png',
  chat: '/app/chat.png',
}

export function ProductStage() {
  return (
    <div
      id="hero-product"
      className="relative mx-auto flex min-h-[34rem] max-w-5xl items-center justify-center px-4 py-10 lg:min-h-[42rem]"
    >
      <div
        className="pointer-events-none absolute left-1/2 top-1/2 h-[34rem] w-[34rem] -translate-x-1/2 -translate-y-1/2 rounded-full border border-cyan/15 lg:h-[42rem] lg:w-[42rem]"
        aria-hidden="true"
      />
      <div
        className="pointer-events-none absolute left-1/2 top-1/2 h-[24rem] w-[24rem] -translate-x-1/2 -translate-y-1/2 rounded-full border border-purple/15 lg:h-[30rem] lg:w-[30rem]"
        aria-hidden="true"
      />

      <div className="relative z-10 w-[250px] sm:w-[280px]">
        <PhoneBezel>
          <img
            src={shots.home}
            alt="CAOCAP Home with CoCaptain and CoStar"
            className="block w-full"
          />
        </PhoneBezel>
      </div>

      <div className="float-card absolute left-[2%] top-[16%] z-20 hidden w-[16.5rem] lg:block">
        <ShotCard
          src={shots.chat}
          alt="CoCaptain chat"
          className="h-[18.5rem] object-[center_42%]"
        />
      </div>
      <div className="float-card float-card-delayed absolute right-[1%] top-[8%] z-20 hidden w-[10.25rem] lg:block">
        <PhoneBezel>
          <img
            src={shots.workspace}
            alt="CoCaptain workspace canvas"
            className="block w-full"
          />
        </PhoneBezel>
      </div>
      <div className="float-card absolute bottom-[8%] left-[6%] z-20 hidden w-48 lg:block">
        <CollabCard />
      </div>
    </div>
  )
}

function PhoneBezel({ children }: { children: ReactNode }) {
  return (
    <div className="rounded-[2.55rem] bg-[#1c1c1e] p-[9px] shadow-[0_40px_80px_rgba(26,36,51,0.18)]">
      <div className="overflow-hidden rounded-[2.05rem] bg-[#f2f2f7]">
        {children}
      </div>
    </div>
  )
}

function ShotCard({
  src,
  alt,
  className,
}: {
  src: string
  alt: string
  className: string
}) {
  return (
    <div className="overflow-hidden rounded-[1.6rem] border border-white/80 bg-white shadow-[0_18px_50px_rgba(26,36,51,0.12)]">
      <img src={src} alt={alt} className={`w-full object-cover ${className}`} />
    </div>
  )
}

function CollabCard() {
  return (
    <div className="rounded-2xl bg-white/90 p-4 shadow-[0_18px_50px_rgba(26,36,51,0.1)] backdrop-blur">
      <div className="flex -space-x-2">
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
      <p className="mt-2 text-[12px] font-semibold">Together</p>
      <p className="mt-1 text-[11px] leading-snug text-muted">
        Review before you publish.
      </p>
    </div>
  )
}

export function MiniHome() {
  return (
    <div className="overflow-hidden rounded-xl bg-[#f2f2f7]">
      <img
        src={shots.home}
        alt=""
        className="h-28 w-full object-cover object-[center_18%]"
      />
    </div>
  )
}

export function MiniCanvas() {
  return (
    <div className="overflow-hidden rounded-xl">
      <img
        src={shots.workspace}
        alt=""
        className="h-20 w-full object-cover object-center"
      />
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
