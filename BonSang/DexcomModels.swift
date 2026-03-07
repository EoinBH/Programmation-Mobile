//
//  DexcomModels.swift
//  BonSang
//
//  Created by Eoin Brereton Hurley on 01/03/2026.
//

import Foundation

struct DexcomResponse: Codable {
    let recordType: String
    let recordVersion: String
    let records: [GlucoseRecord]
}

struct GlucoseRecord: Codable {
    let systemTime: String
    let displayTime: String
    let value: Double
    let trend: String
    let trendRate: Double?
}
