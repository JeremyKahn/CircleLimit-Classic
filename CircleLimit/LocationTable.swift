//
//  LocationTable.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 1/6/16.
//  Copyright © 2016 Jeremy Kahn. All rights reserved.
//

import Foundation

// A class of objects each with a Location, with a way to generate the neighboring Location's
// Any two things that are close to each other must have Location's that are equal or are neighbors
public protocol Locatable {
    
    associatedtype  Location : Hashable
    
    var location : Location {get}
    
    static func neighbors(_: Location) -> [Location]
}

// You can look up a Locatable object in a LocationTable, and it will only search for it in its Location or neighboring Location's
// This works well for a dictionary where the keys are points in a manifold, and there may have been slight errors in the keys introduced by computation
open class LocationTable<T: Locatable> {
    
    var simpleArray : [T] = []
    
    var table : Dictionary<T.Location, Array<T>> = Dictionary()
    
    var count = 0
    
    public init() {}
    
    open func add(_ entries: [T]) {
        for E in entries {
            add(E)
        }
        count += entries.count
    }
    
    open func add(_ E : T) {
        let l = E.location
        if var tempArray = table[l] {
            tempArray.append(E)
            table.updateValue(tempArray, forKey: l)
        } else {
            table.updateValue([E], forKey: l)
        }
        count += 1
    }
    
    open func arrayForNearLocation(_ l: T.Location) -> [T] {
        var array : [T] = []
        for l in  T.neighbors(l) {
            if let newArray = table[l] {
                array += newArray
            }
        }
        return array
    }
    
    open var arrayForm : [T] {
        var array : [T] = []
        for (_, list) in table {
            array += list
        }
        return array
    }
    
}
