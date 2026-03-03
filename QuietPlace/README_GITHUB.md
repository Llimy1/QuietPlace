# 📱 QuietPlace

<div align="center">

![QuietPlace Icon](https://via.placeholder.com/150?text=QuietPlace)

**조용한 공간을 위한 완벽한 무음 카메라**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017.0+-blue.svg)](https://www.apple.com/ios)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.9-purple.svg)](https://developer.apple.com/xcode/swiftui/)

[다운로드](#) | [개인정보처리방침](https://llimy1.github.io/QuietPlace/privacy.html) | [이용약관](https://llimy1.github.io/QuietPlace/terms.html)

</div>

---

## 📖 소개

**QuietPlace**는 도서관, 강의실, 세미나, 전시회 등 조용한 환경에서 셔터음 없이 메모와 자료를 촬영할 수 있는 iOS 애플리케이션입니다.

### ✨ 주요 기능

- 🔇 **완전한 무음 촬영** - 셔터음 없이 조용하게 촬영
- 📸 **볼륨 버튼 촬영** - 빠르고 편리한 촬영
- 🎭 **Fake Mode** - 가짜 화면으로 위장
- 📱 **스마트 갤러리** - 빠른 썸네일 로딩
- 💾 **HEIC 고화질 저장** - 용량 효율적인 저장
- 📤 **사진첩 내보내기** - 쉬운 공유
- 🔒 **개인정보 보호** - 로컬 저장만 사용

---

## 🎯 사용 사례

✅ **도서관에서 책 촬영**  
✅ **강의실에서 보드 촬영** (강사 허가 필요)  
✅ **세미나 자료 기록** (허가 확인 필요)  
✅ **조용한 환경에서 메모**

⚠️ **주의:** 타인의 동의 없는 촬영은 법적으로 금지되어 있습니다.

---

## 🛠️ 기술 스택

- **언어:** Swift 5.9
- **프레임워크:** SwiftUI
- **최소 버전:** iOS 17.0+
- **아키텍처:** MVVM
- **카메라:** AVFoundation
- **이미지 처리:** Core Image
- **저장:** FileManager + HEIC

---

## 📱 스크린샷

<div align="center">

| FakeMode | 갤러리 | 설정 |
|----------|--------|------|
| ![](https://via.placeholder.com/250x540?text=FakeMode) | ![](https://via.placeholder.com/250x540?text=Gallery) | ![](https://via.placeholder.com/250x540?text=Settings) |

</div>

---

## 🚀 시작하기

### 요구사항

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+
- Apple Developer Account (배포 시)

### 설치

```bash
# 저장소 클론
git clone https://github.com/Llimy1/QuietPlace.git

# 프로젝트 열기
cd QuietPlace
open QuietPlace.xcodeproj

# 빌드 및 실행 (⌘R)
```

---

## 📂 프로젝트 구조

```
QuietPlace/
├── App/
│   └── QuietPlaceApp.swift
├── Views/
│   ├── ContentView.swift
│   ├── FakeModeView.swift
│   ├── GalleryView.swift
│   ├── SettingsView.swift
│   ├── OnboardingView.swift
│   └── SplashView.swift
├── Managers/
│   ├── CameraManager.swift
│   ├── PhotoDataManager.swift
│   └── VolumeButtonHandler.swift
├── Components/
│   ├── CameraPreview.swift
│   └── PhotoPicker.swift
├── Utilities/
│   ├── Debug.swift
│   └── Constants.swift
└── Resources/
    └── Assets.xcassets
```

---

## ⚙️ 주요 컴포넌트

### CameraManager
- 카메라 세션 관리
- 고성능 촬영 (CIContext 최적화)
- 프레임 처리 및 이미지 생성

### PhotoDataManager
- HEIC 포맷 저장
- 썸네일 캐싱
- 파일 시스템 관리

### VolumeButtonHandler
- 볼륨 버튼 이벤트 감지
- 시스템 UI 숨김
- 안정적인 모니터링

---

## 🔧 설정

### Info.plist 권한

```xml
<key>NSCameraUsageDescription</key>
<string>QuietPlace는 조용한 환경에서 메모와 자료를 촬영하기 위해 카메라 권한이 필요합니다.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>촬영한 사진을 사진첩으로 내보내기 위해 권한이 필요합니다.</string>
```

---

## 🎨 커스터마이징

### Fake Mode 스타일
- 그라디언트 배경
- 커스텀 텍스트
- 배경 이미지 업로드
- 이모지 추가

### 설정 옵션
- 프리뷰 크기 (소/중/대)
- 탭 촬영 활성화
- 플래시 설정
- 저장 형식

---

## 📊 성능 최적화

- ✅ CIContext 사전 워밍업
- ✅ 썸네일 캐싱 (메모리 + 디스크)
- ✅ 비동기 이미지 로딩
- ✅ HEIC 고효율 압축
- ✅ 메모리 관리 최적화

---

## 🔒 개인정보 보호

QuietPlace는 사용자의 개인정보를 최우선으로 생각합니다:

- ✅ 모든 데이터는 **기기에만** 저장
- ✅ **인터넷 연결 불필요**
- ✅ **외부 서버 전송 없음**
- ✅ **광고 없음**
- ✅ **추적 없음**

자세한 내용: [개인정보처리방침](https://llimy1.github.io/QuietPlace/privacy.html)

---

## ⚖️ 법적 고지

본 앱은 **교육적, 학술적 목적**으로만 사용되어야 합니다.

⚠️ **금지 행위:**
- 타인의 동의 없는 촬영
- 사생활 침해
- 불법적인 목적의 사용

🚨 **법적 책임:** 모든 법적 책임은 사용자에게 있습니다.

자세한 내용: [이용약관](https://llimy1.github.io/QuietPlace/terms.html)

---

## 🛣️ 로드맵

### Version 1.0 (출시)
- [x] 무음 촬영
- [x] Fake Mode
- [x] 갤러리
- [x] 사진첩 내보내기

### Version 1.1 (예정)
- [ ] 위젯 지원
- [ ] 라이브 포토 지원
- [ ] 더 많은 Fake Mode 템플릿
- [ ] 사진 편집 기능

### Version 2.0 (계획)
- [ ] iPad 지원
- [ ] macOS Catalyst
- [ ] 클라우드 동기화 (옵션)
- [ ] Apple Watch 연동

---

## 🤝 기여

기여를 환영합니다! Pull Request를 보내주세요.

1. Fork this repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

---

## 📧 문의

- **개발자:** 이민혁
- **이메일:** llimy.mh@gmail.com
- **GitHub:** [@Llimy1](https://github.com/Llimy1)

---

## 🙏 감사의 말

- Apple - SwiftUI 및 AVFoundation 프레임워크
- iOS 개발 커뮤니티
- 모든 베타 테스터분들

---

## 📱 다운로드

<div align="center">

[![Download on the App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&releaseDate=1234567890)](https://apps.apple.com/)

**곧 App Store에서 만나보세요!**

</div>

---

<div align="center">

**QuietPlace** - 조용함의 시작

Made with ❤️ in Seoul, Korea

© 2026 QuietPlace. All rights reserved.

</div>
