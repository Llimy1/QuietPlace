# 🛠️ QuietPlace 코드 품질 개선 가이드

**날짜:** 2026년 3월 3일  
**버전:** 1.0.0 출시 전 개선

---

## ✅ **개선 완료된 항목**

### 1. Debug.swift 파일 생성 ✅
- 위치: `QuietPlace/Debug.swift`
- 기능: 디버그 전용 print 함수
- 프로덕션 빌드에서 자동 제거

### 2. Constants.swift 파일 생성 ✅
- 위치: `QuietPlace/Constants.swift`
- 기능: 매직 넘버와 문자열 상수화
- 유지보수성 향상

---

## 🎯 **수동 개선 필요 사항**

### **Step 1: Xcode 프로젝트에 파일 추가**

#### Debug.swift 추가:
```
1. Xcode에서 QuietPlace 그룹 선택
2. 우클릭 > Add Files to "QuietPlace"...
3. QuietPlace/Debug.swift 선택
4. ✅ Copy items if needed
5. ✅ Add to targets: QuietPlace
6. Add 클릭
```

#### Constants.swift 추가:
```
1. Xcode에서 QuietPlace 그룹 선택
2. 우클릭 > Add Files to "QuietPlace"...
3. QuietPlace/Constants.swift 선택
4. ✅ Copy items if needed
5. ✅ Add to targets: QuietPlace
6. Add 클릭
```

---

### **Step 2: print → debugPrint 변경**

**변경할 파일들:**

#### 1. CameraManager.swift
변경 대상 (16개):
```swift
// 변경 전
print("📸 Using 4K resolution")
print("✅ Frame ready!")
print("⚠️ Already capturing photo")

// 변경 후
debugPrint("📸 Using 4K resolution")
debugPrint("✅ Frame ready!")
debugPrint("⚠️ Already capturing photo")
```

**방법:**
- Xcode에서 Find & Replace (Cmd + Shift + F)
- Find: `print("`
- Replace: `debugPrint("`
- 파일별로 신중하게 변경

#### 2. ContentView.swift
변경 대상 (8개):
```swift
print("🔐 앱 시작 시 권한 요청 시작...")
print("✅ 모든 권한 요청 완료")
print("📷 카메라 권한: ...")
print("📸 사진 라이브러리 권한: ...")
```

#### 3. FakeModeView.swift
변경 대상 (3개):
```swift
print("📱 [FakeMode] View appeared")
print("⚠️ Photo capture already in progress")
print("❌ Photo capture failed:")
```

#### 4. SettingsManager.swift
변경 대상 (3개):
```swift
print("✅ Preview scale saved:")
print("✅ Tap to capture:")
print("✅ Settings loaded")
```

---

### **Step 3: 매직 넘버를 상수로 변경 (선택사항)**

#### FakeModeView.swift
```swift
// 변경 전
try? await Task.sleep(for: .seconds(0.4))

// 변경 후
try? await Task.sleep(for: .seconds(AppConstants.Timing.tapDetectionInterval))
```

#### SettingsManager.swift
```swift
// 변경 전
self.previewScale = min(max(savedScale, 0.20), 0.80)

// 변경 후
self.previewScale = min(max(savedScale, 
    AppConstants.UI.previewMinScale), 
    AppConstants.UI.previewMaxScale)
```

---

## ⚡ **빠른 실행 가이드 (추천)**

### **최소한의 개선 (30분)**

```
1. Xcode에서 Debug.swift 프로젝트에 추가
2. 전역 Find & Replace:
   - Find: print("
   - Replace: debugPrint("
   - Scope: 전체 프로젝트
   - ⚠️ 주의: 하나씩 확인하면서 Replace
3. 빌드 & 테스트
```

### **완벽한 개선 (2시간)**

```
1. Debug.swift 추가
2. Constants.swift 추가
3. print → debugPrint 변경 (모든 파일)
4. 매직 넘버 → 상수 변경
5. 하드코딩 문자열 → 상수 변경
6. 주석 정리
7. 빌드 & 테스트
```

---

## 🚫 **절대 변경하지 말 것**

```
❌ 기능 로직
❌ 상태 관리 구조
❌ UI 레이아웃
❌ 카메라/사진 처리 로직
❌ 권한 요청 플로우
❌ 데이터 저장 방식
```

---

## ✅ **변경해도 안전한 것**

```
✅ print → debugPrint
✅ 숫자 → 상수
✅ 문자열 → 상수
✅ 주석 추가/정리
✅ 공백/포맷팅
```

---

## 📊 **우선순위**

### 높음 (필수)
- [x] Debug.swift 생성
- [ ] Debug.swift Xcode에 추가
- [ ] print → debugPrint 변경

### 중간 (권장)
- [x] Constants.swift 생성
- [ ] Constants.swift Xcode에 추가
- [ ] 주요 매직 넘버 상수화

### 낮음 (선택)
- [ ] 모든 매직 넘버 상수화
- [ ] 하드코딩 문자열 상수화
- [ ] 주석 완벽하게 정리

---

## 🔧 **Xcode Find & Replace 사용법**

### 전역 검색/치환:
```
1. Cmd + Shift + F (Find Navigator)
2. 검색어 입력: print("
3. 오른쪽 Replace 입력: debugPrint("
4. Find > Replace
5. 하나씩 확인하면서 Next > Replace
```

### 파일별 검색/치환:
```
1. 파일 열기
2. Cmd + F
3. 검색어 입력
4. Replace 입력
5. Replace All (신중하게!)
```

---

## ⚠️ **주의사항**

### Before Replace:
```
✅ Git commit (현재 상태 저장)
✅ 백업 생성
```

### After Replace:
```
✅ 빌드 확인 (Cmd + B)
✅ 앱 실행 테스트
✅ 모든 기능 동작 확인
✅ Git commit
```

---

## 🎯 **테스트 체크리스트**

변경 후 반드시 테스트:

```
□ 앱 실행
□ 볼륨 버튼 촬영
□ 화면 탭 촬영
□ 프리뷰 크기 조절
□ 갤러리 보기
□ 사진 삭제
□ 사진 내보내기
□ 설정 변경
□ 온보딩 화면
```

---

## 📝 **변경 이력**

### 2026-03-03
- Debug.swift 파일 생성
- Constants.swift 파일 생성
- 개선 가이드 문서 작성

### TODO (출시 후)
- 에러 메시지 사용자 친화적으로 개선
- Analytics 추가 (선택사항)
- 성능 모니터링 추가 (선택사항)

---

**이 가이드를 따라 안전하게 코드 품질을 개선하세요!** ✨
