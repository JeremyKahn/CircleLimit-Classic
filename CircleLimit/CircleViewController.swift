//
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

// The mask is being applied to the point on the polygon
struct MatchedPoint {
    var index: Int
    var polyline: HyperbolicPolyline
    var mask: HyperbolicTransformation
    
    func moveTo(z: HPoint) {
        polyline.movePointAtIndex(index, to: mask.inverse.appliedTo(z))
    }
}

typealias GroupSystem = [(HDrawable, [Action])]

class CircleViewController: UIViewController, PoincareViewDataSource, UIGestureRecognizerDelegate, ColorPickerDelegate {
    
    // MARK: Debugging variables
    var tracingGroupMaking = false
    
    var tracingGesturesAndTouches = false
    
    var trivialGroup = false
    
    // MARK: Basic overrides
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("CircleViewController loaded")
        var generators: [HyperbolicTransformation] = []
        var guidelines: [HDrawable] = []
        var twistedGenerators: [Action] = []
        if !trivialGroup {
            (generators, guidelines) = pqrGeneratorsAndGuidelines(3, q: 3, r: 4)
            for object in guidelines {
                object.intrinsicLineWidth = 0.005
                object.lineColor = UIColor.grayColor()
                object.useFillColorTable = false
            }
            
            // This will show the fixed points of all the elliptic elements
            guidelines.append(HyperbolicDot(center: HPoint()))
            for g in generators {
                let fixedPointDot = HyperbolicDot(center: g.fixedPoint!)
                guidelines.append(fixedPointDot)
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
    
    // MARK: - Flags
    var drawing = true
    
    var suppressTouches: Bool {
        return !drawing || changingColor || formingPolygon
    }

    // MARK: - General properties
    var guidelines : [HDrawable] = []
    
    var drawGuidelines = true
    
    var drawObjects: [HDrawable] = []
    
    var oldDrawObjects: [HDrawable] = [] {
        didSet {
//            print("There are now \(oldDrawObjects.count) old draw objects")
        }
    }
    
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
    
    var formingPolygon: Bool {
        return newCurve != nil
    }
    
    var mask: HyperbolicTransformation = HyperbolicTransformation()
    
    
    var touchDistance: Double {
        let m = Double(multiplier)
        let baseTouchDistance = 0.2
        let exponent = 0.25
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
    
    var groupSystemToDraw: GroupSystem {
        return groupSystem(mode, objects: objectsToDraw)
    }
    
    var multiplier = CGFloat(1.0)
    
    var mode : Mode = .Usual {
        didSet {
            print("Mode changed to \(mode)")
        }
    }
    
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

    // MARK: - Get the group you want
    func groupSystem(mode: Mode, objects: [HDrawable]) -> GroupSystem {
        let zoomAbs = 2.0 / Double(multiplier)
        let cutoffAbs = min(zoomAbs, cutoff[mode]!)
        let distance = absToDistance(cutoffAbs)
        return groupSystem(cutoffDistance: distance, objects: objects)
    }

    
    func groupSystem(cutoffDistance distance: Double, objects: [HDrawable]) -> GroupSystem {
        return groupSystem(cutoffDistance: distance, center: HPoint(), objects: objects, useMask: true)
    }
    
    // This one is intended for touch matching
    func groupSystem(cutoffDistance distance: Double, center: HPoint, objects: [HDrawable]) -> GroupSystem {
        return groupSystem(cutoffDistance: distance, center: center, objects: objects, useMask: false)
    }
    
    func groupSystem(cutoffDistance distance: Double, center: HPoint, objects: [HDrawable], useMask: Bool) -> GroupSystem {
        let (objectsCenter, objectsRadius) = centerAndRadiusFor(objects)
        let maskDistance = useMask ? mask.distance : 0.0
        let totalDistance = objectsRadius + distance + center.distanceToOrigin + objectsCenter.distanceToOrigin + maskDistance
        var group = groupForDistance(totalDistance)
    
        if useMask {
            group = group.map { Action(M: mask.following($0.motion), P: $0.action) }
        }
        
        let newRadius = distance + objectsRadius
        group = filterForTwoPointsAndDistance(group, point1: center, point2: objectsCenter, distance: newRadius)
        
        var result: GroupSystem = []
        for object in objects {
            let objectGroup = filterForTwoPointsAndDistance(group, point1: center, point2: object.centerPoint, distance: distance + object.radius)
            if objectGroup.count > 0 {
                result.append((object, objectGroup))
            }
        }
        return result
    }
    
    
    func filterForTwoPointsAndDistance(group: [Action], point1: HPoint, point2: HPoint, distance: Double) -> [Action] {
        let startFilter = NSDate()
        let g = group.filter() { point1.liesWithin(distance)($0.motion.appliedTo(point2)) }
        let prefilterTime = NSDate().timeIntervalSinceDate(startFilter) * 1000
        print("Filter time: \(Int(prefilterTime)) milliseconds", when: tracingGroupMaking)
        return g
    }
    
    
    // TODO: Modify the center-and-radius algorithm to find the smallest disk containing a collection of disks, and use it here
    func centerAndRadiusFor(objects: [HDrawable]) -> (HPoint, Double) {
        let centers = objects.map {$0.centerPoint}
        let (center, radius) = centerPointAndRadius(centers, delta: 0.1)
        let totalRadius = objects.reduce(0) {max($0, $1.centerPoint.distanceTo(center) + $1.radius ) }
        return (center, totalRadius)
    }
    
    
    // MARK: - Undo and redo
    // TODO: Undo with a shake, clear picture...with what?
    struct State {
        var completedObjects: [HDrawable]?
        var newCurve: HyperbolicPolyline?
    }
    
    var stateStack: [State] = []
    
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?) {
        if motion == .MotionShake {
            undo()
        }
    }
    
    func undo() {
        print("undo!")
        mode = .Usual
        guard stateStack.count > 0 else { return }
        let lastState = stateStack.removeLast()
        if let previousObjects = lastState.completedObjects {
            drawObjects = previousObjects
        }
        newCurve = lastState.newCurve
        poincareView.setNeedsDisplay()
    }
    
    func redo() {
        print("redo")
        mode = .Usual
        guard undoneObjects.count > 0 else {return}
        drawObjects.append(undoneObjects.removeLast())
        poincareView.setNeedsDisplay()
    }
    
 
    func clearPicture() {
        print("In clearPicture with \(guidelines.count) guidelines")
        drawObjects = []
        newCurve = nil
        poincareView.setNeedsDisplay()
    }
    
    
    // MARK: - Adding points and drawing
    let drawRadius = 0.99
    
    func hPoint(rawLocation: CGPoint) -> HPoint? {
        var thing = rawLocation
        thing = CGPointApplyAffineTransform(thing,toPoincare)
        let (x, y) = (Double(thing.x), Double(thing.y))
        //        print("New point: " + x.nice() + " " + y.nice())
        if x * x + y * y < drawRadius * drawRadius {
            let z = HPoint(x + y.i)
            return mask.inverse.appliedTo(z)
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
    
    var newCurve : HyperbolicPolyline?
    
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
        mode = .Usual
        undoneObjects = []
        guard let curve = newCurve else { return }
        curve.complete()
        print("Appending a curve with \(curve.points.count) points")
        stateStack = stateStack.filter {$0.completedObjects != nil}
        stateStack.append(State(completedObjects: drawObjects, newCurve: nil))
        newCurve = nil
        drawObjects.append(curve)
        poincareView.setNeedsDisplay()
    }
    
    var printingTouches = true
    
    func nearbyPointsTo(point: HPoint, withinDistance distance: Double) -> [MatchedPoint] {
        let objects = drawObjects.filter() { $0 is HyperbolicPolyline }
        let g = groupSystem(cutoffDistance: distance, center: point, objects: objects)
        var matchedPoints: [MatchedPoint] = []
        for (object, group)  in g {
            let polyline = object as! HyperbolicPolyline
            
            for a in group {
                let indices = polyline.pointsNear(point, withMask: a.motion, withinDistance: distance)
                let matched = indices.map { MatchedPoint(index: $0, polyline: polyline, mask: a.motion) }
                matchedPoints += matched
            }
        }
        return matchedPoints
    }
    
    var matchedPoints: [MatchedPoint] = []
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        print("touchesBegan", when: tracingGesturesAndTouches)
        super.touchesBegan(touches, withEvent: event)
        guard touches.count == 1 else {return}
        if suppressTouches {return}
        print("Saving objects", when: tracingGesturesAndTouches)
        oldDrawObjects = drawObjects.map { $0.copy() }
        mode = .Moving
        if let touch = touches.first {
            if let z = hPoint(touch.locationInView(poincareView)) {
                let distance = touchDistance
                matchedPoints = nearbyPointsTo(z, withinDistance: distance)
                
                if matchedPoints.count == 0 {
                    addPointToArcs(z)
                }
            }
        }
        touchesMoved(touches, withEvent: event)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        //        if printingTouches { print("touchesMoved") }
        super.touchesMoved(touches, withEvent: event)
        guard touches.count == 1 else {return}
        if suppressTouches {return}
        if let touch = touches.first {
            if let z = hPoint(touch.locationInView(poincareView)) {
                for m in matchedPoints {
                    m.moveTo(z)
                }
            }
        }
        poincareView.setNeedsDisplay()
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        print("touchesEnded", when:  tracingGesturesAndTouches)
        guard touches.count == 1 else {return}
        super.touchesEnded(touches, withEvent: event)
        if suppressTouches {return}
        touchesMoved(touches, withEvent: event)
        mode = .Usual
        stateStack.append(State(completedObjects: oldDrawObjects, newCurve: nil))
        oldDrawObjects = []
        poincareView.setNeedsDisplay()
    }
    
    
    // MARK: Adding a point to a line
    func addPointToArcs(z: HPoint) {
        let objects = objectsToDraw.filter() { $0 is HyperbolicPolyline }
        
        let g = groupSystem(cutoffDistance: touchDistance, center: z, objects: objects)
        
        for (object, group) in g {
            let polyline = object as! HyperbolicPolyline
            
            var instructions: [(Int, HPoint, HyperbolicTransformation)] = []
            for a in group {
                let indices = polyline.sidesNear(z, withMask: a.motion, withinDistance: touchDistance)
                if indices.count == 0 { continue }
                if indices.count > 1 {
                    print("Matched more than one side in a single polyline: \(indices)")
                }
                for index in indices {
                    instructions.append((index, a.motion.inverse.appliedTo(z), a.motion))
                }
            }
            polyline.insertPointsAfterIndices(instructions.map({($0.0, $0.1)}))
            instructions.sortInPlace() { $0.0 < $1.0 }
            for i in 0..<instructions.count {
                let (index, _ , pointMask) = instructions[i]
                matchedPoints.append(MatchedPoint(index: index + i + 1, polyline: polyline, mask: pointMask))
            }
        }
    }
    
    // MARK: - Color Picker Preview Source and Delegate
    var colorToStartWith: UIColor = UIColor.blueColor()
    
    var changingColor = false
    
    struct ColorChangeInformation {
        var polygon: HyperbolicPolygon
        var colorNumber: ColorNumber
        var changeColorTableEntry: Bool
    }
    
    // Slightly naughty to use an implicitly unwrapped optional
    var colorChangeInformation: ColorChangeInformation!
    
    func applyColor(color: UIColor) {
        let polygon = colorChangeInformation.polygon
        if colorChangeInformation.changeColorTableEntry {
            polygon.fillColorTable[colorChangeInformation.colorNumber] = color
        } else {
            polygon.fillColor = color
        }
    }
    
    func applyColorAndReturn(color: UIColor) {
        applyColor(color)
        dismissViewControllerAnimated(true, completion: nil)
        cancelEffectOfTouches()
        changingColor = false
        poincareView.setNeedsDisplay()
    }
    
    // TODO: Fix the problem with the segue
    func setColor(polygon: HyperbolicPolygon, withAction action: Action) {
        changingColor = true
        cancelEffectOfTouches()
        let colorNumber = action.action.mapping[ColorNumber.baseNumber]!
        colorToStartWith = polygon.fillColorTable[colorNumber]!
        colorChangeInformation = ColorChangeInformation(polygon: polygon, colorNumber: colorNumber, changeColorTableEntry: true)
        performSegueWithIdentifier("chooseColor", sender: self)
    }
    
    // MARK: - Gesture recognition
    
    @IBOutlet var panRecognizer: UIPanGestureRecognizer!
    
    @IBOutlet var pinchRecognizer: UIPinchGestureRecognizer!
    
    @IBOutlet var longPressRecognizer: UILongPressGestureRecognizer!
    
    //    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOfGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    //        return otherGestureRecognizer === swipeRecognizer
    //    }
    
    //    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailByGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    //        return gestureRecognizer === swipeRecognizer
    //    }
    
    func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == longPressRecognizer {
            return gestureRecognizer.numberOfTouches() == 1
        } else {
            return true
        }
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOfGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        switch gestureRecognizer {
        case singleTapRecognizer:
            switch otherGestureRecognizer {
            case doubleTapRecognizer, pinchRecognizer, panRecognizer:
                return true
            default: return false
            }
        case longPressRecognizer:
            switch otherGestureRecognizer {
            case pinchRecognizer, panRecognizer:
                return true
            default: return false
            }
        default:
            return false
        }
    }

    
    
    @IBAction func simplePan(gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .Began:
            drawing = false
            //            newCurve = nil
            mode = mode == .Drawing ? .Drawing :  .Moving
            cancelEffectOfTouches()
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
            stateStack.append(State(completedObjects: nil, newCurve: (newCurve!.copy() as! HyperbolicPolyline)))
            newCurve!.addPoint(z!)
        }
        poincareView.setNeedsDisplay()
    }
    
    
    @IBAction func doubleTap(sender: UITapGestureRecognizer) {
        if newCurve == nil {
            let z = hPoint(sender.locationInView(poincareView))
            guard z != nil else { return }
            newCurve = HyperbolicPolygon(z!)
            stateStack.append(State(completedObjects: nil, newCurve: nil))
            mode = .Drawing
            poincareView.setNeedsDisplay()
        } else  {
            switch newCurve!.points.count {
            case 0, 1:
                newCurve = nil
            case 2:
                newCurve = HyperbolicPolyline(newCurve!.points)
            default:
                newCurve!.addPoint(newCurve!.points[0])
            }
            returnToUsualMode()
            poincareView.setNeedsDisplay()
        }
    }
    
    @IBAction func longPress(sender: UILongPressGestureRecognizer) {
        let z = hPoint(sender.locationInView(poincareView))
        if let point = z {
            if tracingGesturesAndTouches {
                drawObjects.append(HyperbolicDot(center: point, radius: touchDistance))
            }
            cancelEffectOfTouches()
//            addPointToArcs(point)
            let polylines = drawObjects.filter({$0 is HyperbolicPolyline})
            let g = groupSystem(cutoffDistance: touchDistance, center: point, objects: polylines).reverse()
            // As constructed this just sets the color of the first polygon that matches
            // So if you touch overlapping polygons, or between two polygons, the result is unpredictable
            // It makes some effort to change the highest polygon
            for (object, group) in g {
                let polyline = object as! HyperbolicPolyline
                for action in group {
                    if polyline.sidesNear(point, withMask: action.motion, withinDistance: touchDistance).count > 0 {
                        return
                    }
                }
            }
            OUTER: for (object, group) in g.filter({$0.0 is HyperbolicPolygon}) {
                let polygon = object as! HyperbolicPolygon
                for action in group {
                    if polygon.containsPoint(point, withMask: action.motion) {
                        setColor(polygon, withAction: action)
                        break OUTER
                    }
                }
            }
        }
    }
    
    func recomputeMask() {
        if formingPolygon { return }
        var bestA = mask.a.abs
        var bestMask = mask
        //        println("Trying to improve : \(bestA)")
        var foundBetter = false
        repeat {
            foundBetter = false
            for E in searchingGroup  {
                let newMask = mask.following(E.motion.inverse)  // Let's try it
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
            cancelEffectOfTouches()
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
    
    
    func cancelEffectOfTouches() {
        if oldDrawObjects.count > 0 {
            print("Restoring objects and cancelling move points", when: tracingGesturesAndTouches)
            drawObjects = oldDrawObjects
            oldDrawObjects = []
            matchedPoints = []
        }
    }
    // MARK: Outlets to other views
    
    @IBOutlet weak var poincareView: PoincareView! {
        didSet {
            poincareView.dataSource = self
        }
    }
    
 
//      MARK: - Navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        switch segue.identifier! {
        case "chooseColor":
            changingColor = true
            let triangleViewController = segue.destinationViewController as! TriangleViewController
            triangleViewController.delegate = self
        default:
            break
        }
     }

    
}
