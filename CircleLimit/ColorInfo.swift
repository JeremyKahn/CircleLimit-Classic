//
//  ColorInfo.swift
//  CircleLimitClassic
//
//  Created by Kahn on 6/7/18.
//  Copyright © 2018 Jeremy Kahn. All rights reserved.
//

import UIKit

class ColorInfo: Codable {
    
    var lineColor: UIColor = UIColor.black
    
    var fillColorTable: ColorTable = [1: UIColor.blue, 2: UIColor.green, 3: UIColor.red, 4: UIColor.yellow]
    
    var fillColor: UIColor = UIColor.clear
    
    init() {}
    
    convenience init(fillColor: UIColor) {
        self.init()
        self.fillColor = fillColor
    }
    
    enum CodingKeys: String, CodingKey {
        case lineColor
        case fillColorTable
        case fillColor
    }

    
    func encode(to encoder: Encoder) throws {
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(lineColor.data, forKey: .lineColor)
            try container.encode(fillColor.data, forKey: .fillColor)
            var dataTable: [ColorNumber: ColorData] = [:]
            for i in fillColorTable.keys {
                dataTable[i] = fillColorTable[i]!.data
            }
            try container.encode(dataTable, forKey: .fillColorTable)
        }
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let fillColorData = try values.decode(ColorData.self, forKey: .fillColor)
        fillColor = UIColor(data: fillColorData)
        let lineColorData = try values.decode(ColorData.self, forKey: .lineColor)
        lineColor = UIColor(data: lineColorData)
        let dataTable = try values.decode([ColorNumber:ColorData].self, forKey: .fillColorTable)
        fillColorTable = [:]
        for i in dataTable.keys {
            fillColorTable[i] = UIColor(data: dataTable[i]!)
        }
    }


}


