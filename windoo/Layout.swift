//
//  Layout.swift
//  windoo
//
//  Created by Kutvonen, Konsta on 9/26/20.
//

import Foundation
import SwiftUI

func mod(_ a: Int, _ n: Int) -> Int {
    precondition(n > 0, "modulus must be positive")
    let r = a % n
    return r >= 0 ? r : r + n
}

func getStatusIcons(windows: [Window], activeWindow: Int) -> [String] {
    var used: Set<AXUIElement> = []
    var left = activeWindow
    var right = activeWindow
    var leftarr: [String] = []
    var rightarr: [String] = []
    
    while leftarr.count + rightarr.count + 1 < windows.count {
        left = mod(left - 1, windows.count)
        right = mod(right + 1, windows.count)
        if !used.contains(windows[left].window) {
            leftarr.append(windows[left].owner)
            used.insert(windows[left].window)
        }
        if !used.contains(windows[right].window) {
            rightarr.append(windows[right].owner)
            used.insert(windows[right].window)
        }
    }
    
    return leftarr.reversed() + [windows[activeWindow].owner] + rightarr
}

func moveWindow(windowWrapper: Window, with: ResizePosition) {
    var newPoint = with.position
    let window = windowWrapper.window
    var newSize = with.size
    var position : CFTypeRef
    var size : CFTypeRef
    
    position = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!,&newPoint)!;
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position);
    
    size = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!,&newSize)!;
    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size);
    
    AXUIElementSetAttributeValue(window, kAXFrontmostAttribute as CFString, 1 as AnyObject)
    AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, 1 as AnyObject)
    
    
    var currSize : AnyObject?
    AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &currSize)
    print(currSize, windowWrapper.owner)
    AXUIElementSetAttributeValue(window, "AXFocused" as CFString, 1 as AnyObject)
    AXUIElementSetAttributeValue(window, "AXMain" as CFString, 1 as AnyObject)
    
    
    for app in NSWorkspace.shared.runningApplications {
        if app.localizedName == windowWrapper.owner {
            //                app.hide()
            app.activate(options: .activateIgnoringOtherApps)
        }
    }
}

protocol Layout {
    func shiftLayout(by: Int) -> Void
    func activate(with: [Window]) -> Void
    func activate() -> Void
    func disable() -> Void
    func currActive() -> Int
    func setActive(act: Int) -> Void
}

struct ResizePosition {
    var position: CGPoint
    var size: CGSize
}

class TwoWindowSideBySide: Layout {
    var windows: [Window] = []
    var activeWindow = 0
    var frame: NSRect
    let numWindows = 2
    
    init(frame: NSRect, windows: [Window]) {
        self.frame = frame
        self.windows = windows
    }
    
    func setActive(act: Int) {
        activeWindow = act
    }
    
    func currActive() -> Int {
        return activeWindow
    }
    
    func shiftLayout(by: Int) {
        if windows.count == 0 { return }
        activeWindow += by
        if activeWindow == windows.count { activeWindow = 0 }
        if activeWindow < 0 { activeWindow = windows.count - 1 }
        activate()
    }
    
    func activate(with: [Window]) {
        windows = with
        activate()
    }
    

    
    func getWindowsToResize() -> [Window] {
        if windows.count == 0 { return [] }
        return [windows[activeWindow], activeWindow != (windows.count - 1) ? windows[activeWindow + 1] : windows[0]]
    }
    
    func getPositions() -> [ResizePosition] {
        let width = frame.width
        let height = frame.height
        let windSize = CGSize(width: width / 2, height: height)
        return [
            ResizePosition(position: CGPoint(x: 0, y: 0), size: windSize),
            ResizePosition(position: CGPoint(x: width / 2, y: 0), size: windSize),
        ]
        
    }
    
    func activate() {
        windows = windows.filter({ (wind) -> Bool in
            return isWindow(wind.window)
        })
        let positions = getPositions()
        let opWindows = getWindowsToResize()
        
        for window in windows {
            AXUIElementSetAttributeValue(window.window, "AXFocused" as! CFString, 0 as AnyObject)
            AXUIElementSetAttributeValue(window.window, "AXMain" as! CFString, 0 as AnyObject)
        }
        
        for i in (0..<numWindows).reversed() {
            moveWindow(windowWrapper: opWindows[i], with: positions[i])
        }
        
        AppDelegate.createStatusImage(currApps: getStatusIcons(windows: windows, activeWindow: activeWindow), w: 18, h: 18)
    }
    
    
    func disable() {
        
    }
}

class SingleWindowLayout: Layout {
    var windows: [Window] = []
    var activeWindow = 0
    var frame: NSRect
    let numWindows = 1
    
    init(frame: NSRect, windows: [Window]) {
        self.frame = frame
        self.windows = windows
    }
    
    func setActive(act: Int) {
        activeWindow = act
    }
    
    func currActive() -> Int {
        return activeWindow
    }
    
    func shiftLayout(by: Int) {
        if windows.count == 0 { return }
        activeWindow += by
        if activeWindow == windows.count { activeWindow = 0 }
        if activeWindow < 0 { activeWindow = windows.count - 1 }
        activate()
    }
    
    func activate(with: [Window]) {
        windows = with
        activate()
    }
    
    func getWindowsToResize() -> [Window] {
        if windows.count == 0 { return [] }
        return [windows[activeWindow]]
    }
    
    func getPositions() -> [ResizePosition] {
        let width = frame.width
        let height = frame.height
        let windSize = CGSize(width: width, height: height)
        return [
            ResizePosition(position: CGPoint(x: 0, y: 0), size: windSize)
        ]
        
    }
    
    func activate() {
        windows = windows.filter({ (wind) -> Bool in
            return isWindow(wind.window)
        })
        let positions = getPositions()
        let opWindows = getWindowsToResize()
        
        for window in windows {
            AXUIElementSetAttributeValue(window.window, "AXFocused" as! CFString, 0 as AnyObject)
            AXUIElementSetAttributeValue(window.window, "AXMain" as! CFString, 0 as AnyObject)
        }
        
        for i in (0..<numWindows).reversed() {
            moveWindow(windowWrapper: opWindows[i], with: positions[i])
        }
        
        AppDelegate.createStatusImage(currApps: getStatusIcons(windows: windows, activeWindow: activeWindow), w: 18, h: 18)
    }
    
    
    func disable() {
        
    }
}
