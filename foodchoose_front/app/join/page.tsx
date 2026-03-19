"use client";

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
}

type Phase =
  | "loading"
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
  const joinedRef = useRef(false);
  const appCheckDoneRef = useRef(false);

  /* ── 0) 앱 열기 시도 → 1.5초 후 없으면 웹으로 진행 ── */
  useEffect(() => {
    if (!code) {
      appCheckDoneRef.current = true;
      init();
      return;
    }

    const appUrl = `foodchoose://join?code=${code}`;
    window.location.href = appUrl;

    let timer: ReturnType<typeof setTimeout>;

    const handleVisibilityChange = () => {
      if (document.hidden) {
        clearTimeout(timer);
      }
    };
    document.addEventListener("visibilitychange", handleVisibilityChange);

    timer = setTimeout(() => {
      document.removeEventListener("visibilitychange", handleVisibilityChange);
      if (!appCheckDoneRef.current) {
        appCheckDoneRef.current = true;
        init();
      }
    }, 1500);

    return () => {
      clearTimeout(timer);
      document.removeEventListener("visibilitychange", handleVisibilityChange);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [code]);

  /* ── 1) 익명 로그인 → 방 찾기 → 참가 ── */
  const init = useCallback(async () => {
    if (!code) {
      setError("초대 코드가 없습니다.");
      setPhase("error");
      return;
    }
    try {
      const cred = await signInAnonymously(auth);
      setUid(cred.user.uid);

      const q = query(
        collection(db, "rooms"),
        where("code", "==", code.toUpperCase()),
        limit(1)
      );
      const snap = await getDocs(q);
      if (snap.empty) {
        setError("방을 찾을 수 없습니다.");
        setPhase("error");
        return;
      }

      const roomDoc = snap.docs[0];
      const roomId = roomDoc.id;

      if (!joinedRef.current) {
        joinedRef.current = true;
        await updateDoc(doc(db, "rooms", roomId), {
          participantCount: increment(1),
        });
      }

      onSnapshot(doc(db, "rooms", roomId), (docSnap) => {
        if (!docSnap.exists()) return;
        const d = docSnap.data();
        const r: Room = {
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
        };
        setRoom(r);
      });
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "알 수 없는 오류");
      setPhase("error");
    }
  }, [code]);

  /* ── 2) room.status 변경 → phase 전환 ── */
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
  if (phase === "loading")
    return (
      <Screen>
        <div className="flex flex-col items-center gap-6">
          <div className="text-6xl">📱</div>
          <Spinner label="앱이 설치되어 있으면 자동으로 열립니다..." />
          <p className="text-xs text-gray-400 text-center">
            앱이 없으면 잠시 후 웹에서 자동으로 진행됩니다
          </p>
        </div>
      </Screen>
    );
  if (phase === "error")
    return (
      <Screen>
        <div className="text-6xl mb-4">😕</div>
        <h1 className="text-2xl font-bold text-gray-800 mb-2">오류</h1>
        <p className="text-gray-500 mb-8">{error}</p>
        <a
          href="/"
          className="inline-block bg-[#E85D04] text-white font-bold py-3 px-8 rounded-xl"
        >
          홈으로
        </a>
      </Screen>
    );
  if (!room) return <Screen><Spinner label="로딩 중..." /></Screen>;

  return (
    <>
      {phase === "lobby" && <LobbyView room={room} />}
      {phase === "input" && (
        <InputView room={room} uid={uid} onDone={() => setPhase("waiting")} />
      )}
      {phase === "waiting" && <WaitingView room={room} />}
      {phase === "voting" && <VotingView room={room} uid={uid} />}
      {phase === "done" && <DoneView room={room} />}
    </>
  );
}

/* ─────────────────── 로비 ─────────────────── */
function LobbyView({ room }: { room: Room }) {
  return (
    <Screen>
      <Header title="대기실" />
      <div className="text-center mb-8">
        <p className="text-sm text-gray-400 mb-2">입장 코드</p>
        <div className="inline-block bg-white border-2 border-[#E85D04] rounded-xl px-8 py-4">
          <span className="text-4xl font-bold tracking-[0.3em] text-[#E85D04]">
            {room.code}
          </span>
        </div>
      </div>
      <div className="flex items-center gap-2 mb-4">
        <span className="text-[#E85D04] text-xl">👥</span>
        <span className="text-lg font-bold">
          참가자 {room.participantCount}명
        </span>
      </div>
      <div className="space-y-2 mb-8">
        {Array.from({ length: room.participantCount }).map((_, i) => (
          <div
            key={i}
            className="flex items-center gap-3 bg-white rounded-xl px-4 py-3"
          >
            <div
              className="w-9 h-9 rounded-full flex items-center justify-center text-lg"
              style={{
                backgroundColor: `rgba(232,93,4,${0.15 + i * 0.1})`,
              }}
            >
              👤
            </div>
            <span>{i === 0 ? "방장" : `참가자 ${i + 1}`}</span>
          </div>
        ))}
      </div>
      <div className="bg-orange-50 rounded-xl p-4 flex items-center justify-center gap-3">
        <div className="w-5 h-5 border-2 border-[#E85D04] border-t-transparent rounded-full animate-spin" />
        <span className="text-gray-600">방장이 시작할 때까지 기다려주세요</span>
      </div>
    </Screen>
  );
}

/* ─────────────────── 선호도 입력 ─────────────────── */
function InputView({
  room,
  uid,
  onDone,
}: {
  room: Room;
  uid: string;
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
    setInput: React.Dispatch<React.SetStateAction<string>>
  ) => {
    const val = text.trim();
    if (!val || list.includes(val)) return;
    setList((prev) => [...prev, val]);
    setInput("");
  };

  const removeTag = (
    tag: string,
    setList: React.Dispatch<React.SetStateAction<string[]>>
  ) => {
    setList((prev) => prev.filter((t) => t !== tag));
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
    <Screen>
      <Header title="음식 선호도 입력" />
      <section className="mb-8">
        <h2 className="text-lg font-bold mb-1">🙂 먹고 싶은 음식</h2>
        <p className="text-xs text-gray-400 mb-3">최소 3개 입력해주세요</p>
        <TagInput
          value={wantInput}
          onChange={setWantInput}
          onAdd={() => addTag(wantInput, wants, setWants, setWantInput)}
          placeholder="예: 치킨, 피자..."
          color="#E85D04"
        />
        <TagList
          tags={wants}
          color="#E85D04"
          onRemove={(t) => removeTag(t, setWants)}
        />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-bold mb-1">😞 먹기 싫은 음식</h2>
        <p className="text-xs text-gray-400 mb-3">선택사항이에요</p>
        <TagInput
          value={dontInput}
          onChange={setDontInput}
          onAdd={() => addTag(dontInput, donts, setDonts, setDontInput)}
          placeholder="예: 초밥, 회..."
          color="#607D8B"
        />
        <TagList
          tags={donts}
          color="#607D8B"
          onRemove={(t) => removeTag(t, setDonts)}
        />
      </section>

      <button
        onClick={submit}
        disabled={submitting}
        className="w-full bg-[#E85D04] text-white font-bold py-4 rounded-xl text-lg disabled:opacity-50 transition"
      >
        {submitting ? "제출 중..." : `제출 (${wants.length}/3)`}
      </button>
    </Screen>
  );
}

/* ─────────────────── 대기 ─────────────────── */
function WaitingView({ room }: { room: Room }) {
  const progress =
    room.participantCount > 0
      ? room.submittedCount / room.participantCount
      : 0;
  const allDone = room.submittedCount >= room.participantCount;

  return (
    <Screen>
      <Header title="결과 기다리는 중" />
      <div className="flex flex-col items-center justify-center flex-1 py-12">
        <div className="text-6xl mb-6">🍳</div>
        {allDone ? (
          <>
            <p className="text-xl font-bold text-center mb-2">
              AI가 음식을
              <br />
              추천하고 있어요...
            </p>
            <div className="mt-6 w-8 h-8 border-3 border-[#E85D04] border-t-transparent rounded-full animate-spin" />
          </>
        ) : (
          <>
            <p className="text-xl font-bold text-center mb-6">
              친구들이 선호도를
              <br />
              입력하고 있어요
            </p>
            <div className="w-full bg-gray-200 rounded-full h-4 overflow-hidden mb-3">
              <div
                className="bg-[#E85D04] h-full rounded-full transition-all duration-500"
                style={{ width: `${progress * 100}%` }}
              />
            </div>
            <p className="text-gray-500">
              {room.submittedCount} / {room.participantCount}명 완료
            </p>
          </>
        )}
      </div>
    </Screen>
  );
}

/* ─────────────────── 투표 ─────────────────── */
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
    if (entries.length === 0) return;
    const winner = entries.reduce((a, b) => (a[1] >= b[1] ? a : b))[0];
    await updateDoc(doc(db, "rooms", room.id), {
      finalFood: winner,
      decisionMethod: "vote",
      status: "done",
    });
  };

  const pickRandom = async () => {
    const foods = room.recommendations;
    if (foods.length === 0) return;
    const food = foods[Math.floor(Math.random() * foods.length)];
    await updateDoc(doc(db, "rooms", room.id), {
      finalFood: food,
      decisionMethod: "random",
      status: "done",
    });
  };

  return (
    <Screen>
      <Header title="AI 추천 Top 3" />
      <p className="text-xl font-bold text-center mb-6">
        🤖 AI가 추천하는
        <br />
        오늘의 음식!
      </p>

      <div className="space-y-3 mb-6">
        {room.recommendations.map((food, i) => {
          const voteCount = room.votes[food] ?? 0;
          const isMyVote = myVote === food;
          return (
            <div
              key={food}
              className={`bg-white rounded-xl p-4 flex items-start gap-4 border-2 transition ${
                isMyVote ? "border-[#E85D04] bg-orange-50" : "border-transparent"
              }`}
            >
              <span className="text-3xl">{medals[i]}</span>
              <div className="flex-1 min-w-0">
                <p className="text-lg font-bold">{food}</p>
                {room.recommendationReasons[food] && (
                  <p className="text-xs text-gray-500 mt-1">
                    {room.recommendationReasons[food]}
                  </p>
                )}
                {totalVotes > 0 && (
                  <p className="text-sm text-gray-400 mt-1">{voteCount}표</p>
                )}
              </div>
              {!myVote ? (
                <button
                  onClick={() => vote(food)}
                  className="flex-shrink-0 bg-[#E85D04] text-white font-bold px-4 py-2 rounded-lg text-sm"
                >
                  투표
                </button>
              ) : isMyVote ? (
                <span className="text-[#E85D04] text-2xl">✓</span>
              ) : null}
            </div>
          );
        })}
      </div>

      {isHost ? (
        <div className="flex gap-3">
          <button
            onClick={finalizeVote}
            className="flex-1 bg-[#E85D04] text-white font-bold py-3 rounded-xl"
          >
            🗳️ 투표 결과 확정
          </button>
          <button
            onClick={pickRandom}
            className="flex-1 bg-purple-600 text-white font-bold py-3 rounded-xl"
          >
            🎲 랜덤 뽑기
          </button>
        </div>
      ) : (
        <div className="bg-orange-50 rounded-xl p-4 text-center text-gray-600">
          {!myVote
            ? "원하는 음식에 투표해주세요!"
            : "방장이 결과를 확정할 때까지 기다려주세요"}
        </div>
      )}
    </Screen>
  );
}

/* ─────────────────── 최종 결과 ─────────────────── */
function DoneView({ room }: { room: Room }) {
  const method =
    room.decisionMethod === "vote" ? "투표로 결정!" : "🎲 랜덤으로 결정!";
  return (
    <Screen>
      <div className="flex flex-col items-center justify-center flex-1 py-12">
        <div className="text-7xl mb-4">🎉</div>
        <p className="text-xl text-gray-500 mb-4">오늘의 메뉴는...</p>
        <div className="w-full bg-[#E85D04] rounded-2xl px-8 py-6 shadow-lg shadow-orange-300/40 mb-5">
          <p className="text-4xl font-bold text-white text-center">
            {room.finalFood ?? "?"}
          </p>
        </div>
        <p className="text-gray-500 mb-10">{method}</p>
        <a
          href="/"
          className="w-full bg-[#E85D04] text-white font-bold py-4 rounded-xl text-lg text-center block"
        >
          처음으로
        </a>
      </div>
    </Screen>
  );
}

/* ─────────────────── 공용 컴포넌트 ─────────────────── */
function Screen({ children }: { children: React.ReactNode }) {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-4 py-6">
      <div className="max-w-md w-full">{children}</div>
    </main>
  );
}

function Header({ title }: { title: string }) {
  return (
    <div className="bg-[#E85D04] -mx-4 -mt-6 mb-6 px-4 py-4 rounded-b-2xl">
      <h1 className="text-white text-lg font-bold text-center">{title}</h1>
    </div>
  );
}

function Spinner({ label }: { label: string }) {
  return (
    <div className="flex flex-col items-center gap-4">
      <div className="w-8 h-8 border-3 border-[#E85D04] border-t-transparent rounded-full animate-spin" />
      <p className="text-gray-500">{label}</p>
    </div>
  );
}

function TagInput({
  value,
  onChange,
  onAdd,
  placeholder,
  color,
}: {
  value: string;
  onChange: (v: string) => void;
  onAdd: () => void;
  placeholder: string;
  color: string;
}) {
  return (
    <div className="flex gap-2 mb-2">
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => e.key === "Enter" && onAdd()}
        placeholder={placeholder}
        className="flex-1 border border-gray-200 rounded-lg px-3 py-2 bg-white focus:outline-none focus:border-[#E85D04]"
      />
      <button
        onClick={onAdd}
        style={{ color }}
        className="text-2xl font-bold px-2"
      >
        +
      </button>
    </div>
  );
}

function TagList({
  tags,
  color,
  onRemove,
}: {
  tags: string[];
  color: string;
  onRemove: (tag: string) => void;
}) {
  if (tags.length === 0) return null;
  return (
    <div className="flex flex-wrap gap-2">
      {tags.map((tag) => (
        <span
          key={tag}
          className="inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm border"
          style={{
            borderColor: color + "40",
            backgroundColor: color + "10",
            color,
          }}
        >
          {tag}
          <button onClick={() => onRemove(tag)} className="ml-1 opacity-60">
            ✕
          </button>
        </span>
      ))}
    </div>
  );
}

/* ─────────────────── 엔트리 ─────────────────── */
export default function JoinPage() {
  return (
    <Suspense
      fallback={
        <main className="min-h-screen flex items-center justify-center">
          <div className="w-8 h-8 border-3 border-[#E85D04] border-t-transparent rounded-full animate-spin" />
        </main>
      }
    >
      <JoinContent />
    </Suspense>
  );
}
