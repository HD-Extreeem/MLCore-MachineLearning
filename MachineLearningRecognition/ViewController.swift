//
//  ViewController.swift
//  MachineLearningGestureRecognition
//
//  Created by Hadi Deknache on 2017-12-23.
//  Copyright © 2017 Hadi Deknache. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate{
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var debugTextView: UITextView!
    @IBOutlet weak var textOverlay: UITextField!
    
    
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    var visionRequests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        debugTextView.isEditable = false
        textOverlay.isEnabled = false
        // --- ARKIT Setups ---
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information on bottom,set to true if wanted to be show
        sceneView.showsStatistics = false
        
        // Create a new scene for ARkit
        let scene = SCNScene()
        
        // Set the scene to the view of ARkit!
        sceneView.scene = scene
        
        // Setup Vision Model with trainedModel created
        guard let selectedModel = try? VNCoreMLModel(for:
            ani_model().model) else {
                fatalError("Could not load model, check whether the model is correct and placed in right place")
        }
        
        // Set up Vision-CoreML Request
        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size for screen
        visionRequests = [classificationRequest]
        
        // Begin Loop to Update CoreML
        loopCoreMLUpdate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Do any desired updates to SceneKit here.
        }
    }
    
    // MACHINE LEARNING
    
    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate for not freezing application)
        dispatchQueueML.async {
            self.updateCoreML()
            self.loopCoreMLUpdate()
        }
    }
    
    func updateCoreML() {
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        // Run Vision Image Request
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }
    
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results were found")
            return
        }
        
        // Get Classifications from liveImage
        let classifications = observations[0...2] // top 3 results
            .flatMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        // Render Classifications
        DispatchQueue.main.async {
            // Display Debug Text on screen
            self.debugTextView.text = "Probabilities Percent: \n" + classifications
            
            // Display Top Symbol
            var symbol = "🤷‍♂️"
            let topPrediction = classifications.components(separatedBy: "\n")[0]
            let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
            // Checking prediction of the live Image if it is over 60%
            let predictionPercent:Float? = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
            if (predictionPercent != nil && predictionPercent! > 0.6) {
                if (topPredictionName == "Squirrel") { symbol = "🐿" }
                else if (topPredictionName == "Bear") { symbol = "🐻" }
                else if (topPredictionName == "Squid") { symbol = "🐙" }
            }
            self.textOverlay.text = symbol
        }
    }
    
    // MARK: - HIDE STATUS BAR
    override var prefersStatusBarHidden : Bool { return true }
}



