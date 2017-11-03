//
//  CollectionViewController.swift
//  VoiceSearch
//
//  Created by Xiaomei Huang on 11/2/17.
//  Copyright © 2017 Xiaomei Huang. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import Speech
import CoreSpotlight
import MobileCoreServices



class CollectionViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegateFlowLayout, AVAudioRecorderDelegate, UISearchBarDelegate {
    
    var memories = [URL]()
    var activeMemory: URL!
    var audioRecorder: AVAudioRecorder?
    var recordURL: URL!
    var audioPlayer: AVAudioPlayer?
    var filteredMemories = [URL]()
    var searchQuery: CSSearchQuery?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        recordURL = getDocDir().appendingPathComponent("recording.m4a")
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(tapAdd))

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false


        // Do any additional setup after loading the view.
        loadMemories()
    }
    
    @objc func tapAdd(){
        let vc = UIImagePickerController()
        vc.modalPresentationStyle = .formSheet
        vc.delegate = self
        navigationController?.present(vc, animated: true)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredMemories(text: searchText)
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func filteredMemories(text: String){
        
        guard text.characters.count > 0 else {
            filteredMemories = memories
            
            UIView.performWithoutAnimation {
                collectionView?.reloadSections(IndexSet(integer: 1))
            }
            return
        }
        
        var allItems = [CSSearchableItem]()
        searchQuery?.cancel()
        let queryString = "contentDescription == \"*\(text)*\"c"
        searchQuery = CSSearchQuery(queryString: queryString, attributes: nil)
        
        searchQuery?.foundItemsHandler = {items in allItems.append(contentsOf: items)}
        
        searchQuery?.completionHandler = {error in
            DispatchQueue.main.async { [unowned self] in
                self.activeFilter(matches: allItems)
                
            }
        }
        searchQuery?.start()
        
    }
    
    func activeFilter(matches:[CSSearchableItem] ){
        filteredMemories = matches.map({ item in
            return URL(fileURLWithPath: item.uniqueIdentifier)
        })
        UIView.performWithoutAnimation {
            collectionView?.reloadSections(IndexSet(integer: 1))
        }
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true)
        
        if let possibleImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            saveNewMemory(image: possibleImage)
            loadMemories()
        }
    }
    
    func saveNewMemory(image: UIImage){
        // create a unique name for the memory
        let memoryName = "memory-\(Date().timeIntervalSince1970)"
        
        // use the name to create filenames for the fullsize image and the thumbmail
        let imageName = memoryName + ".jpg"
        let thumbNailName = memoryName + ".thumb"
        
        do {
            // create a URL where we can write the JPEG
            let imagePath = getDocDir().appendingPathComponent(imageName)
            
            // convert the uiimage into JPEG data object
            if let jpegData = UIImageJPEGRepresentation(image, 80){
                try jpegData.write(to: imagePath, options: [.atomicWrite])
                
            }
            // crete thumbnail
            if let thumbnail = resize(image: image, to: 200){
                let imagePath = getDocDir().appendingPathComponent(thumbNailName)
                
                if let jpegData = UIImageJPEGRepresentation(thumbnail, 80){
                    try jpegData.write(to: imagePath, options: [.atomicWrite])
                }
            }
        } catch {
            print("failed to save")
        }
        
    }
    
    func resize(image: UIImage, to width: CGFloat) -> UIImage?{
        // calculate
        let scale = width / image.size.width
        
        // calculate height
        let height = image.size.height * scale
        
        // create a new image context to draw into
        UIGraphicsBeginImageContextWithOptions(CGSize(width:width, height: height), false, 0)
        
        //draw original into context
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // resized version
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return newImage
        
    }
    


    func checkPermission(){
        let photoAuth = PHPhotoLibrary.authorizationStatus() == .authorized
        let recordAuth = AVAudioSession.sharedInstance().recordPermission() == .granted
        let transcriptAuth = SFSpeechRecognizer.authorizationStatus() == .authorized
        
        let authorized = photoAuth && recordAuth && transcriptAuth
        if authorized == false {
            if let vc = storyboard?.instantiateViewController(withIdentifier: "FirstRun"){
                navigationController?.present(vc, animated: true)
            }
        }
        
        
    }
    
    func getDocDir() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docDir = paths[0]
        
        return docDir
    }
    
    func loadMemories() {
        memories.removeAll()
        
        guard let files = try?  // might fail if no permission
            FileManager.default.contentsOfDirectory(at: getDocDir(), includingPropertiesForKeys: nil, options: []) else {
                return
        }
        for file in files {
            let filename = file.lastPathComponent
            
            if filename.hasSuffix(".thumb"){
                // get the root name of the memory(without its path extension
                let noExtension = filename.replacingOccurrences(of: ".thumb", with: "")
                // create a full path from the memory
                let memoryPath = getDocDir().appendingPathComponent(noExtension)
                // add it to array
                memories.append(memoryPath)
            }
        }
        filteredMemories = memories
        collectionView?.reloadSections(IndexSet(integer:1))  // reload pics without touch searchbar
    }
    
    
    
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkPermission()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        if section == 0 {
            return 0
        } else {
            return filteredMemories.count
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MemoryCell", for: indexPath) as! MemoryCell
        let memory = filteredMemories[indexPath.row]
        
        let imageName = thumbmailURL(for: memory).path
        
        let image = UIImage.init(contentsOfFile: imageName)
        
        cell.imageView.image = image
    
        // Configure the cell
        // add guesture
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
    
    @objc func memoryLongPress(sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            let cell = sender.view as! MemoryCell
            
            if let index = collectionView?.indexPath(for: cell){
                activeMemory = filteredMemories[index.row]
                recordMemory()
            }
        } else if sender.state == .ended {
            finishRecording(success: true)
        }
    }
    
    func recordMemory(){
        audioPlayer?.stop()
        //
        collectionView?.backgroundColor = UIColor.blue
        let recordingSession = AVAudioSession.sharedInstance()
        do {
            // configure the seesion for recording and palyback through the speaker
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
            // set up high quality rocording session
            let settings = [AVFormatIDKey:Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100, AVNumberOfChannelsKey:2, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            // create the audio recording, and assign the delegate
            audioRecorder = try AVAudioRecorder(url:recordURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
        } catch let error {
            print(error)
            finishRecording(success: false)
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
    
    func finishRecording(success: Bool){
        // set back backgroup color
        collectionView?.backgroundColor = UIColor.lightGray
        
        // stop recording
        audioRecorder?.stop()
        
        // create url out
        if success {
            do {
                let memoryAudioURL = activeMemory.appendingPathExtension("m4a")
                let fm = FileManager.default
                // delete existing recordings
                if fm.fileExists(atPath: memoryAudioURL.path){
                    try fm.removeItem(at: memoryAudioURL)
                }
                // move recorded file into url
                try fm.moveItem(at: recordURL, to: memoryAudioURL)
                
                // start transcription
                transcribeAudio(memory: activeMemory)


            } catch let err {
                print(err)
            }
        }
        
    }
    
    func transcribeAudio(memory: URL){
        // get the path
        let audio = audioURL(for: memory)
        let transcription = transcriptionURL(for: memory)
        
        // create new recognizer
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: audio)
        
        // start recognition
        recognizer?.recognitionTask(with: request, resultHandler: { (result, err) in
            guard let result = result else {
                print (err)
                return
            }
            if result.isFinal {
                // pull out the best
                let text = result.bestTranscription.formattedString
                
                // write it to disk at the right filename
                do {
                    try text.write(to: transcription, atomically: true, encoding: String.Encoding.utf8)
                    
                    self.indexMemory(memory: memory, text:text)
                    
                } catch {
                    print("failed to save")
                }
            }
        })
    }
    
    func indexMemory(memory: URL, text: String){
        // create a basic attribute set
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        
        attributeSet.title = "voice search demo"
        attributeSet.contentDescription = text
        attributeSet.thumbnailURL = thumbmailURL(for: memory)
        
        // wrap it into searchable item, using the full path as the identifier
        let item = CSSearchableItem(uniqueIdentifier: memory.path, domainIdentifier: "com.tilthere", attributeSet: attributeSet)
        
        // make it never expire
        item.expirationDate = Date.distantFuture
        
        //spotlight to inex the item
        CSSearchableIndex.default().indexSearchableItems([item]) { (error) in
            if let error = error {
                print (error.localizedDescription)
            } else {
                print ("search item indexed: \(text)")
            }
        }
        
        
        
        
    }
    
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
    }

    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 1 {
            return CGSize.zero
        } else {
            return CGSize(width: 0, height: 50)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let memory = filteredMemories[indexPath.row]
        let fm = FileManager.default
        
        do {
            let audioName = audioURL(for: memory)
            let transcriptionName = transcriptionURL(for: memory)
            
            if fm.fileExists(atPath: audioName.path){
                audioPlayer = try AVAudioPlayer(contentsOf: audioName)
                audioPlayer?.play()
            }
            if fm.fileExists(atPath: transcriptionName.path){
                let contents = try String(contentsOf: transcriptionName)
                print(contents)
            }
            
        } catch let error {
            print(error)
        }
    }
    
    
    func imageURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("jpg")
    }
    
    func thumbmailURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("thumb")
    }
    
    func audioURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("m4a")
    }
    
    func transcriptionURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("txt")
    }

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}
