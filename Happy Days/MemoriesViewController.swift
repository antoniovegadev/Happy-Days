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
import CoreSpotlight
import MobileCoreServices

class MemoriesViewController: UICollectionViewController, AVAudioRecorderDelegate {

    var memories = [URL]()
    var activeMemory: URL!
    var audioRecorder: AVAudioRecorder?
    var recordingURL: URL!
    var audioPlayer: AVAudioPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        loadMemories()

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))

        recordingURL = getDocumentsDirectory().appendingPathComponent("recording.m4a")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        checkPermissions()
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 0
        } else {
            return memories.count
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Memory", for: indexPath) as! MemoryCell

        let memory = memories[indexPath.row]
        let imageName = thumbnailURL(for: memory).path
        let image = UIImage(contentsOfFile: imageName)
        cell.imageView.image = image

        if cell.gestureRecognizers == nil {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(memoryLongPress))
            recognizer.minimumPressDuration = 0.25
            cell.addGestureRecognizer(recognizer)

            cell.layer.borderColor = UIColor.white.cgColor
            cell.layer.borderWidth = 3
            cell.layer.cornerRadius = 10
        }
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
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

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }

    func loadMemories() {
        memories.removeAll()

        // attempt to load all the memories in our documents directory
        guard let files = try? FileManager.default.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil, options: []) else { return }

        // loop over every file found
        for file in files {
            let filename = file.lastPathComponent

            // check it ends with ".thumb" so we don't count each memory more than once
            if filename.hasSuffix(".thumb") {
                // get the root name of the memory
                let noExtension = filename.replacingOccurrences(of: ".thumb", with: "")

                // creat a full path from the memory
                let memoryPath = getDocumentsDirectory().appendingPathComponent(noExtension)

                // add it to our array
                memories.append(memoryPath)
            }
        }

        collectionView.reloadSections(IndexSet(integer: 1))
    }

    func saveNewMemory(image: UIImage) {
        // create a unique name for this memory
        let memoryName = "memory-\(Date().timeIntervalSince1970)"

        // use the unique name to create filenames for the full-size image and the thumbnail
        let imageName = memoryName + ".jpg"
        let thumbnailName = memoryName + ".thumb"

        do {
            // create a URL where we can write the JPEG to
            let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)

            // convert the UIImage into a JPEG data object
            if let jpegData = image.jpegData(compressionQuality: 0.8) {
                // write that data to the URL we created
                try jpegData.write(to: imagePath, options: [.atomic])
            }

            if let thumbnail = resize(image: image, to: 200) {
                let imagePath = getDocumentsDirectory().appendingPathComponent(thumbnailName)
                if let jpegData = thumbnail.jpegData(compressionQuality: 0.8) {
                    try jpegData.write(to: imagePath, options: [.atomic])
                }
            }
        } catch {
            print("Failed to save to disk.")
        }
    }

    func resize(image: UIImage, to width: CGFloat) -> UIImage? {
        let scale = width / image.size.width

        let height = image.size.height * scale

        // create a new image context we can draw into
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)

        // draw the original image into the context
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))

        // pull out the resized versions
        let newImage = UIGraphicsGetImageFromCurrentImageContext()

        // end the context so UIKit can clean up
        UIGraphicsEndImageContext()

        // send it back to the caller
        return newImage
    }

    @objc func addTapped() {
        let vc = UIImagePickerController()
        vc.modalPresentationStyle = .formSheet
        vc.delegate = self
        navigationController?.present(vc, animated: true)
    }

    @objc func memoryLongPress(sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            let cell = sender.view as! MemoryCell

            if let index = collectionView?.indexPath(for: cell) {
                activeMemory = memories[index.row]
                recordMemory()
            }
        } else if sender.state == .ended {
            finishRecording(success: true)
        }
    }

    func recordMemory() {
        audioPlayer?.stop()

        collectionView?.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)

        let recordingSession = AVAudioSession.sharedInstance()

        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try recordingSession.setActive(true)

            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch let error {
            print("Failed to record: \(error)")
            finishRecording(success: false)
        }
    }

    func finishRecording(success: Bool) {
        collectionView?.backgroundColor = UIColor.darkGray

        audioRecorder?.stop()

        if success {
            do {
                let memoryAudioURL = activeMemory.appendingPathExtension("m4a")
                let fm = FileManager.default

                if fm.fileExists(atPath: memoryAudioURL.path) {
                    try fm.removeItem(at: memoryAudioURL)
                }

                try fm.moveItem(at: recordingURL, to: memoryAudioURL)

                transcribeAudio(memory: activeMemory)
            } catch let error {
                print("Failure finishing recording: \(error)")
            }
        }
    }

    func transcribeAudio(memory: URL) {
        let audio = audioURL(for: memory)
        let transcription = transcriptionURL(for: memory)

        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: audio)

        recognizer?.recognitionTask(with: request) { [unowned self] (result, error) in
            guard let result = result else {
                print("There was an error: \(error!)")
                return
            }

            if result.isFinal {
                let text = result.bestTranscription.formattedString

                do {
                    try text.write(to: transcription, atomically: true, encoding: String.Encoding.utf8)
                    self.indexMemory(memory: memory, text: text)
                } catch {
                    print("Failed to save transcription")
                }
            }

        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let memory = memories[indexPath.row]
        let fm = FileManager.default

        do {
            let audioName = audioURL(for: memory)
            let transcriptionName = transcriptionURL(for: memory)

            if fm.fileExists(atPath: audioName.path) {
                audioPlayer = try AVAudioPlayer(contentsOf: audioName)
                audioPlayer?.play()
            }

            if fm.fileExists(atPath: transcriptionName.path) {
                let contents = try String(contentsOf: transcriptionName)
                print(contents)
            }
        } catch  {
            print("Error loading audio")
        }
    }

    func indexMemory(memory: URL, text: String) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.text)
        attributeSet.title = "Happy Days Memory"
        attributeSet.contentDescription = text
        attributeSet.thumbnailURL = thumbnailURL(for: memory)

        let item = CSSearchableItem(uniqueIdentifier: memory.path, domainIdentifier: "dev.antoniovega", attributeSet: attributeSet)

        item.expirationDate = Date.distantFuture

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Indexing error: \(error.localizedDescription)")
            } else {
                print("Search item successfully indexed: \(text)")
            }
        }
    }
}

extension MemoriesViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegateFlowLayout {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true)

        if let possibleImage = info[.originalImage] as? UIImage {
            saveNewMemory(image: possibleImage)
            loadMemories()
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 1 {
            return CGSize.zero
        } else {
            return CGSize(width: 0, height: 50)
        }
    }
}


extension MemoriesViewController {
    func imageURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("jpg")
    }

    func thumbnailURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("thumb")
    }

    func audioURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("m4a")
    }

    func transcriptionURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("txt")
    }
}
