//
//  FileMaster.swift
//  CircleLimitClassic
//
//  Created by Kahn on 6/7/18.
//  Copyright © 2018 Jeremy Kahn. All rights reserved.
//

import UIKit

func filePath(fileName: String) -> URL {
    let dirs : [String] = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)
    
    let dir = dirs[0] //documents directory
    let result = dir.appending("/" + fileName)
    print("Local path = \(filePath)")
    
    return URL(fileURLWithPath: result)
}
