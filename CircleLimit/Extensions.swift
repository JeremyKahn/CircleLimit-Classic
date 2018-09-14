//
//  Extensions.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 11/25/15.
//  Copyright © 2015 Jeremy Kahn. All rights reserved.
//

import UIKit

extension Timer {
    

    
}

func timeInMillisecondsSince(_ date: Date) -> Int {
    return (1000 * Date().timeIntervalSince(date)).int
}


func print(_ s: String, when condition: Bool) {
    if condition {
        print(s)
    }
}

protocol NicelyPrinting {
    
    var nice: String {get}
    
}

extension Double: NicelyPrinting {
    
    var nice: String {
        return String(format: "%.3f", self)
    }
    
    var int: Int {
        return Int(self)
    }
    
}

extension CGRect {
    
    var centralSquare: CGRect {
        if width <= height {
            return CGRect(x: minX, y: minY + (height - width)/2, width: width, height: width)
        } else {
            return CGRect(x: minX + (width - height)/2, y: minY, width: height, height: height)
        }
    }
    
}

extension UIView {
    
    // Using a function since `var image` might conflict with an existing variable
    // (like on `UIImageView`)
    func asImage() -> UIImage {
        return asImageWithBounds(bounds)
    }
    
    func asImageWithBounds(_ newBounds: CGRect) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: newBounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
    
    func asSquareImage() -> UIImage {
        return asImageWithBounds(bounds.centralSquare)
    }
}

extension Array {
    
    mutating func insertAtIndices(_ instructions: [(Int, Element)]) {
        let sorted = instructions.sorted() { $0.0 < $1.0  }
        for i in 0..<sorted.count {
            let (j, a) = sorted[i]
            insert(a, at: j + i)
        }
    }
    
    mutating func insertAfterIndices(_ instructions: [(Int, Element)]) {
        let incremented = instructions.map { ($0.0 + 1, $0.1) }
        insertAtIndices(incremented)
    }

}

extension Complex where T : NicelyPrinting {
    var nice: String {
        let plus = im.isSignMinus ? "" : "+"
        return "(\(re.nice)\(plus)\(im.nice).i)"
    }
}
