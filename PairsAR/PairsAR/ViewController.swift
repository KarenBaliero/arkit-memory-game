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
        
        ModelComponent.registerComponent()
        
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
                for (index,entity) in entities.enumerated() {
                    entity.setScale([0.002,0.002,0.002], relativeTo: anchor)
                    
                    entity.name = String(index)
                    
                    //como nao vamos mais rotacionar precisa mudar a posicao inicial do modelo
                    let box = entity.visualBounds(relativeTo: cards[index])
                    let width = box.max.x - box.min.x
                    let height = box.max.y - box.min.y
                    
                    print(box,entity.name)
                    entity.position =  [0,height,0]
                    //aqui tem q rotacionando pq rotaciona o card embaixo
                    entity.orientation =  simd_quatf(angle: .pi, axis: [1, 0, 0])
                    print(entity.visualBounds(relativeTo: cards[index]).center)
                    entity.generateCollisionShapes(recursive: true)
                    entity.components[ModelComponent.self] = ModelComponent()
                    entity.components[ModelComponent.self]?.width = width
                    entity.components[ModelComponent.self]?.height = height
                    
                    for _ in 1...2 {
                        var clone = entity.clone(recursive: true)
                        
                        objects.append(clone)
                    }
                }
                objects.shuffle()
                
                for (index, object) in objects.enumerated() {
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
                print("card", card.position.y, model.position.y)
                if let modelComponent = model.components[ModelComponent.self] as? ModelComponent {
                    
                    if modelComponent.revealed {
                        moveDownModel(entity: model)
                    }else{
                        moveUpModel(entity: model)
                    }
                }
              
            }else {
                //neste caso o card já é o model
                guard let newcard = card.parent else{return}
                
                print("model", newcard.position.y, card.position.y)
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
    
    
    //problema a se explorar são os movimentos relativos, tb como mover o modelo ao inves do card, tb como descobrir o tamanho para mover o necessário, rotacionar o objeto antes de subir (?), 2 animaçoes juntas
    
    
    func moveUpModel(entity: Entity){
        print(entity.visualBounds(relativeTo: nil).center)
        var modelTransform = entity.transform
        if let modelComponent = entity.components[ModelComponent.self] as? ModelComponent {
            let heigh = modelComponent.height //somar mais um tanto pra mostar 0.05
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
    
}
