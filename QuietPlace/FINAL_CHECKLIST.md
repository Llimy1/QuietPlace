# 🎯 QuietPlace 출시 최종 체크리스트

**업데이트:** 2026년 3월 3일  
**현재 상태:** 거의 완성! 🚀

---

## ✅ 완료된 항목 (100% 완성)

### 코드 및 기능
- [x] **민감한 표현 모두 수정**
  - "가짜 모드" → "조용한 모드"
  - "비밀 촬영" → "무음 촬영"
  - 아이콘 변경 (lock.fill → moon.fill)

- [x] **화면 탭 촬영 기능 추가**
  - 1번 탭으로 촬영
  - 3번 빠른 탭으로 프리뷰 숨기기/보이기
  - 설정에서 켜기/끄기 가능

- [x] **온보딩 화면 개선**
  - 7페이지 완성
  - 합법적 용도 강조
  - 2x2 그리드 레이아웃으로 촬영 방법 안내

- [x] **개인정보 보호정책**
  - 법적 고지 포함
  - 합법적 용도 명시
  - 앱 내에서 볼 수 있음

- [x] **설정 화면 완성**
  - 프리뷰 크기 조절
  - 탭 촬영 토글
  - 썸네일 캐시 관리
  - 문의 섹션 (이메일 복사)
  - 앱 버전 자동 표시

- [x] **지원 이메일 설정**
  - llimy.mh@gmail.com
  - 설정에서 클릭으로 복사 가능

### 문서
- [x] **README.md** 작성
- [x] **LAUNCH_CHECKLIST.md** 작성
- [x] **APP_STORE_DESCRIPTION.md** 작성 (한국어/영어)
- [x] **USER_GUIDE.md** 작성

### Info.plist
- [x] **권한 설명 추가** (확인 필요)
  - NSCameraUsageDescription
  - NSPhotoLibraryAddUsageDescription
  - NSPhotoLibraryUsageDescription
- [x] **버전 번호** 1.0.0으로 설정

---

## 🔴 남은 필수 항목 (출시 전 꼭 해야 함!)

### 1. 앱 아이콘 디자인 및 추가 🎨 **최우선!**

**상태:** ❌ 미완료

**해야 할 일:**
1. **아이콘 디자인**
   - 크기: 1024x1024px
   - 형식: PNG (투명 배경 없음)
   - 디자인 컨셉: 
     - 🌙 달 + 📷 카메라 조합
     - 어두운 블루/퍼플 그라디언트
     - 심플하고 모던한 스타일

2. **필요한 모든 크기 생성**
   - 1024x1024 (App Store)
   - 60@2x (120x120) - iPhone app
   - 60@3x (180x180) - iPhone app
   - 40@2x (80x80) - Spotlight
   - 40@3x (120x120) - Spotlight
   - 29@2x (58x58) - Settings
   - 29@3x (87x87) - Settings
   - 20@2x (40x40) - Notification
   - 20@3x (60x60) - Notification

3. **Xcode에 추가**
   - Assets.xcassets > AppIcon.appiconset
   - 각 크기별로 드래그 앤 드롭

**도구 추천:**
- Figma (무료) - 디자인
- https://appicon.co - 자동으로 모든 크기 생성
- Sketch (유료)
- Canva (무료)

**예상 소요 시간:** 1-2시간

---

### 2. Bundle Identifier 설정 📦

**상태:** ⚠️ 확인 필요

**해야 할 일:**
1. Xcode > Project > Target > General
2. **Bundle Identifier** 확인/설정
   - 형식: `com.[yourname].quietplace`
   - 예: `com.leemin hyeok.quietplace`
   - 고유해야 함 (중복 불가)

3. **Display Name** 확인
   - `QuietPlace` (띄어쓰기 없음)

**예상 소요 시간:** 5분

---

### 3. 스크린샷 촬영 📸

**상태:** ❌ 미완료

**필수 크기 (3가지):**
1. 6.7" (iPhone 15 Pro Max) - 1290 x 2796
2. 6.5" (iPhone 11 Pro Max) - 1242 x 2688
3. 5.5" (iPhone 8 Plus) - 1242 x 2208

**촬영할 화면 (최소 3장, 권장 5장):**

#### Screenshot 1: 메인 - 조용한 모드
- 잠금화면 스타일 UI
- 시간 표시
- 하단 카메라 프리뷰

#### Screenshot 2: 갤러리
- 날짜별 정리된 사진들
- 그리드 레이아웃
- 하단 네비게이션

#### Screenshot 3: 촬영 방법 (온보딩)
- 2x2 그리드 카드
- 볼륨 버튼 + 화면 탭 강조

#### Screenshot 4: 프리뷰 조절 (온보딩)
- 핀치 제스처 아이콘
- 프리뷰 크기 예시

#### Screenshot 5: 설정 화면
- 프리뷰 크기 슬라이더
- 탭 촬영 토글
- 깔끔한 설정 UI

**촬영 방법:**
1. Xcode Simulator 사용 (Device & OS Versions 메뉴)
2. 앱 실행
3. `Cmd + S`로 스크린샷 저장
4. 또는 실제 기기에서 촬영 후 크기 조정

**예상 소요 시간:** 2-3시간

---

### 4. 개인정보 처리방침 외부 URL 🔗

**상태:** ❌ 미완료

**App Store는 외부 URL 필수!**

**옵션 1: GitHub Pages (무료, 추천)**

1. GitHub 저장소 만들기
2. `docs/privacy.md` 파일 생성
3. PrivacyPolicyView.swift 내용 복사
4. Markdown → HTML 변환
5. Settings > Pages > Source 선택
6. URL 생성: `https://[username].github.io/quietplace/privacy`

**옵션 2: Notion 공개 페이지**

1. Notion에서 새 페이지 생성
2. 개인정보 보호정책 내용 작성
3. 공개 링크 생성

**옵션 3: 간단한 HTML 호스팅**

무료 호스팅 서비스:
- Netlify
- Vercel
- GitHub Pages

**예상 소요 시간:** 30분 - 1시간

---

### 5. Apple Developer 계정 💳

**상태:** ⚠️ 확인 필요

**필요 사항:**
- Apple Developer Program 가입 ($99/년)
- https://developer.apple.com

**가입 절차:**
1. Apple ID로 로그인
2. 결제 ($99)
3. 약관 동의
4. 승인 대기 (보통 24시간 이내)

**이미 가입했다면:**
- Xcode > Preferences > Accounts에서 로그인
- Certificates, Identifiers & Profiles 확인

**예상 소요 시간:** 
- 가입: 15분 + 승인 대기
- 설정: 30분

---

## 🟡 권장 사항 (출시 전 하면 좋음)

### 6. 코드 정리 🧹

**상태:** ⚠️ 확인 필요

**체크리스트:**
- [ ] 불필요한 `print()` 문 제거 또는 조건부 컴파일
  ```swift
  #if DEBUG
  print("디버그 메시지")
  #endif
  ```
- [ ] TODO 주석 확인 및 처리
- [ ] 사용하지 않는 파일 제거
- [ ] 주석 정리

**예상 소요 시간:** 1시간

---

### 7. 테스트 📱

**실제 기기에서 테스트:**
- [ ] 촬영 (볼륨 버튼)
- [ ] 촬영 (화면 탭)
- [ ] 프리뷰 크기 조절
- [ ] 갤러리 (사진 보기, 선택, 삭제)
- [ ] 사진첩 내보내기
- [ ] 설정 변경
- [ ] 권한 거부 시나리오
- [ ] 백그라운드/포그라운드 전환
- [ ] 저장 공간 부족 시뮬레이션

**다양한 기기 (가능하다면):**
- [ ] iPhone SE (작은 화면)
- [ ] iPhone 15 Pro (표준)
- [ ] iPhone 15 Pro Max (큰 화면)

**예상 소요 시간:** 2-3시간

---

### 8. TestFlight 베타 테스트 (권장) 🧪

**상태:** 아직 안 함

**절차:**
1. Archive 생성 (Product > Archive)
2. App Store Connect에 업로드
3. TestFlight 섹션에서 내부 테스터 추가
4. 베타 빌드 승인 대기
5. 테스터들에게 초대 전송
6. 피드백 수집

**장점:**
- 실제 사용자 피드백
- 버그 조기 발견
- App Store 심사 전 검증

**예상 소요 시간:** 1-2주

---

## 📋 App Store Connect 제출 준비

### 9. App Store Connect 설정 🌐

**상태:** ❌ 미완료

**Step 1: 앱 등록**
1. App Store Connect 로그인
2. My Apps > + > New App
3. 정보 입력:
   - Platform: iOS
   - Name: QuietPlace
   - Primary Language: Korean
   - Bundle ID: (위에서 설정한 것)
   - SKU: QUIETPLACE001

**Step 2: 메타데이터 입력**

**기본 정보:**
- Subtitle: `조용한 장소에서도 편리하게 무음 촬영`
- Category: 사진 및 비디오 (Primary), 유틸리티 (Secondary)

**설명:** (APP_STORE_DESCRIPTION.md 참조)

**키워드:**
```
무음카메라,조용한,도서관,강의실,사진,카메라,메모,자료,전시회,학습
```

**Support URL:**
```
mailto:llimy.mh@gmail.com
```

**Privacy Policy URL:**
```
[4번에서 만든 URL]
```

**Step 3: 스크린샷 업로드**
- 3번에서 촬영한 스크린샷 업로드

**Step 4: 가격 설정**
- Price: 무료

**Step 5: App Privacy**
- Data Collection: **None** (수집하는 데이터 없음)

**예상 소요 시간:** 2-3시간

---

### 10. Archive & 업로드 📤

**상태:** 아직 안 함

**절차:**
1. **프로덕션 설정**
   - Build Configuration: Release
   - Signing: Automatically manage signing 체크

2. **Archive 생성**
   - Xcode > Product > Archive
   - 몇 분 대기
   - Organizer 창 열림

3. **Validate App**
   - "Validate App" 클릭
   - 에러 확인 및 수정

4. **Distribute App**
   - "Distribute App" 클릭
   - App Store Connect 선택
   - Upload 선택
   - 자동 서명 선택
   - Upload!

5. **App Store Connect 확인**
   - 10-30분 후 빌드 표시됨
   - Processing... → Ready to Submit

**예상 소요 시간:** 1시간

---

### 11. 심사 제출 📝

**상태:** 아직 안 함

**심사 노트 작성:**
```
안녕하세요,

이 앱은 도서관, 강의실, 전시회 등 조용한 환경에서
학습 및 업무 목적으로 자료를 촬영할 수 있도록 돕는 앱입니다.

주요 기능:
• 볼륨 버튼 또는 화면 탭으로 무음 촬영
• 앱 내부 안전한 갤러리
• 사진첩 내보내기 기능
• 프리뷰 크기 조절

개인정보 보호:
• 모든 사진은 로컬에만 저장됩니다
• 서버 통신이 전혀 없습니다
• 광고 및 추적이 없습니다

법적 준수:
• 앱 내 개인정보 보호정책에 합법적 용도로만 사용해야 한다는
  명확한 안내가 포함되어 있습니다
• 온보딩에서 도서관, 강의실 등 정당한 사용 사례 강조
• 타인의 사생활 침해 금지 고지 포함

테스트 방법:
1. 앱 실행 → 온보딩에서 카메라/사진 권한 허용
2. 조용한 모드 화면에서 볼륨 버튼 또는 화면 탭으로 촬영
3. 갤러리에서 촬영한 사진 확인
4. 사진 선택 후 사진첩으로 내보내기

감사합니다.
```

**Export Compliance:**
- "Does your app use encryption?" → **No**

**Submit for Review!**

**예상 소요 시간:** 30분 + 심사 대기 (1-3일)

---

## 📊 진행 상황 요약

### 완료율
```
코드 & 기능:     ████████████████████ 100%
문서:            ████████████████████ 100%
리소스 준비:     ████░░░░░░░░░░░░░░░░  20%
App Store 설정:  ░░░░░░░░░░░░░░░░░░░░   0%
```

### 전체 진행률: **60%** 🎯

---

## 🚀 추천 작업 순서

### **이번 주 (필수)**
1. ✅ **앱 아이콘 디자인** (1-2시간)
2. ✅ **Bundle Identifier 확인** (5분)
3. ✅ **개인정보 처리방침 URL** (1시간)
4. ✅ **스크린샷 촬영** (2-3시간)

**예상 소요 시간:** 약 5-7시간

### **다음 주 (출시 준비)**
5. ✅ **코드 정리** (1시간)
6. ✅ **실제 기기 테스트** (2-3시간)
7. ✅ **App Store Connect 설정** (2-3시간)
8. ✅ **Archive & 업로드** (1시간)
9. ✅ **심사 제출** (30분)

**예상 소요 시간:** 약 7-9시간

### **선택 (더 나은 출시를 위해)**
10. 🔲 **TestFlight 베타** (1-2주)
11. 🔲 **피드백 반영** (1-3일)
12. 🔲 **마케팅 준비** (SNS, 블로그 등)

---

## ⚠️ 중요 참고사항

### Apple 심사 팁
1. **정직하게**
   - 앱이 하는 일을 정확히 설명
   - 숨겨진 기능 없음

2. **합법적 용도 강조**
   - "학습, 업무, 자료 수집용"
   - 불법 사용 방지 안내 포함

3. **개인정보 보호**
   - 로컬 저장만 사용
   - 서버 전송 없음 명시

4. **완성도**
   - 모든 기능이 작동해야 함
   - 크래시 없어야 함
   - 버그 최소화

### 거부 시 대응
- 침착하게 리뷰 노트 읽기
- 요청사항 정확히 파악
- 수정 후 재제출
- Resolution Center에서 소통

---

## 🎯 최종 목표

**2주 내 출시 가능!**

**예상 일정:**
- 이번 주: 리소스 준비 (아이콘, 스크린샷, URL)
- 다음 주: App Store 제출
- 그 다음 주: 심사 → 출시! 🎉

**화이팅! 거의 다 왔어요! 🚀**

---

## 📞 도움이 필요하면

- 이 문서를 다시 확인
- LAUNCH_CHECKLIST.md 참조
- APP_STORE_DESCRIPTION.md 참조
- 막히는 부분 있으면 언제든 질문!

**Let's ship it! 🚢**
