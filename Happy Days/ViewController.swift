//
//  ViewController.swift
//  Happy Days
//
//  Created by Antonio Vega on 12/7/21.
//

import UIKit
import AVFoundation
import Photos
import Speech

class ViewController: UIViewController {

    @IBOutlet weak var helpLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    func requestPhotoPermissions() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [unowned self] authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.requestRecordPermissions()
                } else {
                    self.helpLabel.text = "Photos permissions was declined; please enable it in settings then tap Continue again."
                }
            }
        }
    }

    func requestRecordPermissions() {
        AVAudioSession.sharedInstance().requestRecordPermission { [unowned self] allowed in
            DispatchQueue.main.async {
                if allowed {
                    self.requestTranscribePermissions()
                } else {
                    self.helpLabel.text = "Recording permissions was declines; please enable it in setting then tap Continue again."
                }
            }
        }
    }

    func requestTranscribePermissions() {
        SFSpeechRecognizer.requestAuthorization { [unowned self] authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.authorizationComplete()
                } else {
                    self.helpLabel.text = "Transcription permission was declined; please enable it in settings then tap Continue again."
                }
            }
        }
    }

    func authorizationComplete() {
        dismiss(animated: true)
    }

    @IBAction func requestPermissions(_ sender: UIButton) {
        requestPhotoPermissions()
    }
    
}

