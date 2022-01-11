//
//  MemoriesViewController.swift
//  Happy Days
//
//  Created by Antonio Vega on 1/11/22.
//

import UIKit
import AVFoundation
import Photos
import Speech

class MemoriesViewController: UICollectionViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        checkPermissions()
    }

    func checkPermissions() {
        let photosAuthorized = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
        let recordedAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
        let transcribeAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized

        let authorized = photosAuthorized && recordedAuthorized && transcribeAuthorized

        if authorized == false {
            if let vc = storyboard?.instantiateViewController(withIdentifier: "FirstRun") {
                navigationController?.present(vc, animated: true)
            }
        }
    }

}
