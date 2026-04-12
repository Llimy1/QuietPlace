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
                    .padding(.bottom, 70) // 배너 광고 위에 표시
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

private enum DragSelectionMode {
    case select
    case deselect
}

private struct PhotoFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
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

    @State private var photoFrames: [String: CGRect] = [:]
    @State private var dragSelectionMode: DragSelectionMode?
    @State private var handledPhotoIDs: Set<String> = []
    @State private var lastDragLocation: CGPoint?
    @State private var coordinateSpaceName = UUID().uuidString

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(photos) { photo in
                PhotoThumbnail(
                    photo: photo,
                    isSelected: selectedPhotos.contains(photo.id),
                    isSelectionMode: isSelectionMode
                )
                .background {
                    // 선택 모드일 때만 GeometryReader 추적 (일반 스크롤 시 불필요한 preference 업데이트 방지)
                    if isSelectionMode {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: PhotoFramePreferenceKey.self,
                                value: [photo.id: proxy.frame(in: .named(coordinateSpaceName))]
                            )
                        }
                    }
                }
                .onTapGesture {
                    handlePhotoTap(photo)
                }
            }
        }
        .coordinateSpace(name: coordinateSpaceName)
        .onPreferenceChange(PhotoFramePreferenceKey.self) { frames in
            guard isSelectionMode else { return }
            let visiblePhotoIDs = Set(photos.map(\.id))
            photoFrames = frames.filter { visiblePhotoIDs.contains($0.key) }
        }
        .simultaneousGesture(dragSelectionGesture)
        .onChange(of: isSelectionMode) { _, isEnabled in
            if !isEnabled {
                photoFrames = [:]
                resetDragSelection()
            }
        }
    }

    private var dragSelectionGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named(coordinateSpaceName))
            .onChanged { value in
                guard isSelectionMode else { return }
                guard let mode = beginDragSelectionIfNeeded(at: value.startLocation) else { return }

                let startPoint = lastDragLocation ?? value.startLocation
                updateDragSelection(from: startPoint, to: value.location, mode: mode)
                lastDragLocation = value.location
            }
            .onEnded { _ in
                resetDragSelection()
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

    private func beginDragSelectionIfNeeded(at startLocation: CGPoint) -> DragSelectionMode? {
        if let dragSelectionMode {
            return dragSelectionMode
        }

        guard let photoID = photoID(at: startLocation) else { return nil }
        let mode: DragSelectionMode = selectedPhotos.contains(photoID) ? .deselect : .select
        dragSelectionMode = mode
        applyDragSelection(to: [photoID], mode: mode)
        return mode
    }

    private func updateDragSelection(from start: CGPoint, to end: CGPoint, mode: DragSelectionMode) {
        let sweepRect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: max(abs(end.x - start.x), 1),
            height: max(abs(end.y - start.y), 1)
        )
        .insetBy(dx: -8, dy: -8)

        let touchedPhotoIDs = photoFrames.compactMap { photoID, frame in
            frame.intersects(sweepRect) ? photoID : nil
        }

        applyDragSelection(to: touchedPhotoIDs, mode: mode)
    }

    private func applyDragSelection(to photoIDs: [String], mode: DragSelectionMode) {
        for photoID in photoIDs {
            guard handledPhotoIDs.insert(photoID).inserted else { continue }

            switch mode {
            case .select:
                selectedPhotos.insert(photoID)
            case .deselect:
                selectedPhotos.remove(photoID)
            }
        }
    }

    private func photoID(at location: CGPoint) -> String? {
        photoFrames.first(where: { _, frame in
            frame.contains(location)
        })?.key
    }

    private func resetDragSelection() {
        dragSelectionMode = nil
        handledPhotoIDs.removeAll()
        lastDragLocation = nil
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
    
    private var cellSize: CGFloat {
        (UIScreen.main.bounds.width - 4) / 3  // spacing 2 × 2 = 4
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

        let screenWidth = UIScreen.main.bounds.width
        let scale = UIScreen.main.scale
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
        Task.detached(priority: .utility) {
            let image = photoItem.getThumbnail(size: size)
            await MainActor.run {
                thumbnail = image
                isLoading = false
            }
        }
    }
}

// 선택 모드 액션 바
struct SelectionActionBar: View {
    let selectedCount: Int
    let onDelete: () -> Void
    let onDownload: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Text("\(selectedCount)장 선택됨")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .padding(.top, 12)
            
            HStack(spacing: 0) {
                Button(action: onDelete) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 24))
                        Text("삭제")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                }
                
                Divider()
                    .frame(height: 50)
                
                Button(action: onDownload) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 24))
                        Text("저장")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 16)
        }
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 0)
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
