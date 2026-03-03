# 🌙 QuietPlace

> 조용한 장소에서도 편리하게 무음 촬영

QuietPlace는 도서관, 강의실, 전시회 등 조용한 환경에서 방해 없이 사진을 촬영할 수 있도록 도와주는 iOS 앱입니다.

---

## ✨ 주요 기능

### 📱 조용한 모드
- 잠금화면 스타일의 깔끔한 인터페이스
- 화면 하단에 작은 카메라 프리뷰
- 조용한 환경에서 방해받지 않고 촬영

### 🔊 볼륨 버튼 촬영
- 볼륨 업/다운 버튼으로 간편하게 촬영
- 셔터음 없는 무음 촬영
- 진동으로 촬영 완료 알림

### 📏 프리뷰 크기 조절
- 두 손가락 핀치 제스처로 확대/축소
- 20% ~ 80% 자유롭게 조절
- 60% 이상 시 촬영 버튼 자동 표시

### 🖼️ 안전한 갤러리
- 앱 내부에만 저장되는 사진
- 날짜별 자동 정리
- 여러 장 선택 및 삭제
- 사진첩으로 간편하게 내보내기

---

## 🔒 개인정보 보호

- ✅ 모든 사진은 기기에만 저장
- ✅ 서버 전송 없음
- ✅ 광고 및 추적 없음
- ✅ 인터넷 연결 불필요

---

## 📱 시스템 요구사항

- **iOS:** 17.0 이상
- **기기:** iPhone (iPad 미지원)
- **권한:** 카메라, 사진 라이브러리

---

## 🛠️ 기술 스택

- **Language:** Swift 5.9+
- **Framework:** SwiftUI
- **Architecture:** MVVM
- **Minimum Deployment:** iOS 17.0

### 주요 기술
- `AVFoundation` - 카메라 제어 및 사진 촬영
- `Photos` - 사진 라이브러리 관리
- `MediaPlayer` - 볼륨 버튼 감지
- `SwiftUI` - 선언적 UI
- `Combine` - 반응형 프로그래밍

---

## 📂 프로젝트 구조

```
QuietPlace/
├── App/
│   ├── QuietPlaceApp.swift          # 앱 진입점
│   └── ContentView.swift             # 메인 뷰 (탭 관리)
│
├── Views/
│   ├── FakeModeView.swift           # 조용한 모드 (메인 카메라)
│   ├── GalleryView.swift            # 갤러리 화면
│   ├── SettingsView.swift           # 설정 화면
│   ├── OnboardingView.swift         # 온보딩 화면
│   ├── PrivacyPolicyView.swift      # 개인정보 보호정책
│   └── Components/
│       ├── CameraPreview.swift      # 카메라 프리뷰
│       ├── PhotoPicker.swift        # 사진 선택기
│       └── BrandComponents.swift    # 브랜드 컴포넌트
│
├── Managers/
│   ├── CameraManager.swift          # 카메라 세션 관리
│   ├── PhotoDataManager.swift       # 사진 저장/로드
│   ├── SettingsManager.swift        # 설정 관리
│   ├── VolumeButtonHandler.swift    # 볼륨 버튼 감지
│   └── ThumbnailCache.swift         # 썸네일 캐시
│
└── Models/
    └── PhotoItem.swift              # 사진 데이터 모델
```

---

## 🚀 빌드 및 실행

### 1. 요구사항
- Xcode 15.0 이상
- macOS Sonoma 14.0 이상
- Apple Developer 계정 (배포 시)

### 2. 설치
```bash
git clone https://github.com/[username]/quietplace.git
cd quietplace
open QuietPlace.xcodeproj
```

### 3. 실행
1. Xcode에서 프로젝트 열기
2. 시뮬레이터 또는 실제 기기 선택
3. `Cmd + R` 로 빌드 및 실행

> ⚠️ **참고:** 카메라 기능은 시뮬레이터에서 제대로 작동하지 않습니다. 실제 기기에서 테스트하세요.

---

## 📋 출시 체크리스트

자세한 내용은 [`LAUNCH_CHECKLIST.md`](./LAUNCH_CHECKLIST.md) 참조

### 필수 항목
- [ ] Info.plist 권한 설명 추가
- [ ] 앱 아이콘 추가 (모든 크기)
- [ ] 버전 및 빌드 번호 설정
- [ ] 개인정보 처리방침 URL 준비
- [ ] 스크린샷 준비 (3개 크기)
- [ ] App Store Connect 설정

### 심사 대비
- [x] 민감한 표현 수정 완료
- [x] 합법적 용도 강조
- [x] 법적 책임 고지 추가

---

## ⚠️ 법적 고지

이 앱은 **학습, 업무, 자료 수집 등 합법적인 용도로만 사용**되어야 합니다.

타인의 동의 없는 촬영이나 사생활 침해는 법적으로 금지되어 있으며, 사용자는 관련 법률을 준수할 책임이 있습니다.

---

## 📄 라이선스

Copyright © 2026 이민혁. All rights reserved.

---

## 🤝 기여

버그 리포트나 기능 제안은 Issues를 통해 제출해주세요.

---

## 📞 지원

- **이메일:** llimy.mh@gmail.com
- **GitHub Issues:** [이슈 페이지]

---

## 📱 다운로드

App Store에서 다운로드 (출시 예정)

[App Store 링크]

---

**Made with ❤️ in Swift**
