//
//  ImageUploader.swift
//  priority-soft-ios
//
//  Created by Kostic on 27.3.25..
//

import UIKit
import Network
import CoreLocation

class ImageUploader {
    static let shared = ImageUploader()
    private let monitor = NWPathMonitor()
    private var queue: [PhotoInfo] = []
    private var uploadingSet = Set<String>()
    private let maxRetryCount = 5
    var onUploadProgress: ((Int) -> Void)?

    private var uploadedImages = 0 {
        didSet {
            DispatchQueue.main.async {
                self.onUploadProgress?(self.uploadedImages)
            }
            saveUploadedImages(uploadedImages)
        }
    }

    private init() {
        loadQueueFromDisk()
        uploadedImages = getUploadedImages()

        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                print("📶 Internet available")
                self.uploadQueuedImages()
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }

    func handleImageCapture(_ image: UIImage, location: CLLocation?) async {
        let photo = PhotoInfo(image: image, location: location)
        saveImageToQueue(photo)
        saveTotalImages(getTotalImages() + 1)

        if hasInternetConnection() {
            await uploadImage(photo)
        }
    }

    private func hasInternetConnection() -> Bool {
        return monitor.currentPath.status == .satisfied
    }

    private func uploadImage(_ photo: PhotoInfo, retryCount: Int = 0) async {
        if uploadingSet.contains(photo.imageFilename) { return }
        uploadingSet.insert(photo.imageFilename)

        guard let imageData = try? Data(contentsOf: getFilePath(for: photo.imageFilename)) else {
            print("⚠️ Image file not found: \(photo.imageFilename)")
            uploadingSet.remove(photo.imageFilename)
            return
        }

        guard let url = URL(string: "https://prioritysoftfile-upload-testap-production.up.railway.app/upload?candidateName=Luka") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let filename = photo.imageFilename

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            print("✅ Image uploaded successfully: \(photo.imageFilename)")
            self.uploadedImages += 1
            removeImageFromQueue(photo)
            deleteImageFromDisk(photo.imageFilename)
            uploadingSet.remove(photo.imageFilename)

        } catch {
            print("❌ Upload failed, retrying...")
            uploadingSet.remove(photo.imageFilename)
            if retryCount < self.maxRetryCount {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await uploadImage(photo, retryCount: retryCount + 1)
            } else {
                print("❌ Upload permanently failed, keeping in queue.")
            }
        }
    }

    private func saveImageToQueue(_ photo: PhotoInfo) {
        if !queue.contains(where: { $0.imageFilename == photo.imageFilename }) {
            queue.append(photo)
            saveQueueToDisk()
        }
    }

    private func removeImageFromQueue(_ photo: PhotoInfo) {
        if let index = queue.firstIndex(where: { $0.imageFilename == photo.imageFilename }) {
            queue.remove(at: index)
            saveQueueToDisk()
        }
    }

    private var isUploadingQueuedImages = false

    func uploadQueuedImages() {
        if isUploadingQueuedImages { return }
        isUploadingQueuedImages = true

        if queue.isEmpty {
            loadQueueFromDisk()
        }
        Task {
            while !queue.isEmpty {
                let photo = queue.first!
                await uploadImage(photo)
            }
            saveQueueToDisk()
            isUploadingQueuedImages = false
        }
    }

    private func saveQueueToDisk() {
        if let encoded = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(encoded, forKey: "uploadQueue")
        }
    }

    private func loadQueueFromDisk() {
        if let savedData = UserDefaults.standard.data(forKey: "uploadQueue"),
           let decoded = try? JSONDecoder().decode([PhotoInfo].self, from: savedData) {
            queue = decoded.filter { fileExists($0.imageFilename) }
        }
    }

    private func deleteImageFromDisk(_ filename: String) {
        let filePath = getFilePath(for: filename)
        try? FileManager.default.removeItem(at: filePath)
    }

    private func fileExists(_ filename: String) -> Bool {
        let filePath = getFilePath(for: filename)
        return FileManager.default.fileExists(atPath: filePath.path)
    }

    private func getFilePath(for filename: String) -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(filename)
    }

    func getTotalImages() -> Int {
        UserDefaults.standard.integer(forKey: "totalImages")
    }

    private func saveTotalImages(_ count: Int) {
        UserDefaults.standard.set(count, forKey: "totalImages")
    }

    func getUploadedImages() -> Int {
        UserDefaults.standard.integer(forKey: "uploadedImages")
    }

    private func saveUploadedImages(_ count: Int) {
        UserDefaults.standard.set(count, forKey: "uploadedImages")
    }
}

//class Job: Codable {
//    let id: UUID
//
//    init(id: UUID = UUID()) {
//        self.id = id
//    }
//
//    func execute(completion: @escaping (Bool) -> Void) {
//        fatalError("Subclasses must implement `execute`")
//    }
//}
//

//class UploadImageJob: Job {
//    let photo: PhotoInfo
//
//    init(photo: PhotoInfo) {
//        self.photo = photo
//        super.init()
//    }
//
//    required init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        self.photo = try container.decode(PhotoInfo.self, forKey: .photo)
//        super.init()
//    }
//
//    override func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(photo, forKey: .photo)
//    }
//
//    override func execute(completion: @escaping (Bool) -> Void) {
//        guard let imageData = try? Data(contentsOf: getFilePath(for: photo.imageFilename)) else {
//            print("Image file not found: \(photo.imageFilename), skipping upload")
//            completion(false)
//            return
//        }
//
//        guard let url = URL(string: "https://prioritysoftfile-upload-testap-production.up.railway.app/upload?candidateName=Luka") else {
//            completion(false)
//            return
//        }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//
//        let boundary = UUID().uuidString
//        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
//
//        var body = Data()
//        let filename = photo.imageFilename
//
//        body.append("--\(boundary)\r\n".data(using: .utf8)!)
//        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
//        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
//        body.append(imageData)
//        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
//
//        request.httpBody = body
//
//        Task {
//            do {
//                let (_, response) = try await URLSession.shared.data(for: request)
//
//                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
//                    throw URLError(.badServerResponse)
//                }
//
//                print("Image uploaded: \(photo.imageFilename)")
//                deleteImageFromDisk(photo.imageFilename)
//                DispatchQueue.main.async {
//                    completion(true)
//                }
//
//            } catch {
//                print("Upload failed")
//                DispatchQueue.main.async {
//                    completion(false)
//                }
//            }
//        }
//    }
//
//    private func deleteImageFromDisk(_ filename: String) {
//        let filePath = getFilePath(for: filename)
//        try? FileManager.default.removeItem(at: filePath)
//    }
//
//    private func getFilePath(for filename: String) -> URL {
//        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(filename)
//    }
//
//    private enum CodingKeys: String, CodingKey {
//        case photo
//    }
//}
//
//class JobQueue {
//    static let shared = JobQueue()
//
//    private let storageKey = "jobQueueStorage"
//    private var jobs: [Job] = []
//    private let queueLock = DispatchQueue(label: "com.queue.lock", qos: .background)//DispatchQueue(label: "com.queue.lock")
//    private var isProcessing = false
//    private let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
//
//    private init() {
//        loadJobs()
//        startProcessingLoop()
//    }
//
//    func addJob(_ job: Job) {
//        queueLock.sync {
//            jobs.append(job)
//            saveJobs()
//        }
//    }
//
//    private func startProcessingLoop() {
////        timer.schedule(deadline: .now(), repeating: 1.0)
////        timer.setEventHandler { [weak self] in
////            self?.processJobs()
////        }
////        timer.resume()
//        DispatchQueue.global(qos: .background).async {
//            self.processJobs()
//        }
//    }
//
//    private func processJobs() {
////        queueLock.sync {
//            if jobs.isEmpty {
//                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
//                    self.processJobs()
//                }
//                return
//            }
////        }
//
//        guard let job = getCurrentJob() else {
//
//            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
//                self.processJobs()
//            }
//            return
//        }
//
//        job.execute { success in
//            self.handleJobCompletion(success: success)
//
//            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
//                self.processJobs()
//            }
//        }
//    }
//
//    private func getCurrentJob() -> Job? {
//        queueLock.sync {
//            return jobs.first
//        }
//    }
//
//    private func handleJobCompletion(success: Bool) {
//        queueLock.sync {
//            if success {
//                if !jobs.isEmpty {
//                    jobs.removeFirst()
//                }
//            } else {
//                print("Job failed")
//            }
//            saveJobs()
//            isProcessing = false
//        }
//    }
//
//    private func saveJobs() {
//        let encoder = JSONEncoder()
//        if let data = try? encoder.encode(jobs) {
//            UserDefaults.standard.set(data, forKey: storageKey)
//        }
//    }
//
//    private func loadJobs() {
//        let decoder = JSONDecoder()
//        if let data = UserDefaults.standard.data(forKey: storageKey),
//           let savedJobs = try? decoder.decode([UploadImageJob].self, from: data) {
//            jobs = savedJobs
//        }
//    }
//}
//
//

//class ImageUploader {
//    static let shared = ImageUploader()
//    private let monitor = NWPathMonitor()
//    private let queue = JobQueue.shared
//    var onUploadProgress: ((Int) -> Void)?
//
//    private var uploadedImages = 0 {
//        didSet {
//            DispatchQueue.main.async {
//                self.onUploadProgress?(self.uploadedImages)
//            }
//            saveUploadedImages(uploadedImages)
//        }
//    }
//
//    private init() {
//        uploadedImages = getUploadedImages()
//
//        monitor.pathUpdateHandler = { path in
//            if path.status == .satisfied {
//                print("Internet available, starting upload...")
////                self.queue.processNextJob()
//            }
//        }
//        let queue = DispatchQueue(label: "NetworkMonitor")
//        monitor.start(queue: queue)
//    }
//
//    func handleImageCapture(_ image: UIImage, location: CLLocation?) async {
//        let photo = PhotoInfo(image: image, location: location)
//        let job = UploadImageJob(photo: photo)
//        queue.addJob(job)
//    }
//
//    func getTotalImages() -> Int {
//        return UserDefaults.standard.integer(forKey: "totalImages")
//    }
//
//    private func saveTotalImages(_ count: Int) {
//        UserDefaults.standard.set(count, forKey: "totalImages")
//    }
//
//    func getUploadedImages() -> Int {
//        return UserDefaults.standard.integer(forKey: "uploadedImages")
//    }
//
//    private func saveUploadedImages(_ count: Int) {
//        UserDefaults.standard.set(count, forKey: "uploadedImages")
//    }
//}
