//
//  GroupGeneration.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 1/6/16.
//  Copyright © 2016 Jeremy Kahn. All rights reserved.
//

import Foundation

// right now we're using _semigroup_ generators
// this generates all elements of the semigroup which can be realized as a path of words in the generators, each meeting the cutoff
func generatedGroup(generators: [HyperbolicTransformation], bigCutoff: Double) -> [HyperbolicTransformation] {
    let bigGroup = LocationTable<HyperbolicTransformation>()
    bigGroup.add(HyperbolicTransformation())
    bigGroup.add(generators)
    var frontier = generators
    while(frontier.count > 0) {
        var newFrontier: [HyperbolicTransformation] = []
        for M in frontier {
            search: for T in generators {
                let X = M.following(T)
                if X.a.abs > bigCutoff  {
                    continue
                }
                //              Check to see if X is already listed in bigGroup
                for U in bigGroup.arrayForNearLocation(X.location) {
                    if U.nearTo(X) {
                        continue search
                    }
                }
                newFrontier.append(X)
                bigGroup.add(X)
                //                println("Found group element number \(++n): \(X.a, X.lambda)")
            }
        }
        frontier = newFrontier
    }
    print("Found \(bigGroup.count) elements in the big group")
    return bigGroup.arrayForm
}

// the hyperbolic length of c in triangle ABC
func lengthFromAngles(A: Double, B: Double, C:Double) -> Double {
    return acosh((cos(A) * cos(B) + cos(C)) / (sin(A) * sin(B)))
}


// produces the standard three (redundant) generators for an orientable pqr triangle group
func pqrGeneratorsAndGuidelines(p: Int, q: Int, r: Int) -> ([HyperbolicTransformation], [HDrawable]) {
    let pi = Double.PI
    let (pp, qq, rr) = (pi / Double(p), pi / Double(q), pi / Double(r))
    assert(pp + qq + rr < pi)
    let b = lengthFromAngles(pp, B: rr, C: qq)
    let c = lengthFromAngles(pp, B: qq, C: rr)
    let A2 = HyperbolicTransformation(rotationInRadians: pp)
    let A = A2.following(A2)
    let TB = HyperbolicTransformation(hyperbolicTranslation: b)
    let TC = HyperbolicTransformation(hyperbolicTranslation: c)
    let RTB = A2.following(TB)
    let RQ = HyperbolicTransformation(rotationInRadians: 2 * qq)
    let RR = HyperbolicTransformation(rotationInRadians: 2 * rr)
    let B = TC.following(RQ).following(TC.inverse())
    let C = RTB.following(RR).following(RTB.inverse())
    let identity = HyperbolicTransformation.identity
    assert(A.toThe(p) == identity)
    assert(B.toThe(q) == identity)
    assert(C.toThe(r) == identity)
    assert(A.following(B).following(C) == identity)
    
    let P = 0 + 0.i
    let Q = TC.appliedTo(P)
    let R = RTB.appliedTo(P)
    
    let guidelines : [HDrawable] = [HyperbolicPolyline([P, Q]), HyperbolicPolyline([Q, R]), HyperbolicPolyline([R, P])]
    
    
    return ([A, B, C], guidelines)
}
