"use client";

import Image from "next/image";
import { useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useRef, useState } from "react";
import { auth, db } from "@/lib/firebase";
import { signInAnonymously, signOut } from "firebase/auth";
import {
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  increment,
  limit,
  onSnapshot,
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from "firebase/firestore";

const FOOD_CATEGORIES = [
  "버거",
  "치킨",
  "구이",
  "피자",
  "족발",
  "보쌈",
  "한식",
  "분식",
  "돈까스",
  "찜/탕",
  "중식",
  "일식",
  "회/해물",
  "양식",
  "커피/차",
  "디저트",
  "간식",
  "아시안",
  "샌드위치",
  "샐러드",
  "멕시칸",
  "도시락",
  "죽",
] as const;

interface PreferenceDoc {
  wantFoods?: string[];
  dontWantFoods?: string[];
}

interface Room {
  id: string;
  code: string;
  hostId: string;
  status: string;
  participantCount: number;
  submittedCount: number;
  restaurantSubmittedCount: number;
  recommendations: string[];
  recommendationReasons: Record<string, string>;
  votes: Record<string, number>;
  votedCount: number;
  selectedCategory?: string;
  finalFood?: string;
  decisionMethod?: string;
  participants: Record<string, string>;
}

type Phase =
  | "loading"
  | "nickname"
  | "joining"
  | "error"
  | "lobby"
  | "category_input"
  | "category_waiting"
  | "category_done"
  | "restaurant_input"
  | "restaurant_voting"
  | "restaurant_revote"
  | "done";

function calculateTopFood(preferences: PreferenceDoc[]) {
  const scores = Object.fromEntries(FOOD_CATEGORIES.map((food) => [food, 0]));
  const wants = Object.fromEntries(FOOD_CATEGORIES.map((food) => [food, 0]));
  const blockedFoods = new Set<string>();

  preferences.forEach((preference) => {
    new Set(preference.wantFoods ?? []).forEach((food) => {
      if (!(food in scores)) return;
      scores[food as keyof typeof scores] += 1;
      wants[food as keyof typeof wants] += 1;
    });
    new Set(preference.dontWantFoods ?? []).forEach((food) => {
      if (!(food in scores)) return;
      blockedFoods.add(food);
    });
  });

  const candidates = [...FOOD_CATEGORIES].filter(
    (food) => !blockedFoods.has(food) && wants[food] > 0,
  );

  if (!candidates.length) return null;

  const ranked = candidates.sort((a, b) => {
    const scoreCompare = scores[b] - scores[a];
    if (scoreCompare !== 0) return scoreCompare;
    const wantCompare = wants[b] - wants[a];
    if (wantCompare !== 0) return wantCompare;
    return FOOD_CATEGORIES.indexOf(a) - FOOD_CATEGORIES.indexOf(b);
  });

  return {
    food: ranked[0],
  };
}

function JoinContent() {
  const searchParams = useSearchParams();
  const code = searchParams.get("code") ?? "";

  const [phase, setPhase] = useState<Phase>("loading");
  const [error, setError] = useState("");
  const [room, setRoom] = useState<Room | null>(null);
  const [uid, setUid] = useState("");
  const [nickname, setNickname] = useState("");
  const joinedRef = useRef(false);
  const roomUnsubRef = useRef<(() => void) | null>(null);

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

  useEffect(() => {
    void initAuth();
  }, [initAuth]);

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

        roomUnsubRef.current?.();
        roomUnsubRef.current = onSnapshot(doc(db, "rooms", roomId), (docSnap) => {
          if (!docSnap.exists()) {
            // 방이 삭제됨 (방장이 나감)
            roomUnsubRef.current?.();
            setRoom(null);
            setPhase("error");
            setError("방장이 방을 나가서 방이 종료되었어요.");
            return;
          }
          const d = docSnap.data();
          setRoom({
            id: docSnap.id,
            code: d.code,
            hostId: d.hostId,
            status: d.status,
            participantCount: d.participantCount ?? 0,
            submittedCount: d.submittedCount ?? 0,
            restaurantSubmittedCount: d.restaurantSubmittedCount ?? 0,
            recommendations: d.recommendations ?? [],
            recommendationReasons: d.recommendationReasons ?? {},
            votes: d.votes ?? {},
            votedCount: d.votedCount ?? 0,
            selectedCategory: d.selectedCategory,
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

  useEffect(() => {
    return () => {
      roomUnsubRef.current?.();
    };
  }, []);

  const leaveRoom = useCallback(async () => {
    if (!room || !uid) return;

    try {
      roomUnsubRef.current?.();
      if (room.hostId === uid) {
        await deleteDoc(doc(db, "rooms", room.id));
      } else {
        await updateDoc(doc(db, "rooms", room.id), {
          participantCount: increment(-1),
          [`participants.${uid}`]: deleteField(),
        });
      }
    } catch {}

    joinedRef.current = false;
    await signOut(auth).catch(() => undefined);
    window.location.href = "/";
  }, [room, uid]);

  useEffect(() => {
    if (!room) return;
    switch (room.status) {
      case "waiting":
        setPhase("lobby");
        break;
      case "inputting":
        setPhase("category_input");
        break;
      case "category_done":
        setPhase("category_done");
        break;
      case "restaurant_inputting":
        setPhase("restaurant_input");
        break;
      case "restaurant_voting":
        setPhase("restaurant_voting");
        break;
      case "restaurant_revote_select":
        setPhase("restaurant_revote");
        break;
      case "done":
        setPhase("done");
        break;
      default:
        break;
    }
  }, [room]);

  if (phase === "loading" || phase === "joining") return <LoadingView />;
  if (phase === "nickname") return <NicknameView onSubmit={joinWithNickname} />;
  if (phase === "error") return <ErrorView message={error} />;
  if (!room) return <LoadingView />;

  return (
    <>
      {phase === "lobby" && (
        <LobbyView room={room} uid={uid} onLeave={leaveRoom} />
      )}
      {phase === "category_input" && (
        <CategoryFlow room={room} uid={uid} />
      )}
      {phase === "category_done" && <CategoryDoneView room={room} uid={uid} />}
      {phase === "restaurant_input" && (
        <RestaurantInputView room={room} uid={uid} />
      )}
      {phase === "restaurant_voting" && (
        <RestaurantVotingView room={room} uid={uid} />
      )}
      {phase === "restaurant_revote" && (
        <RestaurantRevoteView room={room} uid={uid} />
      )}
      {phase === "done" && <DoneView room={room} uid={uid} />}
    </>
  );
}

function LoadingView() {
  return (
    <PageWrapper>
      <CenterCard title="연결 중..." desc="방 정보를 불러오고 있어요">
        <Spinner />
      </CenterCard>
    </PageWrapper>
  );
}

function NicknameView({ onSubmit }: { onSubmit: (name: string) => void }) {
  const [value, setValue] = useState("");
  return (
    <PageWrapper>
      <CenterCard title="이름을 입력해주세요" desc="방에서 표시될 이름이에요">
        <input
          value={value}
          onChange={(e) => setValue(e.target.value)}
          className="w-full rounded-[16px] border border-[#DFE6E9] px-4 py-3 text-[18px] outline-none"
          placeholder="이름 입력"
        />
        <GradientButton
          className="mt-4"
          onClick={() => onSubmit(value.trim())}
          disabled={!value.trim()}
        >
          입장하기
        </GradientButton>
      </CenterCard>
    </PageWrapper>
  );
}

function ErrorView({ message }: { message: string }) {
  return (
    <PageWrapper>
      <CenterCard title="오류" desc={message}>
        <GradientButton href="/">홈으로 돌아가기</GradientButton>
      </CenterCard>
    </PageWrapper>
  );
}

function LobbyView({
  room,
  uid,
  onLeave,
}: {
  room: Room;
  uid: string;
  onLeave: () => void;
}) {
  const isHost = room.hostId === uid;

  const start = async () => {
    await updateDoc(doc(db, "rooms", room.id), { status: "inputting" });
  };

  return (
    <PageWrapper>
      <TopBar onLeave={onLeave} />
      <Card>
        <p className="text-[14px] text-[#636E72]">입장 코드</p>
        <p className="mt-2 text-[38px] font-black tracking-[0.18em] text-[#FF7A45]">
          {room.code}
        </p>
      </Card>
      <Card className="mt-4">
        <p className="text-[18px] font-black text-[#202633]">
          참가자 {room.participantCount}명
        </p>
        <div className="mt-4 space-y-2">
          {Object.entries(room.participants).map(([id, name]) => (
            <div key={id} className="rounded-[14px] border border-[#DFE6E9] bg-white px-4 py-3">
              {name}
            </div>
          ))}
        </div>
      </Card>
      <div className="mt-4">
        {isHost ? (
          <GradientButton
            onClick={start}
            disabled={room.participantCount < 2}
          >
            {room.participantCount < 2 ? "2명 이상 모여야 시작해요" : "지금 시작하기"}
          </GradientButton>
        ) : (
          <Card>방장이 시작할 때까지 기다려주세요</Card>
        )}
      </div>
    </PageWrapper>
  );
}

function CategoryFlow({ room, uid }: { room: Room; uid: string }) {
  const [wants, setWants] = useState<string[]>([]);
  const [donts, setDonts] = useState<string[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  // 라운드 재시작 감지: submittedCount가 0으로 리셋되면 로컬 상태 초기화
  useEffect(() => {
    if (room.submittedCount === 0 && room.status === "inputting" && submitted) {
      setSubmitted(false);
      setWants([]);
      setDonts([]);
    }
  }, [room.submittedCount, room.status, submitted]);

  useEffect(() => {
    if (
      room.submittedCount >= room.participantCount &&
      room.participantCount > 0 &&
      room.status === "inputting"
    ) {
      const finalize = async () => {
        const snap = await getDocs(collection(db, "rooms", room.id, "preferences"));
        const prefs = snap.docs.map((d) => d.data() as PreferenceDoc);
        const result = calculateTopFood(prefs);
        if (!result) {
          await Promise.all(snap.docs.map((d) => deleteDoc(d.ref)));
          await updateDoc(doc(db, "rooms", room.id), {
            submittedCount: 0,
            recommendationReasons: {
              __systemMessage:
                "누군가 먹기 싫은 메뉴 때문에 후보가 남지 않았어요. 다시 골라주세요.",
            },
          });
          return;
        }
        await updateDoc(doc(db, "rooms", room.id), {
          status: "category_done",
          selectedCategory: result.food,
          recommendationReasons: {},
          recommendations: [],
          votes: {},
          votedCount: 0,
          finalFood: deleteField(),
          decisionMethod: "weighted",
        });
      };
      void finalize();
    }
  }, [room]);

  const toggle = (
    food: string,
    current: string[],
    setCurrent: React.Dispatch<React.SetStateAction<string[]>>,
    other: string[],
    setOther: React.Dispatch<React.SetStateAction<string[]>>,
  ) => {
    if (current.includes(food)) {
      setCurrent((prev) => prev.filter((v) => v !== food));
      return;
    }
    setCurrent((prev) => [...prev, food]);
    if (other.includes(food)) {
      setOther((prev) => prev.filter((v) => v !== food));
    }
  };

  const submit = async () => {
    if (!wants.length) return;
    setSubmitting(true);
    await setDoc(doc(db, "rooms", room.id, "preferences", uid), {
      wantFoods: wants,
      dontWantFoods: donts,
      submittedAt: Timestamp.now(),
    });
    await updateDoc(doc(db, "rooms", room.id), {
      submittedCount: increment(1),
      recommendationReasons: {},
    });
    setSubmitted(true);
    setSubmitting(false);
  };

  const alreadySubmitted = submitted;
  const remaining = Math.max(0, room.participantCount - room.submittedCount);

  if (alreadySubmitted) {
    return (
      <PageWrapper>
        <CenterCard
          title="기다리는 중"
          desc={`지금 ${room.submittedCount}명이 골랐고 ${remaining}명이 더 골라야 해요`}
        >
          <Progress submitted={room.submittedCount} total={room.participantCount} />
        </CenterCard>
      </PageWrapper>
    );
  }

  return (
    <PageWrapper>
      <Card>
        <p className="text-[22px] font-black text-[#202633]">음식 카테고리 선택</p>
        {room.recommendationReasons.__systemMessage ? (
          <div className="mt-4 rounded-[14px] bg-[#FFF4EF] px-4 py-3 text-[13px] font-semibold text-[#2D3436]">
            {room.recommendationReasons.__systemMessage}
          </div>
        ) : null}
      </Card>
      <SelectSection
        title="먹고 싶은 음식"
        selected={wants}
        onToggle={(food) => toggle(food, wants, setWants, donts, setDonts)}
      />
      <SelectSection
        title="먹기 싫은 음식"
        selected={donts}
        onToggle={(food) => toggle(food, donts, setDonts, wants, setWants)}
      />
      <GradientButton
        className="mt-4"
        onClick={submit}
        disabled={!wants.length || submitting}
      >
        {submitting ? "제출 중..." : "제출하기"}
      </GradientButton>
    </PageWrapper>
  );
}

function CategoryDoneView({ room, uid }: { room: Room; uid: string }) {
  const isHost = room.hostId === uid;

  const startRestaurant = async () => {
    await updateDoc(doc(db, "rooms", room.id), {
      status: "restaurant_inputting",
      restaurantSubmittedCount: 0,
      recommendations: [],
      votes: {},
      votedCount: 0,
      finalFood: deleteField(),
      decisionMethod: deleteField(),
    });
  };

  return (
    <PageWrapper>
      <CenterCard title="선택된 카테고리" desc="">
        <div className="rounded-[20px] bg-[linear-gradient(135deg,#FF7A45_0%,#FDB74A_100%)] px-6 py-8 text-center text-[34px] font-black text-white">
          {room.selectedCategory ?? "?"}
        </div>
        {isHost ? (
          <>
            <p className="mt-5 text-center text-[18px] font-extrabold text-[#202633]">
              음식점도 고르시겠어요?
            </p>
            <GradientButton className="mt-4" onClick={startRestaurant}>
              네
            </GradientButton>
            <GradientButton href="/" className="mt-3">
              홈으로 가기
            </GradientButton>
          </>
        ) : (
          <p className="mt-5 text-center text-[15px] leading-6 text-[#636E72]">
            방장이 다음 단계를 선택하는 중이에요.
            <br />
            잠시만 기다려주세요.
          </p>
        )}
      </CenterCard>
    </PageWrapper>
  );
}

function RestaurantInputView({ room, uid }: { room: Room; uid: string }) {
  const [value, setValue] = useState("");
  const [items, setItems] = useState<string[]>([]);
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    if (
      room.restaurantSubmittedCount >= room.participantCount &&
      room.participantCount > 0 &&
      room.status === "restaurant_inputting"
    ) {
      const finalize = async () => {
        const snap = await getDocs(
          collection(db, "rooms", room.id, "restaurantSuggestions"),
        );
        const set = new Set<string>();
        snap.docs.forEach((d) => {
          const data = d.data();
          (data.restaurants ?? []).forEach((name: string) => {
            const trimmed = name.trim();
            if (trimmed) set.add(trimmed);
          });
        });
        await updateDoc(doc(db, "rooms", room.id), {
          status: "restaurant_voting",
          recommendations: Array.from(set),
          votes: Object.fromEntries(Array.from(set).map((v) => [v, 0])),
          votedCount: 0,
        });
      };
      void finalize();
    }
  }, [room]);

  const add = () => {
    const trimmed = value.trim();
    if (!trimmed || items.includes(trimmed)) return;
    setItems((prev) => [...prev, trimmed]);
    setValue("");
  };

  const submit = async () => {
    if (!items.length) return;
    await setDoc(doc(db, "rooms", room.id, "restaurantSuggestions", uid), {
      restaurants: items,
      submittedAt: Timestamp.now(),
    });
    await updateDoc(doc(db, "rooms", room.id), {
      restaurantSubmittedCount: increment(1),
    });
    setSubmitted(true);
  };

  if (submitted) {
    return (
      <PageWrapper>
        <CenterCard
          title="음식점 입력 대기 중"
          desc={`지금 ${room.restaurantSubmittedCount}명이 입력했고 ${Math.max(
            0,
            room.participantCount - room.restaurantSubmittedCount,
          )}명이 더 입력해야 해요`}
        >
          <Progress
            submitted={room.restaurantSubmittedCount}
            total={room.participantCount}
          />
        </CenterCard>
      </PageWrapper>
    );
  }

  return (
    <PageWrapper>
      <Card>
        <p className="text-[22px] font-black text-[#202633]">
          음식점 입력
        </p>
        <p className="mt-2 text-[14px] text-[#636E72]">
          메뉴 카테고리: {room.selectedCategory ?? "-"}
        </p>
      </Card>
      <Card className="mt-4">
        <div className="flex gap-2">
          <input
            value={value}
            onChange={(e) => setValue(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && add()}
            placeholder="예: 교촌치킨 강남점"
            className="flex-1 rounded-[14px] border border-[#DFE6E9] px-4 py-3 outline-none"
          />
          <button
            onClick={add}
            className="rounded-[14px] bg-[#FF7A45] px-4 py-3 font-bold text-white"
          >
            추가
          </button>
        </div>
        <div className="mt-4 flex flex-wrap gap-2">
          {items.map((item) => (
            <button
              key={item}
              onClick={() => setItems((prev) => prev.filter((v) => v !== item))}
              className="rounded-full border border-[#DFE6E9] bg-white px-3 py-2 text-[13px] font-bold"
            >
              {item} ✕
            </button>
          ))}
        </div>
      </Card>
      <GradientButton className="mt-4" onClick={submit} disabled={!items.length}>
        제출하기
      </GradientButton>
    </PageWrapper>
  );
}

function RestaurantVotingView({ room, uid }: { room: Room; uid: string }) {
  const [selected, setSelected] = useState<string[]>([]);
  const [submitted, setSubmitted] = useState(false);
  const isHost = room.hostId === uid;

  useEffect(() => {
    if (
      room.votedCount >= room.participantCount &&
      room.participantCount > 0 &&
      room.status === "restaurant_voting" &&
      room.finalFood == null &&
      isHost
    ) {
      const winner = Object.entries(room.votes).reduce((a, b) =>
        a[1] >= b[1] ? a : b,
      )[0];
      void updateDoc(doc(db, "rooms", room.id), {
        status: "done",
        finalFood: winner,
        decisionMethod: "vote",
      });
    }
  }, [room, isHost]);

  const submitVote = async () => {
    if (!selected.length) return;
    const updates: Record<string, unknown> = { votedCount: increment(1) };
    selected.forEach((food) => {
      updates[`votes.${food}`] = increment(1);
    });
    await updateDoc(doc(db, "rooms", room.id), updates);
    setSubmitted(true);
  };

  const pickRandom = async () => {
    const food =
      room.recommendations[Math.floor(Math.random() * room.recommendations.length)];
    await updateDoc(doc(db, "rooms", room.id), {
      status: "done",
      finalFood: food,
      decisionMethod: "random",
    });
  };

  if (submitted) {
    return (
      <PageWrapper>
        <CenterCard
          title="투표 대기 중"
          desc={`지금 ${room.votedCount}명이 투표했고 ${Math.max(
            0,
            room.participantCount - room.votedCount,
          )}명이 더 투표해야 해요`}
        >
          <Progress submitted={room.votedCount} total={room.participantCount} />
        </CenterCard>
      </PageWrapper>
    );
  }

  return (
    <PageWrapper>
      <Card>
        <p className="text-[22px] font-black text-[#202633]">음식점 투표</p>
      </Card>
      <div className="mt-4 space-y-3">
        {room.recommendations.map((food) => {
          const active = selected.includes(food);
          return (
            <button
              key={food}
              onClick={() =>
                setSelected((prev) =>
                  active ? prev.filter((v) => v !== food) : [...prev, food],
                )
              }
              className={`w-full rounded-[18px] border-2 px-4 py-4 text-left font-bold ${
                active
                  ? "border-[#FF7A45] bg-[#FFF4EF]"
                  : "border-[#DFE6E9] bg-white"
              }`}
            >
              {food}
            </button>
          );
        })}
      </div>
      <GradientButton className="mt-4" onClick={submitVote} disabled={!selected.length}>
        투표 제출
      </GradientButton>
      {isHost ? (
        <button
          onClick={pickRandom}
          className="mt-3 h-14 w-full rounded-[18px] border border-[#DFE6E9] bg-white font-extrabold text-[#202633]"
        >
          랜덤으로 선택하기
        </button>
      ) : null}
    </PageWrapper>
  );
}

function RestaurantRevoteView({ room, uid }: { room: Room; uid: string }) {
  const isHost = room.hostId === uid;
  const [selected, setSelected] = useState<string[]>(room.recommendations);

  if (!isHost) {
    return (
      <PageWrapper>
        <CenterCard title="재투표 준비 중" desc="방장이 다시 투표할 음식점을 고르고 있어요" />
      </PageWrapper>
    );
  }

  const confirm = async () => {
    if (selected.length < 2) return;
    await updateDoc(doc(db, "rooms", room.id), {
      status: "restaurant_voting",
      recommendations: selected,
      votes: Object.fromEntries(selected.map((v) => [v, 0])),
      votedCount: 0,
      finalFood: deleteField(),
      decisionMethod: deleteField(),
    });
  };

  return (
    <PageWrapper>
      <Card>
        <p className="text-[22px] font-black text-[#202633]">재투표 후보 선택</p>
      </Card>
      <div className="mt-4 space-y-3">
        {room.recommendations.map((food) => {
          const active = selected.includes(food);
          return (
            <button
              key={food}
              onClick={() =>
                setSelected((prev) =>
                  active ? prev.filter((v) => v !== food) : [...prev, food],
                )
              }
              className={`w-full rounded-[18px] border-2 px-4 py-4 text-left font-bold ${
                active
                  ? "border-[#FF7A45] bg-[#FFF4EF]"
                  : "border-[#DFE6E9] bg-white"
              }`}
            >
              {food}
            </button>
          );
        })}
      </div>
      <GradientButton className="mt-4" onClick={confirm} disabled={selected.length < 2}>
        선택한 음식점으로 재투표
      </GradientButton>
    </PageWrapper>
  );
}

function DoneView({ room, uid }: { room: Room; uid: string }) {
  const isHost = room.hostId === uid;

  const revote = async () => {
    await updateDoc(doc(db, "rooms", room.id), {
      status: "restaurant_revote_select",
      finalFood: deleteField(),
      decisionMethod: deleteField(),
    });
  };

  return (
    <PageWrapper>
      <CenterCard title="최종 음식점 결과" desc="">
        <div className="rounded-[20px] bg-[linear-gradient(135deg,#FF7A45_0%,#FDB74A_100%)] px-6 py-8 text-center text-[32px] font-black text-white">
          {room.finalFood ?? "?"}
        </div>
        <GradientButton href="/" className="mt-4">
          홈으로 가기
        </GradientButton>
        {room.decisionMethod === "vote" && isHost ? (
          <button
            onClick={revote}
            className="mt-3 h-14 w-full rounded-[18px] border border-[#DFE6E9] bg-white font-extrabold text-[#202633]"
          >
            재투표하기
          </button>
        ) : null}
      </CenterCard>
    </PageWrapper>
  );
}

function SelectSection({
  title,
  selected,
  onToggle,
}: {
  title: string;
  selected: string[];
  onToggle: (food: string) => void;
}) {
  return (
    <Card className="mt-4">
      <p className="text-[16px] font-black text-[#202633]">{title}</p>
      <div className="mt-4 flex flex-wrap gap-2">
        {FOOD_CATEGORIES.map((food) => {
          const active = selected.includes(food);
          return (
            <button
              key={food}
              onClick={() => onToggle(food)}
              className={`rounded-full border px-3 py-2 text-[13px] font-bold ${
                active
                  ? "border-[#FF7A45] bg-[#FF7A45] text-white"
                  : "border-[#DFE6E9] bg-white text-[#202633]"
              }`}
            >
              {food}
            </button>
          );
        })}
      </div>
    </Card>
  );
}

function PageWrapper({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative min-h-screen overflow-hidden bg-[var(--bg)]">
      <div className="mx-auto w-full max-w-[440px] px-5 py-5 sm:py-8">{children}</div>
    </div>
  );
}

function Card({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={`rounded-[24px] border border-[#DFE6E9] bg-white p-5 shadow-[0_8px_22px_rgba(32,38,51,0.06)] ${className ?? ""}`}>
      {children}
    </div>
  );
}

function CenterCard({
  title,
  desc,
  children,
}: {
  title: string;
  desc: string;
  children?: React.ReactNode;
}) {
  return (
    <div className="flex min-h-[calc(100vh-40px)] items-center">
      <Card className="w-full">
        <p className="text-center text-[28px] font-black text-[#202633]">{title}</p>
        {desc ? <p className="mt-3 text-center text-[14px] leading-6 text-[#636E72]">{desc}</p> : null}
        <div className="mt-6">{children}</div>
      </Card>
    </div>
  );
}

function TopBar({ onLeave }: { onLeave: () => void }) {
  return (
    <div className="mb-4 flex justify-end">
      <button
        type="button"
        onClick={onLeave}
        className="rounded-full border border-[#eadfd7] bg-white/90 px-4 py-2 text-[13px] font-semibold text-[#6f7785]"
      >
        방 나가기
      </button>
    </div>
  );
}

function Progress({ submitted, total }: { submitted: number; total: number }) {
  const percent = total > 0 ? (submitted / total) * 100 : 0;
  return (
    <div>
      <div className="h-3 w-full overflow-hidden rounded-full bg-[#DFE6E9]">
        <div
          className="h-full rounded-full bg-[linear-gradient(135deg,#FF7A45_0%,#FDB74A_100%)]"
          style={{ width: `${percent}%` }}
        />
      </div>
      <p className="mt-3 text-center text-[13px] font-bold text-[#FF7A45]">
        {submitted} / {total}명 완료
      </p>
    </div>
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
  const cls = `flex h-14 w-full items-center justify-center rounded-[18px] text-[17px] font-extrabold ${
    disabled ? "cursor-not-allowed bg-[#DFE6E9] text-[#636E72]" : "bg-[linear-gradient(135deg,#ff7a45_0%,#ff9a62_100%)] text-white"
  } ${className ?? ""}`;
  if (href) {
    return <a href={href} className={cls}>{children}</a>;
  }
  return (
    <button type="button" onClick={onClick} disabled={disabled} className={cls}>
      {children}
    </button>
  );
}

function Spinner() {
  return <div className="mx-auto h-8 w-8 animate-spin rounded-full border-[3px] border-[#FF7A45]/30 border-t-[#FF7A45]" />;
}

export default function JoinPage() {
  return (
    <Suspense fallback={<LoadingView />}>
      <JoinContent />
    </Suspense>
  );
}
