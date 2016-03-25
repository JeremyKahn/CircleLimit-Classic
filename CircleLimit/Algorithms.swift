//
//  Algorithms.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 3/22/16.
//  Copyright © 2016 Jeremy Kahn. All rights reserved.
//

import UIKit

func centerPointAndRadius(points: [HPoint], delta: Double) -> (HPoint, Double) {
    var M = HyperbolicTransformation(a: points[0])
    var movingPoints = points.map() { M.appliedTo($0) }
    var finished = false
    var motion: HyperbolicTransformation
    var radius: Double
    var numberOfIterations = 0
    repeat {
        (motion, finished, radius) = wayToShiftFinishedAndRadius(movingPoints, delta: delta)
        movingPoints = movingPoints.map() { motion.appliedTo($0) }
        M = motion.following(M)
        numberOfIterations += 1
    } while !finished
//    print("Number of iterations: \(numberOfIterations)")
    return (M.inverse().appliedTo(HPoint()), radius)
}

// Right now our goal is not the optimal algorithm
func wayToShiftFinishedAndRadius(points: [HPoint], delta: Double) -> (HyperbolicTransformation, Bool, Double) {
    var maxAbs = 0.0
    var indexMax = 0
    for i in 0..<points.count {
        if points[i].abs > maxAbs {
            maxAbs = points[i].abs
            indexMax = i
        }
    }
    let maxDistance = absToDistance(maxAbs)
    if maxDistance < delta {
        return (HyperbolicTransformation(), true, maxDistance)
    }
    let cutoff = distanceToAbs(maxDistance - delta)
    var closePoints = points.filter() { $0.abs > cutoff }
    let argMax = points[indexMax].arg
    var shiftedArgs = Array<Double>(count: closePoints.count, repeatedValue: 0)
    for i in 0..<closePoints.count {
        var arg = closePoints[i].arg - argMax
        arg = arg < Double.PI ? arg + 2 * Double.PI : arg
        arg = arg > Double.PI ? arg - 2 * Double.PI : arg
        shiftedArgs[i] = arg
    }
    // WTF is the problem with max?
    let maxArg = shiftedArgs.reduce(-Double.PI) { max($0, $1) }
    let minArg = shiftedArgs.reduce(Double.PI) { min($0, $1) }
    if maxArg - minArg < 0.9 * Double.PI {
        let avgArg = argMax + (maxArg + minArg)/2
        let a = Complex<Double>(abs: delta/2, arg: avgArg)
        let M = HyperbolicTransformation(a: a)
        return (M, false, 0)
    }
    return (HyperbolicTransformation(), true, maxDistance)
}

extension Array {
    
//    func maximizingElement<T: Comparable, Element>(startpoint: T, function: Element -> T) -> Element {
//        return self.reduce(startpoint) { max($0, function($1)) }
//    }
    
}