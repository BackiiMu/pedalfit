# Pedaltrain 제품 프리셋 + 커스텀 보드

확인일: 2026-10-26. 공식 제품 페이지의 **보드 본체 가로 × 깊이**를 사용한다. 케이스 내부·외부 치수 및 보드 높이를 배치 면적에 섞지 않는다. 같은 본체의 케이스 옵션은 하나의 프리셋으로 합친다.

공식 inch 제원을 1 in = 25.4 mm로 환산했다. 공식 cm 병기값은 페이지마다 반올림 차이가 있다(예: Classic 3 깊이 16 in은 환산 시 406.4 mm, 일부 페이지 cm 표시는 41 cm). 환산값 소수 자릿수는 제조공차나 실측 정밀도를 보장하지 않는다.

## 프리셋 19개

| 시리즈 | 모델 / 공식 출처 | inch (가로 × 깊이) | mm (가로 × 깊이) |
|---|---|---|---|
| Nano | [Nano](https://pedaltrain.com/collections/shop-nano-series/products/pedaltrain-nano-and-accessories-no-case) | 14 × 5.5 | 355.6 × 139.7 |
| Nano | [Nano+](https://pedaltrain.com/collections/under-150/products/pt-npl-sc) | 18 × 5 | 457.2 × 127 |
| Nano | [Nano MAX](https://pedaltrain.com/collections/best-selling-products/products/pedaltrain-nano-max-with-soft-case) | 28 × 5.5 | 711.2 × 139.7 |
| Metro | [Metro 16](https://pedaltrain.com/products/pedaltrain-metro-16-and-accessories-no-case) | 16 × 8 | 406.4 × 203.2 |
| Metro | [Metro 20](https://pedaltrain.com/products/pedaltrain-metro-20-and-accessories-no-case) | 20 × 8 | 508 × 203.2 |
| Metro | [Metro 24](https://pedaltrain.com/collections/flat/products/pt-m24-sc) | 24 × 8 | 609.6 × 203.2 |
| Metro | [Metro MAX](https://pedaltrain.com/collections/flat/products/pedaltrain-metro-max-with-soft-case) | 28 × 8 | 711.2 × 203.2 |
| Classic | [Classic JR](https://pedaltrain.com/products/pt-clj-sc) | 18 × 12.5 | 457.2 × 317.5 |
| Classic | [Classic 1](https://pedaltrain.com/collections/8-incline/products/pt-cl1-tc) | 22 × 12.5 | 558.8 × 317.5 |
| Classic | [Classic 2](https://pedaltrain.com/products/pt-cl2-tc) | 24 × 12.5 | 609.6 × 317.5 |
| Classic | [Classic 3](https://pedaltrain.com/collections/hard-case-models/products/pedaltrain-classic-3-with-tour-case) | 24 × 16 | 609.6 × 406.4 |
| Classic | [JR MAX](https://pedaltrain.com/products/pedaltrain-jr-max-with-soft-case) | 28 × 12.5 | 711.2 × 317.5 |
| Classic | [Classic PRO](https://pedaltrain.com/products/pt-clp-tcw) | 32 × 16 | 812.8 × 406.4 |
| Novo | [Novo 18](https://pedaltrain.com/products/pt-n18-tc) | 18 × 14.5 | 457.2 × 368.3 |
| Novo | [Novo 24](https://pedaltrain.com/collections/pedal-boards/products/pt-n24-sc) | 24 × 14.5 | 609.6 × 368.3 |
| Novo | [Novo 32](https://pedaltrain.com/collections/pedal-boards/products/novo-32-with-wheeled-tour-case) | 32 × 14.5 | 812.8 × 368.3 |
| XD | [XD-18](https://pedaltrain.com/products/pedaltrain-xd18-with-soft-case) | 18 × 17.5 | 457.2 × 444.5 |
| XD | [XD-24](https://pedaltrain.com/products/pedaltrain-xd-24) | 24 × 17.5 | 609.6 × 444.5 |
| Terra | [Terra 42](https://pedaltrain.com/collections/tour-case/products/pt-ter-tcw) | 42 × 14.5 | 1066.8 × 368.3 |

구형 PT-JR/PT-1/PT-2/PT-PRO 및 PRO-FX 등은 이번 기본 목록에서 제외했다. 현재 공식 제품 페이지를 근거로 구성한 19개 크기 목록이며, 모든 과거 모델을 포함한 목록이 아니다.

## 보드 생성 화면

정식 화면은 기존 제안대로 3개(내 보드 / 보드 생성·수정 / 배치 편집기)를 유지한다. 생성 화면에 **제품 프리셋 / 커스텀** 탭을 둔다.

- 제품 프리셋: 제조사 Pedaltrain → 시리즈 필터 → 모델 선택 → 실제 비율 미리보기와 치수 → 보드 만들기.
- 커스텀: 보드 이름 → 가로·깊이(mm) 직접 입력 → 비율 미리보기 → 보드 만들기.
- 프리셋에서 치수를 수정하면 커스텀으로 전환하고 원본 프리셋 ID는 출처로 보관한다. 변경한 치수를 순정 모델 제원처럼 표시하지 않는다.
- 저장된 보드는 선택 시점의 치수를 함께 저장한다. 카탈로그 업데이트가 기존 배치를 자동으로 늘이거나 줄이지 않도록 한다.
- 기존 배치에서 보드를 다른 크기로 바꿀 때 페달의 mm 크기와 좌표를 유지하고 경계 이탈을 표시한다. 페달 자체를 축소해서 억지로 맞추지 않는다.

## 배치 엔진에 사용할 범위

이번 데이터는 상면 배치를 위한 명목 너비·깊이 프리셋이다. 레일별 폭·간격·상면의 정확한 부착 가능 영역, 경사로 인한 투영 차이, 실물 제조공차는 검증하지 않았다. 레일 그림을 넣더라도 해당 정밀 형상을 검증하기 전에는 시각화용으로 구분한다. 본체 외곽 내 배치와 실제 레일 위 고정 가능성은 별도의 검사다.

데이터: `assets/catalog/pedaltrain_boards.json`. Flutter 프리셋 선택 화면에 연결하고 pubspec 에셋으로 등록했다. 공식 사진·로고는 포함하지 않았다.
