export default function Home() {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-6">
      <div className="max-w-md w-full text-center">
        <div className="text-8xl mb-6">🍽️</div>
        <h1 className="text-4xl font-bold text-[#E85D04] mb-3">골라음식</h1>
        <p className="text-gray-500 mb-10">
          오늘 뭐 먹을지, AI가 정해드려요!
        </p>

        <div className="bg-white rounded-2xl shadow-lg p-8 mb-8">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">
            이렇게 사용해요
          </h2>
          <div className="space-y-4 text-left">
            <Step num={1} text="방을 만들고 친구들을 초대해요" />
            <Step num={2} text="먹고 싶은 것, 싫은 것을 입력해요" />
            <Step num={3} text="AI가 모두의 취향을 분석해 추천해요" />
            <Step num={4} text="투표로 최종 음식을 정해요!" />
          </div>
        </div>

        <div className="space-y-3">
          <a
            href="#"
            className="block w-full bg-[#E85D04] text-white font-bold py-4 rounded-xl text-lg hover:bg-[#d14f03] transition"
          >
            📱 앱 다운로드 (iOS)
          </a>
          <a
            href="#"
            className="block w-full bg-[#34A853] text-white font-bold py-4 rounded-xl text-lg hover:bg-[#2d9249] transition"
          >
            📱 앱 다운로드 (Android)
          </a>
        </div>

        <p className="text-xs text-gray-400 mt-8">
          © 2026 골라음식. All rights reserved.
        </p>
      </div>
    </main>
  );
}
function Step({ num, text }: { num: number; text: string }) {
  return (
    <div className="flex items-start gap-3">
      <span className="flex-shrink-0 w-7 h-7 bg-[#E85D04] text-white rounded-full flex items-center justify-center text-sm font-bold">
        {num}
      </span>
      <span className="text-gray-600 pt-0.5">{text}</span>
    </div>
  );
}

