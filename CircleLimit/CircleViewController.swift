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
    
    
    // MARK: Debugging variables
    var tracingGroupMaking = true
    
    var tracingGesturesAndTouches = false
    
    var trivialGroup = false
    
    //
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
        let bigGroup = generatedGroup(twistedGenerators, bigCutoff: bigGroupCutoff)
        groupForIntegerDistance = Array<[Action]>(count: maxGroupDistance + 1, repeatedValue: [])
        for i in 0...maxGroupDistance {
            groupForIntegerDistance[i] = selectElements(bigGroup, cutoff: distanceToAbs(Double(i)))
        }
        // Right now this is just a guess
        let I = ColorNumberPermutation()
        searchingGroup = groupForIntegerDistance[5].filter() { $0.action == I }
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
    
     // One group for each integral distance cutoff
    var groupForIntegerDistance: [[Action]] = []
    
    func groupForDistance(distance: Double) -> [Action] {
        return groupForIntegerDistance[min(maxGroupDistance, Int(distance) + 1)]
    }
    
    var group = [Mode : [Action]]()
    
    // Change these values to determine the size of the various groups
    var cutoff : [Mode : Double] = [.Usual : 0.98, .Moving : 0.8, .Drawing : 0.8]
    
    var bigGroupCutoff = 0.995
    
    var maxGroupDistance: Int {
        return Int(absToDistance(bigGroupCutoff)) + 1
    }
    
    // The translates (by the color fixing subgroup) of a disk around the origin of this radius should cover the boundary of that disk
    // Right now the size is determined by trial and error
    var searchingGroup: [Action] = []
    
    enum Mode {
        case Usual
        case Drawing
        case Moving
     }
    
    // Right now this is not used for anything and so can be removed
    var formingPolygon = false
    
    var mask: HyperbolicTransformation = HyperbolicTransformation()
    
    
    var touchDistance: Double {
        let m = Double(multiplier)
        let baseTouchDistance = 0.2
        let exponent = 0.5
        return baseTouchDistance/pow(m, 1 - exponent)
    }
    
    // MARK: PoincareViewDataSource
    var objectsToDraw: [HDrawable] {
        var fullDrawObjects = drawGuidelines ? guidelines : []
        fullDrawObjects += drawObjects
        if newCurve != nil {
            fullDrawObjects.append(newCurve!)
        }
        return fullDrawObjects
    }
    
    var groupToDraw: [Action] {
        return groupForMode(mode, withObjects: objectsToDraw, withMask: true)
    }
    
    var multiplier = CGFloat(1.0)
    
    var mode : Mode = .Usual
    
    func cutOffDistanceForAbsoluteCutoff(cutoffAbs: Double) -> Double {
        let scaleCutoff = Double(2/multiplier)
        let lesserAbs = min(scaleCutoff, cutoffAbs)
        return absToDistance(lesserAbs)
    }
    
    var cutoffDistance: Double {
        return cutOffDistanceForAbsoluteCutoff(cutoff[mode]!)
    }
    
    // MARK: Stuff from the poincareView
    var toPoincare : CGAffineTransform {
        return CGAffineTransformInvert(poincareView.tf)
    }
    
    var scale: CGFloat {
        return poincareView.scale
    }

    // MARK: Get the group you want
    
    // Returns all group elements (optionally followed by the mask) that might map the objects to intersect the disk of given radius around the origin
    func groupForDistanceCutoff(cutoffDistance: Double, withObjects objects: [HDrawable], withMask useMask: Bool) -> [Action] {
        let (center, objectRadius) = centerAndRadiusFor(objects)
        let maskOriginDistance = useMask ? mask.distance : 0.0
        let totalDistance = center.distanceToOrigin + maskOriginDistance + objectRadius + cutoffDistance
        var g = groupForDistance(totalDistance)
        
        if useMask {
            g = g.map() { Action(M: mask.following($0.motion), P: $0.action) }
        }
            
        let newRadius = cutoffDistance + objectRadius
        g = filterForCenterAndRadius(g, center: center, radius: newRadius)
        return g
    }
    
    func groupForMode(mode: Mode, withObjects objects: [HDrawable], withMask useMask: Bool ) -> [Action] {
        let myCutoff = cutoff[mode]!
        let distance = absToDistance(myCutoff)
        return groupForDistanceCutoff(distance, withObjects: objects, withMask: useMask)
    }
    
    func filterForCenterAndRadius(group: [Action], center: HPoint, radius: Double) -> [Action] {
        let startFilter = NSDate()
        let absCutoff = distanceToAbs(radius)
        let g = group.filter() { $0.motion.appliedTo(center).abs < absCutoff }
        let prefilterTime = NSDate().timeIntervalSinceDate(startFilter) * 1000
        print("Prefilter time: \(Int(prefilterTime)) milliseconds", when: tracingGroupMaking)
        return g
    }
    
    // TODO: Modify the center-and-radius algorithm to find the smallest disk containing a collection of disks, and use it here
    func centerAndRadiusFor(objects: [HDrawable]) -> (HPoint, Double) {
        let centers = objects.map() {$0.centerPoint}
        let (center, radius) = centerPointAndRadius(centers, delta: 0.1)
        let totalRadius = objects.reduce(0) {max($0, $1.centerPoint.distanceTo(center) + $1.radius ) }
        return (center, totalRadius)
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
            let z = HPoint(x + y.i)
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
        let totalDistance = distance + absToDistance(point.abs)
        let objects = drawObjects.filter() { $0 is HyperbolicPolygon }
        let g = groupForDistanceCutoff(totalDistance, withObjects: objects, withMask: false)
        var matchedPoints: [MatchedPoint] = []
        for object in drawObjects {
            let polygon = object as! HyperbolicPolygon
            
            // filtering the group by object
            let cutoffDistance = distance + object.radius
            let objectGroup = g.filter() { point.liesWithin(cutoffDistance)($0.motion.appliedTo(object.centerPoint)) }
                
//                { point.distanceTo($0.motion.appliedTo(object.centerPoint)) < cutoffDistance }
            
            for a in objectGroup {
                let indices = polygon.pointsNear(selectedPoint: point, withMask: a.motion, withinDistance: distance)
                let matched = indices.map() { MatchedPoint(index: $0, polygon: polygon, mask: a.motion) }
                matchedPoints += matched
            }
        }
        return matchedPoints
    }
    
    var matchedPoints: [MatchedPoint] = []
    
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
        touchesMoved(touches, withEvent: event)
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
    
    @IBOutlet var longPressRecognizer: UILongPressGestureRecognizer!
    
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
    
    
    @IBAction func longPress(sender: UILongPressGestureRecognizer) {
        
    }
    
    func recomputeMask() {
        if mode == .Drawing { return }
        var bestA = mask.a.abs
        var bestMask = mask
        //        println("Trying to improve : \(bestA)")
        var foundBetter = false
        repeat {
            foundBetter = false
            for E in searchingGroup  {
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
