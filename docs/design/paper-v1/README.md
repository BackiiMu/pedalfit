# Paper v1 · 2026-10-27

사용자가 제공한 `/Users/backiimu/Downloads/DESIGN-notion.md`를 참고한 앱 디자인 개편입니다. 문서는 디자인 참고 자료로 사용했으며 문서 내 제품별 예제나 웹 마케팅 레이아웃을 앱 기능으로 추가하지 않았습니다.

- 배경 #F6F5F4, 흰 표면, 검정에 가까운 글자, 얇은 회색 선.
- 파랑 #0075DE는 주요 버튼·선택·포커스 표시. 페달 그림은 기존 색상 유지.
- 카드 모서리 10–12, 조작 버튼 6–8, 입력창 6. 웹 마케팅용 알약 CTA는 모바일 도구에 그대로 적용하지 않음.
- 제목은 600–700, 과한 800/900 굵기 제거. 본문은 시스템 서체. Notion 전용 글꼴·아이콘·로고를 복제하지 않음.
- 목록·생성·편집기·라이브러리·맞추기·테트리스에 공통 규칙 적용. 보드 크기·게임 판정·저장 포맷은 유지.
- 장식적 홍보 문구를 기능 설명으로 정리. 패널은 색으로 덩어리를 나누기보다 여백과 경계로 구분.

공통 구현: `lib/design/app_design.dart`. 모든 PNG는 실제 Flutter 화면의 테스트 렌더이며 AI 생성 시안이나 실기기 캡처가 아닙니다. 한국어 확인을 위해 macOS 시스템 글꼴을 테스트 런타임에만 로드했습니다. 재현용 보드 데이터는 예시입니다.

- 01-boards.png: 목록
- 02-editor.png: 편집·선택 패널
- 03-library.png: 제품 검색/추가
- 04-games.png: 두 게임 선택
- 05-tetris.png: 실제 낙하 게임
- 06-packing.png: 맞추기 게임
- overview.png: 목록/편집기/라이브러리 묶음

검증: 정적 분석, 전체 47개 테스트. 320px·390px·가로·넓은 화면과 기존 편집·저장·게임 흐름을 검증했습니다. iPhone 실기기는 연결이 끊겨 이번 디자인 개편을 실기기에 설치하지 못했습니다. Android 실기기도 검증하지 않았습니다.

렌더 재생성:

```
flutter test --no-pub --dart-define=CAPTURE_DESIGN=true test/design_preview_test.dart
flutter test --no-pub --dart-define=CAPTURE_PACKING=true test/packing_screen_test.dart
```
