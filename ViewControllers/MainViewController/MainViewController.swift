import UIKit
import AVFoundation
import CoreLocation

class MainViewController: UIViewController, AVCapturePhotoCaptureDelegate, CLLocationManagerDelegate {

    @IBOutlet private weak var cameraPreviewView: UIView!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var imageProgressLabel: UILabel!

    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var captureOutput: AVCapturePhotoOutput?
    private var locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var isCapturing = false

    private var _totalImages = 0
    private var totalImages: Int {
        get {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }
            return _totalImages
        }
        set {
            objc_sync_enter(self)
            _totalImages = newValue
            objc_sync_exit(self)
        }
    }

    private var uploadedImages = 0 {
        didSet {
            DispatchQueue.main.async {
                self.imageProgressLabel.text = "\(self.uploadedImages)/\(self.totalImages)"
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        totalImages = ImageUploader.shared.getTotalImages()
        uploadedImages = ImageUploader.shared.getUploadedImages()
        updateProgressLabel()

        ImageUploader.shared.onUploadProgress = { [weak self] uploadedCount in
            guard let self = self else { return }
            self.uploadedImages = uploadedCount
            self.updateProgressLabel()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkPermissions()
    }

    private func checkPermissions() {
        CameraAccessHelper.requestCameraPermission { [weak self] granted in
            if granted {
                self?.checkLocationPermission()
            } else {
                self?.isCapturing = false
                self?.showPermissionError()
            }
        }
    }

    private func checkLocationPermission() {
        LocationAccessHelper.shared.requestLocationPermission { [weak self] granted in
            if granted {
                self?.setupCameraPreview()
                self?.setupLocationManager()
            } else {
                self?.isCapturing = false
                self?.showPermissionError()
            }
        }
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func setupCameraPreview() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No back camera available")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            }
        } catch {
            print("Error setting up camera input: \(error)")
            return
        }

        captureOutput = AVCapturePhotoOutput()
        if captureSession?.canAddOutput(captureOutput!) == true {
            captureSession?.addOutput(captureOutput!)
        }

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        videoPreviewLayer?.videoGravity = .resizeAspectFill
        videoPreviewLayer?.frame = cameraPreviewView.bounds
        cameraPreviewView.layer.addSublayer(videoPreviewLayer!)

        isCapturing = true

        DispatchQueue.global(qos: .background).async {
            self.captureSession?.startRunning()
        }
    }

    private func updateProgressLabel() {
        DispatchQueue.main.async {
            self.imageProgressLabel.text = "\(self.uploadedImages)/\(self.totalImages)"
            self.statusLabel.text = self.uploadedImages == self.totalImages ? "Uploaded" : "Uploading"
        }
    }

    private func showPermissionError() {
        let errorVC = ErrorViewController(nibName: "ErrorViewController", bundle: nil)
        errorVC.modalTransitionStyle = .crossDissolve
        errorVC.modalPresentationStyle = .overFullScreen
        navigationController?.present(errorVC, animated: true)
    }

    @IBAction private func captureButtonTapped(_ sender: UIButton) {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        captureOutput?.capturePhoto(with: settings, delegate: self)
    }
}

extension MainViewController {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) else {
            print("Failed to capture photo")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.totalImages += 1
            self.updateProgressLabel()
            self.statusLabel.text = "Photo captured, uploading..."
        }

        let compressedImage = image.resizedToUnder5MB()

        Task {
            await ImageUploader.shared.handleImageCapture(compressedImage, location: currentLocation)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
    }
}
