//
//  UIImage+Extensions.swift
//  priority-soft-ios
//
//  Created by Kostic on 28.3.25..
//

import UIKit

extension UIImage {
    func resizedToUnder5MB() -> UIImage {
        var compression: CGFloat = 1.0
        var imageData = self.jpegData(compressionQuality: compression)

        while let data = imageData, data.count > 5 * 1024 * 1024, compression > 0.1 {
            compression -= 0.1
            imageData = self.jpegData(compressionQuality: compression)
        }

        return UIImage(data: imageData!) ?? self
    }
}
