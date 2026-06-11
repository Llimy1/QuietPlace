//
//  GalleryView.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/23/26.
//

import SwiftUI
import Combine

struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var photoDataManager = PhotoDataManager.shared
    @State private var isSelectionMode = false
    @State private var selectedPhotos: Set<String> = []
    @State private var showFullscreen = false
    @State private var selectedPhotoIndex = 0
    @State private var isDownloading = false
    @State private var showDownloadAlert = false
    @State private var downloadMessage = ""
    @State private var hasInitialized = false

    // 드래그 선택 상태 (애플 사진앱 스타일: 가로 시작 = 선택, 세로 시작 = 스크롤)
    @State private var photoFrames: [String: CGRect] = [:]
    @State private var isDragSelecting = false
    @State private var dragSelectionPhase: DragSelectionPhase = .idle
    @State private var dragAnchorPhotoID: String?
    @State private var lastDragPhotoID: String?
    @State private var dragShouldSelect = true
    @State private var preDragSelection: Set<String> = []

    // 가장자리 자동 스크롤 상태
    @State private var scrollProxy: ScrollViewProxy?
    @State private var scrollViewportSize: CGSize = .zero
    @State private var lastDragLocation: CGPoint?
    @State private var autoScrollDirection: AutoScrollDirection = .none
    @State private var autoScrollTask: Task<Void, Never>?

    /// 셀 프레임과 드래그 좌표를 같은 기준으로 맞추기 위한 좌표공간 이름
    static let dragSelectionSpace = "gallerySelectionSpace"

    /// 드래그 시작 방향에 따라 선택/스크롤 중 하나로 잠금
    private enum DragSelectionPhase {
        case idle        // 방향 미정
        case selecting   // 가로 시작 → 드래그 선택
        case scrolling   // 세로 시작 → 스크롤에 양보
    }

    private enum AutoScrollDirection {
        case none
        case up
        case down
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 메인 컨텐츠
                if photoDataManager.photos.isEmpty {
                    // 사진이 없을 때
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer()
                                .frame(height: 60)
                            
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("사진이 없습니다")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("카메라로 사진을 촬영하세요")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                            
                            NativeAdCardView()
                                .padding(.top, 20)
                        }
                        .padding(.bottom, 130)
                    }
                } else {
                    // 사진이 있을 때
                    ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20, pinnedViews: []) {
                            // 네이티브 광고 1개 - LazyVStack 첫 항목으로 고정
                            // (섹션마다 넣으면 스크롤 시 WKWebView 프로세스가 반복 생성/파괴됨)
                            NativeAdCardView()

                            // 날짜별로 그룹핑된 사진들 (화면에 보이는 섹션만 렌더링)
                            ForEach(sortedDateKeys, id: \.self) { dateKey in
                                if let sectionPhotos = groupedPhotos[dateKey] {
                                    PhotoSection(
                                        title: "\(dateKey) - \(formattedDate(for: sectionPhotos.first?.createdDate))",
                                        photos: sectionPhotos,
                                        isSelectionMode: $isSelectionMode,
                                        selectedPhotos: $selectedPhotos,
                                        onPhotoTap: { photo in
                                            if let index = photoDataManager.photos.firstIndex(where: { $0.id == photo.id }) {
                                                selectedPhotoIndex = index
                                                showFullscreen = true
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 80)
                    }
                    .coordinateSpace(name: Self.dragSelectionSpace)
                    .scrollDisabled(isDragSelecting)
                    .simultaneousGesture(dragSelectionGesture)
                    .onPreferenceChange(PhotoFramePreferenceKey.self) { frames in
                        photoFrames = frames
                    }
                    .background(
                        // 가장자리 자동 스크롤 판정용 뷰포트 크기 추적
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear { scrollViewportSize = geometry.size }
                                .onChange(of: geometry.size) { _, newSize in
                                    scrollViewportSize = newSize
                                }
                        }
                    )
                    .onAppear { scrollProxy = proxy }
                    }
                }
                
                // 하단 배너 광고
                BannerAdView()
                    .frame(height: AppConstants.Ads.bannerHeight)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            }
            
            // 선택 모드일 때 액션 바 (바텀 네비게이션 위에 표시)
            if isSelectionMode && !selectedPhotos.isEmpty {
                VStack {
                    Spacer()
                    
                    SelectionActionBar(
                        selectedCount: selectedPhotos.count,
                        onDelete: deleteSelectedPhotos,
                        onDownload: downloadSelectedPhotos
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, AppConstants.Ads.bannerHeight)
                }
            }
        }
            .navigationTitle("갤러리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button(action: {
                            isSelectionMode = false
                            selectedPhotos.removeAll()
                        }) {
                            Text("취소")
                        }
                    } else {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("뒤로")
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !photoDataManager.photos.isEmpty {
                        Button(action: {
                            if isSelectionMode {
                                // 전체 선택/해제
                                if selectedPhotos.count == photoDataManager.photos.count {
                                    selectedPhotos.removeAll()
                                } else {
                                    selectedPhotos = Set(photoDataManager.photos.map { $0.id })
                                }
                            } else {
                                isSelectionMode.toggle()
                            }
                        }) {
                            Text(isSelectionMode ? (selectedPhotos.count == photoDataManager.photos.count ? "전체 해제" : "전체 선택") : "선택")
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showFullscreen) {
                PhotoFullscreenView(
                    photos: photoDataManager.photos,
                    currentIndex: $selectedPhotoIndex,
                    isPresented: $showFullscreen
                )
            }
            .alert("사진 저장 완료", isPresented: $showDownloadAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(downloadMessage)
            }
            .alert("저장 오류", isPresented: $photoDataManager.showError) {
                Button("확인", role: .cancel) {
                    photoDataManager.showError = false
                }
            } message: {
                Text(photoDataManager.errorMessage ?? "알 수 없는 오류가 발생했습니다")
            }
            .onAppear {
                // PhotoDataManager.init()에서 이미 로드를 시작하므로
                // photos가 비어있을 때(아직 로드 전)만 명시적 로드 호출
                guard !hasInitialized else { return }
                hasInitialized = true
                if photoDataManager.photos.isEmpty {
                    Task {
                        await photoDataManager.loadPhotosAsync()
                    }
                }
            }
            .onChange(of: isSelectionMode) { _, isOn in
                if !isOn {
                    resetDragSelection()
                }
            }
            .overlay {
                if isDownloading {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text("사진 저장 중...")
                                .foregroundColor(.white)
                                .font(.system(size: 17))
                        }
                        .padding(30)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
            }
    }
    
    // MARK: - Computed Properties

    // photosByDate()는 매 render마다 호출되므로 photos가 바뀔 때만 재계산
    private var groupedPhotos: [String: [PhotoItem]] {
        photoDataManager.photosByDate()
    }

    private var sortedDateKeys: [String] {
        groupedPhotos.keys.sorted { key1, key2 in
            // Today > Yesterday > 다른 날짜 순서
            if key1 == "Today" { return true }
            if key2 == "Today" { return false }
            if key1 == "Yesterday" { return true }
            if key2 == "Yesterday" { return false }
            return key1 > key2
        }
    }

    private static let sectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private func formattedDate(for date: Date?) -> String {
        guard let date = date else { return "" }
        return Self.sectionDateFormatter.string(from: date)
    }
    
    // MARK: - Drag Selection (애플 사진앱 스타일)

    private var dragSelectionGesture: some Gesture {
        // minimumDistance로 탭과 구분: 12pt 미만 이동은 탭으로 처리됨
        DragGesture(minimumDistance: 12, coordinateSpace: .named(Self.dragSelectionSpace))
            .onChanged(handleDragChanged)
            .onEnded { _ in
                resetDragSelection()
            }
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        guard isSelectionMode else { return }

        if dragSelectionPhase == .idle {
            // 시작 방향으로 잠금: 가로 = 선택 드래그, 세로 = 스크롤에 양보
            let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
            if isHorizontal, let anchorID = photoID(at: value.startLocation) {
                dragSelectionPhase = .selecting
                isDragSelecting = true  // 선택 드래그 동안만 스크롤 잠금
                dragAnchorPhotoID = anchorID
                dragShouldSelect = !selectedPhotos.contains(anchorID)
                preDragSelection = selectedPhotos
            } else {
                dragSelectionPhase = .scrolling
                return
            }
        }

        guard dragSelectionPhase == .selecting, let anchorID = dragAnchorPhotoID else { return }

        lastDragLocation = value.location
        updateAutoScroll(for: value.location)

        // 손가락이 셀 사이 틈이나 광고 위에 있으면 마지막으로 지나간 셀 기준 유지
        guard let currentID = photoID(at: value.location) ?? lastDragPhotoID else { return }
        if currentID != lastDragPhotoID {
            lastDragPhotoID = currentID
            UISelectionFeedbackGenerator().selectionChanged()
        }
        applyDragSelection(from: anchorID, to: currentID)
    }

    private func resetDragSelection() {
        stopAutoScroll()
        dragSelectionPhase = .idle
        isDragSelecting = false
        dragAnchorPhotoID = nil
        lastDragPhotoID = nil
        lastDragLocation = nil
        preDragSelection = []
    }

    // MARK: 가장자리 자동 스크롤

    private func updateAutoScroll(for location: CGPoint) {
        let edgeZone: CGFloat = 100
        let viewportHeight = scrollViewportSize.height

        if viewportHeight > 0, location.y > viewportHeight - edgeZone {
            autoScrollDirection = .down
        } else if location.y < edgeZone {
            autoScrollDirection = .up
        } else {
            autoScrollDirection = .none
        }

        if autoScrollDirection == .none {
            stopAutoScroll()
        } else if autoScrollTask == nil {
            startAutoScroll()
        }
    }

    private func startAutoScroll() {
        autoScrollTask = Task { @MainActor in
            while !Task.isCancelled && dragSelectionPhase == .selecting {
                performAutoScrollStep()
                try? await Task.sleep(for: .milliseconds(160))
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTask?.cancel()
        autoScrollTask = nil
        autoScrollDirection = .none
    }

    /// 한 줄(3칸)씩 스크롤하면서, 새로 드러난 셀을 멈춰 있는 손가락 위치 기준으로 선택에 반영
    private func performAutoScrollStep() {
        guard dragSelectionPhase == .selecting,
              autoScrollDirection != .none,
              let proxy = scrollProxy,
              let anchorID = dragAnchorPhotoID else { return }

        if let location = lastDragLocation,
           let idUnderFinger = photoID(at: location) {
            if idUnderFinger != lastDragPhotoID {
                lastDragPhotoID = idUnderFinger
                UISelectionFeedbackGenerator().selectionChanged()
            }
            applyDragSelection(from: anchorID, to: idUnderFinger)
        }

        guard let referenceID = lastDragPhotoID else { return }
        let orderedIDs = orderedPhotoIDs
        guard let referenceIndex = orderedIDs.firstIndex(of: referenceID) else { return }

        let rowStep = 3  // 3열 그리드 한 줄
        let targetIndex = autoScrollDirection == .down
            ? min(referenceIndex + rowStep, orderedIDs.count - 1)
            : max(referenceIndex - rowStep, 0)
        guard targetIndex != referenceIndex else { return }

        withAnimation(.linear(duration: 0.15)) {
            proxy.scrollTo(
                orderedIDs[targetIndex],
                anchor: autoScrollDirection == .down ? .bottom : .top
            )
        }
    }

    /// 현재 보이는 셀 프레임에서 좌표에 해당하는 사진 ID 찾기
    private func photoID(at point: CGPoint) -> String? {
        photoFrames.first(where: { $0.value.contains(point) })?.key
    }

    /// 화면 표시 순서로 펼친 사진 ID 목록
    private var orderedPhotoIDs: [String] {
        sortedDateKeys.flatMap { groupedPhotos[$0]?.map(\.id) ?? [] }
    }

    /// 앵커~현재 셀 구간을 일괄 선택/해제 (드래그를 되돌리면 시작 시점 상태로 복원)
    private func applyDragSelection(from anchorID: String, to currentID: String) {
        let orderedIDs = orderedPhotoIDs
        guard let anchorIndex = orderedIDs.firstIndex(of: anchorID),
              let currentIndex = orderedIDs.firstIndex(of: currentID) else { return }

        var newSelection = preDragSelection
        for id in orderedIDs[min(anchorIndex, currentIndex)...max(anchorIndex, currentIndex)] {
            if dragShouldSelect {
                newSelection.insert(id)
            } else {
                newSelection.remove(id)
            }
        }
        selectedPhotos = newSelection
    }

    // MARK: - Actions

    private func deleteSelectedPhotos() {
        let photosToDelete = photoDataManager.photos.filter { selectedPhotos.contains($0.id) }
        
        withAnimation(.easeOut(duration: 0.3)) {
            photoDataManager.deletePhotos(photosToDelete)
            selectedPhotos.removeAll()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSelectionMode = false
        }
    }
    
    private func downloadSelectedPhotos() {
        let photosToDownload = photoDataManager.photos.filter { selectedPhotos.contains($0.id) }
        
        Task {
            isDownloading = true
            
            let result = await photoDataManager.downloadToPhotosLibrary(photosToDownload)
            
            isDownloading = false
            
            if result.success {
                // 한국어 메시지
                if result.savedCount == result.totalCount {
                    // 모두 성공
                    downloadMessage = "사진 \(result.savedCount)장이 저장되었습니다"
                } else {
                    // 일부만 성공
                    downloadMessage = "사진 \(result.savedCount)/\(result.totalCount)장이 저장되었습니다"
                }
            } else {
                downloadMessage = "사진을 저장할 수 없습니다. 설정에서 사진 라이브러리 접근 권한을 확인해주세요."
            }
            
            showDownloadAlert = true
            selectedPhotos.removeAll()
            isSelectionMode = false
        }
    }
}

/// 드래그 선택 히트테스트용으로 화면에 보이는 셀들의 프레임을 수집
struct PhotoFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct SelectablePhotoGrid: View {
    let photos: [PhotoItem]
    @Binding var isSelectionMode: Bool
    @Binding var selectedPhotos: Set<String>
    let onPhotoTap: (PhotoItem) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(photos) { photo in
                PhotoThumbnail(
                    photo: photo,
                    isSelected: selectedPhotos.contains(photo.id),
                    isSelectionMode: isSelectionMode
                )
                .overlay {
                    // 선택 모드에서만 셀 프레임 보고 (드래그 선택 히트테스트용)
                    if isSelectionMode {
                        GeometryReader { geometry in
                            Color.clear
                                .preference(
                                    key: PhotoFramePreferenceKey.self,
                                    value: [photo.id: geometry.frame(in: .named(GalleryView.dragSelectionSpace))]
                                )
                        }
                    }
                }
                .onTapGesture {
                    handlePhotoTap(photo)
                }
                .id(photo.id)  // 가장자리 자동 스크롤(scrollTo) 타깃
            }
        }
    }

    private func handlePhotoTap(_ photo: PhotoItem) {
        if isSelectionMode {
            toggleSelection(for: photo.id)
        } else {
            onPhotoTap(photo)
        }
    }

    private func toggleSelection(for photoID: String) {
        if selectedPhotos.contains(photoID) {
            selectedPhotos.remove(photoID)
        } else {
            selectedPhotos.insert(photoID)
        }
    }
}

// 사진 섹션 (날짜별 광고 1개 - 사진 중간에 삽입)
struct PhotoSectionWithAds: View {
    let title: String
    let photos: [PhotoItem]
    @Binding var isSelectionMode: Bool
    @Binding var selectedPhotos: Set<String>
    let onPhotoTap: (PhotoItem) -> Void
    
    /// 광고 삽입 위치 (사진 N장 뒤에 광고)
    private let adInsertAfter = 6
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 16)
            
            if photos.count <= adInsertAfter {
                // 사진이 적으면: 그리드 전체 → 광고
                photoGrid(photos: photos)
                NativeAdCardView()
            } else {
                // 사진이 많으면: 앞부분 그리드 → 광고 → 나머지 그리드
                let firstChunk = Array(photos.prefix(adInsertAfter))
                let restChunk = Array(photos.dropFirst(adInsertAfter))
                
                photoGrid(photos: firstChunk)
                NativeAdCardView()
                photoGrid(photos: restChunk)
            }
        }
    }
    
    @ViewBuilder
    private func photoGrid(photos: [PhotoItem]) -> some View {
        SelectablePhotoGrid(
            photos: photos,
            isSelectionMode: $isSelectionMode,
            selectedPhotos: $selectedPhotos,
            onPhotoTap: onPhotoTap
        )
    }
}

// 사진 섹션 (기본)
struct PhotoSection: View {
    let title: String
    let photos: [PhotoItem]
    @Binding var isSelectionMode: Bool
    @Binding var selectedPhotos: Set<String>
    let onPhotoTap: (PhotoItem) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 16)
            
            SelectablePhotoGrid(
                photos: photos,
                isSelectionMode: $isSelectionMode,
                selectedPhotos: $selectedPhotos,
                onPhotoTap: onPhotoTap
            )
        }
    }
}

// 사진 썸네일
struct PhotoThumbnail: View {
    let photo: PhotoItem
    let isSelected: Bool
    let isSelectionMode: Bool
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    
    private var currentScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
    }

    private var cellSize: CGFloat {
        ((currentScreen?.bounds.width ?? 390) - 4) / 3  // spacing 2 × 2 = 4
    }
    
    var body: some View {
        ZStack {
            // 실제 사진 썸네일
            if let thumbnailImage = thumbnail {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cellSize, height: cellSize)
                    .clipped()
            } else if isLoading {
                // 로딩 중
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: cellSize, height: cellSize)
            } else {
                // 이미지 로드 실패
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
                .frame(width: cellSize, height: cellSize)
            }
            
            // 선택 오버레이
            if isSelectionMode {
                Color.blue.opacity(isSelected ? 0.3 : 0)
                    .frame(width: cellSize, height: cellSize)
                
                VStack {
                    HStack {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.blue : Color.white.opacity(0.3))
                                .frame(width: 24, height: 24)
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(8)
                    }
                    
                    Spacer()
                }
                .frame(width: cellSize, height: cellSize)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .contentShape(Rectangle())
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard thumbnail == nil else { return }

        let screenWidth = currentScreen?.bounds.width ?? 390
        let scale = currentScreen?.scale ?? 3
        let thumbnailSize = (screenWidth / 3) * scale
        let size = CGSize(width: thumbnailSize, height: thumbnailSize)
        let photoItem = photo

        // 메모리 캐시 즉시 확인 (Task 없이 동기, 캐시 히트 시 빠른 표시)
        if let cached = ThumbnailCache.shared.memoryCache.object(forKey: photoItem.id as NSString) {
            thumbnail = cached
            isLoading = false
            return
        }

        // 디스크 I/O는 백그라운드에서 (.utility: 메인스레드 경쟁 방지)
        Task(priority: .utility) {
            let image = await photoItem.getThumbnailAsync(size: size)
            thumbnail = image
            isLoading = false
        }
    }
}

// 선택 모드 액션 바
struct SelectionActionBar: View {
    let selectedCount: Int
    let onDelete: () -> Void
    let onDownload: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(selectedCount)장 선택됨")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDelete) {
                Label("삭제", systemImage: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button(action: onDownload) {
                Label("저장", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.96),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// 전체화면 개별 페이지 - 현재/인접 페이지만 실제 이미지 로드
private struct FullscreenPhotoPage: View {
    let photo: PhotoItem
    let isNearby: Bool
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if !isNearby {
                Color.black
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("이미지를 불러올 수 없습니다")
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear { if isNearby { loadImage() } }
        .onChange(of: isNearby) { _, nearby in if nearby { loadImage() } }
    }

    private func loadImage() {
        guard image == nil else { return }
        let path = photo.fileURL.path
        Task.detached(priority: .userInitiated) {
            let img = UIImage(contentsOfFile: path)
            await MainActor.run { image = img }
        }
    }
}

// 전체화면 사진 보기
struct PhotoFullscreenView: View {
    let photos: [PhotoItem]
    @Binding var currentIndex: Int
    @Binding var isPresented: Bool
    @State private var showDeleteAlert = false
    @State private var isDownloading = false
    @State private var showDownloadAlert = false
    @State private var downloadMessage = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 사진
            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    FullscreenPhotoPage(
                        photo: photo,
                        isNearby: abs(index - currentIndex) <= 1
                    )
                    .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif

            
            // 상단 UI
            VStack {
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("\(currentIndex + 1) / \(photos.count)")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // 하단 액션
                HStack(spacing: 40) {
                    ActionButton(icon: "trash", title: "삭제") {
                        showDeleteAlert = true
                    }
                    
                    ActionButton(icon: "arrow.down.circle", title: "저장") {
                        downloadCurrentPhoto()
                    }
                }
                .padding(.bottom, 40)
            }
            
            // 다운로드 중 오버레이
            if isDownloading {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("사진 저장 중...")
                            .foregroundColor(.white)
                            .font(.system(size: 17))
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
        }
        .alert("사진 삭제", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                deleteCurrentPhoto()
            }
        } message: {
            Text("이 사진을 삭제하시겠습니까?")
        }
        .alert("사진 저장 완료", isPresented: $showDownloadAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(downloadMessage)
        }
    }
    
    private func deleteCurrentPhoto() {
        guard currentIndex < photos.count else { return }
        let photoToDelete = photos[currentIndex]
        PhotoDataManager.shared.deletePhotos([photoToDelete])
        
        // 삭제 후 화면 닫기
        isPresented = false
    }
    
    private func downloadCurrentPhoto() {
        guard currentIndex < photos.count else { return }
        let photoToDownload = photos[currentIndex]
        
        Task {
            isDownloading = true
            
            let result = await PhotoDataManager.shared.downloadToPhotosLibrary([photoToDownload])
            
            isDownloading = false
            
            if result.success {
                downloadMessage = "사진이 저장되었습니다"
            } else {
                downloadMessage = "사진을 저장할 수 없습니다. 설정에서 사진 라이브러리 접근 권한을 확인해주세요."
            }
            
            showDownloadAlert = true
        }
    }
}

// 액션 버튼
struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 13))
            }
            .foregroundColor(.white)
        }
    }
}

#Preview {
    NavigationStack {
        GalleryView()
    }
}
