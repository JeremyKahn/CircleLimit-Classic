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

func timeInMillisecondsSince(date: NSDate) -> Int {
    return (1000 * NSDate().timeIntervalSinceDate(date)).int
}

extension Double {
    
    func nice() -> String {
        return String(format: "%.2f", self)
    }
    
    var int: Int {
        return Int(self)
    }
}

func asinh(y: Double) -> Double {
    return log(y + sqrt(y * y + 1))
}