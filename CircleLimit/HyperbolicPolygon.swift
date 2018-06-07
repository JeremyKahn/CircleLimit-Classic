//
//  HyperbolicPolygon.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 3/31/16.
//  Copyright © 2016 Jeremy Kahn. All rights reserved.
//

import UIKit

class HyperbolicPolygon: HyperbolicPolyline {
    
    override func copy() -> HDrawable {
        return HyperbolicPolygon(self)
    }
    
//    init(_ a: HyperbolicPolygon) {
//        super.init(a)
//    }
//
//    override init(_ z: HPoint) {
//        super.init(z)
//    }
//
//    override init(_ pp: [HPoint]) {
//        super.init(pp)
//    }
    
    
    var polygonAndCurves: (UIBezierPath, [UIBezierPath]) {
        let points = maskedPointsToDraw
        //        print("Fill color: \(color)")
        let totalPath = UIBezierPath()
        totalPath.move(to: points[0].cgPoint)
        var borderPaths: [UIBezierPath] = []
        for i in 0..<(points.count - 1) {
            let (a, b) = (points[i], points[i+1])
            let addGeodesicTo = addGeodesicFrom(a, to: b)
            addGeodesicTo(totalPath)
            
            let borderPath = UIBezierPath()
            borderPath.move(to: a.cgPoint)
            addGeodesicTo(borderPath)
 
            borderPath.lineWidth = suitableLineWidth(a, b)
            borderPath.lineCapStyle = CGLineCap.round
            borderPaths.append(borderPath)
        }
        return (totalPath, borderPaths)
    }
    
    override func draw() {
        let (totalPath, borderPaths) = polygonAndCurves
        fillColor.setFill()
        lineColor.setStroke()
        totalPath.lineCapStyle = CGLineCap.round
        totalPath.fill()
        _ = borderPaths.map { $0.stroke() }
        if points.count == 1 { super.draw() }
    }
    
    func containsPoint(_ point: HPoint, withMask mask: HyperbolicTransformation) -> Bool {
        self.mask = mask
        let (polygon, _) = polygonAndCurves
        return polygon.contains(point.cgPoint)
    }
}


