//
//  HyperbolicDot.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 7/19/15.
//  Copyright (c) 2015 Jeremy Kahn. All rights reserved.
//

import UIKit

typealias HPoint = Complex64

func absToDistance(a: Double) -> Double {
    return log((1 + a)/(1 - a))
}

func distanceToAbs(d: Double) -> Double {
    let e = exp(d)
    return (e-1)/(e+1)
}

func distanceFromOrigin(z: HPoint) -> Double {
    return absToDistance(z.abs)
}

func distanceBetween(z: HPoint,w: HPoint) -> Double {
    let M = HyperbolicTransformation(a: z)
    return distanceFromOrigin(M.appliedTo(w))
    
}

//extension HPoint {
//
//    func hyperbolicDistanceToOrigin() -> Double {
//        return distanceFromOrigin(self)
//    }
//
//}

extension Double {
    var degrees:  Int {
        return Int(360 * self/(2 * M_PI))
    }
}

func distanceFromOriginToGeodesicArc(a: HPoint, b: HPoint) -> Double {
    var (aa, bb) = (a, b)
    if (bb/aa).arg < 0 {
        swap(&aa, &bb)   }
    var (c, r, _, _,_) = geodesicArcCenterRadiusStartEnd(aa, b: bb)
    if (c/aa).arg < 0 {
        print("Anomoly aa: \(aa.arg.degrees, bb.arg.degrees, c.arg.degrees, (c/aa).arg.degrees)")
        return distanceFromOrigin(aa)
    }
    else if (bb/c).arg < 0 {
        print("Anomoly bb: \(aa.arg.degrees, bb.arg.degrees, c.arg.degrees, (bb/c).arg.degrees)")
        return distanceFromOrigin(bb)
    }
    else {
        c.abs = c.abs - r
        return distanceFromOrigin(c)
    }
}

func distanceOfArcToPoint(start: HPoint, end: HPoint, middle: HPoint) -> Double {
    let M = HyperbolicTransformation(a: middle)
    return distanceFromOriginToGeodesicArc(M.appliedTo(start), b: M.appliedTo(end))
}



func geodesicArcCenterRadiusStartEnd(a: HPoint, b: HPoint) -> (Complex64, Double, Double, Double, Bool) {
    let M = HyperbolicTransformation(a: a)
    let M_inverse = M.inverse()
    let bPrime = M.appliedTo(b)
    var (u, v) = (-bPrime/bPrime.abs, bPrime/bPrime.abs)
    (u, v) = (M_inverse.appliedTo(u), M_inverse.appliedTo(v))
    var theta = 0.5 * (v/u).arg
    var (aa, bb) = (a, b)
    var swapped = false
    if theta < 0 {
        swap(&u, &v)
        swap(&aa, &bb)
        theta = -theta
        swapped = true
    }
    let radius = tan(theta)
    let center = Complex(abs: 1/cos(theta), arg: u.arg + theta)
    let start = (aa-center).arg
    let end = (bb-center).arg
    return (center, radius, start, end, swapped)
}

func approximatingCubicBezierToCircularArc(center: Complex64, radius: Double, start: Double, end: Double, swapped: Bool) -> (Complex64, Complex64) {
    var theta = (end - start).abs
    if theta > Double.PI {
        theta = 2 * Double.PI - theta
    }
    let h = magicNumber(theta)
    let startPoint = center + radius * exp(start.i)
    let startControl = startPoint + radius * h * exp(start.i - Double.PI.i/2)
    let endPoint = center + radius * exp(end.i)
    let endControl = endPoint + radius * h * exp(end.i + Double.PI.i/2)
    return swapped ? (endControl, startControl) : (startControl, endControl)
}

func controlPointsForApproximatingCubicBezierToGeodesic(a: HPoint, b: HPoint) -> (HPoint, HPoint) {
    let (center, radius, start, end, swapped) = geodesicArcCenterRadiusStartEnd(a, b: b)
    let (startControl, endControl) = approximatingCubicBezierToCircularArc(center, radius: radius, start: start, end: end, swapped: swapped)
    return (startControl, endControl)
}

func magicNumber(theta: Double) -> Double {
    return (4.0/3.0) * tan(theta / 4)
}

func pointForComplex(z: Complex64) -> CGPoint {
    return CGPoint(x: z.re, y: z.im)
}

protocol HDrawable : class {
    
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
    
    func drawWithMask(mask: HyperbolicTransformation) {
        self.mask = mask
        draw()
        
//        let centerDot = HyperbolicDot(center: centerPoint, radius: radius)
//        centerDot.color = UIColor(colorLiteralRed: 1, green: 0, blue: 0, alpha: 0.5)
//        centerDot.drawWithMask(mask)
    }
    
    func drawWithMaskAndAction(A: Action) {
        if useColorTable {
            color = colorTable[A.action.mapping[baseNumber]!]!
        }
        drawWithMask(A.motion)
    }
    
}

class HyperbolicPolygon: HyperbolicPolyline {
    
    var borderColor = UIColor.blackColor()
    
    // Right now this makes the border by calling super
    override func draw() {
        let points = maskedPointsToDraw
        color.setFill()
        //        print("Fill color: \(color)")
        let totalPath = UIBezierPath()
        totalPath.moveToPoint(pointForComplex(points[0]))
        for i in 0..<(points.count - 1) {
            let (startControl, endControl) = controlPointsForApproximatingCubicBezierToGeodesic(points[i], b: points[i+1])
            totalPath.addCurveToPoint(pointForComplex(points[i+1]), controlPoint1: pointForComplex(startControl), controlPoint2: pointForComplex(endControl))
        }
        totalPath.lineCapStyle = CGLineCap.Round
        totalPath.fill()
        color = borderColor
        super.draw()
        
    }
    
}

class HyperbolicPolyline : HDrawable {
    
    var centerPoint = HPoint()
    
    var radius: Double = 0
    
    var points: [Complex64] = []
    
    var mask: HyperbolicTransformation = HyperbolicTransformation()
    
    static let stepsPerNaturalExponentOfScale: Double = 3
    
    var scaleOfMask : Int {
        let _scaleOfMask = min(Int(0.00001 - HyperbolicPolyline.stepsPerNaturalExponentOfScale * log(1-mask.a.abs)), HyperbolicPolyline.maxScaleIndex)
        //        print("Scale of mask: \(_scaleOfMask)")
        return _scaleOfMask
    }
    
    var activeSubsequence : [Int] {
        let subsequenceIndices = subsequenceTable[scaleOfMask]
        if subsequenceIndices == [] {
            return [Int](0..<points.count)
        } else {
            return subsequenceTable[scaleOfMask]
        }
    }
    
    var maskedPointsToDraw: [HPoint] {
        //        print("Drawing a curve with subsequence: \(activeSubsequence)")
        var maskedPoints = subsequenceOf(points, withIndices: activeSubsequence)
        for i in 0..<maskedPoints.count {
            maskedPoints[i] = mask.appliedTo(maskedPoints[i])
        }
        return maskedPoints
    }
    
    var intrinsicLineWidth : Double {
        return size
    }
    
    var size = 0.01
    
    var color: UIColor = UIColor.purpleColor()
    
    var colorTable: ColorTable = [1: UIColor.blueColor(), 2: UIColor.greenColor(), 3: UIColor.redColor(), 4: UIColor.yellowColor()]
    
    var baseNumber = ColorNumber.baseNumber
    
    var useColorTable = true
    
    init(_ p: Complex64) {
        points = [p]
        update()
    }
    
    init(_ pp: [Complex64]) {
        points = pp
        update()
        complete()
    }
    
    init(_ a: HyperbolicPolyline) {
        self.points = a.points
        self.color = a.color
        self.size  = a.size
        update()
        complete()
    }
    
    func addPoint(p: Complex64) {
        assert(p.abs <= 1)
        points.append(p)
        update()
    }
    
    func update() {
        (centerPoint, radius) = centerPointAndRadius(points, delta: 0.1)
    }
    
    var maxRadius = 1000.0
    
    // MARK - Building the Subsequence Table
    
    func complete() {
        buildSubsequenceTable()
    }
    
    static var initialDistanceToleranceMultiplier = 0.2
    
    var initialDistanceTolerance : Double {
        return size * HyperbolicPolyline.initialDistanceToleranceMultiplier
    }
    
    var distanceTolerance : Double {
        return initialDistanceTolerance * exp(Double(scaleIndex)/HyperbolicPolyline.stepsPerNaturalExponentOfScale)
    }
    
    static var maximumShrinkageFactor: Double = 1
    
    static var maxScaleIndex = Int(log(maximumShrinkageFactor) * stepsPerNaturalExponentOfScale)
    
    var scaleIndex : Int = 0
    
    var subsequenceTable : [[Int]] = [[Int]](count: maxScaleIndex + 1, repeatedValue: [])
    
    struct radialDistanceCache {
        var sinTheta : Double
        var cosTheta : Double
        var sinhDistanceToOrigin : Double
        var coshDistanceToOrigin : Double
        
        init(z : Complex64) {
            let a = z.abs
            if a == 0 {
                sinTheta = 0.0
                cosTheta = 1.0
                sinhDistanceToOrigin = 0.0
                coshDistanceToOrigin = 1.0
            }
            else {
                sinTheta = z.im / a
                cosTheta = z.re / a
                sinhDistanceToOrigin = 2 * a / ( 1 - a * a )
                coshDistanceToOrigin = (1 + a * a)/(1 - a * a)
            }
        }
        
        func sinAngleTo(y: radialDistanceCache) -> Double {
            return sinTheta * y.cosTheta - cosTheta * y.sinTheta
        }
        
        func cosAngleTo(y: radialDistanceCache) -> Double {
            return cosTheta * y.cosTheta + sinTheta * y.sinTheta
        }
        
        func coshDistanceTo(y: radialDistanceCache) -> Double {
            let cosDeltaTheta = cosAngleTo(y)
            return coshDistanceToOrigin * y.coshDistanceToOrigin - sinhDistanceToOrigin * y.sinhDistanceToOrigin * cosDeltaTheta
        }
        
        func distanceFromRadialLineTo(y: radialDistanceCache) -> Double {
            let sinDeltaTheta = sinAngleTo(y)
            let sinhAltitude = y.sinhDistanceToOrigin * sinDeltaTheta.abs
            let coshDistanceToY = coshDistanceTo(y)
            let sinhDistanceToY = sqrt(coshDistanceToY * coshDistanceToY - 1)
            let minSinhAdjancentSides = min(y.sinhDistanceToOrigin, sinhDistanceToY)
            let sinhDistanceFromRadialLineSegmentToY = max(sinhAltitude, minSinhAdjancentSides)
            return asinh(sinhDistanceFromRadialLineSegmentToY)
        }
    }
    
    
    
    var canReplaceWithStraightLineCache : [Bool] = []
    
    // this whole trick relies on the particular implemetation of bestSequenceTo
    func canReplaceWithStraightLine(i: Int, _ j: Int) -> Bool {
        if canReplaceWithStraightLineCache.count == j {
            return canReplaceWithStraightLineCache[i]
        }
        else {
            let M = HyperbolicTransformation(a: points[j])
            var normalizedPoints : [radialDistanceCache] = []
            for k in 0..<j {
                normalizedPoints.append(radialDistanceCache(z: M.appliedTo(points[k])))
            }
            // the next line is an idiom to make the array the correct size
            canReplaceWithStraightLineCache = [Bool](count: j, repeatedValue: true)
            for k in 0..<j {
                var canReplaceWithStraightLine = true
                for l in (k+1)..<j {
                    canReplaceWithStraightLine = canReplaceWithStraightLine && normalizedPoints[k].distanceFromRadialLineTo(normalizedPoints[l]) < distanceTolerance
                }
                canReplaceWithStraightLineCache[k] = canReplaceWithStraightLine
            }
            return canReplaceWithStraightLineCache[i]
        }
    }
    
    func buildSubsequenceTable() {
        print(points)
        for i in 0...HyperbolicPolyline.maxScaleIndex {
            scaleIndex = i
            subsequenceTable[i] = simplifyingSubsequenceIndices()
        }
    }
    
    func simplifyingSubsequenceIndices() -> [Int] {
        print("distanceTolerance: \(distanceTolerance)")
        return bestSequenceTo(points.count - 1, toMinimizeSumOf: { (x: Int, y: Int) -> Int in
            return 1
            }, withConstraint: canReplaceWithStraightLine)
    }
    
    
    // MARK - Drawing
    
    // For the ambitious: make this a filled region between two circular arcs
    func geodesicArc(a: HPoint, _ b: HPoint) -> UIBezierPath {
        assert(a.abs <= 1 && b.abs <= 1)
        //        println("Drawing geodesic arc from \(a) to \(b)")
        let (center, radius, start, end,_) = geodesicArcCenterRadiusStartEnd(a, b: b)//
        //        println("Data: \(center, radius, start, end)")
        var path : UIBezierPath
        if radius > maxRadius || radius.isNaN {
            path = UIBezierPath()
            path.moveToPoint(CGPoint(x: a.re, y: a.im))
            path.addLineToPoint(CGPoint(x: b.re, y: b.im))
        } else {
            path = UIBezierPath(arcCenter: CGPoint(x: center.re, y: center.im),
                                radius: CGFloat(radius),
                                startAngle: CGFloat(start),
                                endAngle: CGFloat(end),
                                clockwise: false)
        }
        path.lineWidth = suitableLineWidth(a, b)
        return path
    }
    
    func suitableLineWidth(a: HPoint, _ b: HPoint) -> CGFloat {
        let t = ((a + b)/2).abs
        return CGFloat(intrinsicLineWidth * (1 - t * t))
    }
    
    func draw() {
        //        println("Drawing path for points \(points)")
        color.set()
        let points = maskedPointsToDraw
        if points.count == 1 {
            let dot = HyperbolicDot(center: points[0], radius: size)
            dot.draw()
        }
        for i in 0..<(points.count - 1) {
            let path = geodesicArc(points[i], points[i+1])
            path.lineCapStyle = CGLineCap.Round
            path.stroke()
        }
    }
    
    func transformedBy(M: HyperbolicTransformation) -> HDrawable {
        let new = HyperbolicPolyline(self)
        new.transformBy(M)
        return new
    }
    
    func transformBy(M: HyperbolicTransformation) {
        for i in 0...(points.count-1) {
            points[i] = M.appliedTo(points[i])
            assert(points[i].abs <= 1)
        }
    }
}


class HyperbolicDot : HDrawable {
    
    var centerPoint: HPoint {
        return center
    }
    
    var center: Complex64 = Complex64()
    
    var mask: HyperbolicTransformation = HyperbolicTransformation()
    
    var radius : Double {
        return size
    }
    
    var size = 0.03
    
    var color: UIColor = UIColor.purpleColor()
    
    var colorTable: ColorTable = [1: UIColor.blueColor(), 2: UIColor.greenColor(), 3: UIColor.redColor(), 4: UIColor.yellowColor()]
    
    var baseNumber = ColorNumber.baseNumber
    
    var useColorTable = true
    
    init(dot: HyperbolicDot) {
        self.center = dot.center
        self.size  = dot.size
        self.color = dot.color
    }
    
    init(center: Complex64, radius: Double) {
        self.center = center
        self.size = radius
    }
    
    init(center: Complex64) {
        self.center = center
    }
    
    func drawWithMask(mask: HyperbolicTransformation) {
        let dot = self.transformedBy(mask)
        dot.draw()
    }
    
    func draw() {
        let (x, y, r) = poincareDiskCenterRadius()
        let euclDotCenter = CGPoint(x: x, y: y)
        let c = circlePath(euclDotCenter, radius: CGFloat(r))
        color.set()
        c.fill()
    }
    
    func poincareDiskCenterRadius() -> (centerX: Double, centerY: Double, radius: Double) {
        let dotR = center.abs
        let E = (1 + dotR)/(1 - dotR)
        let M = exp(radius)
        let Q0 = M * E
        let tPlus = (Q0 - 1)/(Q0 + 1)
        let Q1 = E / M
        let tMinus = (Q1 - 1)/(Q1 + 1)
        let euclCenterAbs = (tPlus + tMinus)/2
        let euclR = (tPlus - tMinus)/2
        //        println("dotR: \(dotR) E: \(E) M: \(M) Q0: \(Q0) Q1: \(Q1) tPlus: \(tPlus) tMinus: \(tMinus)")
        let complexEuclCenter = Complex(abs: euclCenterAbs, arg: center.arg)
        return(complexEuclCenter.re, complexEuclCenter.im, euclR)
    }
    
    func transformBy(M: HyperbolicTransformation) {
        center = M.appliedTo(center)
    }
    
    func transformedBy(M: HyperbolicTransformation) -> HDrawable {
        let dot = HyperbolicDot(dot: self)
        dot.transformBy(M)
        return dot
    }
}

