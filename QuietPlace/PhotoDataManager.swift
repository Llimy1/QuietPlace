//
//  PhotoDataManager.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/23/26.
//

import SwiftUI
import UIKit
import Photos
import Combine

@MainActor
class PhotoDataManager: ObservableObject {
    static let shared = PhotoDataManager()
    
    @Published var photos: [PhotoItem] = []
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    private let fileManager = FileManager.default
    private var photosDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("Photos", isDirectory: true)
    }
    
    private init() {
        createPhotosDirectoryIfNeeded()
        // ⚡️ 백그라운드에서 사진 로드 (UI 블록 방지)
        Task.detached(priority: .userInitiated) {
            await self.loadPhotosAsync()
        }
    }
    
    // MARK: - Directory Setup
    
    private func createPhotosDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: photosDirectory.path) {
            try? fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Save Photo
    
    /// ⚡️ 비동기 사진 저장 (UI 블록 없음)
    func savePhotoAsync(_ image: UIImage) async -> PhotoItem? {
        let photoId = UUID().uuidString
        let createdDate = Date()
        
        // 1️⃣ 먼저 PhotoItem 생성 (UI 즉시 업데이트)
        let fileExtension: String
        if #available(iOS 11.0, *) {
            fileExtension = "heic"
        } else {
            fileExtension = "jpg"
        }
        
        let fileName = "\(photoId).\(fileExtension)"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        
        let photoItem = PhotoItem(
            id: photoId,
            fileName: fileName,
            fileURL: fileURL,
            createdDate: createdDate
        )
        
        // 2️⃣ 즉시 photos 배열에 추가 (썸네일이 바로 나타남)
        photos.insert(photoItem, at: 0)
        
        // 3️⃣ 백그라운드에서 실제 저장 (UI 블록 없음)
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // 백그라운드에서 HEIC 변환
            let imageData: Data?
            if #available(iOS 11.0, *) {
                imageData = image.heicData()
            } else {
                imageData = image.jpegData(compressionQuality: 0.85)
            }
            
            guard let data = imageData else {
                debugPrint("❌ Failed to convert image to data")
                await MainActor.run {
                    self.errorMessage = "이미지 데이터 변환에 실패했습니다"
                    self.showError = true
                    // 실패 시 photos에서 제거
                    self.photos.removeAll { $0.id == photoId }
                }
                return
            }
            
            // 디스크에 저장
            do {
                try data.write(to: fileURL)
                debugPrint("✅ Photo saved: \(fileName)")
                
                // 4️⃣ 썸네일 미리 생성 (백그라운드에서)
                await ThumbnailCache.shared.getThumbnailAsync(for: photoItem)
                
            } catch {
                debugPrint("❌ Failed to save photo: \(error)")
                await MainActor.run {
                    self.errorMessage = "사진 저장에 실패했습니다: \(error.localizedDescription)"
                    self.showError = true
                    // 실패 시 photos에서 제거
                    self.photos.removeAll { $0.id == photoId }
                }
            }
        }
        
        return photoItem
    }
    
    /// 동기 저장 (호환성 유지, 사용 비권장)
    @available(*, deprecated, message: "Use savePhotoAsync instead")
    func savePhoto(_ image: UIImage) -> PhotoItem? {
        // 동기 버전은 더 이상 권장하지 않지만 호환성을 위해 유지
        let photoId = UUID().uuidString
        
        // 항상 HEIF 포맷으로 저장 (iOS 기본, 고품질, 작은 용량)
        let fileExtension: String
        let imageData: Data?
        
        if #available(iOS 11.0, *) {
            fileExtension = "heic"
            imageData = image.heicData()
        } else {
            // Fallback to JPEG for iOS 10 and below
            fileExtension = "jpg"
            imageData = image.jpegData(compressionQuality: 0.85)
        }
        
        let fileName = "\(photoId).\(fileExtension)"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        
        guard let data = imageData else {
            debugPrint("❌ Failed to convert image to data")
            errorMessage = "이미지 데이터 변환에 실패했습니다"
            showError = true
            return nil
        }
        
        do {
            try data.write(to: fileURL)
            
            let photoItem = PhotoItem(
                id: photoId,
                fileName: fileName,
                fileURL: fileURL,
                createdDate: Date()
            )
            
            photos.insert(photoItem, at: 0) // 최신 사진을 앞에
            debugPrint("✅ Photo saved: \(fileName)")
            
            return photoItem
            
        } catch {
            debugPrint("❌ Failed to save photo: \(error)")
            errorMessage = "사진 저장에 실패했습니다: \(error.localizedDescription)"
            showError = true
            return nil
        }
    }
    
    // MARK: - Load Photos
    
    /// ⚡️ 비동기 사진 로드 (UI 블록 없음)
    func loadPhotosAsync() async {
        debugPrint("⚡️ [PhotoDataManager] Starting async photo load...")
        
        let startTime = Date()
        
        // 백그라운드 스레드에서 파일 시스템 작업
        let loadedPhotos = await Task.detached(priority: .userInitiated) { [photosDirectory, fileManager] () -> [PhotoItem] in
            do {
                let fileURLs = try fileManager.contentsOfDirectory(
                    at: photosDirectory,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )
                
                let photos = fileURLs.compactMap { url -> PhotoItem? in
                    // jpg 또는 heic 파일만 로드
                    let ext = url.pathExtension.lowercased()
                    guard ext == "jpg" || ext == "jpeg" || ext == "heic" else { return nil }
                    
                    let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                    let createdDate = attributes?[.creationDate] as? Date ?? Date()
                    let photoId = url.deletingPathExtension().lastPathComponent
                    
                    return PhotoItem(
                        id: photoId,
                        fileName: url.lastPathComponent,
                        fileURL: url,
                        createdDate: createdDate
                    )
                }
                
                // 날짜순 정렬 (최신순)
                return photos.sorted { $0.createdDate > $1.createdDate }
                
            } catch {
                debugPrint("❌ Failed to load photos: \(error)")
                return []
            }
        }.value
        
        // MainActor에서 UI 업데이트
        await MainActor.run {
            self.photos = loadedPhotos
            let elapsed = Date().timeIntervalSince(startTime)
            debugPrint("✅ Loaded \(loadedPhotos.count) photos in \(String(format: "%.2f", elapsed))s")
        }
    }
    
    /// 동기 로드 (호환성 유지, 사용 비권장)
    @available(*, deprecated, message: "Use loadPhotosAsync instead")
    func loadPhotos() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: photosDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            photos = fileURLs.compactMap { url -> PhotoItem? in
                // jpg 또는 heic 파일만 로드
                let ext = url.pathExtension.lowercased()
                guard ext == "jpg" || ext == "jpeg" || ext == "heic" else { return nil }
                
                let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                let createdDate = attributes?[.creationDate] as? Date ?? Date()
                let photoId = url.deletingPathExtension().lastPathComponent
                
                return PhotoItem(
                    id: photoId,
                    fileName: url.lastPathComponent,
                    fileURL: url,
                    createdDate: createdDate
                )
            }
            
            // 날짜순 정렬 (최신순)
            photos.sort { $0.createdDate > $1.createdDate }
            
            debugPrint("✅ Loaded \(photos.count) photos")
            
        } catch {
            debugPrint("❌ Failed to load photos: \(error)")
        }
    }
    
    // MARK: - Delete Photos
    
    func deletePhotos(_ photoItems: [PhotoItem]) {
        for item in photoItems {
            do {
                try fileManager.removeItem(at: item.fileURL)
                photos.removeAll { $0.id == item.id }
                
                // 캐시에서도 제거
                ThumbnailCache.shared.removeThumbnail(for: item.id)
                
                debugPrint("✅ Deleted photo: \(item.fileName)")
            } catch {
                debugPrint("❌ Failed to delete photo: \(error)")
            }
        }
    }
    
    // MARK: - Download to Photos Library
    
    func downloadToPhotosLibrary(_ photoItems: [PhotoItem]) async -> (success: Bool, savedCount: Int, totalCount: Int) {
        // Photos 권한 확인
        let status = await requestPhotosPermission()
        guard status == .authorized || status == .limited else {
            debugPrint("❌ Photos permission denied")
            errorMessage = "사진 라이브러리 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요."
            showError = true
            return (false, 0, photoItems.count)
        }
        
        var successCount = 0
        var lastError: Error?
        
        for item in photoItems {
            // 파일에서 이미지 로드
            guard let image = UIImage(contentsOfFile: item.fileURL.path) else {
                debugPrint("❌ Failed to load image from: \(item.fileURL.path)")
                continue
            }
            
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                successCount += 1
                debugPrint("✅ Downloaded to Photos: \(item.fileName)")
            } catch {
                debugPrint("❌ Failed to download \(item.fileName): \(error)")
                lastError = error
            }
        }
        
        // 결과 처리
        if successCount > 0 {
            debugPrint("✅ Downloaded \(successCount)/\(photoItems.count) photos to library")
            return (true, successCount, photoItems.count)
        } else {
            // 모든 사진 다운로드 실패
            if let error = lastError {
                errorMessage = "사진을 저장할 수 없습니다: \(error.localizedDescription)"
            } else {
                errorMessage = "사진을 불러올 수 없습니다. 파일이 손상되었을 수 있습니다."
            }
            showError = true
            return (false, 0, photoItems.count)
        }
    }
    
    private func requestPhotosPermission() async -> PHAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        if status == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        
        return status
    }
    
    // MARK: - Get Photo by Date
    
    func photosByDate() -> [String: [PhotoItem]] {
        let calendar = Calendar.current
        var grouped: [String: [PhotoItem]] = [:]
        
        for photo in photos {
            let dateString = dateString(from: photo.createdDate)
            grouped[dateString, default: []].append(photo)
        }
        
        return grouped
    }
    
    func dateString(from date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - PhotoItem Model

struct PhotoItem: Identifiable, Equatable {
    let id: String
    let fileName: String
    let fileURL: URL
    let createdDate: Date
    
    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
    
    /// 썸네일 가져오기 (캐시 사용 - 동기)
    func getThumbnail(size: CGSize = CGSize(width: 400, height: 400)) -> UIImage? {
        return ThumbnailCache.shared.getThumbnail(for: self, size: size)
    }
    
    /// 썸네일 가져오기 (캐시 사용 - 비동기)
    func getThumbnailAsync(size: CGSize = CGSize(width: 400, height: 400)) async -> UIImage? {
        return await ThumbnailCache.shared.getThumbnailAsync(for: self, size: size)
    }
}
// MARK: - UIImage Extension (HEIF Support)

import ImageIO
import UniformTypeIdentifiers

extension UIImage {
    /// HEIC 포맷으로 변환 (고품질, 작은 용량)
    /// - Parameter compressionQuality: 압축 품질 (0.0 ~ 1.0, 기본값 0.9 = 높은 품질)
    func heicData(compressionQuality: CGFloat = 0.9) -> Data? {
        guard #available(iOS 11.0, *) else { return nil }
        
        // CGImage로 변환 (알파 채널 제거)
        guard let cgImage = self.cgImage else {
            debugPrint("❌ Failed to get CGImage from UIImage")
            return self.jpegData(compressionQuality: compressionQuality)
        }
        
        // ⚡️ 알파 채널이 없는 새 CGImage 생성 (경고 제거)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            debugPrint("❌ Failed to create CGContext")
            return self.jpegData(compressionQuality: compressionQuality)
        }
        
        // CGImage를 알파 없이 그리기
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        guard let imageWithoutAlpha = context.makeImage() else {
            debugPrint("❌ Failed to create image without alpha")
            return self.jpegData(compressionQuality: compressionQuality)
        }
        
        // 메모리에 데이터 생성
        let data = NSMutableData()
        
        // ImageDestination 생성 (HEIC 포맷)
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            debugPrint("❌ Failed to create HEIC destination")
            return self.jpegData(compressionQuality: compressionQuality)
        }
        
        // HEIC 옵션 설정
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        
        // 알파 없는 이미지 추가 및 저장
        CGImageDestinationAddImage(destination, imageWithoutAlpha, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            debugPrint("❌ Failed to finalize HEIC image")
            return self.jpegData(compressionQuality: compressionQuality)
        }
        
        return data as Data
    }
}


