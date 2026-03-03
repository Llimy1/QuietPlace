//
//  ThumbnailCache.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/24/26.
//

import UIKit
import ImageIO

@MainActor
class ThumbnailCache {
    static let shared = ThumbnailCache()
    
    // Make memoryCache internal so it can be accessed for cleanup
    let memoryCache = NSCache<NSString, UIImage>()
    nonisolated private let diskCacheDirectory: URL
    
    private init() {
        // 메모리 캐시 설정 (50MB - reduced for better memory management)
        memoryCache.totalCostLimit = 50 * 1024 * 1024
        // 최대 100개 썸네일
        memoryCache.countLimit = 100
        
        // 디스크 캐시 디렉토리 설정
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheDirectory = cacheDir.appendingPathComponent("Thumbnails", isDirectory: true)
        
        // 디스크 캐시 디렉토리 생성
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
        
        // 메모리 경고 시 메모리 캐시 비우기
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.memoryCache.removeAllObjects()
            print("⚠️ Memory warning - ThumbnailCache cleared")
        }
        
        print("✅ ThumbnailCache initialized (Memory: \(memoryCache.totalCostLimit / 1024 / 1024)MB, Disk: \(diskCacheDirectory.path))")
    }
    
    /// 썸네일 가져오기 (동기 - 디스크 I/O 포함, UI 즉시 반응)
    nonisolated func getThumbnail(for photoItem: PhotoItem, size: CGSize = CGSize(width: 400, height: 400)) -> UIImage? {
        let key = photoItem.id as NSString
        
        // 1️⃣ 메모리 캐시 확인
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }
        
        // 2️⃣ 디스크 캐시 확인 (동기 - 빠름)
        if let diskCached = loadThumbnailFromDisk(id: photoItem.id) {
            let cost = estimateCost(for: diskCached)
            memoryCache.setObject(diskCached, forKey: key, cost: cost)
            return diskCached
        }
        
        // 3️⃣ 원본에서 생성 (동기)
        if let thumbnail = generateThumbnail(from: photoItem.fileURL, size: size) {
            let cost = estimateCost(for: thumbnail)
            memoryCache.setObject(thumbnail, forKey: key, cost: cost)
            saveThumbnailToDisk(thumbnail, id: photoItem.id)
            return thumbnail
        }
        
        return nil
    }
    
    /// 비동기 썸네일 로드 (백그라운드에서 생성) - 옵션
    nonisolated func getThumbnailAsync(for photoItem: PhotoItem, size: CGSize = CGSize(width: 400, height: 400)) async -> UIImage? {
        // 동기 함수 호출 (백그라운드 스레드에서)
        return await Task.detached(priority: .userInitiated) {
            return self.getThumbnail(for: photoItem, size: size)
        }.value
    }
    
    // MARK: - Private Methods
    
    /// ⚡️ 플레이스홀더 생성 (즉시 반환)
    private func createPlaceholder(size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // 회색 배경
            UIColor.systemGray5.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 카메라 아이콘
            let iconSize: CGFloat = min(size.width, size.height) * 0.3
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            
            if let cameraIcon = UIImage(systemName: "photo")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: iconSize * 0.6, weight: .light)
            ) {
                UIColor.systemGray3.setFill()
                cameraIcon.draw(in: iconRect)
            }
        }
    }
    
    /// 고성능 썸네일 생성 (ImageIO 사용, 알파 채널 없음) - nonisolated
    nonisolated private func generateThumbnail(from url: URL, size: CGSize) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        // 더 빠른 썸네일 생성을 위한 최적화된 옵션
        let maxPixelSize = max(size.width, size.height)
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCache: false, // 캐싱하지 않음 (메모리 절약)
            kCGImageSourceShouldAllowFloat: false // 정수 픽셀만 (빠름)
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        // 알파 채널이 있는지 확인하고 제거
        let alphaInfo = cgImage.alphaInfo
        
        // 알파 채널이 있으면 RGB로 변환 (알파 제거)
        if alphaInfo != .none && alphaInfo != .noneSkipFirst && alphaInfo != .noneSkipLast {
            let width = cgImage.width
            let height = cgImage.height
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            // bytesPerRow를 4의 배수로 정렬
            let bytesPerRow = ((width * 4) + 3) & ~3
            
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                // Context 생성 실패 시 원본 반환
                return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            }
            
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            guard let newCGImage = context.makeImage() else {
                return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            }
            
            return UIImage(cgImage: newCGImage, scale: 1.0, orientation: .up)
        }
        
        // 알파 채널이 없으면 그대로 반환
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }
    
    /// 비동기 썸네일 생성
    nonisolated private func generateThumbnailAsync(from url: URL, size: CGSize) async -> UIImage? {
        return await Task.detached(priority: .userInitiated) {
            return self.generateThumbnail(from: url, size: size)
        }.value
    }
    
    /// 디스크에서 썸네일 로드 - nonisolated
    nonisolated private func loadThumbnailFromDisk(id: String) -> UIImage? {
        let thumbnailURL = diskCacheDirectory.appendingPathComponent("\(id).jpg")
        
        guard FileManager.default.fileExists(atPath: thumbnailURL.path),
              let data = try? Data(contentsOf: thumbnailURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    /// 비동기 디스크 로드
    nonisolated private func loadThumbnailFromDiskAsync(id: String) async -> UIImage? {
        return await Task.detached(priority: .utility) {
            return self.loadThumbnailFromDisk(id: id)
        }.value
    }
    
    /// 디스크에 썸네일 저장 - nonisolated (간단하고 빠르게)
    nonisolated private func saveThumbnailToDisk(_ image: UIImage, id: String) {
        let thumbnailURL = diskCacheDirectory.appendingPathComponent("\(id).jpg")
        
        // JPEG는 알파 채널을 자동으로 제거하고 저장 (가장 간단한 방법)
        // 이미 generateThumbnail에서 알파를 제거했으므로 경고 없음
        if let data = image.jpegData(compressionQuality: 0.7) {
            try? data.write(to: thumbnailURL, options: [.atomic])
        }
    }
    
    /// 비동기 디스크 저장 (낮은 우선순위)
    nonisolated private func saveThumbnailToDiskAsync(_ image: UIImage, id: String) async {
        await Task.detached(priority: .background) { // utility → background로 변경
            self.saveThumbnailToDisk(image, id: id)
        }.value
    }
    
    /// 이미지 메모리 비용 추정
    nonisolated private func estimateCost(for image: UIImage) -> Int {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        return width * height * 4 // RGBA
    }
    
    // MARK: - Public Methods
    
    /// 특정 썸네일 제거 (메모리 & 디스크)
    func removeThumbnail(for id: String) {
        // 메모리에서 제거
        memoryCache.removeObject(forKey: id as NSString)
        
        // 디스크에서 제거 (백그라운드)
        let cacheDir = diskCacheDirectory
        Task.detached(priority: .utility) {
            let thumbnailURL = cacheDir.appendingPathComponent("\(id).jpg")
            try? FileManager.default.removeItem(at: thumbnailURL)
        }
    }
    
    /// 전체 캐시 비우기 (메모리 & 디스크)
    func clearCache() {
        // 메모리 캐시 비우기
        memoryCache.removeAllObjects()
        
        // 디스크 캐시 비우기 (백그라운드)
        let cacheDir = diskCacheDirectory
        Task.detached(priority: .utility) {
            if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            print("✅ ThumbnailCache cleared (memory + disk)")
        }
    }
    
    /// 오래된 캐시 정리 (7일 이상)
    func cleanupOldCache(olderThan days: Int = 7) {
        let calendar = Calendar.current
        guard let expirationDate = calendar.date(byAdding: .day, value: -days, to: Date()) else { return }
        
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: self.diskCacheDirectory,
                includingPropertiesForKeys: [.creationDateKey]
            ) else { return }
            
            var removedCount = 0
            
            for file in files {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < expirationDate {
                    try? FileManager.default.removeItem(at: file)
                    removedCount += 1
                }
            }
            
            if removedCount > 0 {
                print("✅ Cleaned up \(removedCount) old thumbnails")
            }
        }
    }
    
    /// 캐시 상태 정보
    func cacheInfo() -> (memoryCount: Int, memoryLimit: String, diskCount: Int, diskSize: String) {
        let memoryLimit = "\(memoryCache.totalCostLimit / 1024 / 1024)MB"
        
        // 디스크 정보 조회 (동기적으로, 하지만 빠른 작업)
        let cacheDir = diskCacheDirectory
        let diskFiles = (try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? []
        let diskCount = diskFiles.count
        
        var diskSize: UInt64 = 0
        for file in diskFiles {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
               let fileSize = attributes[.size] as? UInt64 {
                diskSize += fileSize
            }
        }
        
        let diskSizeString = "\(diskSize / 1024 / 1024)MB"
        
        return (memoryCount: memoryCache.countLimit, memoryLimit: memoryLimit, diskCount: diskCount, diskSize: diskSizeString)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
