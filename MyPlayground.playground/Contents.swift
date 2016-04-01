//: Playground - noun: a place where people can play

protocol A {}

protocol B {}

class C: A, B {}

var x: Int = 0

func hello(_: A) {
    x = 1
}

hello(C())

x

func hello(_: B) {
    x = 2
}

hello(C())





