# 금오공과대학교 LMS 로고 v4

파일: `kumoh-lms-logo-v4.png`.
사용자가 첨부한 금오공대 로고와 부산경상대학교 LMS 배치 예시를 바탕으로 내장 image_gen 도구로 합성했다. 사용자가 선택한 디자인으로 Android/iOS 런처에 적용했다. 흰색 배경과 Android adaptive icon 여백을 사용한다.

재생성: 프로젝트 루트에서 `dart run flutter_launcher_icons`. 설정은 `flutter_launcher_icons.yaml`에 있다.

## 생성 프롬프트

Use case: compositing. Create a clean university LMS logo lockup using the TWO attached reference images. Image 1 is the EXACT source emblem to preserve: the round Kumoh National Institute of Technology seal, gray circular ring with white Korean and English lettering, blue water-drop symbol, and black "kit" in the center. Image 2 is a LAYOUT REFERENCE ONLY: a university seal centered above a Korean university name and LMS on a second text line. Discard the previously generated abstract app icons completely. Use ONLY the actual Kumoh emblem from Image 1, preserving its lettering, proportions, gray ring, blue symbol and black kit precisely, without redesigning or replacing any part. Place this emblem centered at the top, with generous clear spacing below it. Under the emblem add the exact Korean text "금오공과대학교" on ONE centered line in a clean bold Korean sans-serif typeface, dark charcoal. On the next line center the exact text "LMS" in a slightly smaller medium-weight matching sans-serif, dark charcoal. These are the ONLY added words. Korean spelling must be exact: 금오공과대학교. Composition similar to the hierarchy of Image 2, but use the Kumoh emblem and specified text only. Transparent background, no dark/black background, no decorative effects, no drop shadows, no outline on the added text, no gradients outside the original emblem, no mockup. Square canvas, complete emblem and two text lines fully visible with balanced padding. Emblem about 55% canvas width in the upper portion, text line about 75% canvas width beneath it. Output one high quality centered logo lockup with genuine alpha transparency.
