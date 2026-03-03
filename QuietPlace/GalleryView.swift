//
//  GalleryView.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/23/26.
//

import SwiftUI
import Combine

struct GalleryView: View {
    @Binding var currentTab: ContentView.Tab
    @Binding var previousTab: ContentView.Tab
    @StateObject private var photoDataManager = PhotoDataManager.shared
    @State private var isSelectionMode = false
    @State private var selectedPhotos: Set<String> = []  // PhotoItem ID로 변경
    @State private var showFullscreen = false
    @State private var selectedPhotoIndex = 0
    @State private var showMenu = false
    @State private var isDownloading = false
    @State private var showDownloadAlert = false
    @State private var downloadMessage = ""
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 메인 컨텐츠
                if photoDataManager.photos.isEmpty {
                    // 사진이 없을 때
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("사진이 없습니다")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("카메라로 사진을 촬영하세요")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                } else {
                    // 사진이 있을 때
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // 날짜별로 그룹핑된 사진들
                            ForEach(groupedPhotos.keys.sorted(by: { key1, key2 in
                                // Today > Yesterday > 다른 날짜 순서
                                if key1 == "Today" { return true }
                                if key2 == "Today" { return false }
                                if key1 == "Yesterday" { return true }
                                if key2 == "Yesterday" { return false }
                                return key1 > key2
                            }), id: \.self) { dateKey in
                                if let photos = groupedPhotos[dateKey] {
                                    PhotoSection(
                                        title: "\(dateKey) - \(formattedDate(for: photos.first?.createdDate))",
                                        photos: photos,
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
                        .padding(.bottom, 80) // 바텀 바 공간 확보
                    }
                }
                
                // 고정 바텀 네비게이션 바 (항상 표시)
                GalleryBottomNavigationBar(currentTab: $currentTab, previousTab: $previousTab)
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
                    .padding(.bottom, 70) // 바텀 바 위에 표시
                }
            }
        }
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
                            currentTab = previousTab
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
                // Refresh photos when gallery appears
                photoDataManager.loadPhotos()
                
                // Prefetching 제거 - 오히려 느림
            }
            .onDisappear {
                // Clear memory cache when leaving gallery to free up memory
                // Disk cache remains for fast loading next time
                Task {
                    ThumbnailCache.shared.memoryCache.removeAllObjects()
                    print("🧹 Gallery memory cache cleared")
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
    
    private var groupedPhotos: [String: [PhotoItem]] {
        photoDataManager.photosByDate()
    }
    
    private func formattedDate(for date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Prefetching
    
    private func prefetchThumbnails() async {
        let screenWidth = UIScreen.main.bounds.width
        let thumbnailSize = (screenWidth / 3) * UIScreen.main.scale
        let size = CGSize(width: thumbnailSize, height: thumbnailSize)
        
        // 처음 20개 사진만 사전 로딩 (백그라운드에서)
        let photosToPreload = Array(photoDataManager.photos.prefix(20))
        
        print("🔄 Prefetching \(photosToPreload.count) thumbnails...")
        
        await withTaskGroup(of: Void.self) { group in
            for photo in photosToPreload {
                group.addTask {
                    _ = await photo.getThumbnailAsync(size: size)
                }
            }
        }
        
        print("✅ Prefetching complete!")
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

// 고정 바텀 네비게이션 바
struct GalleryBottomNavigationBar: View {
    @Binding var currentTab: ContentView.Tab
    @Binding var previousTab: ContentView.Tab
    
    var body: some View {
        HStack(spacing: 0) {
            BottomNavButton(
                icon: "moon.fill",
                title: "조용한 모드"
            ) {
                previousTab = currentTab
                currentTab = .fakeMode
            }
            
            BottomNavButton(
                icon: "photo.fill",
                title: "갤러리",
                isActive: true
            ) {
                // 이미 갤러리에 있음
            }
            
            BottomNavButton(
                icon: "gearshape.fill",
                title: "설정"
            ) {
                previousTab = currentTab
                currentTab = .settings
            }
        }
        .frame(height: 70)
        .background(
            Color(red: 0.11, green: 0.11, blue: 0.12)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// 바텀 네비게이션 버튼
struct BottomNavButton: View {
    let icon: String
    let title: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 11))
            }
            .foregroundColor(isActive ? .blue : .gray)
            .frame(maxWidth: .infinity)
        }
    }
}

// 갤러리 메뉴 바텀 시트 (삭제 가능 - 더 이상 필요 없음)
struct GalleryMenuBottomSheet: View {
    @Binding var showMenu: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 핸들
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray)
                .frame(width: 40, height: 5)
                .padding(.top, 12)
            
            VStack(spacing: 12) {
                GalleryMenuButton(
                    title: "카메라 모드",
                    icon: "camera.fill"
                ) {
                    showMenu = false
                    // TODO: 카메라로 이동
                }
                
                GalleryMenuButton(
                    title: "조용한 모드",
                    icon: "moon.fill"
                ) {
                    showMenu = false
                    // TODO: Fake Mode로 이동
                }
                
                GalleryMenuButton(
                    title: "설정",
                    icon: "gearshape.fill"
                ) {
                    showMenu = false
                    // TODO: 설정으로 이동
                }
            }
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .cornerRadius(20)
        .padding(.horizontal, 0)
    }
}

// 갤러리 메뉴 버튼
struct GalleryMenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(red: 0.17, green: 0.17, blue: 0.18))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
}

// 사진 섹션
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
            
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photos) { photo in
                    PhotoThumbnail(
                        photo: photo,
                        isSelected: selectedPhotos.contains(photo.id),
                        isSelectionMode: isSelectionMode
                    )
                    .onTapGesture {
                        if isSelectionMode {
                            if selectedPhotos.contains(photo.id) {
                                selectedPhotos.remove(photo.id)
                            } else {
                                selectedPhotos.insert(photo.id)
                            }
                        } else {
                            onPhotoTap(photo)
                        }
                    }
                }
            }
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 실제 사진 썸네일
                if let thumbnailImage = thumbnail {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width)
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
                } else {
                    // 이미지 로드 실패
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
                
                // 선택 오버레이
                if isSelectionMode {
                    Color.blue.opacity(isSelected ? 0.3 : 0)
                    
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
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .onAppear {
                loadThumbnail()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func loadThumbnail() {
        // 썸네일 크기 설정
        let screenWidth = UIScreen.main.bounds.width
        let thumbnailSize = screenWidth / 3
        let size = CGSize(width: thumbnailSize, height: thumbnailSize)
        
        // 동기로 로드 (경량화 전 방식)
        thumbnail = photo.getThumbnail(size: size)
        isLoading = false
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

// 전체화면 사진 보기
struct PhotoFullscreenView: View {
    let photos: [PhotoItem]
    @Binding var currentIndex: Int
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
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
                    ZStack {
                        if let image = UIImage(contentsOfFile: photo.fileURL.path) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            // 이미지 로드 실패
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                
                                Text("이미지를 불러올 수 없습니다")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                            } else {
                                scale = 2.0
                                lastScale = 2.0
                            }
                        }
                    }
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
    GalleryView(currentTab: .constant(.gallery), previousTab: .constant(.fakeMode))
}
