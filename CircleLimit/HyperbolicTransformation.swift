//
//  HyperbolicTransformation.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 1/6/16.
//  Copyright © 2016 Jeremy Kahn. All rights reserved.
//

import Foundation

// representation is z -> lambda * (z - a)/(1 - a.bar * z)
struct HyperbolicTransformation : CustomStringConvertible, Locatable, Codable {
    
    var a: Complex64 = Complex64()
    
    var lambda: Complex64 = Complex64(1.0, 0.0)
    
    // MARK: Initializers
    
    init(a: Complex64, lambda: Complex64) {
        var l = lambda
        l.abs = 1.0
        self.a = a
        self.lambda = l
    }
    
    init(a: Complex64) {
        self.a = a
    }
    
    init(a: HPoint) {
        self.a = a.z
    }
    
    init() {
        
    }
    
    init(rotationInTurns: Double) {
        let x = rotationInTurns * Double.PI * 2
        lambda = exp(x.i)
    }
    
    init(rotationInRadians: Double) {
        lambda = exp(rotationInRadians.i)
    }
    
    init(hyperbolicTranslation: Double) {
        a = -sinh(hyperbolicTranslation/2)/cosh(hyperbolicTranslation/2) + 0.i
    }
    
    // MARK: Computed Properties
    var abs: Double {
        return a.abs
    }
    
    var distance: Double {
        return absToDistance(abs)
    }
    
    // MARK: Group operations
    static let identity = HyperbolicTransformation()
    
    func appliedTo(_ z: Complex64) -> Complex64 {
        var w = (z - a) / (1 - a.conj * z)
        w *= lambda
        return w
    }
    
    func appliedTo(_ z: HPoint) -> HPoint {
        return HPoint(appliedTo(z.z))
    }
    
    var inverse: HyperbolicTransformation
        { return HyperbolicTransformation(a: -self.a * self.lambda, lambda: self.lambda.conj) }
    
    var fixedPoint: HPoint? {
        guard lambda != 1 + 0.i else {return nil}
        if a == 0  { return HPoint() } // Maybe we should return  -a * lambda * (1 - lambda) for small a
        let num = 4 * a.abs * a.abs * lambda
        let denom = (1 - lambda) * (1 - lambda)
        let thingInside = 1 + num/denom
        // we should have thingInside.im == 0
        guard thingInside.re > 0 else {return nil}
        let mult = (1 - lambda)/(2 * a.conj)
        let fp = mult * (1 - sqrt(thingInside.re))
        return HPoint(fp)
    }
    
//    func inverse() -> HyperbolicTransformation {
//        return HyperbolicTransformation(a: -a * lambda, lambda: lambda.conj)
//    }
    
    func following(_ B: HyperbolicTransformation) -> HyperbolicTransformation {
        let tZ = B.inverse.appliedTo(a)
        var u = Complex64(1.0, 0.0) + a.conj * B.a * B.lambda
        u = u.conj / u
        u *= lambda * B.lambda
        return  HyperbolicTransformation(a: tZ, lambda: u)
    }
    
    func toThe(_ n: Int) -> HyperbolicTransformation {
        assert(n >= 0)
        var M = HyperbolicTransformation()
        for _ in 0..<n {
            M = M.following(self)
        }
        return M
    }
    
    
    // MARK: Location, comparison, and description
    typealias Location = Int
    
    // Doesn't really matter how it converts the Double to an Int
    var location: Location {
        return Int(1/(1-a.abs)) // should always be at least 1
    }
    
    static func neighbors(_ l: Location) -> [Location] {
        return [l-1, l, l+1]
    }
    
    static var tolerance = 0.001
    
    func closeToIdentity() -> Bool {
        return closeToIdentity(HyperbolicTransformation.tolerance)
    }
    
    func closeToIdentity(_ tolerance: Double) -> Bool {
        return a.abs < tolerance && (lambda - 1).abs < tolerance
    }
    
    func nearTo(_ B:HyperbolicTransformation) -> Bool {
        return nearTo(B, tolerance: HyperbolicTransformation.tolerance)
    }
    
    func nearTo(_ B:HyperbolicTransformation, tolerance: Double) -> Bool {
        let E = self.following(B.inverse)
        return E.closeToIdentity(tolerance)
    }
    
    var description : String {
        return "\(lambda.nice, a.nice)"
    }
    
    // MARK: Random generation
    
    static func randomDouble() -> Double {
        let n = 1000000
        return Double(Int(arc4random()) % n) / Double(n)
    }
    
    static func randomHyperbolicTransformation() -> HyperbolicTransformation {
        let a = (randomDouble() + randomDouble().i)/sqrt(2)
        let lambda = exp((randomDouble() * Double.PI * 2).i)
        return HyperbolicTransformation(a: a, lambda: lambda)
    }
    
}


func == (left: HyperbolicTransformation, right: HyperbolicTransformation) -> Bool {
    return left.nearTo(right)
}

func != (left: HyperbolicTransformation, right: HyperbolicTransformation) -> Bool {
    return !(left == right)
}

