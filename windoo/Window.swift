//
//  Window.swift
//  windoo
//
//  Created by Kutvonen, Konsta on 9/25/20.
//

import Foundation

struct Window: Hashable {
    let pid: Int32
    let owner: String
    let window: AXUIElement
}
