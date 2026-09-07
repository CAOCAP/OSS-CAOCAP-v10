import duoIcon from '@brand/appicons/duo/caocap_duo_appicon_1024.png'

export function Wordmark() {
  return (
    <a href="#top" className="inline-flex items-center gap-2.5 text-navy">
      <img src={duoIcon} alt="" className="h-8 w-8 rounded-[0.55rem]" />
      <span className="text-[15px] font-semibold tracking-[0.18em]">CAOCAP</span>
    </a>
  )
}
