//
//  ViewController.swift
//  VoiceSearch
//
//  Created by Xiaomei Huang on 11/2/17.
//  Copyright © 2017 Xiaomei Huang. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import Speech

class ViewController: UIViewController {
    @IBOutlet weak var label: UILabel!
    
    
    
    @IBAction func clickConfirm(_ sender: Any) {
        requestPhotoPermissions()
      
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    func requestPhotoPermissions(){
        PHPhotoLibrary.requestAuthorization { (authStatus) in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.requestRecordingPermissions()
                } else {
                    self.label.text = "Photo permission was declined; Please enable it in the setting then tap Confirm again"
                }
            }
        }
        
    }
    
    func requestRecordingPermissions() {
        AVAudioSession.sharedInstance().requestRecordPermission { (allowed) in
            DispatchQueue.main.async {
                if allowed {
                    self.requestTranscribePermissions()
                } else {
                    self.label.text = "Recording permission was declined; Please enable it in the setting then tap Confirm again"
                }
            }
        }
    }
    
    func requestTranscribePermissions(){
        SFSpeechRecognizer.requestAuthorization { (status) in
            DispatchQueue.main.async {
                if status == .authorized {
                    self.authorizationCompleted()
                } else {
                    self.label.text = "Transcription permission was declined; Please enable it in the setting then tap Confirm again"
                }
            }
        }
    }
    
    func authorizationCompleted(){
        dismiss(animated: true, completion: nil)
    }
    

}

