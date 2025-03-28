//
//  LocationAccessHelper.swift
//  priority-soft-ios
//
//  Created by Kostic on 28.3.25..
//

import Foundation
import CoreLocation

class LocationAccessHelper: NSObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager?
    private var completion: ((Bool) -> Void)?

    static let shared = LocationAccessHelper()

    private override init() {
        super.init()
    }

    func requestLocationPermission(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        locationManager = CLLocationManager()
        locationManager?.delegate = self

        if #available(iOS 14.0, *) {
            let status = locationManager?.authorizationStatus
            handleAuthorization(status)
        } else {
            let status = CLLocationManager.authorizationStatus()
            handleAuthorization(status)
        }
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus?) {
        guard let status = status else {
            completion?(false)
            return
        }

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            completion?(true)
        case .notDetermined:
            locationManager?.requestWhenInUseAuthorization()
        case .denied, .restricted:
            completion?(false)
        @unknown default:
            completion?(false)
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorization(status)
    }
}
