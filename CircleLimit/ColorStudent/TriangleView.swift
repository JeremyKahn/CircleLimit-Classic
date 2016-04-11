//
//  TriangleView.swift
//  ColorStudent
//
//  Created by Jeremy Kahn on 10/11/15.
//  Copyright © 2015 Jeremy Kahn. All rights reserved.
//

import UIKit


struct ColorChoiceParameters {
    var color1 : UIColor = UIColor.blueColor()
    var color2 : UIColor = UIColor.cyanColor()
    var color1weight : CGFloat = 0
    var color2weight : CGFloat = 0
    
    var outwardNormalVectors: [CGPoint] = []
    
    func colorWithCenterColor(center: UIColor) -> UIColor {
        let weights = [color1weight, color2weight, centerColorWeight]
        let colors = [color1, color2, center]
        return weightedColor(weights, colors: colors)
    }
    
    var centerColorWeight: CGFloat {
        return 1 - color1weight - color2weight
    }
}

@IBDesignable
class TriangleView: UIView {
    
    // We have to use an explicit optional in order to use IBDesignable
    var dataSource: TriangleViewController?
    
    let colorHexagon = [UIColor.blueColor(), UIColor.cyanColor(), UIColor.greenColor(), UIColor.yellowColor(), UIColor.redColor(), UIColor.magentaColor(), UIColor.blueColor()]
    
    func hexagonIndicesFromColorIndices(maxI maxI: Int, secondI: Int) -> (Int, Int) {
        var pure = 2 * (2 - maxI)
        let mixed = 1 + 2 * ((maxI + secondI) % 3)
        if mixed == 5 && pure == 0 {
            pure = 6
        }
        return (pure, mixed)
    }
    
    func locationOfColor(color: UIColor) -> (CGPoint, CGFloat) {
        var rgb = Array<CGFloat>(count: 3, repeatedValue: 1)
        (rgb[0], rgb[1], rgb[2], _) = color.rgba
        var (maximum, second): (CGFloat, CGFloat) = (-1, -1)
        var (maxI, secondI) = (0, 0)
        for i in 0...2 {
            if rgb[i] > maximum {
                secondI = maxI
                second = maximum
                maxI = i
                maximum = rgb[i]
            }
            else if rgb[i] > second {
                secondI = i
                second = rgb[i]
            }
        }
        let thirdI = (3 - maxI - secondI) % 3
        let third = rgb[thirdI]
        let (pureW, mixedW) = (maximum - second, second - third)
        let whiteW = maximum - third == 1 ? 0 : third/(1 - (maximum - third))
        let (pureI, mixedI) = hexagonIndicesFromColorIndices(maxI: maxI, secondI: secondI)
        let triangle = ColorTriangle(colorVertices: [colorHexagon[pureI], colorHexagon[mixedI], UIColor(white: whiteW, alpha: 1)], spatialVertices:  [geometricHexagon[pureI], geometricHexagon[mixedI], CGPointZero])
        return (triangle.weightedAverageVertex(pureW, mixedW), whiteW)
    }
        
    @IBInspectable
    var sizeMultiplier: CGFloat = 9
    
    var lightness: CGFloat { return dataSource?.lightness ?? 1 }
    
    // Fit the root of unity hexagon into the unit square
    let hexagonInTheSquare: CGFloat = 1
    
    var dynamicSizeMultiplier: CGFloat { return dataSource?.dynamicSizeMultiplier ?? 1 }
    
    var centerX: CGFloat { return dataSource?.centerX ?? 0}
    
    var centerY: CGFloat { return dataSource?.centerY ?? 0}
    
    var size: CGFloat  {
        return sizeMultiplier/10 * dynamicSizeMultiplier * min(bounds.height, bounds.width)/2
    }
    
    let sqrt3over2: CGFloat = sqrt(3.0)/2
    
    lazy var geometricHexagon: [CGPoint] = {
        let piOver3 = M_PI/3
        var _geometricHexagon = Array<CGPoint>(count: 7, repeatedValue: CGPoint())
        for i in 0...6 {
            _geometricHexagon[i] = CGPoint(x: cos(i.double * piOver3), y: sin(i.double * piOver3))
        }
        return _geometricHexagon
    }()
    
    var colorCenter: UIColor {
        return UIColor(white: lightness, alpha: 1)
    }
    
    
    // Returns the ColorChoiceParameters for (centerX, centerY)
    var colorChoice: ColorChoiceParameters {
        if centerX == 0 && centerY == 0 {
            return ColorChoiceParameters()
        }
        let twoPi = M_PI.cg * 2
        var argument = atan2(centerY, centerX)
        argument = argument > 0 ? argument : argument + twoPi
        var triangleNumber = Int(6.cg * argument/twoPi)
        if triangleNumber == 6 {
            triangleNumber = 0
            argument = 0
        }
        //        print("In triangle number \(triangleNumber)")
        let steppedArgument = triangleNumber.cg * twoPi/6
        
        let newX = cos(steppedArgument) * centerX + sin(steppedArgument) * centerY
        let newY = -sin(steppedArgument) * centerX + cos(steppedArgument) * centerY
        //        print("center X and Y: \(centerX, centerY)")
        //        print("new X and Y: \(newX, newY)")
        
        let weightX = newX - newY/sqrt(3.0)
        let weightY = newY / sqrt3over2
        //        print("weight of X and Y: \(weightX, weightY)")
        
        if triangleNumber > 5 || triangleNumber < 0 {
            print("Error: \(triangleNumber)")
        }
        
        var outwardNormalVectors = [CGPoint(x: cos(steppedArgument + twoPi/12), y: sin(steppedArgument + twoPi/12))]
        if steppedArgument == argument {
            outwardNormalVectors += [CGPoint(x: cos(steppedArgument - twoPi/12), y: sin(steppedArgument - twoPi/12))]
        }
        
        return ColorChoiceParameters(color1: colorHexagon[triangleNumber], color2: colorHexagon[triangleNumber + 1],
            color1weight: weightX, color2weight: weightY, outwardNormalVectors: outwardNormalVectors)
    }
    
    var geometricCenter: CGPoint {
        return CGPointZero
    }
    
    var currentTransform: CGAffineTransform {
        let innerTranslation = CGAffineTransformMakeTranslation(-centerX, -centerY)
        let rescale = CGAffineTransformMakeScale(size, size)
        let outerTranslation = CGAffineTransformMakeTranslation(bounds.width/2, bounds.height/2)
        return innerTranslation * rescale * outerTranslation
    }
    
    func colorTriangle(i: Int) -> GradientColorTriangle {
        return GradientColorTriangle(colorVertices: [colorCenter, colorHexagon[i], colorHexagon[i+1]],
            spatialVertices: [geometricCenter, geometricHexagon[i], geometricHexagon[i+1]])
    }
    
    override func drawRect(rect: CGRect) {
//        let start = NSDate()
        let currentContext = UIGraphicsGetCurrentContext()
        CGContextConcatCTM(currentContext, currentTransform)
        //        print("Drawing:")
        //        print("Now centered at: \(colorChoice.colorWithCenterColor(colorCenter))")
        for i in 0...5 {
            let triangle = colorTriangle(i)
            triangle.draw()
        }
//        let time = Int(1000 * NSDate().timeIntervalSinceDate(start))
        //        print("Drawing takes \(time) milliseconds")
    }
    
}
