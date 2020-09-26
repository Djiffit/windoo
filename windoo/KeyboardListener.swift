//
//  KeyboardListener.swift
//  windoo
//
//  Created by Kutvonen, Konsta on 9/26/20.
//

import Foundation
import SwiftUI

class KeyboardListener {
    let windowManager: WindowManager
    
    init(wm: WindowManager) {
        windowManager = wm
    }
    
    func keyDown(with event: NSEvent) -> Bool {
//        print(event)
        switch event.characters {
        case "f":
            windowManager.activateWindow()
        case "a":
            windowManager.shiftWindows(change: -1)
        case "d":
            windowManager.shiftWindows(change: 1)
        default:
            print("no action")
        }
        return false
    }
}
