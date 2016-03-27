//  ZOMBIES ARE ENABLED
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

struct MatchedPoint {
    var index: Int
    var polygon: HyperbolicPolygon
    var mask: HyperbolicTransformation
}


class CircleViewController: UIViewController, PoincareViewDataSource, UIGestureRecognizerDelegate {
    
    var tracingGroupMaking = false
    
    var tracingGesturesAndTouches = true
    
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
        let bigGroup = generatedGroup(twistedGenerators, bigCutoff: 0.995)
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
    
    var oldDrawObjects: [HDrawable] = []
    
    var undoneObjects: [HDrawable] = []
    
    var mode : Mode = .Usual
    
    var group = [Mode : [Action]]()
    
    // Change these values to determine the size of the various groups
    var cutoff : [ Mode : Double ] = [.Usual : 0.95, .Moving : 0.8, .Drawing : 0.8, .Searching: 0.95]
    
    var bigCutoff: [Mode: Double] = [.Usual: 0.99, .Moving: 0.98, .Drawing: 0.95, .Searching: 0.95]
    
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
    
    // Right now this is not used for anything and so can be removed
    var formingPolygon = false
    
    var mask: HyperbolicTransformation = HyperbolicTransformation()
    
    var multiplier = CGFloat(1.0)
    
    var touchDistance: Double {
        return Double(0.5/multiplier)
    }
    
    var objectsToDraw: [HDrawable] {
        var fullDrawObjects = drawGuidelines ? guidelines : []
        fullDrawObjects += drawObjects
        if newCurve != nil {
            fullDrawObjects.append(newCurve!)
        }
        return fullDrawObjects
    }
    
    
    // TODO: Replace group[mode] with group(cutoff) that selects a group[cutoff] to be prefiltered
    // The cutuff should then depend on the zoom multiplier as well as the mode.
    var groupToDraw: [Action] {
        var g : [Action] = []
        
        let startMakeGroup = NSDate()
        g = group[mode]!
        g = g.map() { Action(M: mask.following($0.motion), P: $0.action) }
        let makeGroupTime = timeInMillisecondsSince(startMakeGroup)
        print("Size of group: \(g.count)", when: tracingGroupMaking)
        print("Time to make the group: \(makeGroupTime)", when: tracingGroupMaking)
        
        g = prefilteredGroupFrom(g, withObjects: objectsToDraw)
        
        return g
    }
    
    func prefilteredGroupFrom(group: [Action], withObjects objects: [HDrawable]) -> [Action] {
        let centers = objects.map() {$0.centerPoint}
        let maxRadius = objects.reduce(0) { max($0, $1.radius) }
        let (center, radius) = centerPointAndRadius(centers, delta: 0.1)
        let totalRadius = radius + maxRadius
        
        let startFilter = NSDate()
        let cutoffAbs = distanceToAbs(cutoffDistance + totalRadius)
        let g = group.filter() { $0.motion.appliedTo(center).abs < cutoffAbs }
        let prefilterTime = NSDate().timeIntervalSinceDate(startFilter) * 1000
        print("Prefilter time: \(Int(prefilterTime)) milliseconds", when: tracingGroupMaking)
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
    
    
    //        func addPoint(touches: Set<NSObject>, _ state: TouchType) {
    //            if (!drawing) { return }
    //            if let touch = touches.first as? UITouch {
    //                if let z = hPoint(touch.locationInView(poincareView)) {
    //                    switch state {
    //                    case .Began:
    //                        newCurve = HyperbolicPolyline(z)
    //                    case .Moved:
    //                        newCurve?.addPoint(z)
    //                        poincareView.setNeedsDisplay()
    //                    case .Ended:
    //                        if newCurve != nil {
    //                            newCurve!.addPoint(z)
    //                            poincareView.setNeedsDisplay()
    //                            performSelectorInBackground("returnToUsualMode", withObject: nil)
    //                        }
    //                    }
    //                }
    //            }
    //        }
    
    
    
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
    
    var printingTouches = true
    
    func nearbyPointsTo(point: HPoint, withinDistance distance: Double) -> [MatchedPoint] {
        var g = group[.Drawing]!  // again this should depend on the zoom scale
        g = prefilteredGroupFrom(g, withObjects: drawObjects)
        var matchedPoints: [MatchedPoint] = []
        for object in drawObjects {
            if !(object is HyperbolicPolygon) { continue }
            let polygon = object as! HyperbolicPolygon
//            print("Attempting to match polygon with points \(polygon.points)")
            
            // filtering the group by object
            let cutoffDistance = distance + object.radius
            let objectGroup = g.filter() { distanceBetween($0.motion.appliedTo(object.centerPoint), w: point) < cutoffDistance }
            
            for a in objectGroup {
                let indices = polygon.pointsNear(selectedPoint: point, withmask: a.motion, withinDistance: distance)
                let matched = indices.map() { MatchedPoint(index: $0, polygon: polygon, mask: a.motion) }
                matchedPoints += matched
            }
        }
        return matchedPoints
    }
    
    var matchedPoints: [MatchedPoint] = []
    
    // TODO: Make the touches work so that the movement is cancelled without touchesEnded
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if printingTouches { print("touchesBegan") }
        super.touchesBegan(touches, withEvent: event)
        guard touches.count == 1 else {return}
        print("Saving objects", when: tracingGesturesAndTouches)
        oldDrawObjects = drawObjects.map() { $0.copy() }
        mode = .Moving
        if let touch = touches.first {
            if let z = hPoint(touch.locationInView(poincareView)) {
                let distance = touchDistance
                matchedPoints = nearbyPointsTo(z, withinDistance: distance)
            }
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
//        if printingTouches { print("touchesMoved") }
        super.touchesMoved(touches, withEvent: event)
        guard touches.count == 1 else {return}
        if let touch = touches.first {
            if let z = hPoint(touch.locationInView(poincareView)) {
                for m in matchedPoints {
                    m.polygon.movePointAtIndex(m.index, to: m.mask.inverse().appliedTo(z))
                }
            }
        }
        poincareView.setNeedsDisplay()
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if printingTouches { print("touchesEnded") }
        super.touchesEnded(touches, withEvent: event)
        touchesMoved(touches, withEvent: event)
        mode = .Usual
        oldDrawObjects = []
        poincareView.setNeedsDisplay()
    }
    
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
        answer = answer || (gestureRecognizer == singleTapRecognizer) && (otherGestureRecognizer == pinchRecognizer || otherGestureRecognizer == panRecognizer)
        //        answer = answer || (gestureRecognizer == pinchRecognizer || gestureRecognizer == panRecognizer) && (otherGestureRecognizer == singleTapRecognizer || otherGestureRecognizer == doubleTapRecognizer)
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
            if oldDrawObjects.count > 0 {
                print("Restoring objects and cancelling move points", when: tracingGesturesAndTouches)
                drawObjects = oldDrawObjects
                matchedPoints = []
            }

            
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
        } else if newCurve != nil {
            newCurve!.addPoint(z!)
            formingPolygon = true
            mode = .Drawing
        }
        poincareView.setNeedsDisplay()
    }
    
    
    @IBAction func doubleTap(sender: UITapGestureRecognizer) {
        if newCurve == nil {
            let z = hPoint(sender.locationInView(poincareView))
            guard z != nil else { return }
            newCurve = HyperbolicPolygon(z!)
            formingPolygon = true
            mode = .Drawing
        } else  {
            newCurve!.addPoint(newCurve!.points[0])
            newCurve!.complete()
            formingPolygon = false
            returnToUsualMode()
        }
        poincareView.setNeedsDisplay()
    }
    
    func recomputeMask() {
        if mode == .Drawing { return }
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
            if oldDrawObjects.count > 0 {
                print("Restoring objects and cancelling move points", when: tracingGesturesAndTouches)
                drawObjects = oldDrawObjects
                matchedPoints = []
            }
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
