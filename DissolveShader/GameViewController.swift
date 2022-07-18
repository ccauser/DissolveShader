//
//  GameViewController.swift
//  DissolveShader
//
//  Created by Christophe Causer on 7/18/22.
//

import SceneKit
import QuartzCore

class GameViewController: NSViewController {
    @IBOutlet weak var gameView: SCNView!
    @IBOutlet weak var dissolveStage: NSSlider!
    @IBOutlet weak var scale: NSSliderCell!
    @IBOutlet weak var keepGeometryTexture: NSButton!
    
    // return the sphere node
    lazy var sphere: SCNNode = {
        guard let sphere = gameView.scene?.rootNode.childNode(withName: "sphere", recursively: true) else { fatalError("Can't find sphere")}
        return sphere
    }()
    
    lazy var box: SCNNode = {
        guard let sphere = gameView.scene?.rootNode.childNode(withName: "box", recursively: true) else { fatalError("Can't find box")}
        return sphere
    }()
    
    lazy var earthImage: NSImage = {
        return bundleImage("earth")
    }()
    
    var lastShaderTexture: NSImage!
    
   // return the first material shared by sphere and box, or create one for both if none available
    lazy var firstMaterial: SCNMaterial = {
        let material = SCNMaterial()
        material.diffuse.contents = earthImage
        guard let _ = sphere.geometry else { fatalError("Can't find sphere geometry")}
        sphere.geometry!.firstMaterial = material
        guard let _ = sphere.geometry else { fatalError("Can't find box geometry")}
        box.geometry!.firstMaterial = material

        return material
    }()
    
   override func viewDidLoad() {
        super.viewDidLoad()
        
        // create a new scene
        let scene = SCNScene(named: "art.scnassets/scene.scn")!
        
        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        
        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 3, z: 3)

       // Force the camera to look at the center of the view
       let lookAtTarget = SCNNode()
       scene.rootNode.addChildNode(lookAtTarget)
       let lookAtConstraint = SCNLookAtConstraint(target: lookAtTarget)
       cameraNode.constraints = [ lookAtConstraint]

        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = NSColor.white
        scene.rootNode.addChildNode(ambientLightNode)
        
        // set the scene to the view
        gameView.scene = scene
        
        // allows the user to manipulate the camera
        gameView.allowsCameraControl = true
        
        // show statistics such as fps and timing information
        gameView.showsStatistics = true
        
        // configure the view
        gameView.backgroundColor = NSColor.black

        setupShader()
    }
    
    func setupShader() {
        let dissolveShader = try! String(contentsOf: Bundle.main.url(forResource: "art.scnassets/dissolve", withExtension: "shader")!)
        guard let noiseImage  = NSImage(contentsOf: Bundle.main.url(forResource: "art.scnassets/gradientH", withExtension: "png")!) else { print("Can't find image"); return}

        // apply shader at material level instead of geometry so it's shared with box too
        firstMaterial.shaderModifiers = [
            SCNShaderModifierEntryPoint.fragment : dissolveShader
        ]

        firstMaterial.setValue(Float(0.5), forKey:"dissolveStage") // Shader propery: half visible at first
        dissolveStage.floatValue = 0.5 // Update UI
        
        firstMaterial.setValue(Float(1.0), forKey:"noiseScale") // Shader propery: repeat pattern once by default
        firstMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(CGFloat( 1.0), CGFloat( 1.0), 1);
        firstMaterial.diffuse.wrapS = SCNWrapMode.repeat
        firstMaterial.diffuse.wrapT = SCNWrapMode.repeat
        scale.intValue = 1 // Update UI

        updateMaterial( noiseImage)
    }

    // Need to update the texture property used by shader and diffuse texture to help visualize
    func updateMaterial( _ noiseImage: NSImage) {
        lastShaderTexture = noiseImage
        firstMaterial.setValue(SCNMaterialProperty(contents: noiseImage), forKey: "noiseTexture")
        if keepGeometryTexture.state == .off {
            firstMaterial.diffuse.contents = noiseImage
        }
    }

    func bundleImage( _ image: String) -> NSImage {
        guard let url = Bundle.main.url(forResource: "art.scnassets/\(image)", withExtension: "png") else { fatalError("Can't find image \(image)")}
        guard let noiseImage  = NSImage(contentsOf: url) else { fatalError("Can't load image \(image)")}
        return noiseImage
    }
    
    @IBAction func hPressed(_ sender: Any) {
        updateMaterial( bundleImage("gradientH"))
    }
    
    @IBAction func vPressed(_ sender: Any) {
        updateMaterial( bundleImage("gradientV"))
    }
    
    @IBAction func nPressed(_ sender: Any) {
        updateMaterial( bundleImage("noise"))
    }
    
    @IBAction func updateGeometryTexture(_ sender: NSButton) {
        if sender.state == .off { // turning off, same texture as shader
            firstMaterial.diffuse.contents = lastShaderTexture
        } else {
            firstMaterial.diffuse.contents = earthImage
        }
    }
    
    @IBAction func updateScale(_ sender: NSSlider) {
        firstMaterial.setValue( sender.intValue, forKey:"noiseScale") // Shader propery: Fully visible at first
        firstMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(CGFloat( sender.floatValue), CGFloat( sender.floatValue), 1);
        firstMaterial.diffuse.wrapS = SCNWrapMode.repeat
        firstMaterial.diffuse.wrapT = SCNWrapMode.repeat    }
    
    @IBAction func updateRevelage(_ sender: NSSlider) {
        firstMaterial.setValue( sender.floatValue, forKey:"dissolveStage") // Shader propery: Fully visible at first
    }
    
    @IBAction func animate(_ sender: NSButton) {
        let duration: CFTimeInterval = 2.5
        let fromValue: Float = 1.0
        let toValue: Float = 0.0

        let dissolveAnimation = CABasicAnimation(keyPath: "dissolveStage")
        dissolveAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        dissolveAnimation.duration = duration
        dissolveAnimation.fromValue = fromValue
        dissolveAnimation.toValue = toValue
        let scnDissolveAnimation = SCNAnimation(caAnimation: dissolveAnimation)
        scnDissolveAnimation.animationDidStop = {( _, anim, finished) in
            let dissolveAnimation = CABasicAnimation(keyPath: "dissolveStage")
            dissolveAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            dissolveAnimation.duration = duration
            dissolveAnimation.fromValue = toValue
            dissolveAnimation.toValue = fromValue
            let scnDissolveAnimation = SCNAnimation(caAnimation: dissolveAnimation)
            self.firstMaterial.setValue(fromValue, forKey:"dissolveStage") // end state value
            self.firstMaterial.addAnimation(scnDissolveAnimation, forKey: "Dissolve")
        }
        
        firstMaterial.setValue(toValue, forKey:"dissolveStage") // end state value
        firstMaterial.addAnimation(scnDissolveAnimation, forKey: "Dissolve")
    }
}
