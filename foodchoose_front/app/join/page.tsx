"use client";

import Image from "next/image";
import { useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useRef, useState } from "react";
import { auth, db } from "@/lib/firebase";
import { signInAnonymously } from "firebase/auth";
import {
  collection,
  query,
  where,
  limit,
  getDocs,
  doc,
  onSnapshot,
  updateDoc,
  setDoc,
  increment,
  Timestamp,
} from "firebase/firestore";

/* ───── 타입 ───── */
interface Room {
  id: string;
  code: string;
  hostId: string;
  status: string;
  participantCount: number;
  submittedCount: number;
  recommendations: string[];
  recommendationReasons: Record<string, string>;
  votes: Record<string, number>;
  finalFood?: string;
  decisionMethod?: string;
  participants: Record<string, string>; // uid → 닉네임
}

type Phase =
  | "loading"
  | "nickname"
  | "joining"
  | "error"
  | "lobby"
  | "input"
  | "waiting"
  | "voting"
  | "done";

/* ─────────────────── 메인 ─────────────────── */
function JoinContent() {
  const searchParams = useSearchParams();
  const code = searchParams.get("code") ?? "";

  const [phase, setPhase] = useState<Phase>("loading");
  const [error, setError] = useState("");
  const [room, setRoom] = useState<Room | null>(null);
  const [uid, setUid] = useState("");
  const [nickname, setNickname] = useState("");
  const joinedRef = useRef(false);
  const appCheckDoneRef = useRef(false);

  /* ── 0) 앱 열기 시도 → 1.5초 후 없으면 웹으로 진행 ── */
  useEffect(() => {
    if (!code) {
      appCheckDoneRef.current = true;
      initAuth();
      return;
    }

    const appUrl = `foodchoose://join?code=${code}`;
    window.location.href = appUrl;

    let timer: ReturnType<typeof setTimeout>;
    const handleVisibilityChange = () => {
      if (document.hidden) clearTimeout(timer);
    };
    document.addEventListener("visibilitychange", handleVisibilityChange);

    timer = setTimeout(() => {
      document.removeEventListener("visibilitychange", handleVisibilityChange);
      if (!appCheckDoneRef.current) {
        appCheckDoneRef.current = true;
        initAuth();
      }
    }, 1500);

    return () => {
      clearTimeout(timer);
      document.removeEventListener("visibilitychange", handleVisibilityChange);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [code]);

  /* ── 1) 익명 로그인 → 닉네임 입력 단계 ── */
  const initAuth = useCallback(async () => {
    if (!code) {
      setError("초대 코드가 없습니다.");
      setPhase("error");
      return;
    }
    try {
      const cred = await signInAnonymously(auth);
      setUid(cred.user.uid);
      setPhase("nickname");
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "알 수 없는 오류");
      setPhase("error");
    }
  }, [code]);

  /* ── 2) 닉네임 확정 → 방 찾기 → 참가 → 실시간 구독 ── */
  const joinWithNickname = useCallback(
    async (name: string) => {
      if (!code || !uid) return;
      setNickname(name);
      setPhase("joining");
      try {
        const q = query(
          collection(db, "rooms"),
          where("code", "==", code.toUpperCase()),
          limit(1),
        );
        const snap = await getDocs(q);
        if (snap.empty) {
          setError("방을 찾을 수 없습니다.");
          setPhase("error");
          return;
        }

        const roomId = snap.docs[0].id;

        if (!joinedRef.current) {
          joinedRef.current = true;
          await updateDoc(doc(db, "rooms", roomId), {
            participantCount: increment(1),
            [`participants.${uid}`]: name,
          });
        }

        onSnapshot(doc(db, "rooms", roomId), (docSnap) => {
          if (!docSnap.exists()) return;
          const d = docSnap.data();
          setRoom({
            id: docSnap.id,
            code: d.code,
            hostId: d.hostId,
            status: d.status,
            participantCount: d.participantCount ?? 0,
            submittedCount: d.submittedCount ?? 0,
            recommendations: d.recommendations ?? [],
            recommendationReasons: d.recommendationReasons ?? {},
            votes: d.votes ?? {},
            finalFood: d.finalFood,
            decisionMethod: d.decisionMethod,
            participants: d.participants ?? {},
          });
        });
      } catch (e: unknown) {
        setError(e instanceof Error ? e.message : "알 수 없는 오류");
        setPhase("error");
      }
    },
    [code, uid],
  );

  /* ── 3) room.status 변경 → phase 전환 ── */
  useEffect(() => {
    if (!room) return;
    switch (room.status) {
      case "waiting":
        setPhase("lobby");
        break;
      case "inputting":
        setPhase((prev) => (prev === "waiting" ? prev : "input"));
        break;
      case "voting":
        setPhase("voting");
        break;
      case "done":
        setPhase("done");
        break;
    }
  }, [room?.status]);

  /* ── 렌더 ── */
  if (phase === "loading" || phase === "joining") return <LoadingView />;
  if (phase === "nickname") return <NicknameView onSubmit={joinWithNickname} />;
  if (phase === "error") return <ErrorView message={error} />;
  if (!room) return <LoadingView />;

  return (
    <>
      {phase === "lobby" && <LobbyView room={room} />}
      {phase === "input" && (
        <InputView
          room={room}
          uid={uid}
          nickname={nickname}
          onDone={() => setPhase("waiting")}
        />
      )}
      {phase === "waiting" && <WaitingView room={room} />}
      {phase === "voting" && <VotingView room={room} uid={uid} />}
      {phase === "done" && <DoneView room={room} />}
    </>
  );
}

/* ─────────────────── LoadingView ─────────────────── */
function LoadingView() {
  return (
    <PageWrapper>
      <GradientHeader>
        <HeaderIcon />
        <HeaderTitle>연결 중...</HeaderTitle>
        <HeaderDesc>앱이 설치되어 있으면 자동으로 열립니다</HeaderDesc>
      </GradientHeader>
      <div className="flex flex-col items-center gap-5 px-7 pt-10">
        <Spinner />
        <p className="text-[13px] text-[#636E72] text-center">
          앱이 없으면 잠시 후 웹에서 자동으로 진행됩니다
        </p>
      </div>
    </PageWrapper>
  );
}

/* ─────────────────── NicknameView ─────────────────── */
function NicknameView({ onSubmit }: { onSubmit: (name: string) => void }) {
  const [value, setValue] = useState("");
  const submit = () => {
    const name = value.trim();
    if (name) onSubmit(name);
  };

  return (
    <PageWrapper>
      <GradientHeader>
        <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1.5 text-[12px] font-semibold tracking-[0.18em] text-white/82">
          <span className="h-2 w-2 rounded-full bg-[#ffba78]" />
          QUICK JOIN
        </div>
        <HeaderIcon />
        <HeaderTitle>뭐 먹을건데</HeaderTitle>
        <HeaderDesc>
          방에 입장하기 전에 닉네임을 정해주세요.
          <br />
          친구들이 바로 알아볼 수 있게 보여집니다.
        </HeaderDesc>
      </GradientHeader>
      <div className="px-5">
        <div className="relative -mt-9 rounded-[30px] border border-white/70 bg-white/92 p-5 shadow-[0_20px_48px_rgba(32,38,51,0.12)] backdrop-blur-sm">
          <div className="mb-5 flex items-start justify-between gap-4">
            <div>
              <p className="text-[12px] font-bold tracking-[0.18em] text-[#ff7f50]">
                NICKNAME
              </p>
              <h2 className="mt-1 text-[24px] font-black tracking-[-0.05em] text-[#202633]">
                어떤 이름으로
                <br />
                들어갈까요?
              </h2>
            </div>
            <div className="rounded-[18px] bg-[#fff4ed] px-3 py-2 text-[12px] font-semibold text-[#ff7a45]">
              최대 10자
            </div>
          </div>

          <div className="mb-4 rounded-[22px] border border-[#ebe6e0] bg-[linear-gradient(180deg,#fffdfa_0%,#fff4ed_100%)] p-4">
            <div className="mb-2 flex items-center justify-between">
              <span className="text-[12px] font-semibold text-[#5d677d]">
                프로필 이름
              </span>
              <span className="text-[12px] font-medium text-[#a1a6b1]">
                {value.trim().length}/10
              </span>
            </div>
            <div className="flex items-center gap-3">
              <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-[16px] bg-[#202633] text-xl text-white">
                {value.trim().charAt(0) || "?"}
              </div>
              <input
                type="text"
                value={value}
                onChange={(e) => setValue(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && submit()}
                placeholder="예) 홍길동"
                maxLength={10}
                autoFocus
                className="w-full bg-transparent text-[22px] font-black tracking-[-0.04em] text-[#202633] placeholder:text-[#c7ccd5] outline-none"
              />
            </div>
          </div>

          <div className="mb-5 flex flex-wrap gap-2">
            {["배고픈호랑이", "치킨러버", "오늘은한식", "매운맛장인"].map((preset) => (
              <button
                key={preset}
                type="button"
                onClick={() => setValue(preset)}
                className="rounded-full border border-[#ebe6e0] bg-[#fcfaf8] px-3 py-2 text-[13px] font-medium text-[#5d677d] transition hover:border-[#ffb08e] hover:text-[#ff7a45]"
              >
                {preset}
              </button>
            ))}
          </div>

          <GradientButton onClick={submit} disabled={!value.trim()}>
            입장하기
          </GradientButton>
        </div>

        <p className="px-2 pt-4 text-center text-[13px] leading-5 text-[#7b808a]">
          닉네임은 방 참가자 목록과 결과 화면에 표시됩니다.
        </p>
      </div>
    </PageWrapper>
  );
}

/* ─────────────────── ErrorView ─────────────────── */
function ErrorView({ message }: { message: string }) {
  return (
    <PageWrapper>
      <GradientHeader>
        <HeaderIcon />
        <HeaderTitle>오류 발생</HeaderTitle>
      </GradientHeader>
      <div className="px-7 pt-8 space-y-5 text-center">
        <p className="text-[15px] text-[#636E72]">{message}</p>
        <GradientButton href="/">홈으로 돌아가기</GradientButton>
      </div>
    </PageWrapper>
  );
}

/* ─────────────────── LobbyView ─────────────────── */
function LobbyView({ room }: { room: Room }) {
  const [copied, setCopied] = useState(false);

  const copyCode = () => {
    navigator.clipboard?.writeText(room.code).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };

  const shareLink = () => {
    const text = `🍽️ 뭐 먹을건데에 초대합니다!\n입장 코드: ${room.code}`;
    if (navigator.share) {
      navigator.share({ text });
    } else {
      navigator.clipboard?.writeText(text);
    }
  };

  const entries = Object.entries(room.participants).sort(([a], [b]) =>
    a === room.hostId ? -1 : b === room.hostId ? 1 : 0,
  );

  return (
    <PageWrapper>
      {/* 헤더 */}
      <div
        className="bg-gradient-to-br from-[#FF7A45] to-[#FFA07A] w-full text-white rounded-b-[32px] px-6 pt-7 pb-7"
        style={{ boxShadow: "0 8px 24px rgba(255,107,53,0.22)" }}
      >
        <div className="inline-flex items-center gap-1.5 bg-white/20 px-3 py-1.5 rounded-full mb-5">
          <span className="text-sm">🍽️</span>
          <span className="text-[13px] font-semibold">참가자</span>
        </div>

        {/* 코드 카드 */}
        <div className="flex justify-center mb-2">
          <button
            onClick={copyCode}
            className="bg-white rounded-[20px] px-7 py-[18px] flex items-center gap-3 transition hover:shadow-xl"
            style={{ boxShadow: "0 6px 20px rgba(0,0,0,0.12)" }}
          >
            <span className="text-[38px] font-black tracking-[10px] text-[#FF8C69]">
              {room.code}
            </span>
            <span className="text-[#FF8C69]/50 text-xl">📋</span>
          </button>
        </div>
        <p className="text-center text-[12px] text-white/70 mb-5">
          {copied ? "코드가 복사됐어요! 👍" : "탭하면 복사돼요"}
        </p>

        {/* 공유 버튼 */}
        <button
          onClick={shareLink}
          className="w-full flex items-center justify-center gap-2 border border-white/60 rounded-[12px] py-3 text-white text-[14px] font-medium hover:bg-white/10 transition"
        >
          <span>📤</span>
          <span>친구에게 링크 공유</span>
        </button>
      </div>

      {/* 참가자 섹션 */}
      <div className="px-6 pt-6 pb-8 space-y-5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="text-lg">👥</span>
            <span className="text-[18px] font-extrabold text-[#2D3436]">
              참가자 {room.participantCount}명
            </span>
          </div>
          <span
            className={`text-[12px] font-semibold px-[10px] py-1 rounded-full ${
              room.participantCount >= 2
                ? "text-[#00B894] bg-[#00B894]/10"
                : "text-[#636E72] bg-[#DFE6E9]/60"
            }`}
          >
            {room.participantCount >= 2 ? "시작 가능" : "1명 더 필요"}
          </span>
        </div>

        {/* 참가자 이름 리스트 */}
        <div className="space-y-2">
          {entries.length > 0
            ? entries.map(([entryUid, name]) => {
                const isHost = entryUid === room.hostId;
                return (
                  <div
                    key={entryUid}
                    className="flex items-center gap-3 bg-white rounded-[12px] border border-[#DFE6E9] px-4 py-3"
                  >
                    <div
                      className={`w-9 h-9 rounded-[10px] flex items-center justify-center text-lg ${
                        isHost ? "bg-[#FF8C69]/[0.12]" : "bg-[#FF6B35]/[0.08]"
                      }`}
                    >
                      {isHost ? "👑" : "👤"}
                    </div>
                    <span className="flex-1 text-[16px] font-medium text-[#2D3436]">
                      {name}
                    </span>
                    {isHost && (
                      <span className="text-[11px] font-semibold text-[#FF8C69] bg-[#FF8C69]/[0.12] px-2 py-0.5 rounded-full">
                        방장
                      </span>
                    )}
                  </div>
                );
              })
            : Array.from({ length: room.participantCount }).map((_, i) => (
                <div
                  key={i}
                  className="flex items-center gap-3 bg-white rounded-[12px] border border-[#DFE6E9] px-4 py-3 opacity-50"
                >
                  <div className="w-9 h-9 rounded-[10px] bg-[#DFE6E9]/60 flex items-center justify-center text-lg">
                    👤
                  </div>
                  <span className="text-[16px] text-[#636E72]">
                    {i === 0 ? "방장" : `참가자 ${i + 1}`}
                  </span>
                </div>
              ))}
        </div>

        {/* 대기 메시지 */}
        <div className="flex items-center justify-center gap-3 bg-[#FF8C69]/[0.08] rounded-[16px] border border-[#FF8C69]/15 px-5 py-4">
          <Spinner small />
          <span className="text-[14px] font-medium text-[#FF8C69]">
            방장이 시작할 때까지 기다려주세요 👀
          </span>
        </div>
      </div>
    </PageWrapper>
  );
}

/* ─────────────────── InputView ─────────────────── */
function InputView({
  room,
  uid,
  nickname,
  onDone,
}: {
  room: Room;
  uid: string;
  nickname: string;
  onDone: () => void;
}) {
  const [wants, setWants] = useState<string[]>([]);
  const [donts, setDonts] = useState<string[]>([]);
  const [wantInput, setWantInput] = useState("");
  const [dontInput, setDontInput] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const addTag = (
    text: string,
    list: string[],
    setList: React.Dispatch<React.SetStateAction<string[]>>,
    setInput: React.Dispatch<React.SetStateAction<string>>,
  ) => {
    const val = text.trim();
    if (!val || list.includes(val)) return;
    setList((prev) => [...prev, val]);
    setInput("");
  };

  const submit = async () => {
    if (wants.length < 3) {
      alert("먹고 싶은 음식을 3개 이상 입력해주세요");
      return;
    }
    setSubmitting(true);
    try {
      await setDoc(doc(db, "rooms", room.id, "preferences", uid), {
        wantFoods: wants,
        dontWantFoods: donts,
        submittedAt: Timestamp.now(),
      });
      await updateDoc(doc(db, "rooms", room.id), {
        submittedCount: increment(1),
      });
      onDone();
    } catch (e: unknown) {
      alert("오류: " + (e instanceof Error ? e.message : e));
      setSubmitting(false);
    }
  };

  return (
    <PageWrapper>
      <div
        className="bg-gradient-to-br from-[#FF6B35] to-[#FF8C69] w-full text-white rounded-b-[32px] px-6 pt-8 pb-8 text-center"
        style={{ boxShadow: "0 8px 24px rgba(255,107,53,0.22)" }}
      >
        <div className="inline-flex items-center gap-1.5 bg-white/20 px-3 py-1.5 rounded-full mb-3">
          <span className="text-sm">🍽️</span>
          <span className="text-[13px] font-semibold">{nickname}</span>
        </div>
        <h1 className="text-[28px] font-black tracking-[-0.5px] text-white">
          음식 선호도 입력
        </h1>
      </div>

      <div className="px-6 pt-6 pb-8 space-y-6">
        {/* 먹고 싶은 음식 */}
        <div>
          <div className="flex items-center gap-3 mb-3">
            <div className="w-9 h-9 rounded-[10px] bg-[#00B894]/[0.12] flex items-center justify-center text-lg">
              ❤️
            </div>
            <div>
              <p className="text-[15px] font-extrabold text-[#2D3436]">
                먹고 싶은 음식
              </p>
              <p className="text-[11px] text-[#636E72]">최소 3개 입력해주세요</p>
            </div>
          </div>
          <div className="flex gap-2 mb-3">
            <input
              type="text"
              value={wantInput}
              onChange={(e) => setWantInput(e.target.value)}
              onKeyDown={(e) =>
                e.key === "Enter" &&
                addTag(wantInput, wants, setWants, setWantInput)
              }
              placeholder="예: 치킨, 피자..."
              className="flex-1 bg-white border border-[#DFE6E9] rounded-[12px] px-4 py-3 text-[15px] text-[#2D3436] placeholder-[#DFE6E9] focus:outline-none focus:border-[#00B894] transition"
            />
            <button
              onClick={() => addTag(wantInput, wants, setWants, setWantInput)}
              className="w-12 h-12 rounded-[12px] bg-[#00B894] text-white text-2xl font-bold flex items-center justify-center shrink-0 transition hover:opacity-90"
            >
              +
            </button>
          </div>
          <div className="flex flex-wrap gap-2 min-h-7">
            {wants.map((tag) => (
              <span
                key={tag}
                className="inline-flex items-center gap-1 px-3 py-1 rounded-full text-[13px] font-medium text-[#00B894] bg-[#00B894]/10 border border-[#00B894]/25"
              >
                {tag}
                <button
                  onClick={() => setWants((p) => p.filter((t) => t !== tag))}
                  className="ml-1 opacity-60 hover:opacity-100"
                >
                  ✕
                </button>
              </span>
            ))}
          </div>
        </div>

        {/* 먹기 싫은 음식 */}
        <div>
          <div className="flex items-center gap-3 mb-3">
            <div className="w-9 h-9 rounded-[10px] bg-[#E17055]/10 flex items-center justify-center text-lg">
              🙅
            </div>
            <div>
              <p className="text-[15px] font-extrabold text-[#2D3436]">
                먹기 싫은 음식
              </p>
              <p className="text-[11px] text-[#636E72]">선택사항이에요</p>
            </div>
          </div>
          <div className="flex gap-2 mb-3">
            <input
              type="text"
              value={dontInput}
              onChange={(e) => setDontInput(e.target.value)}
              onKeyDown={(e) =>
                e.key === "Enter" &&
                addTag(dontInput, donts, setDonts, setDontInput)
              }
              placeholder="예: 초밥, 회..."
              className="flex-1 bg-white border border-[#DFE6E9] rounded-[12px] px-4 py-3 text-[15px] text-[#2D3436] placeholder-[#DFE6E9] focus:outline-none focus:border-[#E17055] transition"
            />
            <button
              onClick={() => addTag(dontInput, donts, setDonts, setDontInput)}
              className="w-12 h-12 rounded-[12px] bg-[#E17055] text-white text-2xl font-bold flex items-center justify-center shrink-0 transition hover:opacity-90"
            >
              +
            </button>
          </div>
          <div className="flex flex-wrap gap-2 min-h-7">
            {donts.map((tag) => (
              <span
                key={tag}
                className="inline-flex items-center gap-1 px-3 py-1 rounded-full text-[13px] font-medium text-[#E17055] bg-[#E17055]/10 border border-[#E17055]/25"
              >
                {tag}
                <button
                  onClick={() => setDonts((p) => p.filter((t) => t !== tag))}
                  className="ml-1 opacity-60 hover:opacity-100"
                >
                  ✕
                </button>
              </span>
            ))}
          </div>
        </div>

        <GradientButton
          onClick={submit}
          disabled={submitting || wants.length < 3}
        >
          {submitting ? "제출 중..." : `제출하기 (${wants.length}/3)`}
        </GradientButton>
      </div>
    </PageWrapper>
  );
}

/* ─────────────────── WaitingView ─────────────────── */
function WaitingView({ room }: { room: Room }) {
  const allDone = room.submittedCount >= room.participantCount;
  const progress =
    room.participantCount > 0
      ? room.submittedCount / room.participantCount
      : 0;

  return (
    <PageWrapper>
      <div
        className="bg-gradient-to-br from-[#FF6B35] to-[#FF8C69] w-full text-white rounded-b-[32px] px-6 pt-8 pb-8 text-center"
        style={{ boxShadow: "0 8px 24px rgba(255,107,53,0.22)" }}
      >
        <h1 className="text-[28px] font-black tracking-[-0.5px]">
          결과 기다리는 중
        </h1>
      </div>
      <div className="px-7 pt-10 pb-8 flex flex-col items-center">
        <div className="text-[64px] mb-6">🍳</div>
        {allDone ? (
          <>
            <p className="text-[19px] font-extrabold text-[#2D3436] text-center mb-2 leading-8">
              AI가 음식을
              <br />
              추천하고 있어요...
            </p>
            <div className="mt-6">
              <Spinner />
            </div>
          </>
        ) : (
          <>
            <p className="text-[19px] font-extrabold text-[#2D3436] text-center mb-8 leading-8">
              친구들이 선호도를
              <br />
              입력하고 있어요
            </p>
            <div className="w-full bg-[#DFE6E9] rounded-full h-3 overflow-hidden mb-3">
              <div
                className="bg-gradient-to-r from-[#FF6B35] to-[#FF8C69] h-full rounded-full transition-all duration-500"
                style={{ width: `${progress * 100}%` }}
              />
            </div>
            <p className="text-[#636E72] text-[14px]">
              {room.submittedCount} / {room.participantCount}명 완료
            </p>
          </>
        )}
      </div>
    </PageWrapper>
  );
}

/* ─────────────────── VotingView ─────────────────── */
function VotingView({ room, uid }: { room: Room; uid: string }) {
  const [myVote, setMyVote] = useState<string | null>(null);
  const medals = ["🥇", "🥈", "🥉"];
  const totalVotes = Object.values(room.votes).reduce((a, b) => a + b, 0);
  const isHost = room.hostId === uid;

  const vote = async (food: string) => {
    if (myVote) return;
    setMyVote(food);
    await updateDoc(doc(db, "rooms", room.id), {
      [`votes.${food}`]: increment(1),
    });
  };

  const finalizeVote = async () => {
    const entries = Object.entries(room.votes);
    if (!entries.length) return;
    const winner = entries.reduce((a, b) => (a[1] >= b[1] ? a : b))[0];
    await updateDoc(doc(db, "rooms", room.id), {
      finalFood: winner,
      decisionMethod: "vote",
      status: "done",
    });
  };

  const pickRandom = async () => {
    const foods = room.recommendations;
    if (!foods.length) return;
    const food = foods[Math.floor(Math.random() * foods.length)];
    await updateDoc(doc(db, "rooms", room.id), {
      finalFood: food,
      decisionMethod: "random",
      status: "done",
    });
  };

  return (
    <PageWrapper>
      <div
        className="bg-gradient-to-br from-[#FF6B35] to-[#FF8C69] w-full text-white rounded-b-[32px] px-6 pt-8 pb-8 text-center"
        style={{ boxShadow: "0 8px 24px rgba(255,107,53,0.22)" }}
      >
        <h1 className="text-[28px] font-black tracking-[-0.5px]">
          AI 추천 Top 3
        </h1>
        <p className="mt-1 text-[14px] text-white/80">
          마음에 드는 메뉴에 투표해요!
        </p>
      </div>

      <div className="px-6 pt-6 pb-8 space-y-4">
        {room.recommendations.map((food, i) => {
          const count = room.votes[food] ?? 0;
          const isMyVote = myVote === food;
          return (
            <div
              key={food}
              className={`bg-white rounded-[14px] border-2 p-4 flex items-start gap-4 transition ${
                isMyVote
                  ? "border-[#FF6B35] bg-[#FF6B35]/[0.04]"
                  : "border-[#DFE6E9]"
              }`}
            >
              <span className="text-3xl shrink-0">{medals[i]}</span>
              <div className="flex-1 min-w-0">
                <p className="text-[17px] font-extrabold text-[#2D3436]">
                  {food}
                </p>
                {room.recommendationReasons[food] && (
                  <p className="text-[12px] text-[#636E72] mt-1 leading-5">
                    {room.recommendationReasons[food]}
                  </p>
                )}
                {totalVotes > 0 && (
                  <p className="text-[13px] font-medium text-[#636E72] mt-1">
                    {count}표
                  </p>
                )}
              </div>
              {!myVote ? (
                <button
                  onClick={() => vote(food)}
                  className="shrink-0 bg-gradient-to-br from-[#FF6B35] to-[#FF8C69] text-white font-bold px-4 py-2 rounded-[10px] text-[14px] transition hover:opacity-90"
                >
                  투표
                </button>
              ) : isMyVote ? (
                <span className="text-[#FF6B35] text-2xl shrink-0 font-bold">
                  ✓
                </span>
              ) : null}
            </div>
          );
        })}

        {isHost ? (
          <div className="flex gap-3 pt-2">
            <button
              onClick={finalizeVote}
              className="flex-1 h-14 rounded-[16px] bg-gradient-to-br from-[#FF6B35] to-[#FF8C69] text-white font-extrabold text-[15px] transition hover:opacity-90"
              style={{ boxShadow: "0 6px 14px rgba(255,107,53,0.30)" }}
            >
              🗳️ 투표 확정
            </button>
            <button
              onClick={pickRandom}
              className="flex-1 h-14 rounded-[16px] bg-[#FDB74A] text-white font-extrabold text-[15px] transition hover:opacity-90"
              style={{ boxShadow: "0 6px 14px rgba(253,183,74,0.30)" }}
            >
              🎲 랜덤
            </button>
          </div>
        ) : (
          <div className="flex items-center justify-center gap-3 bg-[#FF8C69]/[0.08] rounded-[16px] border border-[#FF8C69]/15 px-5 py-4">
            <Spinner small />
            <span className="text-[14px] font-medium text-[#FF8C69]">
              {!myVote
                ? "원하는 음식에 투표해주세요!"
                : "방장이 결과를 확정할 때까지 기다려주세요"}
            </span>
          </div>
        )}
      </div>
    </PageWrapper>
  );
}

/* ─────────────────── DoneView ─────────────────── */
function DoneView({ room }: { room: Room }) {
  const method =
    room.decisionMethod === "vote" ? "🗳️ 투표로 결정!" : "🎲 랜덤으로 결정!";
  return (
    <PageWrapper>
      <div
        className="bg-gradient-to-br from-[#FF6B35] to-[#FDB74A] w-full text-white rounded-b-[32px] px-6 pt-8 pb-8 text-center"
        style={{ boxShadow: "0 8px 24px rgba(255,107,53,0.25)" }}
      >
        <h1 className="text-[28px] font-black tracking-[-0.5px]">
          오늘의 메뉴 결정!
        </h1>
      </div>
      <div className="px-7 pt-10 pb-8 flex flex-col items-center text-center space-y-5">
        <div className="text-[72px]">🎉</div>
        <p className="text-[17px] text-[#636E72]">오늘의 메뉴는...</p>
        <div
          className="w-full bg-gradient-to-br from-[#FF6B35] to-[#FDB74A] rounded-[20px] px-8 py-7"
          style={{ boxShadow: "0 8px 24px rgba(255,107,53,0.30)" }}
        >
          <p className="text-[40px] font-black text-white">
            {room.finalFood ?? "?"}
          </p>
        </div>
        <p className="text-[#636E72] text-[15px]">{method}</p>
        <div className="w-full pt-2">
          <GradientButton href="/">처음으로 돌아가기</GradientButton>
        </div>
      </div>
    </PageWrapper>
  );
}

/* ─────────────────── 공용 컴포넌트 ─────────────────── */
function PageWrapper({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative min-h-screen overflow-hidden bg-[var(--bg)]">
      <div className="pointer-events-none fixed inset-0 -z-10 overflow-hidden">
        <div className="absolute left-1/2 top-[-180px] h-[420px] w-[720px] -translate-x-1/2 rounded-full bg-[radial-gradient(circle,_rgba(255,148,99,0.34)_0%,_rgba(255,148,99,0)_70%)]" />
        <div className="absolute left-[-110px] top-[26%] h-[320px] w-[320px] rounded-full bg-[radial-gradient(circle,_rgba(255,186,120,0.24)_0%,_rgba(255,186,120,0)_72%)]" />
        <div className="absolute right-[-120px] top-[18%] h-[280px] w-[280px] rounded-full bg-[radial-gradient(circle,_rgba(94,109,142,0.18)_0%,_rgba(94,109,142,0)_72%)]" />
      </div>
      <div className="mx-auto w-full max-w-[440px] min-h-screen px-5 py-5 sm:py-8">
        {children}
      </div>
    </div>
  );
}

function GradientHeader({ children }: { children: React.ReactNode }) {
  return (
    <div
      className="relative overflow-hidden rounded-[34px] border border-white/70 bg-[linear-gradient(145deg,#202633_0%,#343b4f_42%,#ff925b_140%)] px-7 pb-12 pt-8 text-center text-white"
      style={{ boxShadow: "0 24px 60px rgba(43, 37, 32, 0.16)" }}
    >
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,rgba(255,255,255,0.2),transparent_40%)]" />
      <div className="absolute right-[-32px] top-[-28px] h-28 w-28 rounded-full border border-white/15 bg-white/10 blur-2xl" />
      <div className="relative">{children}</div>
    </div>
  );
}

function HeaderIcon() {
  return (
    <div className="relative mx-auto mb-5 flex h-[118px] w-[118px] items-center justify-center">
      <div className="absolute inset-0 rounded-[30px] bg-[#ff9b68]/30 blur-2xl" />
      <div className="relative flex h-[118px] w-[118px] items-center justify-center rounded-[32px] border border-white/20 bg-white/12 backdrop-blur-md">
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
  );
}

function HeaderTitle({ children }: { children: React.ReactNode }) {
  return (
    <h1 className="text-[34px] font-black tracking-[-0.06em] leading-[1.05] text-white">
      {children}
    </h1>
  );
}

function HeaderDesc({ children }: { children: React.ReactNode }) {
  return (
    <p className="mt-3 text-[14px] leading-6 text-white/[0.8]">
      {children}
    </p>
  );
}

function GradientButton({
  children,
  onClick,
  disabled,
  href,
  className,
}: {
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  href?: string;
  className?: string;
}) {
  const cls = `flex items-center justify-center gap-2 w-full h-14 rounded-[18px] bg-[linear-gradient(135deg,#ff7a45_0%,#ff9a62_100%)] text-white font-extrabold text-[17px] transition hover:opacity-90 active:opacity-80 ${className ?? ""}`;

  if (href) {
    return (
      <a
        href={href}
        className={cls}
        style={{ boxShadow: "0 6px 14px rgba(255,107,53,0.35)" }}
      >
        {children}
      </a>
    );
  }

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={`${cls} disabled:from-[#DFE6E9] disabled:to-[#DFE6E9] disabled:shadow-none disabled:text-[#636E72] disabled:cursor-not-allowed`}
      style={
        disabled ? undefined : { boxShadow: "0 6px 14px rgba(255,107,53,0.35)" }
      }
    >
      {children}
    </button>
  );
}

function Spinner({ small }: { small?: boolean }) {
  return (
    <div
      className={`${small ? "w-[18px] h-[18px] border-2" : "w-8 h-8 border-[3px]"} border-[#FF6B35] border-t-transparent rounded-full animate-spin shrink-0`}
    />
  );
}

/* ─────────────────── 엔트리 ─────────────────── */
export default function JoinPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-[#FFF9F5] flex items-center justify-center">
          <div className="w-8 h-8 border-[3px] border-[#FF6B35] border-t-transparent rounded-full animate-spin" />
        </div>
      }
    >
      <JoinContent />
    </Suspense>
  );
}
