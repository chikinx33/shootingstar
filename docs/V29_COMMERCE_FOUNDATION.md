# v10.0.29 후원 외형·선택형 광고 연동 기반

2026-10-20 사용자 승인 범위를 구현했다. 실제 ID/계정/지원 연락처가 없으므로 운영 결제·광고는 비활성화한다. APK/Android 번들을 만들지 않았다. ‘소스 구현’, ‘격리 검증’, ‘실제 Google/Android 검증’을 별도로 기록한다.

## 제품 동작

- 성장의 기체 관리와 계정 화면에서 **후원 외형 미리보기**로 이동한다. 기존 기체 PNG 위의 잔광 프레임·별 배지를 기본 모습과 비교한다. 후원 외형은 로비 표시만 바꾸며 능력치/무료 해금에 영향이 없다.
- 서버가 확인한 소유자만 장착한다. 장착 선호만 계정별 기기에 보관하며, 구매 권리는 게임 저장/가져오기/개발자 모드로 만들지 않는다. 구매 전 확인과 구매 복원이 있고 가격은 Play의 `ProductDetails.price`를 쓴다.
- 광고는30초·10격파 이상이며 정산·업로드가 끝난 출격의 결과에서만 선택한다. 기본 보상은 이미 지급됐다. 광고 없음/취소/오류/동의 실패에는 추가 지급이 없다. 광고 진행 중 결과의 재출격/귀환을 막아 다른 전투와 섞이지 않게 한다.
- Google SSV 확인 후20 C, 출격당1회·서명에 포함된 완료 시각의 UTC 하루2회다. 지연된 확인은 원래 완료 날짜에 귀속한다. 완료 콜백만으로는 한 푼도 지급하지 않는다. 앱 종료 후에도 서버 지급은 다음 클라우드 동기화로 복구한다.
- 전투는 여전히 클라이언트 시뮬레이션이다. 정산 ID·최소 실적·서버 nonce는 중복/미정산 요청을 제한하는 장치이며, 전투 조작 전체를 막는 서버 권위 모델이라고 주장하지 않는다.

## 서버 경계

`server/src/commerce.mjs`, `migrations/0002_commerce.sql`:

운영 관리 API의 D1 조회는 권한 오류7403으로1회 차단됐다. 관리 권한은 변경하지 않았다. `commerce_schema.mjs`는 기존 앱 D1 binding을 통해 고정된 추가 스키마만 초기화한다. 첫 인증 요청/예약 작업에서 기존8개 스키마 객체 존재를 검사하고 필요할 때만 `CREATE IF NOT EXISTS`를 한 번의 batch로 실행한다. 기존 계정/저장 스키마는 변경하지 않고 사용자 입력 SQL/관리 엔드포인트는 없다. SQL 파일과 스키마 동등성·동시 초기화·기존 저장 보존·이후 관리 migration 재실행을 검사했다. Wrangler migration 장부에는 관리 API 권한 복구 후 동일 파일을 안전하게 반영할 수 있다. 초기화 동작은 구형0001만 있는 새 로컬 D1에서도 실제 API로 확인했다.

- 구매 토큰의 SHA-256을 고유 키로 쓰고, 재조회용 원문은 AES-256-GCM으로 암호화한다. 패키지/상품/구매 상태/계정 바인딩/수량을 Google API에서 확인한다. PENDING은 소유권 없음, PURCHASED만 지급한다. 기록 후 승인하며 승인 실패는 복원/시간별 작업으로 재시도한다. 같은 토큰을 다른 계정에 넘길 수 없다.
- 환불/취소/미존재 토큰은 회수한다. 한 번 회수한 토큰은 늦게 도착한 이전 조회로 부활하지 않는다. 재구매는 새 토큰을 검증한다. Google Pub/Sub 알림은 Google RS256 JWT의 발급자/대상/이메일/만료를 검증한 뒤 구매를 재조회한다. 알림 본문만으로 지급/회수하지 않는다.
- AdMob 서명은 원래 순서와 percent-escaped query bytes 그대로 ECDSA 검증한다. 고정 Google 공개 키 주소만 조회하고1시간 캐시한다. 계정·출격 nonce·단위·보상 수치/종류·시각·고유 거래를 확인한다.
- 원장 INSERT와20 C/검증 합계/클라우드 revision 증가는 SQLite trigger의 단일 트랜잭션이다. 중복 거래/출격/하루 상한은 서버에서 제한한다. 오래된 업로드는 revision 충돌로 멈춘다. 기기 진행을 선택해도 검증 합계와 차액을 재조정해 보상을 잃지 않는다. 이미 광고 보상을 받은 계정의 구형 클라이언트 업로드는 업데이트를 요구한다.
- 광고 실패는 예약을 닫으며 성공 횟수에 포함하지 않는다. 닫힌 뒤 유효 SSV가 늦게 오면 검증해 지급한다. 지급 전 nonce 유효15분, 전달 지연 최대24시간, 이미 지급한 거래 재전송은 기간이 지나도 중복 성공 응답이다.
- 계정 삭제는 구매/광고 개인 원장도 외래 키로 제거한다. 남아 있는 제공자 영수증은 삭제한 계정 바인딩 때문에 새 계정으로 자동 이전되지 않는다. 실제 결제 기록의 법정 보관/처리 정책과 삭제 예외는 운영 주체가 확정할 출시 필수 사항이다. 현재 구조를 법적 준수 완료로 간주하지 않는다.

## 클라이언트와 SDK

`CommerceController`는 계정 변경/로그아웃 때 소유권을 즉시 비우고 늦은 응답을 버린다. 웹은 미지원 어댑터라 SDK 호출이 없다. Android 어댑터는 `in_app_purchase 3.3.1`, `google_mobile_ads 9.1.0`의 실제 API를 연결한다. 계정 연결/재개 때 복원, 승인된 영수증만 구매 완료 처리, UMP 갱신/필요한 동의 폼/`canRequestAds`/개인정보 선택, SSV nonce를 제공한다.

AdMob 초기화 provider를 기본 비활성화해 ID가 없어도 자동 초기화하지 않는다. Gradle `admobAppId` 또는 `ADMOB_APP_ID`로 전달한 manifest ID와 서버 ID가 일치하고 UMP를 통과한 뒤 명시적으로 SDK를 초기화한다. 네이티브 병합/기기 동작은 APK 금지에 따라 아직 검증하지 않았다.

클라우드의 검증 광고 크레딧 합계는 중복 적용 방지용이다. 유료 소유권과 무관하다. 같은 계정의 서버 진행을 받아도 최근 기기 출격 기록8개는 보존한다. 새 계정에 기기 진행을 연결할 때는 광고 원장 적용 합계의 계정 바인딩을 초기화한다.

## 실제 설정 전환 방법

설정 이름은 `server/.dev.vars.example`을 참고한다. 운영 비밀값은 Wrangler secret으로 관리하며 문서/채팅/게임 저장에 쓰지 않는다.

1. Play Console의 패키지 소유/비소모성 상품과 현지 가격, Android Publisher API 접근 권한을 준비한다. `PLAY_PACKAGE`, `PLAY_SUPPORTER_PRODUCT`, `PLAY_SERVICE_ACCOUNT`, 독립된64자리 hex `PLAY_TOKEN_KEY`, `PLAY_RTDN_AUDIENCE`/`PLAY_RTDN_EMAIL`이 필요하다. 현재 키의 원장을 복호화할 수 있도록 키를 보존하고, 회전은 원장 재암호화 절차와 함께 수행한다.
2. AdMob 실제 앱/보상 단위 ID와 UMP 메시지·대상 연령/처리 정책을 구성한다. `ADMOB_APP_ID`, `ADMOB_REWARDED_UNIT`은 같은 게시자여야 한다. 보상 종류는 `credits`, 수량20, SSV callback은 `/api/commerce/admob-ssv`다. 실제 단위 설정도 이 값과 일치해야 한다.
3. 인증된 Pub/Sub push의 audience/email과 `/api/commerce/play-rtdn`을 연결한다. 계정 바인딩은 서버가 발급한 값 그대로 구매 `applicationUserName`으로 전달한다.
4. 기본값은 `COMMERCE_BILLING_ENABLED=false`, `COMMERCE_ADS_ENABLED=false`다. 일부 값/샘플 ID만으로 활성화되지 않는다. 실제 기기/스토어 검증을 마치기 전 운영 활성화하지 않는다. 공개 API는 Access의 영향을 별도 확인해야 하며 이번 작업에서 보호 설정을 바꾸지 않는다.
5. 연락처/개인정보/삭제 URL/거래 보관 정책·서명·대상 기기 증거를 갖추고 `google_play_readiness.py`를 통과시킨다. APK 금지 지시의 명시적 변경 전 네이티브 빌드하지 않는다.

Google 키 서버/검증 API 외의 임의 URL이나 HTTP 테스트 플래그로 검증을 우회하는 경로는 없다. 단위 테스트의 의존성 주입과 서명 키는 HTTP에서 접근할 수 없는 격리 fixture다.

운영 관리 API의 D1 권한 오류는 계속 별도 운영 권한 과제다. 관리 API로 재시도하지 않았으며, 실제 스키마는 앱 binding 경로의 정상 API 성공으로 확인했다. 공개 UI의 Access 보호도 해제하지 않았다.

## 검증 기록

검증 로그는 `.local/commerce-v29/`에 둔다. 격리 SQLite 스키마/서명/원장 검사17건, 실제 로컬 Worker/D1 경로1건 및 기존 서버 회귀9건, 합계27건이 통과했다. Flutter 전체 회귀634건 통과, 분석 오류/경고0개(기존 info20개), 준비 검사 도구6건 통과다. 실제 원본 위젯의 모바일320/360/390/430 × 글자1.0/1.3에서 미리보기 전환·구매 비활성·페이지 고정·휠/터치 비스크롤8조건을 확인했다. 근거는 `tools/qa/evidence/commerce-v29/summary.json`이다. 작은 화면의 제목 줄바꿈과 배지 심볼을 캡처로 확인해 마지막 표시를 다듬었다. 실제 Google 결제/광고를 요청하지 않았다.

공식 근거: [Flutter 결제 플러그인](https://pub.dev/packages/in_app_purchase), [AdMob Flutter SDK](https://pub.dev/packages/google_mobile_ads), [Play 구매 조회](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/get), [AdMob SSV](https://developers.google.com/admob/flutter/ssv), [UMP](https://developers.google.com/admob/flutter/privacy).

## 최종 배포·운영 확인

- `.local/quick-web/20261020-024514-106383/report.json`: 정식 컴파일34.71초, 스모크5.19초, 배포12.0초, 전체59.01초. Worker `46c52001-ef92-4080-96c5-2d910386add6` 활성100%. API v10.0.29/D1 정상, 결제·광고 false. 기존 Access 차단 증거를 재사용했다.
- `.local/commerce-v29/operating-api-proof.json`: 별도 검증 계정 생성→원래 진행150 C 저장→상품 상태 조회→비활성 구매/광고503→원래 진행 조회→계정 삭제→삭제 세션401. 실제 Google 결제/광고는 요청하지 않았고 기존 이용자 계정을 변경하지 않았다.
- `tools/qa/evidence/commerce-v29/release-smoke.json`: 정식 main.dart 웹에서 v10.0.29 로비→계정→후원 외형→기본 비교→보상 안내 확인. 새 브라우저 문맥/API401 차단을 사용해 실제 계정에 쓰지 않았다. 최종 캡처는 `release-preview-320.png`다. 사용자의 진행 중인 탭은 강제로 새로고침하지 않았다.
- 마지막 외형 표시 수정 후 관련 Flutter8개가 다시 통과했다. Android manifest는 XML 문법만 확인했으며 네이티브 병합/기기 실행 증거로 계산하지 않는다. APK 빌드 없음.

사전 검사 결과는 `.local/commerce-v29/readiness.json`: 플랫폼/SDK 존재3항목 확인, 나머지13항목 blocked. 이는 실제 결제·광고 출시 준비 완료가 아니다.
