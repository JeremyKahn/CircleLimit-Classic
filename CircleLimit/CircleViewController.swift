//
//
//  CircleViewController.swift
//  CircleLimit
//
//  Created by Jeremy Kahn on 7/19/15.
//  Copyright (c) 2015 Jeremy Kahn. All rights reserved.
//

import UIKit
import FacebookCore
import FacebookShare
import FacebookLogin

enum TouchType {
    case began
    case moved
    case ended
}

// The mask is being applied to the point on the polygon
struct MatchedPoint {
    var index: Int
    var polyline: HyperbolicPolyline
    var mask: HyperbolicTransformation
    
    func moveTo(_ z: HPoint) {
        polyline.movePointAtIndex(index, to: mask.inverse.appliedTo(z))
    }
    
    var matchingPoint: HPoint {
        return mask.appliedTo(polyline.points[index])
    }
    
    func cleanUp() {
        polyline.removeRepeatedPoints()
        polyline.updateAndComplete()
    }
}

typealias GroupSystem = [(HDrawable, [Action])]

class CircleViewController: UIViewController, PoincareViewDataSource, UIGestureRecognizerDelegate, ColorPickerDelegate {
    
    // MARK: Debugging variables
    var tracingGroupMaking = false
    
    var tracingGesturesAndTouches = false
    
    var trivialGroup = false
    
    // MARK: Basic overrides
    override var prefersStatusBarHidden : Bool {
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
                object.lineColor = UIColor.gray
                object.useFillColorTable = false
            }
            
            // This will show the fixed points of all the elliptic elements
//            guidelines.append(HyperbolicDot(center: HPoint()))
            for g in generators {
                let fixedPointDot = HyperbolicDot(center: g.fixedPoint!)
                self.fixedPoints.append(fixedPointDot)
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
        groupForIntegerDistance = Array<[Action]>(repeating: [], count: maxGroupDistance + 1)
        for i in 0...maxGroupDistance {
            groupForIntegerDistance[i] = selectElements(bigGroup, cutoff: distanceToAbs(Double(i)))
        }
        // Right now this is just a guess
        let I = ColorNumberPermutation()
        searchingGroup = groupForIntegerDistance[5].filter() { $0.action == I }
        
        load()
    }
    
    func selectElements(_ group: [Action], cutoff: Double) -> [Action] {
        let a = group.filter { (M: Action) in M.motion.a.abs < cutoff }
        print("Selected \(a.count) elements with cutoff \(cutoff)")
        return a
    }
    
    // MARK: - Delete and Clone
    
    @IBAction func deletePage(_ sender: UIButton) {
        galleryContext!.deletePage(currentPage: self)
    }    
    
    @IBAction func clonePage(_ sender: UIButton) {
        galleryContext!.clonePage(currentPage: self)
    }
    

    // MARK: - Location and Context in PageView
    var pageviewIndex = 0
    
    var galleryContext: GalleryContext?

    // MARK: - Save and Load
    static var filenameStem = "CircleViewController"
    
    var persistenceURL: URL {return filePath(fileName: CircleViewController.filenameStem + String(pageviewIndex))}
    
    func save() {
        let stuff: [HDWrapper] = drawObjects.map() {HDWrapper($0)}
        saveStuff(stuff, location: persistenceURL)
    }
    
    func load() {
        let file = persistenceURL
        if let stuff = loadStuff(location: file, type: [HDWrapper].self) {
            print("Successfully loaded from disk")
            drawObjects = stuff.map() {$0.object}
        }
    }
    
    // MARK: - Share
    
    @IBAction func shareOnFacebook(_ sender: UIButton) {
        print("Touched the share button")
//        if let accessToken = AccessToken.current {
//            print("Already have access token")
//        } else {
//            let loginManager = LoginManager()
////            loginManager.logIn()
//
//            loginManager.logIn(publishPermissions: [], viewController: self) { loginResult in
//                switch loginResult {
//                case .failed(let error):
//                    print("There was an error with the FB login")
//                    print(error)
//                case .cancelled:
//                    print("User cancelled login.")
//                case .success(let grantedPermissions, let declinedPermissions, let accessToken):
//                    print("Logged in!")
//                }
//            }
//        }
        let image = poincareView.asSquareImage()
        let photo = Photo(image: image, userGenerated: true)
        let content = PhotoShareContent(photos: [photo])
        do {
            print("Now trying to share")
//            let dialog = ShareDialog(content: content)
//            try ShareDialog.validate(dialog)()
//            try ShareDialog.show(dialog)()
            try ShareDialog.show(from: self, content: content)
        } catch  {
            print("Something went wrong.")
        }
    }
    
    // MARK: - Flags
    var drawing = true
    
    var doNothing = false
    
    var suppressTouches: Bool {
        return !drawing || changingColor || formingPolygon || doNothing
    }

    // MARK: - General properties
    var guidelines : [HDrawable] = []
    
    var fixedPoints: [HDrawable] = []
    
    var drawGuidelines = true
    
    var drawObjects: [HDrawable] = []
    
    var oldDrawObjects: [HDrawable] = [] {
        didSet {
//            print("There are now \(oldDrawObjects.count) old draw objects")
        }
    }
    
    var undoneObjects: [State] = []
    
     // One group for each integral distance cutoff
    var groupForIntegerDistance: [[Action]] = []
    
    func groupForDistance(_ distance: Double) -> [Action] {
        return groupForIntegerDistance[min(maxGroupDistance, Int(distance) + 1)]
    }
    
    var group = [Mode : [Action]]()
    
    // Change these values to determine the size of the various groups
    var cutoff : [Mode : Double] = [.usual : 0.98, .moving : 0.8, .drawing : 0.8]
    
    var bigGroupCutoff = 0.995
    
    var maxGroupDistance: Int {
        return Int(absToDistance(bigGroupCutoff)) + 1
    }
    
    // The translates (by the color fixing subgroup) of a disk around the origin of this radius should cover the boundary of that disk
    // Right now the size is determined by trial and error
    var searchingGroup: [Action] = []
    
    enum Mode {
        case usual
        case drawing
        case moving
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
    
    var mode : Mode = .usual {
        didSet {
            print("Mode changed to \(mode)", when: tracingGroupMaking)
        }
    }
    
    func cutOffDistanceForAbsoluteCutoff(_ cutoffAbs: Double) -> Double {
        let scaleCutoff = Double(2/multiplier)
        let lesserAbs = min(scaleCutoff, cutoffAbs)
        return absToDistance(lesserAbs)
    }
    
    var cutoffDistance: Double {
        return cutOffDistanceForAbsoluteCutoff(cutoff[mode]!)
    }
    
    // MARK: Stuff from the poincareView
    var toPoincare : CGAffineTransform {
        return poincareView.tf.inverted()
    }
    
    var scale: CGFloat {
        return poincareView.scale
    }

    // MARK: - Get the group you want
    func groupSystem(_ mode: Mode, objects: [HDrawable]) -> GroupSystem {
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
    
    
    func filterForTwoPointsAndDistance(_ group: [Action], point1: HPoint, point2: HPoint, distance: Double) -> [Action] {
        let startFilter = Date()
        let g = group.filter() { point1.liesWithin(distance)($0.motion.appliedTo(point2)) }
        let prefilterTime = Date().timeIntervalSince(startFilter) * 1000
        print("Filter time: \(Int(prefilterTime)) milliseconds", when: tracingGroupMaking)
        return g
    }
    
    
    // TODO: Modify the center-and-radius algorithm to find the smallest disk containing a collection of disks, and use it here
    func centerAndRadiusFor(_ objects: [HDrawable]) -> (HPoint, Double) {
        let centers = objects.map {$0.centerPoint}
        let (center, _) = centerPointAndRadius(centers, delta: 0.1)
        let totalRadius = objects.reduce(0) {max($0, $1.centerPoint.distanceTo(center) + $1.radius ) }
        return (center, totalRadius)
    }
    
    
    // MARK: - Undo and redo
    
    @IBAction func undoFromButton(_ sender: UIButton) {
        undo()
    }
    
    @IBAction func redoFromButton(_ sender: UIButton) {
        redo()
    }
    
    struct State {
        var completedObjects: [HDrawable]?
        var newCurve: HyperbolicPolyline?
    }
    
    var stateStack: [State] = []
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            clearPicture()
        }
    }
    
    func undo() {
        print("undo!")
        mode = .usual
        guard stateStack.count > 0 else { return }
        undoneObjects.append(State(completedObjects: drawObjects, newCurve: newCurve))
        let lastState = stateStack.removeLast()
        if let previousObjects = lastState.completedObjects {
            drawObjects = previousObjects
        }
        newCurve = lastState.newCurve
        save()
        poincareView.setNeedsDisplay()
    }
    
    func redo() {
        print("redo")
        mode = .usual
        guard undoneObjects.count > 0 else {return}
        let lastState = undoneObjects.removeLast()
        stateStack.append(State(completedObjects: drawObjects, newCurve: newCurve))
        if let previousObjects = lastState.completedObjects {
            drawObjects = previousObjects
        }
        newCurve = lastState.newCurve
        save()
        poincareView.setNeedsDisplay()
    }
    
 
    func clearPicture() {
        print("In clearPicture with \(guidelines.count) guidelines")
        stateStack.append(State(completedObjects: drawObjects, newCurve: newCurve))
        drawObjects = []
        newCurve = nil
        poincareView.setNeedsDisplay()
    }
    
    
    // MARK: - Adding points and drawing
    let drawRadius = 0.99
    
    func hPoint(_ rawLocation: CGPoint) -> HPoint? {
        var thing = rawLocation
        thing = thing.applying(toPoincare)
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
    
    
    
    func makeDot(_ rawLocation: CGPoint) {
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
        mode = .usual
        undoneObjects = []
        guard let curve = newCurve else { return }
        curve.complete()
        print("Appending a curve with \(curve.points.count) points")
        stateStack = stateStack.filter {$0.completedObjects != nil}
        stateStack.append(State(completedObjects: drawObjects, newCurve: nil))
        newCurve = nil
        drawObjects.append(curve)
        save()
        poincareView.setNeedsDisplay()
    }
    
    var printingTouches = true
    
    func nearbyPointsTo(_ point: HPoint, withinDistance distance: Double) -> [MatchedPoint] {
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
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touchesBegan", when: tracingGesturesAndTouches)
        super.touchesBegan(touches, with: event)
        guard touches.count == 1 else {return}
        if suppressTouches {return}
        print("Saving objects", when: tracingGesturesAndTouches)
        oldDrawObjects = drawObjects.map { $0.copy() }
        mode = .moving
        if let touch = touches.first {
            if let z = hPoint(touch.location(in: poincareView)) {
                let distance = touchDistance
                matchedPoints = nearbyPointsTo(z, withinDistance: distance)
                
                if matchedPoints.count == 0 {
                    addPointToArcs(z)
                }
            }
        }
        touchesMoved(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        //        if printingTouches { print("touchesMoved") }
        super.touchesMoved(touches, with: event)
        guard touches.count == 1 else {return}
        if suppressTouches {return}
        if let touch = touches.first {
            if let z = hPoint(touch.location(in: poincareView)) {
                for m in matchedPoints {
                    m.moveTo(z)
                }
            }
        }
        poincareView.setNeedsDisplay()
    }
    
    // TODO: Make points nearby the last touch jump to it
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touchesEnded", when:  tracingGesturesAndTouches)
        guard touches.count == 1 else {return}
        super.touchesEnded(touches, with: event)
        if suppressTouches {return}
        touchesMoved(touches, with: event)
        if let touch = touches.first {
            if var z = hPoint(touch.location(in: poincareView)) {
                let g = groupSystem(cutoffDistance: touchDistance, center: z, objects: fixedPoints)
                // THIS WILL BE UNDEFINED if g has more than one element
                for (object, group) in g {
                    for action in group {
                        z = action.motion.appliedTo(object.centerPoint)
                        for m in matchedPoints {
                            m.moveTo(z)
                        }
                    }
                }
                
                let nearbyPointsToEndpoint = nearbyPointsTo(z, withinDistance: touchDistance)
                for m in nearbyPointsToEndpoint {
                    m.moveTo(z)
                }
              }
        }
        for m in matchedPoints {
            m.cleanUp()
        }
        mode = .usual
        stateStack.append(State(completedObjects: oldDrawObjects, newCurve: nil))
        oldDrawObjects = []
        save()
        poincareView.setNeedsDisplay()
    }
    
    
    // MARK: Adding a point to a line
    func addPointToArcs(_ z: HPoint) {
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
            instructions.sort() { $0.0 < $1.0 }
            for i in 0..<instructions.count {
                let (index, _ , pointMask) = instructions[i]
                matchedPoints.append(MatchedPoint(index: index + i + 1, polyline: polyline, mask: pointMask))
            }
        }
    }
    
    // MARK: - Color Picker Preview Source and Delegate
    var colorToStartWith: UIColor = UIColor.blue
    
    var changingColor = false
    
    struct ColorChangeInformation {
        var polygon: HyperbolicPolygon
        var colorNumber: ColorNumber
        var changeColorTableEntry: Bool
    }
    
    // Slightly naughty to use an implicitly unwrapped optional
    var colorChangeInformation: ColorChangeInformation!
    
    var useColorTable: Bool {
        set { colorChangeInformation.polygon.useFillColorTable = newValue }
        get { return colorChangeInformation.polygon.useFillColorTable }
    }
    
    func applyColor(_ color: UIColor) {
        let polygon = colorChangeInformation.polygon
        if polygon.useFillColorTable {
            polygon.fillColorTable[colorChangeInformation.colorNumber] = color
        } else {
            polygon.fillColor = color
        }
    }
    
    func applyColorAndReturn(_ color: UIColor) {
        applyColor(color)
        dismiss(animated: true, completion: nil)
        cancelEffectOfTouches()
        changingColor = false
        poincareView.setNeedsDisplay()
    }
    
    // TODO: Fix the problem with the segue
    func setColor(_ polygon: HyperbolicPolygon, withAction action: Action) {
        changingColor = true
        cancelEffectOfTouches()
        let colorNumber = action.action.mapping[ColorNumber.baseNumber]!
        colorToStartWith = polygon.fillColorTable[colorNumber]!
        colorChangeInformation = ColorChangeInformation(polygon: polygon, colorNumber: colorNumber, changeColorTableEntry: true)
        performSegue(withIdentifier: "chooseColor", sender: self)
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
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == longPressRecognizer {
            return gestureRecognizer.numberOfTouches == 1
        } else {
            return true
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
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
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer.name == "gallery" {
            let z = hPoint(touch.location(in: poincareView))
            return z == nil
        } else {
            return true
        }
    }

    
    
    @IBAction func simplePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            drawing = false
            //            newCurve = nil
            mode = mode == .drawing ? .drawing :  .moving
            cancelEffectOfTouches()
        case .changed:
            let translation = gesture.translation(in: poincareView)
            //            println("Raw translation: \(translation.x, translation.y)")
            gesture.setTranslation(CGPoint.zero, in: poincareView)
            var a = Complex64(Double(translation.x/scale), Double(translation.y/scale))
            a = a/(a.abs+1) // This prevents bad transformations
            let M = HyperbolicTransformation(a: -a)
            //            println("Moebius translation: \(M)")
            mask = M.following(mask)
            recomputeMask()
            poincareView.setNeedsDisplay()
        case .ended:
            mode = mode == .drawing ? .drawing : .usual
            recomputeMask()
            poincareView.setNeedsDisplay()
            drawing = true
        default: break
        }
    }
    
    @IBOutlet var singleTapRecognizer: UITapGestureRecognizer!
    
    @IBOutlet var doubleTapRecognizer: UITapGestureRecognizer!
    
    @IBAction func singleTap(_ sender: UITapGestureRecognizer) {
        //        print("tapped")
        let z = hPoint(sender.location(in: poincareView))
        if z == nil {
            print("toggling guidelines")
            drawGuidelines = !drawGuidelines
            mode = .usual
        } else if newCurve != nil {
            stateStack.append(State(completedObjects: nil, newCurve: (newCurve!.copy() as! HyperbolicPolyline)))
            newCurve!.addPoint(z!)
        }
        poincareView.setNeedsDisplay()
    }
    
    
    @IBAction func doubleTap(_ sender: UITapGestureRecognizer) {
        if newCurve == nil {
            let z = hPoint(sender.location(in: poincareView))
            guard z != nil else { return }
            newCurve = HyperbolicPolygon(z!)
            stateStack.append(State(completedObjects: nil, newCurve: nil))
            mode = .drawing
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
    
    @IBAction func longPress(_ sender: UILongPressGestureRecognizer) {
        let z = hPoint(sender.location(in: poincareView))
        if let point = z {
            if tracingGesturesAndTouches {
                drawObjects.append(HyperbolicDot(center: point, radius: touchDistance))
            }
            cancelEffectOfTouches()
//            addPointToArcs(point)
            let polylines = drawObjects.filter({$0 is HyperbolicPolyline})
            let g = groupSystem(cutoffDistance: touchDistance, center: point, objects: polylines).reversed()
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
    
    @IBAction func zoom(_ gesture: UIPinchGestureRecognizer) {
        //        println("Zooming")
        switch gesture.state {
        case .began:
            mode = Mode.moving
            drawing = false
            //            newCurve = nil
            cancelEffectOfTouches()
        case .changed:
            let newMultiplier = multiplier * gesture.scale
            multiplier = newMultiplier >= 1 ? newMultiplier : 1
            gesture.scale = 1
        case .ended:
            drawing = true
            mode = Mode.usual
            galleryContext?.canSwitchPage = (multiplier == 1)
        default: break
        }
        poincareView.setNeedsDisplay()
    }
    
    
    func cancelEffectOfTouches() {
        doNothing = false
        if oldDrawObjects.count > 0 {
            print("Restoring objects and cancelling move points", when: tracingGesturesAndTouches)
            drawObjects = oldDrawObjects
            oldDrawObjects = []
            matchedPoints = []
            save()
            poincareView.setNeedsDisplay()
        }
    }
    // MARK: Outlets to other views
    
    @IBOutlet weak var poincareView: PoincareView! {
        didSet {
            poincareView.dataSource = self
        }
    }
    
 
//      MARK: - Navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier! {
        case "chooseColor":
            changingColor = true
            let triangleViewController = segue.destination as! TriangleViewController
            triangleViewController.delegate = self
        case "help":
            print("Saving old objects", when: tracingGesturesAndTouches)
            doNothing = true
            let helpVC = segue.destination as! HelpViewController
            helpVC.presentingCVC = self
            // the next line is probably ineffective and unnecessary
            oldDrawObjects = drawObjects
        default:
            break
        }
     }

    
}

