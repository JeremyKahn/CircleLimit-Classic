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

func saveStuff<T>(_ stuff: T, location file: URL) where T:Encodable {
    let jse = JSONEncoder()
    let filename = file.absoluteString
    print("Saving to file: \(filename)")
    do {
        let data = try jse.encode(stuff)
//        let jsonString = String(data: data, encoding: .utf8)
//        print(jsonString ?? "No string!")
        try data.write(to: file)
    } catch {
        print(error.localizedDescription)
        print(error)
    }
}

func loadStuff<T>(location file: URL, type: T.Type) -> T? where T:Decodable {
    let filename = file.absoluteString
//    print("Loading from file: \(filename)")
    let jsd = JSONDecoder()
    do {
        let data = try Data.init(contentsOf: file)
        let jsonString = String(data: data, encoding: .utf8)
//        print(jsonString ?? "No string!")
        let stuff = try jsd.decode(type, from: data)
        return stuff
    } catch {
        print(error.localizedDescription)
        print(error)
        return nil
    }
}

