# ✅ QuietPlace 최종 출시 체크리스트

**마지막 업데이트:** 2026년 3월 3일 오후 10시  
**출시 목표일:** 2026년 3월 10-15일

---

## 📱 1. 코드 & 기능 (100% 완료)

### 핵심 기능
- [x] 무음 촬영
- [x] 볼륨 버튼 촬영
- [x] 화면 탭 촬영
- [x] Fake Mode (위장 화면)
- [x] 갤러리 (날짜별 정렬)
- [x] 사진 선택/삭제
- [x] 사진첩 내보내기
- [x] HEIC 고화질 저장
- [x] 썸네일 캐싱

### UI/UX
- [x] 스플래시 화면 (앱 아이콘 + "Quiet Place")
- [x] 온보딩 (7페이지)
- [x] 설정 화면
- [x] 갤러리 UI
- [x] Fake Mode 커스터마이징
- [x] 런처 스크린 (앱 아이콘 색상)

### 최적화
- [x] CIContext 워밍업
- [x] 비동기 이미지 로딩
- [x] 메모리 효율적인 캐싱
- [x] debugPrint 전역 적용
- [x] Constants 분리

---

## 📄 2. 문서 (100% 완료)

### 웹 페이지
- [x] **개인정보처리방침** (https://llimy1.github.io/QuietPlace/privacy.html)
- [x] **이용약관** (https://llimy1.github.io/QuietPlace/terms.html)

### 프로젝트 문서
- [x] README.md
- [x] README_GITHUB.md (GitHub용 상세 버전)
- [x] APP_STORE_SUBMISSION_GUIDE.md
- [x] LAUNCH_SCREEN_GUIDE.md
- [x] CODE_IMPROVEMENT_GUIDE.md
- [x] FINAL_CHECKLIST.md
- [x] APP_ICON_GUIDE.md
- [x] CURRENT_STATUS.md

---

## 🎨 3. 리소스 준비

### 앱 아이콘
- [x] 1024x1024 앱 아이콘 (AppIcon.png)
- [x] "쉿" 제스처 디자인
- [x] Assets에 추가
- [x] 모든 크기 생성

### 색상 테마
- [x] 런처 스크린: Indigo-Purple 그라디언트
- [x] 스플래시 화면: 동일 색상
- [x] 앱 아이콘과 일치

### 스크린샷 (미완료 - 가장 중요!)
- [ ] **iPhone 15 Pro Max (6.7")** - 3-10장
  - [ ] FakeMode 메인 화면
  - [ ] 갤러리 화면
  - [ ] Fake Mode 커스터마이징
  - [ ] 볼륨 버튼 촬영 설명
  - [ ] 설정 화면
  - [ ] 온보딩 주요 장면

- [ ] **iPhone 11 Pro Max (6.5")** - 동일 장면
- [ ] **iPad Pro 12.9"** (선택사항)

### 앱 프리뷰 비디오 (선택사항)
- [ ] 15-30초 데모 영상
- [ ] H.264 포맷
- [ ] 886 x 1920 px

---

## 🔧 4. Xcode 설정

### 프로젝트 설정
- [x] Bundle ID: `Llimy1.QuietPlace`
- [x] Display Name: `QuietPlace`
- [x] Version: `1.0`
- [x] Build: `1`
- [x] Minimum iOS: `17.0`

### Info.plist
- [x] `NSCameraUsageDescription` ✅
  ```
  QuietPlace는 조용한 환경에서 메모와 자료를 촬영하기 위해 카메라 권한이 필요합니다.
  ```

- [x] `NSPhotoLibraryAddUsageDescription` ✅
  ```
  촬영한 사진을 사진첩으로 내보내기 위해 권한이 필요합니다.
  ```

### Signing & Capabilities
- [ ] **Apple Developer 계정 로그인** ⚠️
- [ ] **Automatic Signing 활성화**
- [ ] **Provisioning Profile 확인**
- [ ] **Team 선택**

---

## 📱 5. App Store Connect

### 계정 준비
- [ ] **Apple Developer Program 가입** ($99/년)
- [ ] **계정 활성화 확인**

### 앱 등록
- [ ] **새 앱 생성**
  - Platform: iOS
  - Name: QuietPlace
  - Primary Language: Korean (또는 English)
  - Bundle ID: Llimy1.QuietPlace
  - SKU: quietplace-2026

### 앱 정보 (App Information)
- [ ] **카테고리:** Photography & Video (Primary)
- [ ] **부제목:** 조용한 공간을 위한 무음 카메라
- [ ] **개인정보처리방침 URL:** https://llimy1.github.io/QuietPlace/privacy.html
- [ ] **지원 URL:** https://llimy1.github.io/QuietPlace/privacy.html

### 버전 정보
- [ ] **스크린샷 업로드** (6.7", 6.5")
- [ ] **앱 프리뷰 업로드** (선택사항)
- [ ] **설명 작성**
- [ ] **키워드 입력**
- [ ] **프로모션 텍스트** (선택사항)

### 연령 등급
- [ ] **콘텐츠 설명서 작성**
- [ ] 예상 등급: **4+**

### 가격 및 배포
- [ ] **가격:** 무료
- [ ] **배포 지역:** 전세계 (또는 한국)
- [ ] **출시 시점:** 수동 (심사 후 직접 출시)

---

## 🏗️ 6. 빌드 & 제출

### Archive 준비
- [ ] **Clean Build Folder** (⇧⌘K)
- [ ] **실제 기기에서 테스트**
- [ ] **모든 기능 동작 확인**
- [ ] **크래시 없음 확인**

### Archive 생성
- [ ] **Product → Archive**
- [ ] **Organizer에서 확인**
- [ ] **Validate App** (검증)
- [ ] **Distribute App → App Store Connect**

### TestFlight
- [ ] **빌드 업로드 완료 확인**
- [ ] **처리 대기** (1-2시간)
- [ ] **내부 테스터 초대** (선택사항)
- [ ] **베타 테스트** (선택사항)

### 앱 심사 제출
- [ ] **심사 정보 작성**
- [ ] **연락처 정보 입력**
- [ ] **심사 노트 작성**
- [ ] **데모 계정** (해당 없음)
- [ ] **Submit for Review** 클릭

---

## 📝 7. 앱 설명 (Description)

```
QuietPlace - 조용한 공간을 위한 완벽한 카메라

도서관, 강의실, 세미나, 전시회 등 조용한 환경에서 소리 없이 메모와 자료를 촬영하세요.

✨ 주요 기능

📸 완전한 무음 촬영
• 셔터음 없이 조용하게 촬영
• 볼륨 버튼으로 빠른 촬영
• 탭으로도 촬영 가능

🎨 Fake Mode
• 가짜 화면으로 위장
• 비밀스럽게 촬영
• 다양한 커스터마이징 옵션

📱 스마트 갤러리
• 빠른 썸네일 로딩
• 고화질 HEIC 저장
• 사진첩으로 쉬운 내보내기

🔒 개인정보 보호
• 모든 데이터는 기기에만 저장
• 인터넷 연결 불필요
• 광고 및 추적 없음

⚡️ 최적화된 성능
• 빠른 촬영 속도
• 메모리 효율적
• 배터리 절약

완벽한 학습 도우미
• 수업 자료 촬영
• 도서관에서 메모
• 조용한 환경에서 기록

지금 다운로드하여 QuietPlace의 편리함을 경험해보세요!

⚠️ 책임있는 사용
본 앱은 학술적, 교육적 목적으로 설계되었습니다. 타인의 동의 없이 사진을 촬영하는 것은 법적으로 금지되어 있으며, 사용자는 관련 법률을 준수할 책임이 있습니다.
```

### 키워드 (100자 이내)
```
무음카메라,조용한,도서관,강의,메모,학습,공부,세미나,전시회,자료수집
```

---

## 📊 8. 릴리즈 노트

### Version 1.0
```
QuietPlace의 첫 번째 버전을 소개합니다!

✨ 새로운 기능
• 완전한 무음 촬영
• Fake Mode로 비밀스럽게 촬영
• 볼륨 버튼 촬영 지원
• 고속 갤러리
• HEIC 고화질 저장
• 사진첩 내보내기

🔒 개인정보 보호
• 로컬 저장만 사용
• 인터넷 연결 불필요
• 광고 없음

피드백과 제안을 기다리고 있습니다!
```

---

## 🧪 9. 테스트 체크리스트

### 기능 테스트
- [ ] 카메라 권한 요청 확인
- [ ] 사진 라이브러리 권한 요청 확인
- [ ] 볼륨 버튼으로 촬영
- [ ] 화면 탭으로 촬영
- [ ] Fake Mode 진입 및 촬영
- [ ] 갤러리에서 사진 보기
- [ ] 사진 삭제
- [ ] 사진첩 내보내기
- [ ] 설정 변경 (프리뷰 크기, 탭 촬영 등)
- [ ] 온보딩 플로우
- [ ] 스플래시 화면

### 성능 테스트
- [ ] 메모리 누수 확인 (Instruments)
- [ ] 배터리 소모 테스트
- [ ] 빠른 연속 촬영
- [ ] 대량 사진 로딩 (100장+)

### 호환성 테스트
- [ ] iPhone 15 Pro Max
- [ ] iPhone 14 Pro
- [ ] iPhone SE (3rd gen)
- [ ] iOS 17.0
- [ ] iOS 17.4

---

## ⚠️ 10. 법적 체크리스트

### 문서 확인
- [x] 개인정보처리방침 작성 완료
- [x] 이용약관 작성 완료
- [x] 법적 고지사항 포함
- [x] 책임 면책 조항 포함

### 앱 내 안내
- [x] 온보딩에서 책임있는 사용 안내
- [x] 설정에서 법적 고지 표시
- [x] 합법적 용도 명시

### App Store 심사 대비
- [x] 교육적 목적 강조
- [x] 불법 사용 방지 안내
- [x] 사생활 보호 경고

---

## 📅 11. 일정

### 이번 주 (3월 3-7일)
- [x] **월요일:** 코드 정리 완료 ✅
- [x] **월요일:** 스플래시 화면 추가 ✅
- [x] **월요일:** 이용약관 작성 ✅
- [ ] **화요일:** Apple Developer 가입
- [ ] **화요일:** 스크린샷 촬영 시작
- [ ] **수요일:** 스크린샷 완료 및 편집
- [ ] **목요일:** App Store Connect 설정
- [ ] **금요일:** Archive & 업로드

### 다음 주 (3월 10-14일)
- [ ] **월요일:** TestFlight 테스트
- [ ] **화요일:** 피드백 반영
- [ ] **수요일:** 최종 제출
- [ ] **목-금:** 심사 대기

### 출시 예정
- [ ] **3월 15일 전후:** 앱 출시! 🎉

---

## 🎯 12. 우선순위

### 🔴 최우선 (필수)
1. **Apple Developer 계정 가입** - 제출 필수
2. **스크린샷 촬영** - App Store 필수
3. **Archive 빌드** - 업로드 필수
4. **App Store Connect 설정** - 제출 필수

### 🟡 중요 (권장)
5. 앱 프리뷰 비디오 제작
6. TestFlight 베타 테스트
7. 프로모션 자료 준비

### 🟢 선택 (나중에)
8. 소셜 미디어 홍보
9. 프레스 릴리스
10. 앱 웹사이트 제작

---

## 📧 13. 연락처 & 지원

### 개발자 정보
- **이름:** 이민혁
- **이메일:** llimy.mh@gmail.com
- **GitHub:** @Llimy1

### URL
- **GitHub:** https://github.com/Llimy1/QuietPlace
- **개인정보처리방침:** https://llimy1.github.io/QuietPlace/privacy.html
- **이용약관:** https://llimy1.github.io/QuietPlace/terms.html

---

## ✅ 14. 최종 제출 전 확인

### 마지막 점검
- [ ] 모든 print → debugPrint 변경 확인
- [ ] 테스트 코드 제거
- [ ] 주석 정리
- [ ] 버전 번호 확인
- [ ] Bundle ID 확인
- [ ] 앱 아이콘 확인
- [ ] 권한 설명 확인
- [ ] URL 전부 테스트
- [ ] 빌드 경고 0개
- [ ] 빌드 에러 0개

### 실제 기기 테스트
- [ ] iPhone에서 완전 테스트
- [ ] 재설치 테스트
- [ ] 권한 거부 시나리오 테스트
- [ ] 메모리 부족 시나리오 테스트

---

## 🎉 15. 출시 준비 완료!

### 체크 완료 시
```
✅ 코드: 100%
✅ 문서: 100%
✅ 리소스: 95% (스크린샷 제외)
✅ 법적 준비: 100%
✅ 테스트: 진행 중

다음 단계: 스크린샷 촬영 → Archive → 제출!
```

---

**행운을 빕니다! 🚀**

QuietPlace가 곧 App Store에서 만나뵙겠습니다!

© 2026 QuietPlace. All rights reserved.
