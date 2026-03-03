# Launch Screen 설정 가이드

## 📱 Launch Screen을 단순 색상 배경으로 변경하기

### 방법 1: Launch Screen Storyboard 사용 (권장)

1. **Xcode에서 `LaunchScreen.storyboard` 파일 열기**

2. **기존 요소 모두 삭제**
   - Storyboard에 있는 모든 Label, Image 등 삭제

3. **View Controller의 배경색 설정**
   - View Controller 선택
   - Attributes Inspector (⌥⌘4)에서 Background 색상 변경
   - 추천 색상: `#F2F2F7` (Light Gray 2)
   - RGB: `Red: 0.95, Green: 0.95, Blue: 0.97`

### 방법 2: Info.plist 사용 (iOS 14+)

1. **`Info.plist` 파일 열기**

2. **다음 키 추가:**
```xml
<key>UILaunchScreen</key>
<dict>
    <key>UIColorName</key>
    <string>LaunchScreenBackground</string>
</dict>
```

3. **Assets.xcassets에 Color Set 추가:**
   - Assets.xcassets 열기
   - 우클릭 → New Color Set
   - 이름: `LaunchScreenBackground`
   - 색상: `#F2F2F7`

## 🎨 스플래시 화면 설정

### 1. SplashView.swift 파일 생성 완료 ✅

스플래시 화면이 이미 생성되었습니다:
- 앱 아이콘 표시
- "Quiet Place" 텍스트
- 부드러운 페이드 인 애니메이션

### 2. 앱 아이콘 이미지 준비

**Assets.xcassets에 앱 아이콘 이미지 추가:**

1. `Assets.xcassets` 열기
2. 우클릭 → `New Image Set`
3. 이름: `AppIcon` (정확히 이 이름으로!)
4. 다음 크기의 이미지 추가:
   - 1x: 120x120 px
   - 2x: 240x240 px
   - 3x: 360x360 px

**또는** 앱 아이콘에서 직접 이미지 추출:
- App Icon Set에서 1024x1024 이미지 사용
- Sketch, Figma 등에서 120x120으로 리사이징

### 3. 색상 조정 (선택사항)

`SplashView.swift`에서 배경색 변경:

```swift
// 현재 색상 (연한 회색)
Color(red: 0.95, green: 0.95, blue: 0.97)

// 다른 옵션:
// 흰색
Color.white

// 앱의 기본 색상
Color(red: 0.2, green: 0.2, blue: 0.25)

// 그라데이션
LinearGradient(
    colors: [
        Color(red: 0.95, green: 0.95, blue: 0.97),
        Color(red: 0.9, green: 0.9, blue: 0.95)
    ],
    startPoint: .top,
    endPoint: .bottom
)
```

### 4. 애니메이션 타이밍 조정

`ContentView.swift`에서 스플래시 표시 시간 변경:

```swift
// 현재: 1.5초
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {

// 더 짧게: 1초
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {

// 더 길게: 2초
DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
```

## 📋 체크리스트

- [ ] LaunchScreen.storyboard에서 모든 요소 제거
- [ ] LaunchScreen 배경색을 `#F2F2F7`로 설정
- [ ] Assets.xcassets에 `AppIcon` 이미지 셋 추가
- [ ] 앱 아이콘 이미지 (120x120, 240x240, 360x360) 추가
- [ ] SplashView.swift 파일 프로젝트에 추가 확인
- [ ] ContentView.swift 수정 사항 확인
- [ ] 빌드 및 실행하여 스플래시 화면 확인

## 🎯 결과

1. **앱 실행 시:**
   - Launch Screen: 단순 회색 배경 (즉시 표시)
   - Splash Overlay: 앱 아이콘 + "Quiet Place" (1.5초간 표시)
   - 페이드 아웃 후 메인 화면으로 전환

2. **애니메이션 효과:**
   - 아이콘: 0.8배 → 1.0배 스프링 애니메이션
   - 텍스트: 페이드 인 (0.6초)
   - 전체: 페이드 아웃 (0.4초)

## 💡 팁

### AppIcon 이미지가 없는 경우:
SplashView.swift에서 이미지 대신 SF Symbol 사용:

```swift
// Image("AppIcon") 대신:
Image(systemName: "camera.fill")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 120, height: 120)
    .foregroundColor(.blue)
```

### 스플래시 화면을 한 번만 표시하려면:
ContentView.swift 수정:

```swift
@AppStorage("hasSeenSplash") private var hasSeenSplash = false
@State private var showSplash = true

// onAppear에서:
if !hasSeenSplash {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        withAnimation(.easeOut(duration: 0.4)) {
            showSplash = false
            hasSeenSplash = true
        }
    }
} else {
    showSplash = false
}
```
