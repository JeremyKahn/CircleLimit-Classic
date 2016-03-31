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
    let height = distanceFromOriginToGeodesicLine(a, b)
    let minSideLength = min(distanceFromOrigin(a), distanceFromOrigin(b))
    return max(height, minSideLength)
}

func distanceFromOriginToGeodesicLine(a: HPoint, _ b: HPoint) -> Double {
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

func distanceOfLineToPoint(start: HPoint, end: HPoint, middle: HPoint) -> Double {
    let M = HyperbolicTransformation(a: middle)
    return distanceFromOriginToGeodesicLine(M.appliedTo(start), M.appliedTo(end))
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

