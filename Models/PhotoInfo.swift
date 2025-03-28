//
//  PhotoInfo.swift
//  priority-soft-ios
//
//  Created by Kostic on 28.3.25..
//

import UIKit
import CoreLocation

struct PhotoInfo: Codable {
    let imageFilename: String
    let latitude: Double?
    let longitude: Double?

    var image: UIImage? {
        let filePath = getFilePath(for: imageFilename)
        return UIImage(contentsOfFile: filePath.path)
    }

    var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    init(image: UIImage, location: CLLocation?) {
        self.imageFilename = UUID().uuidString + ".jpg"
        self.latitude = location?.coordinate.latitude
        self.longitude = location?.coordinate.longitude
        saveImageToDisk(image, filename: imageFilename)
    }

    private func saveImageToDisk(_ image: UIImage, filename: String) {
        let filePath = getFilePath(for: filename)
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            try? imageData.write(to: filePath)
        }
    }

    private func getFilePath(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(filename)
    }
}
