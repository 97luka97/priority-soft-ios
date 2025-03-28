//
//  ErrorViewController.swift
//  priority-soft-ios
//
//  Created by Kostic on 26.3.25..
//

import UIKit

class ErrorViewController: UIViewController {

    @IBOutlet private weak var allowButton: UIButton!
    @IBOutlet private weak var errorContainerView: UIView!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupUI()
        checkPermissions()
    }

    private func setupUI() {
        allowButton.layer.cornerRadius = 8
        errorContainerView.roundCorners([.topLeft, .topRight], radius: 24)
    }

    private func checkPermissions() {
        CameraAccessHelper.requestCameraPermission { [weak self] granted in
            if granted {
                self?.checkLocationPermission()
            }
        }
    }

    private func checkLocationPermission() {
        LocationAccessHelper.shared.requestLocationPermission { [weak self] granted in
            if granted {
                self?.dismiss(animated: true)
            }
        }
    }

    @IBAction private func allowButtonTapped(_ sender: UIButton) {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsURL) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }
    }
}
