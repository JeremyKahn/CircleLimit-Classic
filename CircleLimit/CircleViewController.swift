//
//  CircleViewController.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 7/19/15.
//  Copyright (c) 2015 Jeremy Kahn. All rights reserved.
//

import UIKit

enum TouchType {
    case Began
    case Moved
    case Ended
}


class CircleViewController: UIViewController, PoincareViewDataSource, UIGestureRecognizerDelegate {
    
    var trivialGroup = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("CircleViewController loaded")
        var generators: [HyperbolicTransformation] = []
        var guidelines: [HDrawable] = []
        var twistedGenerators: [Action] = []
        if !trivialGroup {
            (generators, guidelines) = pqrGeneratorsAndGuidelines(3, q: 3, r: 4)
            for object in guidelines {
                object.size = 0.005
                object.color = UIColor.grayColor()
                object.useColorTable = false
            }
            
            let (A, B, C) = (generators[0], generators[1], generators[2])
            let a = ColorNumberPermutation(mapping: [1: 2, 2: 3, 3: 1, 4: 4])
            let b = ColorNumberPermutation(mapping: [1: 1, 2: 3, 3: 4, 4: 2])
            let c = ColorNumberPermutation(mapping: [1: 2, 2: 1, 3: 4, 4: 3])
            assert(a.following(b).following(c) == ColorNumberPermutation())
            twistedGenerators = [Action(M: A, P: a), Action(M: B, P: b), Action(M: C, P: c)]
        }
        self.guidelines = guidelines
        let bigGroup = generatedGroup(twistedGenerators, bigCutoff: 0.998)
        for mode in cutoff.keys {
            group[mode] = selectElements(bigGroup, cutoff: bigCutoff[mode]!)        }
    }
    
    func selectElements(group: [Action], cutoff: Double) -> [Action] {
        let a = group.filter { (M: Action) in M.motion.a.abs < cutoff }
        print("Selected \(a.count) elements with cutoff \(cutoff)")
        return a
    }
    
    var guidelines : [HDrawable] = []
    
    var drawGuidelines = true
    
    var drawing = true
    
    var drawObjects: [HDrawable] = []
    
    var undoneObjects: [HDrawable] = []
    
    var mode : Mode = .Usual
    
    var group = [Mode : [Action]]()
    
    // Change these values to determine the size of the various groups
    var cutoff : [ Mode : Double ] = [.Usual : 0.99, .Moving : 0.8, .Drawing : 0.8, .Searching: 0.95]
    
    var bigCutoff: [Mode: Double] = [.Usual: 0.998, .Moving: 0.99, .Drawing: 0.99, .Searching: 0.95]
    
    var cutoffDistance: Double {
        let scaleCutoff = Double(2/multiplier)
        let cutoffAbs = cutoff[mode]!
        let lesserAbs = min(scaleCutoff, cutoffAbs)
        return absToDistance(lesserAbs)
    }
    
    enum Mode {
        case Usual
        case Drawing
        case Moving
        case Searching
    }
    
    var formingPolygon = false
    
    var mask: HyperbolicTransformation = HyperbolicTransformation()
    
    var multiplier = CGFloat(1.0)
    
    var objectsToDraw: [HDrawable] {
        var fullDrawObjects = drawGuidelines ? guidelines : []
        fullDrawObjects += drawObjects
        if newCurve != nil {
            fullDrawObjects.append(newCurve!)
        }
        return fullDrawObjects
    }
    
    var groupToDraw: [Action] {
        var g : [Action] = []
        
        let startMakeGroup = NSDate()
        g = group[mode]!
        g = g.map() { Action(M: mask.following($0.motion), P: $0.action) }
        let makeGroupTime = timeInMillisecondsSince(startMakeGroup)
        print("Size of group: \(g.count))")
        print("Time to make the group: \(makeGroupTime)")

        // Experimental prefiltering
        let objects = objectsToDraw
        let centers = objects.map() {$0.centerPoint}
        let maxRadius = objects.reduce(0) { max($0, $1.radius) }
        let (center, radius) = centerPointAndRadius(centers, delta: 0.1)
        let totalRadius = radius + maxRadius
        
        let startFilter = NSDate()
        let cutoffAbs = distanceToAbs(cutoffDistance + totalRadius)
        g = g.filter() { $0.motion.appliedTo(center).abs < cutoffAbs }
        let prefilterTime = NSDate().timeIntervalSinceDate(startFilter) * 1000
        print("Prefilter time: \(Int(prefilterTime)) milliseconds")
        
        return g
    }
    
    var toPoincare : CGAffineTransform {
        return CGAffineTransformInvert(poincareView.tf)
    }
    
    var scale: CGFloat {
        return poincareView.scale
    }
    
    // MARK: Picture control
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?) {
        if motion == .MotionShake {
            clearPicture()
        }
    }
    
    
    func clearPicture() {
        print("In clearPicture with \(guidelines.count) guidelines")
        drawObjects = []
        newCurve = nil
        poincareView.setNeedsDisplay()
    }
    
    
    // MARK: Adding points and drawing
    let drawRadius = 0.99
    
    func hPoint(rawLocation: CGPoint) -> HPoint? {
        var thing = rawLocation
        thing = CGPointApplyAffineTransform(thing,toPoincare)
        let (x, y) = (Double(thing.x), Double(thing.y))
        //        print("New point: " + x.nice() + " " + y.nice())
        if x * x + y * y < drawRadius * drawRadius {
            let z = HPoint(Double(thing.x), Double(thing.y))
            return mask.inverse().appliedTo(z)
        }
        else {
            return nil
        }
    }
    
    
    
    func makeDot(rawLocation: CGPoint) {
        if let p = hPoint(rawLocation) {
            drawObjects.append(HyperbolicDot(center: p))
            poincareView.setNeedsDisplay()
        }
    }
    
    var touchPoints : [CGPoint] = []
    
    var newCurve : HyperbolicPolygon?
    
    //    var newPolygon: HyperbolicPolygon
    
    
    //    func addPoint(touches: Set<NSObject>, _ state: TouchType) {
    //        if (!drawing) { return }
    //        if let touch = touches.first as? UITouch {
    //            if let z = hPoint(touch.locationInView(poincareView)) {
    //                switch state {
    //                case .Began:
    //                    newCurve = HyperbolicPolyline(z)
    //                case .Moved:
    //                    newCurve?.addPoint(z)
    //                    poincareView.setNeedsDisplay()
    //                case .Ended:
    //                    if newCurve != nil {
    //                        newCurve!.addPoint(z)
    //                        poincareView.setNeedsDisplay()
    //                        performSelectorInBackground("returnToUsualMode", withObject: nil)
    //                    }
    //                }
    //            }
    //        }
    //    }
    //
    
    
    func returnToUsualMode() {
        guard drawing else { return }
        guard let curve = newCurve else { return }
        curve.complete()
        print("Appending a curve with \(curve.points.count) points")
        drawObjects.append(curve)
        newCurve = nil
        mode = .Usual
        undoneObjects = []
        poincareView.setNeedsDisplay()
    }
    
    var printingTouches = false
    
    //    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
    //        if printingTouches { print("touchesBegan") }
    //        super.touchesBegan(touches, withEvent: event)
    //        mode = .Drawing
    //        addPoint(touches, TouchType.Began)
    //    }
    //
    //    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
    //        if printingTouches { print("touchesMoved") }
    //        super.touchesMoved(touches, withEvent: event)
    //        addPoint(touches, TouchType.Moved)
    //    }
    //
    //    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
    //        if printingTouches { print("touchesEnded") }
    //        super.touchesEnded(touches, withEvent: event)
    //        addPoint(touches, TouchType.Ended)
    //    }
    
    // MARK: Gesture recognition
    
    @IBOutlet var panRecognizer: UIPanGestureRecognizer!
    
    @IBOutlet var pinchRecognizer: UIPinchGestureRecognizer!
    
    @IBOutlet var undoRecognizer: UISwipeGestureRecognizer!
    
    @IBOutlet var redoRecognizer: UISwipeGestureRecognizer!
    
    //    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOfGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    //        return otherGestureRecognizer === swipeRecognizer
    //    }
    
    //    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailByGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    //        return gestureRecognizer === swipeRecognizer
    //    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer == undoRecognizer || gestureRecognizer == redoRecognizer
    }
    
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOfGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        var answer = false
        answer = answer || gestureRecognizer == singleTapRecognizer && otherGestureRecognizer == doubleTapRecognizer
        answer = answer || (gestureRecognizer == pinchRecognizer || gestureRecognizer == panRecognizer) && (otherGestureRecognizer == singleTapRecognizer || otherGestureRecognizer == doubleTapRecognizer)
        return answer
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailByGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer == pinchRecognizer && (gestureRecognizer == undoRecognizer || gestureRecognizer == redoRecognizer)
    }
    
    @IBAction func redo(sender: UISwipeGestureRecognizer) {
        print("redo")
        mode = .Usual
        guard undoneObjects.count > 0 else {return}
        drawObjects.append(undoneObjects.removeLast())
        poincareView.setNeedsDisplay()
    }
    
    
    @IBAction func undo(sender: UISwipeGestureRecognizer) {
        print("undo!")
        mode = .Usual
        guard drawObjects.count > 0 else { return }
        undoneObjects.append(drawObjects.removeLast())
        poincareView.setNeedsDisplay()
    }
    
    
    
    @IBAction func simplePan(gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .Began:
            drawing = false
            //            newCurve = nil
            mode = mode == .Drawing ? .Drawing :  .Moving
        case .Changed:
            let translation = gesture.translationInView(poincareView)
            //            println("Raw translation: \(translation.x, translation.y)")
            gesture.setTranslation(CGPointZero, inView: poincareView)
            var a = Complex64(Double(translation.x/scale), Double(translation.y/scale))
            a = a/(a.abs+1) // This prevents bad transformations
            let M = HyperbolicTransformation(a: -a)
            //            println("Moebius translation: \(M)")
            mask = M.following(mask)
            recomputeMask()
            poincareView.setNeedsDisplay()
        case .Ended:
            mode = mode == .Drawing ? .Drawing : .Usual
            recomputeMask()
            poincareView.setNeedsDisplay()
            drawing = true
        default: break
        }
    }
    
    @IBOutlet var singleTapRecognizer: UITapGestureRecognizer!
    
    @IBOutlet var doubleTapRecognizer: UITapGestureRecognizer!
    
    @IBAction func singleTap(sender: UITapGestureRecognizer) {
        //        print("tapped")
        let z = hPoint(sender.locationInView(poincareView))
        if z == nil {
            print("toggling guidelines")
            drawGuidelines = !drawGuidelines
            mode = .Usual
        } else {
            if newCurve == nil {
                newCurve = HyperbolicPolygon(z!)
            } else {
                newCurve!.addPoint(z!)
            }
            formingPolygon = true
            mode = .Drawing
        }
        poincareView.setNeedsDisplay()
    }
    
    
    @IBAction func doubleTap(sender: UITapGestureRecognizer) {
        if newCurve != nil {
            newCurve!.addPoint(newCurve!.points[0])
        }
        formingPolygon = false
        returnToUsualMode()
    }
    
    func recomputeMask() {
        guard !formingPolygon else { return }
        var bestA = mask.a.abs
        var bestMask = mask
        //        println("Trying to improve : \(bestA)")
        var foundBetter = false
        let I = ColorNumberPermutation()
        repeat {
            foundBetter = false
            for E in group[Mode.Searching]! {
                if E.action != I { continue }
                let newMask = mask.following(E.motion.inverse())  // Let's try it
                if  newMask.a.abs < bestA {
                    foundBetter = true
                    bestA = newMask.a.abs
                    bestMask = newMask
                    //                    println("Found \(bestA)")
                }
            }
        } while (foundBetter)
        mask = bestMask
    }
    
    @IBAction func zoom(gesture: UIPinchGestureRecognizer) {
        //        println("Zooming")
        switch gesture.state {
        case .Began:
            mode = Mode.Moving
            drawing = false
            //            newCurve = nil
        case .Changed:
            let newMultiplier = multiplier * gesture.scale
            multiplier = newMultiplier >= 1 ? newMultiplier : 1
            gesture.scale = 1
        case .Ended:
            drawing = true
            mode = Mode.Usual
        default: break
        }
        poincareView.setNeedsDisplay()
    }
    
    // MARK: Outlets to other views
    
    @IBOutlet weak var poincareView: PoincareView! {
        didSet {
            poincareView.dataSource = self
        }
    }
    
    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
    }
    */
    
}
