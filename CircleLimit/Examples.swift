//
//  Examples.swift
//  CircleLimitClassic
//
//  Created by Jeremy Kahn on 9/21/18.
//  Copyright © 2018 Jeremy Kahn. All rights reserved.
//

import Foundation

class Examples {
    
    static let Quad334points =  [HPoint(),
                                 HPoint(0.20280820040075789-0.35127410728572406.i),
                                 HPoint(-0.055795410501151249-0.56326202888535737.i),
                                 HPoint(-0.17415534987450354-0.30164591439257382.i),
                                 HPoint()]

    static let Quad334 = HyperbolicPolygon(Quad334points)
    
    static func getQuad334() -> HDrawable {
        return Quad334.copy()
    }
    
}
