//
//  Protocols.swift
//  ColorStudent
//
//  Created by Jeremy Kahn on 11/7/15.
//  Copyright © 2015 Jeremy Kahn. All rights reserved.
//

import UIKit

protocol ColorPickerPreviewSource {
    
    var preview: UIView { get }
    
    func applyColorToPreview(color: UIColor)
    
}

protocol ColorPickerDelegate {
    
    var colorToStartWith: UIColor { get }
    
    func applyColorAndReturn(color: UIColor)
    
}

protocol ZoomingColorPickerDelegate: ColorPickerDelegate {
    
    var zoomToStartWith: CGFloat { get }
    
}

class DefaultColorPickerPreviewSource: ColorPickerPreviewSource {
    
    var preview = UIView()
    
    func applyColorToPreview(color: UIColor) {
        preview.backgroundColor = color
    }
    
}

class DefaultColorPickerDelegate: ColorPickerDelegate {
    
    var colorToStartWith = UIColor.whiteColor()
    
    func applyColorAndReturn(color: UIColor) {
        print("Chosen color \(color)")
    }
    
}

