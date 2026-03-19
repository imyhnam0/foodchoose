## Commands

```bash
flutter run                  # Run on connected device/emulator
flutter pub get              # Fetch dependencies
flutter build apk            # Build Android APK
flutter build ios            # Build iOS (requires macOS + Xcode)
flutter test                 # Run all tests
flutter analyze              # Static analysis / lint
```

---

# 골라음식 앱 프로젝트 규칙

- 답변과 설명은 항상 한국어로 한다.
- 코드 수정 전에는 먼저 Plan Mode 스타일로 작업 계획을 제시한다.
- Flutter 앱 기준으로 구현한다.
- 상태 관리는 처음에는 단순하게 유지하고, MVP 우선으로 구현한다.
- Firebase Auth는 익명 로그인 기준으로 설계한다.
- Firestore는 실시간 동기화를 우선으로 한다.
- AI 추천 결과는 항상 JSON으로 파싱 가능하게 만든다.
- 보안상 Gemini API 키를 앱에 하드코딩하지 말고 추후 서버/함수 이전을 고려한다.
- 먼저 동작하는 최소 기능을 완성한 뒤 UI 고도화를 한다.
- 큰 변경 후에는 `flutter analyze` 기준으로 오류 여부를 점검한다.

---

## 기술 스택

| 항목 | 내용 |
|------|------|
| 프레임워크 | Flutter (Dart, SDK ^3.8.1) |
| 인증 | Firebase Auth (익명 로그인) |
| DB | Cloud Firestore (실시간 동기화) |
| AI 추천 | Gemini API (`gemini-1.5-flash`, `google_generative_ai: ^0.4.6`) |
| 라우팅 | go_router ^14.8.1 |
| 딥링크 | app_links ^6.4.0 (`foodchoose://join`) |
| 공유 | share_plus ^10.1.4 |

---

## 앱 화면 흐름 (라우터)

```
/                    HomeScreen           — 방 만들기 / 방 코드 입장
/lobby/:roomId       RoomLobbyScreen      — 방 코드 공유, 방장 시작 버튼
/input/:roomId       PreferenceInputScreen — 먹고 싶은 것 / 먹기 싫은 것 입력
/waiting/:roomId     WaitingScreen        — 모두 제출 대기 → Gemini 호출
/results/:roomId     ResultsScreen        — AI Top3 추천 + 투표
/final/:roomId       FinalResultScreen    — 최종 결정 음식 표시
```

---

## 파일 구조

```
lib/
├── main.dart
├── router.dart
├── firebase_options.dart
├── models/
│   ├── room.dart        — Room 모델 (Firestore ↔ Dart)
│   └── preference.dart  — 참가자 선호도 모델
├── services/
│   ├── auth_service.dart   — Firebase 익명 로그인
│   ├── room_service.dart   — Firestore CRUD / 투표 / 추천 저장
│   └── gemini_service.dart — Gemini API 호출 및 파싱
├── screens/
│   ├── home_screen.dart
│   ├── room_lobby_screen.dart
│   ├── preference_input_screen.dart
│   ├── waiting_screen.dart
│   ├── results_screen.dart
│   └── final_result_screen.dart
└── utils/
    ├── constants.dart       — geminiApiKey, deepLinkScheme/Host
    └── deep_link_handler.dart
```

---

## 핵심 데이터 모델

### `Room` (Firestore: `rooms/{roomId}`)

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | String | Firestore 문서 ID |
| `code` | String | 6자리 입장 코드 |
| `hostId` | String | 방장 익명 UID |
| `status` | String | `waiting` → `inputting` → `voting` → `done` |
| `participantCount` | int | 총 참가자 수 |
| `submittedCount` | int | 선호도 제출 완료 수 |
| `recommendations` | List\<String\> | Gemini 추천 Top3 음식 이름 |
| `recommendationReasons` | Map\<String,String\> | 각 음식의 추천 이유 `{ '피자': '이유...' }` |
| `votes` | Map\<String,int\> | 음식별 투표 수 |
| `finalFood` | String? | 최종 결정 음식 |
| `decisionMethod` | String? | `vote` 또는 `random` |

### `Preference` (Firestore: `rooms/{roomId}/preferences/{anonymousId}`)

| 필드 | 타입 | 설명 |
|------|------|------|
| `anonymousId` | String | 참가자 익명 ID (문서 ID) |
| `wantFoods` | List\<String\> | 먹고 싶은 음식 목록 |
| `dontWantFoods` | List\<String\> | 먹기 싫은 음식 목록 |
| `submittedAt` | DateTime | 제출 시각 |

---

## Gemini 서비스 (`gemini_service.dart`)

- 반환 타입: `({List<String> foods, Map<String, String> reasons})`
- 입력: `List<Preference>` — 참가자별 개별 선호도 (합산 아님)
- 프롬프트: 참가자 번호별로 선호도 나열 → 유형/카테고리 분석 → Top3 선정
- 출력 JSON 구조:
  ```json
  {
    "recommendations": [
      { "food": "음식명", "reason": "추천 이유 1~2문장" }
    ]
  }
  ```
- 파싱: `{...}` 블록 추출 → `jsonDecode` → `foods` 리스트 + `reasons` 맵

---

## API 키 위치

- `lib/utils/constants.dart` — `geminiApiKey`
- `android/app/src/main/AndroidManifest.xml` — (Google Maps 등 추후 추가 시)

## Firebase 설정

- `lib/firebase_options.dart` — flutterfire configure로 생성
- Firestore 익명 인증 활성화 필요
- 보안 규칙: `firestore.rules` 참고
