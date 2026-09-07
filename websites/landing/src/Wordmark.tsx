import { brand } from './brand.ts'

export function Wordmark() {
  return (
    <a href="#top" className="inline-flex items-center gap-2.5 text-navy">
      <img
        src={brand.duoAppIcon}
        alt=""
        className="h-8 w-8 rounded-full"
      />
      <span className="text-[15px] font-semibold tracking-[0.18em]">CAOCAP</span>
    </a>
  )
}
