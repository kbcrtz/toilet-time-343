import UIKit
import SwiftUI
import AVFoundation
import FamilyControls
import ManagedSettings

@available(iOS 16.0, *)
final class HomeViewController: UIViewController,
                                AVCapturePhotoCaptureDelegate,
                                UIImagePickerControllerDelegate,
                                UINavigationControllerDelegate {

    @IBOutlet private weak var dashboardContainer: UIView!
    @IBOutlet private weak var cameraPreviewView: UIView!
    @IBOutlet private weak var captureButton: UIButton!

    private var captureSession:  AVCaptureSession?
    private let photoOutput      = AVCapturePhotoOutput()
    private var previewLayer:    AVCaptureVideoPreviewLayer?
    private var capturedImageView: UIImageView?

    private var scanLine: UIView?

    private var activitySelection = FamilyActivitySelection()
    private var pickerHost: UIHostingController<FamilyActivityPicker>?

    //block apps that are saved in localstorage
    private func restorePreviousSelection() {
        let (apps, categories) = TokenStorage.load()

        guard !apps.isEmpty || !categories.isEmpty else { return }

        activitySelection.applicationTokens = apps
        activitySelection.categoryTokens    = categories

        let store = ManagedSettingsStore()
        store.shield.applications          = apps
        store.shield.applicationCategories = .specific(categories)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        //block apps
        restorePreviousSelection()
        //render dashboard
        embedScreenTimeDashboard()
        //make sure camera is gewd
        checkCameraAuthorization()

        
        captureButton.addTarget(self,
                                action: #selector(capturePhoto),
                                for: .touchUpInside)
        //styling the camera
        cameraPreviewView.layer.cornerRadius = 20
        cameraPreviewView.layer.masksToBounds = true
    }
    //render camera preview
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = cameraPreviewView.bounds
    }
    //render dashboard
    private func embedScreenTimeDashboard() {
        let host = UIHostingController(rootView: ScreenTimeDashboard())
        host.view.backgroundColor = .clear

        addChild(host)
        dashboardContainer.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: dashboardContainer.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: dashboardContainer.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: dashboardContainer.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: dashboardContainer.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
    //get camera access
    private func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            //setup the camera if permission granted
            setupCamera()
        case .notDetermined:
            //if its not granted the we request access
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    granted ? self.setupCamera()
                            : self.showPermissionAlert()
                }
            }
        default:
            showPermissionAlert()
        }
    }
    
    //alert if camera permissions are not granted
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Permission Needed",
            message: "Please allow camera access in Settings to use this feature.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    //sets up camera
    private func setupCamera() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(photoOutput)
        else { return }

        session.addInput(input)
        session.addOutput(photoOutput)

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = cameraPreviewView.bounds
        cameraPreviewView.layer.addSublayer(layer)

        session.startRunning()

        captureSession = session
        previewLayer   = layer
    }
    //takes a picture
    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data  = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()

        let imgView = UIImageView(frame: cameraPreviewView.bounds)
        imgView.image = image
        imgView.contentMode = .scaleAspectFill
        imgView.clipsToBounds = true
        cameraPreviewView.addSubview(imgView)
        capturedImageView = imgView

        addScanningOverlay()
        classifyImageWithOpenAI(image)
    }

    // scanning line to signify api call
    private func addScanningOverlay() {
        removeScanningOverlay()

        let line = UIView(frame: CGRect(x: 0, y: 0,
                                        width: cameraPreviewView.bounds.width,
                                        height: 2))
        line.backgroundColor = .green
        cameraPreviewView.addSubview(line)
        scanLine = line

        UIView.animate(withDuration: 2.0,
                       delay: 0,
                       options: [.repeat, .autoreverse],
                       animations: {
            line.frame.origin.y = self.cameraPreviewView.bounds.height - 2
        })
    }
    
    //removes the scanning overlay
    private func removeScanningOverlay() {
        scanLine?.layer.removeAllAnimations()
        scanLine?.removeFromSuperview()
        scanLine = nil
    }
    //chatgpt wrapper
    private func classifyImageWithOpenAI(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let base64Image = imageData.base64EncodedString()

        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer ",
                         forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": "gpt-4.1-mini",
            "input": [
                [
                    "role": "user",
                    "content": [
                        ["type": "input_text",
                         "text": "Does this image show a toilet? Respond with just yes or no."],
                        ["type": "input_image",
                         "image_url": "data:image/jpeg;base64,\(base64Image)"]
                    ]
                ]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let responseText = String(data: data, encoding: .utf8) else {
                print("Request failed:", error?.localizedDescription ?? "Unknown error")
                return
            }

            print("Raw Response:\n\(responseText)")

            let lower = responseText.lowercased()
            DispatchQueue.main.async {
                self.removeScanningOverlay()

                if lower.contains("yes") || lower.contains("toilet") {
                    self.goToConfirmScreen()
                } else {
                    self.showNotToiletAlert()
                }
            }
        }.resume()
    }
    //changes scene to timer picker
    private func goToConfirmScreen() {
        let sb = UIStoryboard(name: "Confirm", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "ConfirmVC")

        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }

    private func showNotToiletAlert() {
        let alert = UIAlertController(
            title: "Not a Toilet",
            message: "Try again with a clearer image of a toilet.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.resetCameraView()
        })
        present(alert, animated: true)
    }

    private func resetCameraView() {
        capturedImageView?.removeFromSuperview()
        capturedImageView = nil
        removeScanningOverlay()

        if let layer = previewLayer {
            layer.frame = cameraPreviewView.bounds
            cameraPreviewView.layer.addSublayer(layer)
        }
        captureSession?.startRunning()
    }
    //button to change limited apps
    @IBAction private func changeRestrictedApps(_ sender: UIButton) {
        presentFamilyActivityPicker()
    }

    private func presentFamilyActivityPicker() {
        let binding = Binding<FamilyActivitySelection>(
            get: { self.activitySelection },
            set: { self.activitySelection = $0 }
        )
        let pickerView = FamilyActivityPicker(selection: binding)

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        done.setTitleColor(.systemBlue, for: .normal)
        done.layer.cornerRadius = 8
        done.addTarget(self,
                       action: #selector(dismissPicker),
                       for: .touchUpInside)

        pickerHost = UIHostingController(rootView: pickerView)
        if let host = pickerHost {
            host.view.addSubview(done)
            done.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                done.topAnchor.constraint(equalTo: host.view.safeAreaLayoutGuide.topAnchor, constant: 16),
                done.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -16)
            ])
            
            present(host, animated: true)
        }
    }

    @objc private func dismissPicker() {
        pickerHost?.dismiss(animated: true) { [weak self] in
            self?.persistSelection()
        }
    }
    //keeps apps persistent throughout userDefaults
    private func persistSelection() {
        let store = ManagedSettingsStore()

        let apps       = activitySelection.applicationTokens
        let categories = activitySelection.categoryTokens

            TokenStorage.save(apps: apps, categories: categories)
            UserDefaults.standard.set(true, forKey: "hasPickedApps")

            if apps.isEmpty && categories.isEmpty {
                store.shield.applications          = nil
                store.shield.applicationCategories = nil
            } else {
                if !apps.isEmpty {
                    store.shield.applications = apps
                } else {
                    store.shield.applications = nil
                }

                if !categories.isEmpty {
                    store.shield.applicationCategories = .specific(categories)
                } else {
                    store.shield.applicationCategories = nil
                }
            }

            print("Updated apps:", apps, "\n Updated categories:", categories)

            if apps.isEmpty && categories.isEmpty {
                showAlert(title: "No Apps Selected",
                          message: "Restrictions have been cleared. Select apps again whenever you like.")
            }
        }
    //show alert helper
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
