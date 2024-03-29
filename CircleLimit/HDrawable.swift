//
//  HDrawable.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 3/31/16.
//  Copyright © 2016 Jeremy Kahn. All rights reserved.
//

import UIKit

protocol Disked {
    
    var centerPoint: HPoint {get}
    
    var radius: Double {get}
        
}

enum HDrawableType: String, Codable {
    
    case polyline
    case polygon
    case dot
    
    var metatype: HDrawable.Type {
        switch self {
        case .polyline: return HyperbolicPolyline.self
        case .polygon: return HyperbolicPolygon.self
        case .dot: return HyperbolicDot.self
        }
    }
}

struct HDWrapper: Codable {
    var object: HDrawable
    
    init(_ object: HDrawable) {
        self.object = object
    }
    
    private enum CodingKeys : CodingKey {
        case type
        case object
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(object.type, forKey: .type)
        try object.encode(to: encoder)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let type = try container.decode(HDrawableType.self, forKey: .type)
        self.object = try type.metatype.init(from: decoder)
    }
}

protocol HDrawable: class, Disked, Codable {
    
    var type: HDrawableType {get}
    
    func copy() -> HDrawable
    
    // Deprecated
    func transformedBy(_: HyperbolicTransformation) -> HDrawable
    
    func draw()
    
    func drawWithMask(_: HyperbolicTransformation)
    
    func drawWithMaskAndAction(_: Action)
    
    var lineColor: UIColor { get set}
    
    var intrinsicLineWidth: Double {get set}
    
    var colorInfo: ColorInfo {get set}
    
    var fillColorTable: ColorTable {get set}
    
    var fillColor: UIColor {get set}
    
    var mask: HyperbolicTransformation { get set}
    
    var fillColorBaseNumber: ColorNumber {get set}
   
    var useFillColorTable: Bool {get set}
    
    var centerPoint: HPoint {get}
    
    var radius: Double {get}
    
}



extension HDrawable {
    
    var fillColorTable: ColorTable {
        get {
            return colorInfo.fillColorTable
        }
        
        set(newValue) {
            colorInfo.fillColorTable = newValue
        }
    }
    
    var fillColor: UIColor {
        get {
            return colorInfo.fillColor
        }
        
        set(newValue) {
            colorInfo.fillColor = newValue
            // debugging stuff!
            if !useFillColorTable || newValue == UIColor.brown {
                print(fillColor, newValue)
            }
        }
    }
    
    var lineColor: UIColor {
        get {
            return colorInfo.lineColor
        }
        
        set(newValue) {
            colorInfo.lineColor = newValue
        }
    }

    
    func filteredGroup(_ group: [Action], cutoffDistance: Double) -> [Action] {
        
        let objectCutoffAbs = distanceToAbs(cutoffDistance + radius)
        
        let objectGroup = group.filter() {$0.motion.appliedTo(centerPoint).abs < objectCutoffAbs}
        
        return objectGroup
    }
    
    func drawWithMask(_ mask: HyperbolicTransformation) {
        self.mask = mask
        draw()
    }
    
    func drawWithMaskAndAction(_ A: Action) {
        if useFillColorTable {
            fillColor = fillColorTable[A.action.mapping[fillColorBaseNumber]!]!
        } else {
//            print(type, useFillColorTable, fillColor.rgba, fillColor, fillColorTable.map() {$0.value.rgba})
        }
        drawWithMask(A.motion)
    }
    
}

