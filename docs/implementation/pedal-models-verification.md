# 실제 모델 추가 검증

2026-10-26

- 실제 모델 8종 추가: Ibanez TS9, TS808, TS Mini, TS9DX; Neural DSP Quad Cortex mini; EHX Big Muff Pi (NYC); IK TONEX Pedal, TONEX ONE.
- 기존 가상 페달 14종 유지. 기존 저장 데이터의 새 필드는 기본값을 사용하므로 이전 보드를 읽을 수 있습니다.
- 제조사·한글 별칭 검색, 제조사명 표시, 와이드 기기 썸네일 크기 수정.
- Quad Cortex mini / TONEX Pedal에는 화면과 복수 스위치가 있는 개략도를 표시합니다. 사진·로고 에셋은 추가하지 않았습니다.
- Big Muff Pi의 폭·깊이 축 해석에 실측 확인이 필요하며 목록 카드에도 안내합니다.
- Flutter 정적 분석: 오류 없음.
- 전체 테스트 18개 통과. 새 테스트는 8종 치수의 저장/복원, 구버전 데이터 호환, 한글 검색, 320px 화면의 와이드 페달 표시를 확인합니다.
- iPhone 17 Pro 시뮬레이터 실행 완료. Android 빌드는 이번 변경에서 검증하지 않았습니다.

치수 근거와 제한은 ../research/pedal_model_presets.md 참조.
이후 페달 테트리스 게임을 구현했습니다. 게임 범위와 검증은 tetris-verification.md를 참고하세요.
