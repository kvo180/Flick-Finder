//
//  ViewController.swift
//  Flick Finder
//
//  Created by Khoa Vo on 10/25/15.
//  Copyright © 2015 AppSynth. All rights reserved.
//

import UIKit

// Define constants
let BASE_URL = "https://api.flickr.com/services/rest"
let METHOD_NAME = "flickr.photos.search"
let API_KEY = "3d99a7b9345ed97b6e3fc2b927ebd9ea"
let EXTRAS = "url_m"
let SAFE_SEARCH = "1"
let DATA_FORMAT = "json"
let NO_JSON_CALLBACK = "1"

class ViewController: UIViewController, UITextFieldDelegate {
    
    // MARK: - Define properties
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var locationSearchButton: UIButton!
    @IBOutlet weak var imageLabel: UILabel!
    @IBOutlet weak var defaultLabel: UILabel!
    let whitespaceSet = NSCharacterSet.whitespaceCharacterSet()
    var photoTitle: String = ""
    var defaultLabelText: String = ""
    var tapRecognizer: UITapGestureRecognizer!
    // 1 - Hardcode the arguments
    var methodArguments = [
    "method": METHOD_NAME,
    "api_key": API_KEY,
    "text": "",
    "safe_search": SAFE_SEARCH,
    "extras": EXTRAS,
    "format": DATA_FORMAT,
    "nojsoncallback": NO_JSON_CALLBACK
    ]

    // MARK: - UI Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set text field delegates
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        
        // Add gesture recognizers
        tapRecognizer = UITapGestureRecognizer(target: self, action: "dismissKeyboard")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        view.addGestureRecognizer(tapRecognizer)
        subscribeToKeyboardNotifications()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        view.removeGestureRecognizer(tapRecognizer)
        unsubscribeToKeyboardNotifications()
    }
    
    // MARK: - IBActions
    @IBAction func phraseSearchButtonPressed(sender: AnyObject) {
        
        executeSearch()
        
        view.endEditing(true)
    }
    
    @IBAction func locationSearchButtonPressed(sender: AnyObject) {
    }
    
    // MARK: - Get image method
    func getImageFromFlickrBySearch(methodArguments: [String : AnyObject]) {
        
        // 3 - Initialize shared NSURLSession
        let session = NSURLSession.sharedSession()
        
        // 4 - Create NSURLRequest
        let urlString = BASE_URL + escapedParameters(methodArguments)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        /* 5 - Initialize task for getting data 
        NOTE 1: The code block below is inside a completion handler, which is executed on a background thread. In order to update the UI properly, the code to update the UI has to be on the MAIN thread, otherwise delays in the UI could happen. This can be done using the dispatch_async(dispatch_get_main_queue) method.
        NOTE 2: If a 'guard' code block below returns an error, it will exit the entire 'let task' method, and anything declared after it will be executed BEFORE the error is thrown. Because of this, label texts can't be set inside the 'guard' code blocks and must instead be set outside of the 'let task' method.
        */
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            // GUARD: Check for a successful response
            guard (error == nil) else {
                print("There was an error with your request: \(error)")
                return
            }
            
            // GUARD: Check if any data was returned
            guard let data = data else {
                print("No data was returned by the request!")
                return
            }
            
            // 6 - Parse the JSON data
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as! NSDictionary
            }
            catch {
                parsedResult = nil
                print("Could not parse the data as JSON: \(data)")
            }
            
            guard let photosDictionary = parsedResult["photos"] as? NSDictionary else {
                print("Cannot find key 'photos' in \(parsedResult)")
                return
            }
            
            // GUARD: Check if any images have been returned
            if let totalPhotos = photosDictionary["total"] as? String {
                guard Int(totalPhotos) > 0 else {
                    print("No images have been returned")
                    return
                }
            }
            
            // photosArray is an array that contains dictionaries
            guard let photosArray = photosDictionary["photo"] as? [[String: AnyObject]] else {
                print("Cannot find key 'photo' in \(photosDictionary)")
                return
            }
            
            // 7 - Generate a random number, then select a random photo
            let randomIndex = Int(arc4random_uniform(UInt32(photosArray.count)))
            let randomPhotoDictionary = photosArray[randomIndex] as [String : AnyObject]
            // If photo has a 'title' key, assign its value to 'photoTitle' string, otherwise display default 'Untitled' text on imageLabel
            if let title = randomPhotoDictionary["title"] as? String {
                self.photoTitle = title
            } else {
                self.photoTitle = "Untitled"
            }
            
            // GUARD: Check if image exists at the URL, then set image and title
            guard let imageUrlString = randomPhotoDictionary["url_m"] as? String else {
                print("Cannot find key 'url_m' in \(randomPhotoDictionary)")
                return
            }
            
            // 8 - If image data exists, set the UI image and title
            let imageUrl = NSURL(string: imageUrlString)
            if let imageData = NSData(contentsOfURL: imageUrl!) {
                dispatch_async(dispatch_get_main_queue(), {
                    // Perform updates on the main thread here!
                    // Keep these updates minimal!
                    self.defaultLabel.alpha = 0.0
                    self.imageView.image = UIImage(data: imageData)
                    self.imageLabel.text = self.photoTitle
                })
            } else {
                print("Image does not exist at \(imageUrl)")
                dispatch_async(dispatch_get_main_queue(), {
                    self.defaultLabel.alpha = 1.0
                    self.imageView.image = nil
                    self.imageLabel.text = "No photos found. Try again!"
                })
            }
        }
        
        // 9 - Resume (execute) the task
        task.resume()
    }
    
    // MARK: - Helper methods
    // Helper function: Given a dictionary of parameters, convert to a string for a URL (ASCII)
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            // Make sure that it is a string value
            let stringValue = "\(value)"
            
            // Escape it 
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            // Append it
            urlVars += [key + "=" + "\(escapedValue!)"]
        }
        
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    // Set textField text value to 'text' key in methodArguments
    func setInputText() {
        if let inputText = phraseTextField.text {
            methodArguments["text"] = inputText
        } else {
            print("Text entered is nil")
        }
    }
    
    // Run only if textField is not empty or does not contain only whitespace
    func executeSearch() {
        if phraseTextField.text!.stringByTrimmingCharactersInSet(whitespaceSet) != "" {
            setInputText()
            
            // 2 - Call the Flickr API using arguments
            getImageFromFlickrBySearch(methodArguments)
        } else {
            imageLabel.text  = "Please enter a search request!"
            imageView.image = nil
        }
    }
    
    // MARK: Delegate methods
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        executeSearch()
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: - Manage notifications
    func subscribeToKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
    }
    
    func unsubscribeToKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillHideNotification, object: nil)
    }
    
    // Close keyboard whenever user taps anywhere outside of keyboard:
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Move view up when keyboard shows
    // Move frame up when keyboardWillShowNotification is received
    func keyboardWillShow(notification: NSNotification) {
        UIView.animateWithDuration(0.5, animations: {
            self.view.frame.origin.y = -self.getKeyboardHeight(notification)
            self.defaultLabel.alpha = 0.0
        })
    }
    
    // Move frame back to initial position when keyboardWillHideNotification is received
    func keyboardWillHide(notification: NSNotification) {
        let initialViewRect: CGRect = CGRectMake(0.0, 0.0, view.frame.size.width, view.frame.size.height)
        UIView.animateWithDuration(0.5, animations: {
            self.view.frame = initialViewRect
            self.defaultLabel.alpha = 1.0
        })
    }
    
    // Called by keyboardWillShow and keyboardWillHide methods when notification is received. Returns keyboard height as a CGFloat
    func getKeyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue // of CGRect
        return keyboardSize.CGRectValue().height
    }

}

