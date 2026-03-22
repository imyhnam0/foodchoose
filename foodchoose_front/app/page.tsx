import Image from "next/image";

export default function Home() {
  return (
    <main className="relative min-h-screen overflow-hidden bg-[var(--bg)]">
      <div className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute left-1/2 top-[-180px] h-[420px] w-[720px] -translate-x-1/2 rounded-full bg-[radial-gradient(circle,_rgba(255,148,99,0.34)_0%,_rgba(255,148,99,0)_70%)]" />
        <div className="absolute left-[-110px] top-[26%] h-[320px] w-[320px] rounded-full bg-[radial-gradient(circle,_rgba(255,186,120,0.26)_0%,_rgba(255,186,120,0)_72%)]" />
        <div className="absolute right-[-120px] top-[18%] h-[280px] w-[280px] rounded-full bg-[radial-gradient(circle,_rgba(94,109,142,0.18)_0%,_rgba(94,109,142,0)_72%)]" />
        <div className="absolute inset-x-0 bottom-0 h-40 bg-[linear-gradient(180deg,rgba(255,249,245,0)_0%,rgba(255,249,245,0.92)_100%)]" />
      </div>

      <div className="mx-auto flex min-h-screen w-full max-w-[440px] flex-col px-5 py-5 sm:py-8">
        <div
          className="relative overflow-hidden rounded-[34px] border border-white/70 bg-[linear-gradient(145deg,#ff7a45_0%,#ff9a62_52%,#ffb07a_100%)] px-7 pb-8 pt-7 text-white"
          style={{ boxShadow: "0 24px 60px rgba(255,122,69,0.24)" }}
        >
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,rgba(255,255,255,0.22),transparent_40%)]" />
          <div className="absolute right-[-32px] top-[-28px] h-28 w-28 rounded-full border border-white/20 bg-[#ffd2ba]/20 blur-2xl" />
          <div className="relative">
            <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1.5 text-[12px] font-semibold tracking-[0.18em] text-white/82">
              <span className="h-2 w-2 rounded-full bg-[#ffba78]" />
              TODAY&apos;S PICK
            </div>
            <div className="mb-6 flex items-center justify-between gap-4">
              <div className="max-w-[190px]">
                <h1 className="text-[34px] font-black tracking-[-0.06em] leading-[1.05]">
                  뭐 먹을건데
                </h1>
                <p className="mt-3 text-[14px] leading-6 text-white/80">
                  정해진 카테고리에서 고르고
                  <br />
                  오늘 메뉴 하나를 정하는 푸드 룸.
                </p>
              </div>
              <div className="relative shrink-0">
                <div className="absolute inset-0 scale-110 rounded-[28px] bg-[#ff9b68]/30 blur-2xl" />
                <div className="relative flex h-[116px] w-[116px] items-center justify-center rounded-[30px] border border-white/20 bg-white/12 backdrop-blur-md">
                  <Image
                    src="/brand-icon.png"
                    alt="뭐 먹을건데 아이콘"
                    width={84}
                    height={84}
                    className="h-[84px] w-[84px] object-contain"
                    priority
                  />
                </div>
              </div>
            </div>
          </div>
         
        </div>

        <div className="space-y-6 px-1 pb-8 pt-6">
          <section className="space-y-4">

            <div className="grid grid-cols-2 gap-4">
              <FeatureTile
                emoji="❤️"
                title="먹고 싶은 음식"
                desc="정해진 카테고리 중 원하는 메뉴를 골라요."
              />
              <FeatureTile
                emoji="🙅"
                title="먹기 싫은 음식"
                desc="빼고 싶은 카테고리도 같이 반영해요."
              />
            </div>
          </section>

          <section className="rounded-[30px] border border-[rgba(52,59,79,0.08)] bg-white/88 p-5 shadow-[0_16px_40px_rgba(52,59,79,0.08)] backdrop-blur-sm">
            <div className="mb-4 flex items-center justify-between gap-3">
              <div>
                <p className="text-[12px] font-bold tracking-[0.18em] text-[#ff7f50]">
                  DOWNLOAD
                </p>
                <p className="mt-1 text-[20px] font-black tracking-[-0.04em] text-[#202633]">
                  앱으로 더 빠르게 시작
                </p>
              </div>
              <div className="rounded-[18px] bg-[#fff1e9] px-3 py-2 text-[12px] font-semibold text-[#ff7f50]">
                iOS / Android
              </div>
            </div>

            <div className="space-y-[14px]">
            <a
              href="#"
              className="flex h-14 w-full items-center justify-center gap-[10px] rounded-[18px] bg-[linear-gradient(135deg,#ff7a45_0%,#ff9a62_100%)] text-[17px] font-extrabold text-white transition hover:opacity-92 active:opacity-80"
              style={{ boxShadow: "0 12px 24px rgba(255,122,69,0.32)" }}
            >
              <span className="text-[22px]">🍎</span>
              <span>App Store 다운로드</span>
            </a>
            <a
              href="#"
              className="flex h-[56px] w-full items-center justify-center gap-[10px] rounded-[18px] border border-[#d9dee6] bg-[#f8f5f2] text-[16px] font-bold text-[#202633] transition hover:border-[#ff7a45]/40 hover:bg-white"
            >
              <span className="text-[22px]">📱</span>
              <span>Google Play 다운로드</span>
            </a>
          </div>
          </section>

          <p className="pb-2 pt-1 text-center text-xs text-[#636E72]/60">
            © 2026 뭐 먹을건데. All rights reserved.
          </p>
        </div>
      </div>
    </main>
  );
}

function HeroStat({ value, label }: { value: string; label: string }) {
  return (
    <div className="rounded-[18px] border border-white/12 bg-white/10 px-3 py-3 backdrop-blur-sm">
      <p className="text-[18px] font-black tracking-[-0.05em] text-white">
        {value}
      </p>
      <p className="mt-1 text-[11px] font-medium text-white/72">{label}</p>
    </div>
  );
}

function FeatureTile({
  emoji,
  title,
  desc,
}: {
  emoji: string;
  title: string;
  desc: string;
}) {
  return (
    <div className="rounded-[28px] border border-[rgba(255,140,105,0.22)] bg-white/92 p-5 shadow-[0_14px_36px_rgba(52,59,79,0.06)]">
      <div className="mb-7 text-[40px] leading-none">{emoji}</div>
      <h3 className="text-[17px] font-black tracking-[-0.05em] text-[#2e241f]">
        {title}
      </h3>
      <p className="mt-3 text-[14px] leading-7 text-[#7a675f]">{desc}</p>
    </div>
  );
}

function StepCard({
  step,
  emoji,
  title,
  desc,
}: {
  step: number;
  emoji: string;
  title: string;
  desc: string;
}) {
  return (
    <div
      className="flex items-start gap-4 rounded-[22px] border border-[#ece8e3] bg-[#fcfaf8] px-4 py-4 transition hover:-translate-y-0.5 hover:bg-white"
      style={{ boxShadow: "0 10px 24px rgba(45,52,54,0.05)" }}
    >
      <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-[14px] bg-[#fff1e9] text-xl">
        {emoji}
      </div>
      <div className="min-w-0">
        <div className="mb-1">
          <span className="rounded-full bg-[#fff1e9] px-2 py-0.5 text-[11px] font-bold text-[#ff7a45]">
            STEP {step}
          </span>
        </div>
        <p className="text-[15px] font-extrabold text-[#202633]">{title}</p>
        <p className="mt-1 text-[13px] leading-5 text-[#636E72]">{desc}</p>
      </div>
    </div>
  );
}
