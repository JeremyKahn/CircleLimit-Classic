//
//  Test.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 4/1/16.
//  Copyright © 2016 Jeremy Kahn. All rights reserved.
//

import UIKit

protocol A { }

protocol B: A { }

func joe(m: A) { }

func sam(m: B) {
    joe(m)
}

func mike(m: [A]) { }

func donald(m: [B]) {
     mike(m)
}

func theDonald(m: [B]) {
    let n: [A] = m.map() { $0 }
    mike(n)
}