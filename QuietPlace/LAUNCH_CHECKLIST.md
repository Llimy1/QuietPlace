# 🚀 QuietPlace 출시 체크리스트

## ✅ 완료된 작업

- [x] 민감한 표현 수정
  - "가짜 모드" → "조용한 모드"
  - "비밀 촬영" → "무음 촬영"
  - 아이콘 변경 (lock.fill → moon.fill)
  
- [x] 온보딩 화면 수정
  - 합법적 사용 사례 강조 (도서관, 강의실, 전시회)
  - 법적 책임 고지 제거 (개인정보 보호정책에 포함)
  
- [x] 개인정보 보호정책 업데이트
  - 합법적 용도 명시
  - 법적 책임 고지 추가
  - 사용 제한 안내 포함

- [x] App Store 설명 문서 작성
  - 한국어/영어 설명
  - 키워드 정리
  - 스크린샷 가이드

---

## 🔴 필수 완료 항목 (출시 전)

### 1. Info.plist 권한 설정 확인 ⚠️ **가장 중요**
```xml
<key>NSCameraUsageDescription</key>
<string>도서관, 강의실 등 조용한 환경에서 자료를 촬영하기 위해 카메라 접근이 필요합니다.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>촬영한 사진을 사진 보관함에 저장하기 위해 필요합니다.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>사진을 사진첩으로 내보내기 위해 필요합니다.</string>
```

**확인 방법:**
- Xcode에서 프로젝트 선택 → Target → Info 탭
- 또는 Info.plist 파일 직접 확인

---

### 2. 앱 아이콘 추가 📱
**위치:** `Assets.xcassets/AppIcon.appiconset`

**필요한 크기:**
- 1024x1024 (App Store)
- 60x60 @2x, @3x (iPhone)
- 40x40 @2x, @3x (Spotlight)
- 20x20 @2x, @3x (Settings)

**디자인 제안:**
- 🌙 달 아이콘 (조용한 밤 이미지)
- 📷 카메라 + 무음 심볼
- 배경: 어두운 파란색/보라색 그라디언트

---

### 3. 버전 및 빌드 번호 설정
**Xcode → Target → General**
- **Display Name:** QuietPlace
- **Bundle Identifier:** `com.[yourname].quietplace`
- **Version:** 1.0.0
- **Build:** 1

**SettingsView.swift 동기화:**
```swift
SettingsRow(
    title: "앱 정보",
    value: "v1.0.0",  // ← 이 값을 Info.plist와 동일하게
    showArrow: false
)
```

자동으로 버전 가져오기로 수정하는 것을 권장:
```swift
let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
```

---

### 4. 개인정보 처리방침 URL 🔗
App Store는 **외부 URL** 필요 (앱 내부만으로는 불충분)

**옵션:**
1. **GitHub Pages** (무료, 추천)
   - `privacy.md` 작성
   - GitHub Pages로 호스팅
   - URL: `https://[username].github.io/quietplace/privacy`

2. **개인 웹사이트**
   
3. **Notion 공개 페이지**

**내용:** PrivacyPolicyView.swift 내용을 웹페이지로 변환

---

### 5. 지원 URL 📧
**완료!** ✅

**설정됨:**
- 이메일: `llimy.mh@gmail.com`
- 앱 내 설정 > 문의 섹션에서 이메일 복사 가능
- App Store Connect에 입력할 Support URL: `mailto:llimy.mh@gmail.com`

---

### 6. 스크린샷 준비 📸

#### 필수 크기 (3가지)
1. **6.7" (iPhone 15 Pro Max):** 1290 x 2796
2. **6.5" (iPhone 11 Pro Max):** 1242 x 2688
3. **5.5" (iPhone 8 Plus):** 1242 x 2208

#### 스크린샷 내용 (최소 3장, 최대 10장)
1. **조용한 모드 메인 화면**
   - 잠금화면 스타일 UI
   - 하단 카메라 프리뷰

2. **갤러리 화면**
   - 날짜별 정리된 사진들
   - 깔끔한 그리드 레이아웃

3. **볼륨 버튼 촬영 안내**
   - 온보딩 3페이지 활용
   - 볼륨 버튼 강조

4. **프리뷰 크기 조절**
   - 온보딩 5페이지 활용

5. **설정 화면**
   - 프리뷰 크기 슬라이더

**촬영 방법:**
- Xcode Simulator 사용
- `Cmd + S`로 스크린샷 저장
- 또는 실제 기기에서 촬영 후 크기 조정

---

### 7. Apple Developer 계정 설정 👤

#### 필요한 것:
- [ ] Apple Developer Program 가입 ($99/년)
- [ ] Certificates, Identifiers & Profiles 설정
- [ ] App Store Connect 앱 등록

#### 단계:
1. **Certificates** 생성
   - iOS Distribution Certificate

2. **Identifiers** 등록
   - App ID: `com.[yourname].quietplace`
   - Capabilities: 기본 설정

3. **Provisioning Profiles** 생성
   - Distribution Profile

4. **Xcode Signing** 설정
   - Target → Signing & Capabilities
   - Team 선택
   - Automatically manage signing 체크

---

## 🟡 권장 사항 (출시 전)

### 8. 코드 정리
- [ ] 불필요한 주석 제거
- [ ] Console.log/print 문 제거 또는 조건부 컴파일
- [ ] TODO 주석 처리

```swift
#if DEBUG
print("디버그 메시지")
#endif
```

---

### 9. 성능 최적화 확인
- [ ] 메모리 누수 체크 (Instruments)
- [ ] 사진 여러 장 촬영 테스트
- [ ] 백그라운드/포그라운드 전환 테스트
- [ ] 저장 공간 부족 시나리오

---

### 10. 접근성 개선
- [ ] VoiceOver 지원 추가
```swift
.accessibilityLabel("촬영 버튼")
.accessibilityHint("볼륨 버튼으로도 촬영할 수 있습니다")
```

- [ ] 다이내믹 타입 지원 확인
- [ ] 색상 대비 확인 (WCAG 기준)

---

### 11. 현지화 (선택사항)
영어 지원을 추가하면 전세계 출시 가능

**추가할 파일:**
- `en.lproj/Localizable.strings`

**또는 SwiftUI 코드에서:**
```swift
Text("조용한 모드", comment: "Quiet mode title")
```

---

### 12. TestFlight 베타 테스트
- [ ] 내부 테스터 초대 (최대 100명)
- [ ] 외부 테스터 초대 (최대 10,000명)
- [ ] 최소 1주일 테스트
- [ ] 피드백 수집 및 버그 수정

---

## 📱 App Store Connect 제출 단계

### Step 1: 앱 등록
1. App Store Connect 로그인
2. "My Apps" → "+" → "New App"
3. 기본 정보 입력
   - Platform: iOS
   - Name: QuietPlace
   - Primary Language: Korean
   - Bundle ID: 선택
   - SKU: QUIETPLACE001

### Step 2: 앱 정보 입력
1. **App Information**
   - Name: QuietPlace
   - Subtitle: 조용한 장소에서도 편리하게 무음 촬영
   - Category: 사진 및 비디오 (Primary), 유틸리티 (Secondary)

2. **Pricing and Availability**
   - Price: 무료
   - Availability: 모든 국가

3. **App Privacy**
   - Data Collection: **None** (수집하는 데이터 없음)
   - Privacy Policy URL: [준비한 URL]

### Step 3: Version 정보
1. **What's New in This Version**
   ```
   QuietPlace의 첫 번째 버전을 소개합니다! 🎉
   
   • 조용한 환경에서 무음 촬영
   • 볼륨 버튼으로 간편한 촬영
   • 프리뷰 크기 자유롭게 조절
   • 안전한 앱 내 갤러리
   ```

2. **Screenshots** 업로드
   - 6.7" (필수)
   - 6.5" (필수)
   - 5.5" (필수)

3. **Description** (APP_STORE_DESCRIPTION.md 참조)

4. **Keywords**
   ```
   무음카메라,조용한,도서관,강의실,사진,카메라,메모,자료,전시회,학습
   ```

5. **Support URL**
   - [준비한 지원 URL]

6. **Marketing URL** (선택사항)

### Step 4: Build 업로드
1. Xcode → Product → Archive
2. Archive 완료 후 Organizer 열림
3. "Distribute App" 클릭
4. "App Store Connect" 선택
5. "Upload" 선택
6. 자동 서명 또는 수동 서명 선택
7. 업로드 완료 (10-30분 후 App Store Connect에 표시)

### Step 5: 심사 노트 작성
```
안녕하세요,

이 앱은 도서관, 강의실, 전시회 등 조용한 환경에서
학습 및 업무 목적으로 자료를 촬영할 수 있도록 돕는 앱입니다.

주요 기능:
• 볼륨 버튼으로 무음 촬영
• 앱 내부 안전한 갤러리
• 사진첩 내보내기 기능

개인정보 보호:
• 모든 사진은 로컬에만 저장됩니다
• 서버 통신이 전혀 없습니다
• 광고 및 추적이 없습니다

법적 준수:
• 앱 내 개인정보 보호정책에 합법적 용도로만 사용해야 한다는
  명확한 안내가 포함되어 있습니다
• 타인의 사생활 침해 금지 고지 포함

테스트 방법:
1. 앱 실행 → 온보딩에서 카메라/사진 권한 허용
2. 조용한 모드 화면에서 볼륨 버튼으로 촬영
3. 갤러리에서 촬영한 사진 확인
4. 사진 선택 후 사진첩으로 내보내기

감사합니다.
```

### Step 6: 제출
1. Build 선택
2. Export Compliance: **No** (암호화 미사용)
3. "Submit for Review" 클릭

---

## ⏱️ 예상 일정

| 단계 | 예상 시간 |
|------|----------|
| 코드 최종 점검 | 1-2일 |
| 앱 아이콘 디자인 | 1일 |
| 스크린샷 준비 | 1일 |
| App Store Connect 설정 | 1일 |
| Archive & 업로드 | 1시간 |
| **TestFlight 베타** | **1-2주** |
| Apple 심사 대기 | 1-3일 |
| 심사 (통과 시) | 1일 |
| **총 예상 기간** | **2-3주** |

---

## ⚠️ 심사 거부 가능성 및 대응

### 가능한 거부 사유

1. **Guideline 1.1.2 - Safety - Objectionable Content**
   - "사생활 침해 우려"
   
   **대응:**
   - 합법적 용도 강조
   - 교육/업무 목적 명시
   - 법적 고지 추가됨을 설명

2. **Guideline 5.1.1 - Legal - Privacy**
   - "불법 촬영 가능성"
   
   **대응:**
   - 개인정보 보호정책에 명확한 제한 사항 명시
   - 사용자 책임 고지 포함
   - 합법적 사용 사례만 마케팅

3. **Guideline 2.3.1 - Performance - Accurate Metadata**
   - "앱 설명과 실제 기능 불일치"
   
   **대응:**
   - 앱 설명과 UI/UX 일치 확인
   - 스크린샷이 실제 기능 정확히 표현

### 거부 시 대응 방법
1. 리뷰 노트 꼼꼼히 읽기
2. 요청사항 정확히 파악
3. 필요한 수정 사항 반영
4. Resolution Center에서 상세히 설명
5. 재제출

---

## 🎯 출시 후 할 일

### 모니터링
- [ ] App Store Connect에서 다운로드 수 확인
- [ ] 크래시 리포트 확인 (Xcode Organizer)
- [ ] 사용자 리뷰 모니터링

### 마케팅
- [ ] SNS 공유
- [ ] 커뮤니티 홍보 (클리앙, 뽐뿌 등)
- [ ] 블로그 포스팅

### 업데이트 계획
- 버그 수정
- 사용자 피드백 반영
- 새로운 기능 추가

---

## 📞 문제 발생 시

### 기술적 문제
- Apple Developer Forums
- Stack Overflow
- Xcode Documentation

### 심사 관련
- App Store Review Guidelines
- App Review (App Store Connect)
- Resolution Center

---

**마지막 업데이트:** 2026년 3월 3일
**버전:** 1.0.0 준비 중
