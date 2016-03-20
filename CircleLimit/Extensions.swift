//
//  Extensions.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 11/25/15.
//  Copyright © 2015 Jeremy Kahn. All rights reserved.
//

import UIKit

extension NSTimer {
    

    
}

extension Double {
    
    func nice() -> String {
        return String(format: "%.2f", self)
    }
}

func asinh(y: Double) -> Double {
    return log(y + sqrt(y * y + 1))
}