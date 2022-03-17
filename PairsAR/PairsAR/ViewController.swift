//
//  ViewController.swift
//  PairsAR
//
//  Created by Karen Lima on 09/03/22.
//

import UIKit
import RealityKit
import Combine
import ARKit
import SceneKit
import SpriteKit

class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet var arView: ARView!
    var anchor = AnchorEntity()
    var cards: [Entity] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.session.delegate = self
        
        /* Face Anchor
        // Verify if your device supports FaceTrackingConfiguration (front camera) and then run the config
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        // Add your face anchors to the scene
        
        let anchor = AnchorEntity(.face) /// muda o tipo de ancoragem
        arView.scene.addAnchor(anchor)
        
        */
        
        for _ in 1...16 {
            let box = MeshResource.generateBox(width: 0.04, height: 0.002, depth: 0.04) // cria o volume
            let metalMaterial = SimpleMaterial(color: .gray, isMetallic: true) //ficar metalico
            let model = ModelEntity(mesh: box, materials: [metalMaterial]) //cria entidade
            
            model.generateCollisionShapes(recursive: true) //poder tocar
            cards.append(model)
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        guard let referenceObjects = ARReferenceObject.referenceObjects(inGroupNamed: "scan", bundle: Bundle.main) else {
            fatalError("Missing expected asset catalog resources.")
        }
        configuration.detectionObjects = referenceObjects

        arView.session.run(configuration)
        
    }
    
    @IBAction func onTap(_ sender: UITapGestureRecognizer) {
        let tapLocation = sender.location(in: arView)
        if let card = arView.entity(at: tapLocation) {
            
            if card.transform.rotation.angle == .pi {
                flipDownCard(card: card)
            } else {
                flipUpCard(card: card)
            }
        }
    }
    

    func flipUpCard(card: Entity){
        var flipUpTransform = card.transform
        flipUpTransform.rotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        card.move(to: flipUpTransform, relativeTo: card.parent, duration: 0.25, timingFunction: .easeInOut)
    }
    func flipDownCard(card: Entity){
        var flipDownTransform = card.transform
        flipDownTransform.rotation = simd_quatf(angle: 0, axis: [1, 0, 0])
        card.move(to: flipDownTransform, relativeTo: card.parent, duration: 0.25, timingFunction: .easeInOut)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("I've found the anchorrr")

        if let newAnchor = anchors.last{
            let anchor = AnchorEntity(anchor: newAnchor)
            arView.scene.addAnchor(anchor)
            self.anchor = anchor
            foundAnchor(anchor: self.anchor)
        }
    }
    
    func foundAnchor(anchor: AnchorEntity){
        
        for (index, card) in cards.enumerated() {
            let x = Float(index % 4) - 1.5
            let z = Float(index / 4) - 1.5
            
            card.position = [x * 0.1, 0, z * 0.1]
            self.anchor.addChild(card)
        }

        let boxSize: Float = 0.7
        let occlusionBoxMesh = MeshResource.generateBox(size: boxSize)
        let occlusionBox = ModelEntity(mesh: occlusionBoxMesh, materials: [OcclusionMaterial()])
        occlusionBox.position.y = -boxSize/2

        occlusionBox.name = "occlusion"
        self.anchor.addChild(occlusionBox)
        
        var cancellable: AnyCancellable? = nil
        
        cancellable = ModelEntity.loadModelAsync(named: "01")
            .append(ModelEntity.loadModelAsync(named: "02"))
            .append(ModelEntity.loadModelAsync(named: "03"))
            .append(ModelEntity.loadModelAsync(named: "09"))
            .append(ModelEntity.loadModelAsync(named: "05"))
            .append(ModelEntity.loadModelAsync(named: "06"))
            .append(ModelEntity.loadModelAsync(named: "07"))
            .append(ModelEntity.loadModelAsync(named: "08"))
            .collect()
            .sink(receiveCompletion: {error in
                print("Error: \(error)")
                cancellable?.cancel()
            }, receiveValue: { [self]entities in
                var objects: [ModelEntity] = []
                for (index,entity) in entities.enumerated() {
                    
                    entity.setScale([0.002,0.002,0.002], relativeTo: self.anchor)
                    entity.name = String(index)
                    entity.generateCollisionShapes(recursive: true)
                    
                    for _ in 1...2 {
                        let clone = entity.clone(recursive: true)
                        objects.append(clone)
                    }
                }
                objects.shuffle()
                
                for (index, object) in objects.enumerated() {
                    self.cards[index].name = "card" + String(index)
                    self.cards[index].addChild(object)
                    self.cards[index].transform.rotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
                }
                cancellable?.cancel()
            })
        }
    
}



