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


class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet var arView: ARView!
    var anchor: AnchorEntity? = nil
    var cards: [Entity] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.session.delegate = self
        
        ModelComponent.registerComponent()
        
        /*
         //Face Anchor
        // Verify if your device supports FaceTrackingConfiguration (front camera) and then run the config
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        // Add your face anchors to the scene
        
        self.anchor = AnchorEntity(.face) /// muda o tipo de ancoragem
        arView.scene.addAnchor(anchor!)
         buildBoard()
        */
        
        
        
         
        //Horizontal Anchor
         
         self.anchor = AnchorEntity(plane: .horizontal)
         arView.scene.addAnchor(anchor!)
         buildBoard()
         
        
        
        /*
         //Object Anchor
         
         let configuration = ARWorldTrackingConfiguration()
         guard let referenceObjects = ARReferenceObject.referenceObjects(inGroupNamed: "scan", bundle: Bundle.main) else {
             fatalError("Missing expected asset catalog resources.")
         }
         configuration.detectionObjects = referenceObjects

         arView.session.run(configuration)
         
         */
    }
    
    func buildBoard(){
        
        guard let anchor = self.anchor else{
             return
        }
        
        for _ in 1...16 {
            let box = MeshResource.generateBox(width: 0.04, height: 0.002, depth: 0.04) // cria o volume
            let metalMaterial = SimpleMaterial(color: .gray, isMetallic: true) //ficar metalico
            let model = ModelEntity(mesh: box, materials: [metalMaterial]) //cria entidade
            
            model.generateCollisionShapes(recursive: true) //cria o shape
            cards.append(model)
        }
        
        for (index, card) in cards.enumerated() {
            let x = Float(index % 4) - 1.5
            let z = Float(index / 4) - 1.5
            
            card.position = [x * 0.1, 0, z * 0.1]
            anchor.addChild(card)
        }

        let boxSize: Float = 0.7
        let occlusionBoxMesh = MeshResource.generateBox(size: boxSize)
        let occlusionBox = ModelEntity(mesh: occlusionBoxMesh, materials: [OcclusionMaterial()])
        occlusionBox.position.y = -boxSize/2

        occlusionBox.name = "occlusion"
        anchor.addChild(occlusionBox)
        
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
                    
                    
                    let box = entity.visualBounds(relativeTo: cards[index])
                    let width = box.max.x - box.min.x
                    let height = box.max.y - box.min.y
                    
                    print(box,entity.name)
                    entity.position =  [0,height,0]
                    
                    entity.orientation =  simd_quatf(angle: .pi, axis: [1, 0, 0])
                    print(entity.visualBounds(relativeTo: cards[index]).center)
                    entity.generateCollisionShapes(recursive: true)
                    entity.components[ModelComponent.self] = ModelComponent()
                    entity.components[ModelComponent.self]?.width = width
                    entity.components[ModelComponent.self]?.height = height
                    
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
    
    @IBAction func onTap(_ sender: UITapGestureRecognizer) {
        let tapLocation = sender.location(in: arView)
        if let card = arView.entity(at: tapLocation) {
            if( card.name == "") {return}
            
//            if(card.name.contains("card") ){
//                if card.transform.rotation.angle == .pi {
//                    flipDownCard(card: card)
//                } else {
//                    flipUpCard(card: card)
//                }
//            }else {
//                guard let newcard = card.parent else{return}
//                if newcard.transform.rotation.angle == .pi {
//                    flipDownCard(card: newcard)
//                } else {
//                    flipUpCard(card: newcard)
//                }
//            }
            
            if(card.name.contains("card") ){
                guard let model = card.children.first else{return}
                if let modelComponent = model.components[ModelComponent.self] as? ModelComponent {
                    
                    if modelComponent.revealed {
                        moveDownModel(entity: model)
                    }else{
                        moveUpModel(entity: model)
                    }
                }
              
            }else {
                //neste caso o card já é o model
                if let modelComponent = card.components[ModelComponent.self] as? ModelComponent {
                    
                    if modelComponent.revealed {
                        moveDownModel(entity: card)
                    }else{
                        moveUpModel(entity: card)
                    }
                }
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
    func moveUpModel(entity: Entity){
        print(entity.visualBounds(relativeTo: nil).center)
        var modelTransform = entity.transform
        if let modelComponent = entity.components[ModelComponent.self] as? ModelComponent {
            let heigh = modelComponent.height
            print(heigh)
            let center = entity.visualBounds(relativeTo: entity.parent).center
            entity.components[ModelComponent.self]?.revealed = true
            print(center, center.y - heigh)
            modelTransform.translation = [0, center.y - heigh/2, 0]
            entity.move(to: modelTransform, relativeTo: entity.parent, duration: 0.25, timingFunction: .easeInOut)
            
        }
        
        
    }
    
    
    
    func moveDownModel(entity: Entity){
        print(entity.visualBounds(relativeTo: nil).center)
        var modelTransform = entity.transform
        if let modelComponent = entity.components[ModelComponent.self] as? ModelComponent {
            let heigh = modelComponent.height
            print(heigh)
            let center = entity.visualBounds(relativeTo: entity.parent).center
            print(center, heigh + center.y)
            entity.components[ModelComponent.self]?.revealed = false
            modelTransform.translation = [0, heigh/2 - center.y , 0]
            entity.move(to: modelTransform, relativeTo: entity.parent, duration: 0.25, timingFunction: .easeInOut)
        
        }
        
    }
    /*
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
        if let newAnchor = anchors.last{
            self.anchor = AnchorEntity(anchor: newAnchor)
            arView.scene.addAnchor(self.anchor!)
            buildBoard()
        }
    }
    */
    
}



