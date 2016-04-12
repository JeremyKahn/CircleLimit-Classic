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
    
    init(_ a: HyperbolicPolygon) {
        super.init(a)
        self.borderColor = a.borderColor
    }
    
    override init(_ z: HPoint) {
        super.init(z)
    }
    
    override init(_ pp: [HPoint]) {
        super.init(pp)
    }
    
    var borderColor = UIColor.blackColor()
    
    var polygonAndCurves: (UIBezierPath, [UIBezierPath]) {
        let points = maskedPointsToDraw
        //        print("Fill color: \(color)")
        let totalPath = UIBezierPath()
        totalPath.moveToPoint(points[0].cgPoint)
        var borderPaths: [UIBezierPath] = []
        for i in 0..<(points.count - 1) {
            let (startControl, endControl) = controlPointsForApproximatingCubicBezierToGeodesic(points[i], b: points[i+1])
            let (startPoint, endPoint, startHControl, endHControl) =
                (points[i].cgPoint,
                 points[i+1].cgPoint,
                 pointForComplex(startControl),
                 pointForComplex(endControl))
            
            let borderPath = UIBezierPath()
            borderPath.moveToPoint(startPoint)
            borderPath.addCurveToPoint(endPoint, controlPoint1: startHControl, controlPoint2: endHControl)
            borderPath.lineWidth = suitableLineWidth(points[i], points[i+1])
            borderPath.lineCapStyle = CGLineCap.Round
            borderPaths.append(borderPath)
            
            totalPath.addCurveToPoint(endPoint, controlPoint1: startHControl, controlPoint2: endHControl)
        }
        return (totalPath, borderPaths)
    }
    
    // Right now this makes the border by calling super
    override func draw() {
        let (totalPath, borderPaths) = polygonAndCurves
        fillColor.setFill()
        borderColor.setStroke()
        totalPath.lineCapStyle = CGLineCap.Round
        totalPath.fill()
        _ = borderPaths.map { $0.stroke() }
        if points.count == 1 { super.draw() }
    }
    
    func containsPoint(point: HPoint, withMask mask: HyperbolicTransformation) -> Bool {
        self.mask = mask
        let (polygon, _) = polygonAndCurves
        return polygon.containsPoint(point.cgPoint)
    }
}


