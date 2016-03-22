//
//  Algorithms.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 3/22/16.
//  Copyright © 2016 Jeremy Kahn. All rights reserved.
//

import UIKit

func centerPoint(points: [HPoint], delta: Double) -> HPoint {
    var M = HyperbolicTransformation(a: points[0])
    var movingPoints = points.map() { M.appliedTo($0) }
    var finished = false
    var motion: HyperbolicTransformation
    repeat {
        (motion, finished) = wayToShiftAndFinished(movingPoints, delta: delta)
        movingPoints = movingPoints.map() { motion.appliedTo($0) }
        M = motion.following(M)
    } while !finished
    return M.inverse().appliedTo(HPoint())
}

// Right now our goal is not the optimal algorithm
func wayToShiftAndFinished(points: [HPoint], delta: Double) -> (HyperbolicTransformation, Bool) {
    var max = 0.0
    var indexMax = 0
    for i in 0..<points.count {
        if points[i].abs > max {
            max = points[i].abs
            indexMax = i
        }
    }
    if max < delta {
        return (HyperbolicTransformation(), true)
    }
    let cutoff = max - 2 * delta/(1 - max * max)
    var closePoints = points.filter() { $0.abs > cutoff }
    let argMax = points[indexMax].arg
    var shiftedArgs = Array<Double>(count: closePoints.count, repeatedValue: 0)
    for i in closePoints.count {
        var arg = closePoints[i].arg - argMax
        arg = arg < Double.PI ? arg + 2 * Double.PI : arg
        arg = arg > Double.PI ? arg - 2 * Double.PI : arg
        shiftedArgs[i] = arg
    }
    let minArg = shiftedArgs.reduce(-Double.PI) { max($0, $1) }
    let maxArg = shiftedArgs.reduce(Double.PI) { min($0, $1) }
    if maxArg - minArg < Double.PI {
        let avgArg = (maxArg + minArg)/2
        let a = Complex<Double>(abs: delta/2, arg: avgArg)
        let M = HyperbolicTransformation(a: a)
        return (M, false)
    }
    return (HyperbolicTransformation(), true)
}

extension Array {
    
//    func maximizingElement<T: Comparable, Element>(startpoint: T, function: Element -> T) -> Element {
//        return self.reduce(startpoint) { max($0, function($1)) }
//    }
    
}