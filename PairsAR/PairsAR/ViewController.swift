//
//  ViewController.swift
//  PairsAR
//
//  Created by Karen Lima on 09/03/22.
//

import UIKit
import RealityKit
import Combine

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let anchor = AnchorEntity(plane: .horizontal, minimumBounds: [0.2, 0.2])
        arView.scene.addAnchor(anchor)
        
        var cards: [Entity] = []
        for _ in 1...16 {
            let box = MeshResource.generateBox(width: 0.04, height: 0.002, depth: 0.04) // cria o volume
            let metalMaterial = SimpleMaterial(color: .gray, isMetallic: true) //ficar metalico
            let model = ModelEntity(mesh: box, materials: [metalMaterial]) //cria entidade
            
            model.generateCollisionShapes(recursive: true) //poder tocar
            cards.append(model)
        }
        
        for (index, card) in cards.enumerated() {
            let x = Float(index % 4) - 1.5
            let z = Float(index / 4) - 1.5
            
            card.position = [x*0.1, 0, z*0.1]
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
            .append(ModelEntity.loadModelAsync(named: "03"))
            .append(ModelEntity.loadModelAsync(named: "04"))
            .append(ModelEntity.loadModelAsync(named: "05"))
            .append(ModelEntity.loadModelAsync(named: "06"))
            .append(ModelEntity.loadModelAsync(named: "07"))
            .append(ModelEntity.loadModelAsync(named: "08"))
            .collect()
            .sink(receiveCompletion: {error in
                print("Error: \(error)")
                cancellable?.cancel()
            }, receiveValue: {entities in
                var objects: [ModelEntity] = []
                for entity in entities {
                    entity.setScale(SIMD3<Float>(0.002, 0.002, 0.002), relativeTo: anchor)
                    entity.generateCollisionShapes(recursive: true)
                    for _ in 1...2 {
                        objects.append(entity.clone(recursive: true))
                    }
                }
                objects.shuffle()
                //coloquei nome pra nao me perder
                for (index, object) in objects.enumerated() {
                    object.name = String(index)
                    cards[index].name = "card" + String(index)
                    
                    cards[index].addChild(object)
                    cards[index].transform.rotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
                }
                cancellable?.cancel()
            })
    }
    
    
    @IBAction func onTap(_ sender: UITapGestureRecognizer) {
        let tapLocation = sender.location(in: arView)
        if let card = arView.entity(at: tapLocation) {
            
            if card.transform.rotation.angle == .pi {
                flipUpCard(card: card)
            } else {
                flipDownCard(card: card)
            }
            print(card.children)
            guard let model = card.children.first else{return}
            
//            if card.position.y > (model.position.y) {
//
//                moveDownModel(card: card)
//            } else {
//
//                moveUpModel(card: card)
//            }
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
    
    
    //problema a se explorar são os movimentos relativos, tb como mover o modelo ao inves do card, tb como descobrir o tamanho para mover o necessário, rotacionar o objeto antes de subir (?), 2 animaçoes juntas
    
    
    func moveUpModel(card: Entity){
        guard let model = card.children.first else{return}
        var modelTransform = model.transform
        modelTransform.rotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        model.move(to: modelTransform, relativeTo: model)
        
        let boxSize = model.visualBounds(relativeTo: nil).boundingRadius //somar mais um tanto pra mostar 0.05
        modelTransform.translation = SIMD3<Float>(0, -boxSize ,0)
        model.move(to: modelTransform, relativeTo: card, duration: 0.25, timingFunction: .easeInOut)
        
    }
    
    
    
    func moveDownModel(card: Entity){
        guard let model = card.children.first else{return}
        var modelTransform = model.transform
        
        let boxSize = model.visualBounds(relativeTo: nil).boundingRadius
        modelTransform.translation = SIMD3<Float>(0, boxSize ,0)
        model.move(to: modelTransform, relativeTo: card, duration: 0.25, timingFunction: .easeInOut)
        
        
        modelTransform.rotation = simd_quatf(angle: 0, axis: [1, 0, 0])
        model.move(to: modelTransform, relativeTo: model)
    }
    
}
