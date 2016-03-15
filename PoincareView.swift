//
//  PoincareView.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 7/19/15.
//  Copyright (c) 2015 Jeremy Kahn. All rights reserved.
//

import UIKit

protocol PoincareViewDataSource : class {
    var objectsToDraw : [HDrawable] {get}
    var groupToDraw : [HyperbolicTransformation] {get}
    var multiplier : CGFloat {get}
}


func circlePath(center: CGPoint, radius: CGFloat) -> UIBezierPath {
    let path =  UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: CGFloat(2 * M_PI), clockwise: false)
    return path
}

@IBDesignable
class PoincareView: UIView {
  
    @IBInspectable
    var viewCenter: CGPoint {
        return convertPoint(center, fromView: superview)
    }
    
    @IBInspectable
    var circleColor: UIColor {
        return UIColor.blueColor()
    }
    
    @IBInspectable
    var viewRadius: CGFloat {
        return min(bounds.size.width, bounds.size.height)/2
    }
    
    @IBInspectable
    var lineWidth: CGFloat = 0.01 {
        didSet {setNeedsDisplay()  }
    }

    func circlePath(center: CGPoint, radius: CGFloat) -> UIBezierPath {
        let path =  UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: cgturn, clockwise: false)
        path.lineWidth = lineWidth
        return path
    }

    let cgturn = CGFloat(2 * M_PI)


    weak var dataSource : PoincareViewDataSource!

    var objects: [HDrawable] {
        return dataSource.objectsToDraw
    }
    
    var group: [HyperbolicTransformation] {
        return dataSource.groupToDraw
    }
    
    var baseScale : CGFloat {
        return viewRadius * 0.99
    }
    
    var scale: CGFloat {
        return baseScale * dataSource!.multiplier
    }
    
    var tf : CGAffineTransform {
//        println("Scale is now \(scale)")
        let t1 = CGAffineTransformMakeTranslation(viewCenter.x, viewCenter.y)
        let t2 = CGAffineTransformScale(t1, scale, scale)
        return t2
    }
     
    override func drawRect(rect: CGRect) {
//        println("entering PoincareView.drawRect with \(objects.count) objects")
        let gcontext = UIGraphicsGetCurrentContext()
        CGContextConcatCTM(gcontext, tf)
        for object in objects {
            for mask in group {
                object.drawWithMask(mask)
            }
        }
        circleColor.set()
        let boundaryCircle = circlePath(CGPointZero, radius: CGFloat(1.0))
        boundaryCircle.lineWidth = lineWidth
        boundaryCircle.stroke()
    }
 }
