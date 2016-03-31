//
//  HDrawable.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 3/31/16.
//  Copyright © 2016 Jeremy Kahn. All rights reserved.
//

import UIKit


protocol HDrawable : class {
    
    func copy() -> HDrawable
    
    // Deprecated
    func transformedBy(_: HyperbolicTransformation) -> HDrawable
    
    func draw()
    
    func drawWithMask(_: HyperbolicTransformation)
    
    func drawWithMaskAndAction(_: Action)
    
    var size: Double { get set}
    
    var color: UIColor { get set}
    
    var colorTable: ColorTable {get set}
    
    var mask: HyperbolicTransformation { get set}
    
    var baseNumber: ColorNumber {get set}
    
    var useColorTable: Bool {get set}
    
    var centerPoint: HPoint {get}
    
    var radius: Double {get}
    
}

extension HDrawable {
    
    func filteredGroup(group: [Action], cutoffDistance: Double) -> [Action] {
        
        let objectCutoffAbs = distanceToAbs(cutoffDistance + radius)
        
        let objectGroup = group.filter() {$0.motion.appliedTo(centerPoint).abs < objectCutoffAbs}
        
        return objectGroup
    }
    
    func drawWithMask(mask: HyperbolicTransformation) {
        self.mask = mask
        draw()
    }
    
    func drawWithMaskAndAction(A: Action) {
        if useColorTable {
            color = colorTable[A.action.mapping[baseNumber]!]!
        }
        drawWithMask(A.motion)
    }
    
}

