//: Playground - noun: a place where people can play

import UIKit

protocol A {
    
    func show()
    
}

extension A {
    
    func show() {
        print("In A")
    }
    
}

class B: A {
    
    func show() {
        print("In B")
    }
    
}

var b: A = B()

b.show()

b.show()

b.show()

4/3 * tan(M_PI/8)


