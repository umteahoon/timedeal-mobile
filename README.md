# 타임딜 모바일 (TimeDeal Mobile)

이웃과 함께 만드는 시간 한정 공동구매 플랫폼 **타임딜**의 모바일 앱(Flutter)입니다.
웹으로 빌드해 **PWA**로 배포하므로, 휴대폰에서 접속한 뒤 "홈 화면에 추가"하면 앱처럼 설치해서 쓸 수 있습니다.

- 모바일(PWA): https://timedeal-mobile.netlify.app
- 웹: https://timedeal.netlify.app

> 2026 대림대학교 창의융합 전공동아리 **C.S.I** · 대림 Tech-Fair 2026 출품작
> 팀원: 엄태훈 · 최다울 · 이동교
> 원본 앱 코드: [daoulee/Time_Deal](https://github.com/daoulee/Time_Deal) `app/`

## 웹과 연동되는 방식

모바일 앱은 웹 타임딜과 **같은 Supabase 프로젝트와 같은 서버 API**(`https://time-deal.onrender.com/api`)를 씁니다.

| 모바일 앱 기능 | 웹에서 보이는 곳 |
|---|---|
| 딜 목록·상세 | 웹 상품·타임딜 (`/api/mobile/deals`) |
| 예약하기 | 웹 주문(현장결제 예약) → 웹 판매자 센터 주문 현황 |
| 예약 취소 | 웹 주문 취소 (재고 복구) |
| 찜 | 웹 찜 목록 |
| 사장님 딜 올리기 | 웹 상품+딜 (웹 홈에 바로 노출) |
| 사장님 픽업 완료·노쇼 처리 | 웹 판매자 fulfillment 상태 |
| 로그인 없이 체험하기 | 웹 체험 계정(`/api/auth/guest`) |

자동 연결:
- 휴대폰으로 웹(timedeal.netlify.app)에 들어오면 → 모바일(PWA)로 이동
- PC로 모바일 주소에 들어오면 → 웹으로 이동
- 주소 끝에 `?view=pc` / `?view=app` 을 붙이면 원하는 쪽으로 고정됩니다.

## 개발·빌드

```bash
flutter pub get
flutter run -d chrome                     # 개발 실행
flutter build web --release               # build/web 에 PWA 생성
```

다른 서버로 붙일 때는 `--dart-define`으로 바꿉니다.

```bash
flutter build web --dart-define=API_BASE_URL=http://localhost:10000/api
```

설정값: `lib/core/config/app_config.dart` (`SUPABASE_URL`, `SUPABASE_KEY`, `API_BASE_URL`, `WEB_SITE_URL`)

## 배포 (Netlify)

`netlify.toml`에 빌드 설정이 들어 있어서 GitHub 저장소를 Netlify에 연결하면 푸시할 때마다 자동으로 빌드·배포됩니다.
로컬에서 `flutter build web` 후 `build/web` 폴더를 Netlify에 올려도 됩니다.

## 참고

- `packages/lucide_icons`: 최신 Flutter에서 `IconData` 상속이 막혀서 아이콘 패키지(lucide_icons 0.257.0)를 고쳐서 넣은 사본입니다.
- 카카오·구글 로그인은 Supabase Auth → URL Configuration → Redirect URLs에 모바일 주소가 등록돼 있어야 동작합니다.
- 지도는 Google Maps JavaScript API 키의 허용 도메인(HTTP 리퍼러)에 모바일 주소가 있어야 표시됩니다.
