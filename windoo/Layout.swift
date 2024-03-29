//
//  Layout.swift
//  windoo
//
//  Created by Kutvonen, Konsta on 9/26/20.
//

import Foundation
import SwiftUI

func mod(_ a: Int, _ n: Int) -> Int {
    if n <= 0 {
        return 0
    }
    let r = a % n
    return r >= 0 ? r : r + n
}

func getStatusIcons(windows: [Window], leftSide: Int, activeWindow: Int, numWindows: Int) -> ([String], Int, Int) {
    if windows.count == 0 {
        return ([], 0, 0)
    }
    let numWindows = numWindows - 1
    var used: Set<AXUIElement> = []
    var left = leftSide
    var right = activeWindow
    var leftarr: [String] = []
    var rightarr: [String] = []
    var midarr: [String] = []
    var leftSide = leftSide
    var activeOffset = 0
    
    for offset in 0..<numWindows + 1 {
        if windows[leftSide].window == windows[activeWindow].window {
            activeOffset = offset
        }
        midarr.append(windows[leftSide].owner)
        used.insert(windows[leftSide].window)
        leftSide = mod(leftSide + 1, windows.count)
    }
    
    while leftarr.count + rightarr.count + midarr.count < windows.count && (!used.contains(windows[left].window) && (!used.contains(windows[right].window))) {
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
    
    return (leftarr.reversed() + midarr + rightarr, leftarr.count, activeOffset + leftarr.count)
}

func disaengageAll() {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
    let infoList = windowsListInfo as! [[String:Any]]
    let visibleWindows = infoList.filter{ $0["kCGWindowLayer"] as! Int == 0 }
    
    print("Start from da top")
    for entry in visibleWindows {
        let owner = entry[kCGWindowOwnerName as String] as! String
        var bounds = entry[kCGWindowBounds as String] as! [String: Int]
        let pid = entry[kCGWindowOwnerPID as String] as? Int32
        let rect = CGRect(x: bounds["X"]!, y: bounds["Y"]!, width: bounds["Width"]!, height: bounds["Height"]!)
        let appRef = AXUIElementCreateApplication(pid!);
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
        if let windowList = value as? [AXUIElement] {
            for window in windowList.reversed()
            {
                if isWindow(window){
                    deActivate(window: window)
                    AXUIElementSetAttributeValue(window, "AXMain" as CFString, 0 as AnyObject)
                    AXUIElementSetAttributeValue(window, "AXFocused" as CFString, 0 as AnyObject)
                    AXUIElementSetAttributeValue(window, kAXFrontmostAttribute as CFString,0 as AnyObject)
                    AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, 0 as AnyObject)
                }
            }
        }
        
    }
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
    
    var currSize : AnyObject?
    AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &currSize)
    activateWindow(window: window, owner: windowWrapper.owner, activate: false)
}

func activateWindow(window: AXUIElement, owner: String, activate: Bool) {
//    AXUIElementSetAttributeValue(window, kAXFrontmostAttribute as CFString, 1 as AnyObject)
//    AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, 1 as AnyObject)
    AXUIElementSetAttributeValue(window, "AXMain" as CFString, 1 as AnyObject)
    AXUIElementSetAttributeValue(window, "AXFocused" as CFString, 1 as AnyObject)
    AXUIElementSetAttributeValue(window, kAXFrontmostAttribute as CFString, 1 as AnyObject)
    AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, 1 as AnyObject)
    
    if activate {
        for app in NSWorkspace.shared.runningApplications {
            if app.localizedName == owner && !app.isActive {
                app.activate(options: .activateIgnoringOtherApps)
            }
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
    func changeWindowPos(by: Int) -> Void
    func getWindows() -> [Window]
    func removeActive() -> Window
    func addWindow(window: Window, active: Bool) -> Void
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
    var leftSide = 0
    
    init(frame: NSRect, windows: [Window]) {
        self.frame = frame
        self.windows = windows
    }
    
    func getWindows() -> [Window] {
        return windows
    }
    
    func addWindow(window: Window, active: Bool) {
        if active {
            windows.insert(window, at: activeWindow)
            activate()
        } else {
            windows.append(window)
        }
    }
    
    func removeActive() -> Window {
        let targ = windows[activeWindow]
        windows = windows.filter({ (wind) -> Bool in
            return wind != targ
        })
        return targ
    }
    
    func setActive(act: Int) {
        activeWindow = max(0, min(act, windows.count - 1))
        leftSide = activeWindow
    }
    
    func currActive() -> Int {
        return activeWindow
    }
    
    func changeWindowPos(by: Int) {
        let otherInd = mod(activeWindow + by, windows.count)
        let temp = windows[activeWindow]
        windows[activeWindow] = windows[otherInd]
        windows[otherInd] = temp
        shiftLayout(by: by)
    }
    
    func shiftLayout(by: Int) {
        if windows.count == 0 { return }
        let same = leftSide == activeWindow
        activeWindow += by
        if activeWindow == windows.count { activeWindow = 0 }
        if activeWindow < 0 { activeWindow = windows.count - 1 }
        if by < 0 && same {
            leftSide = activeWindow
        }
        
        if leftSide > activeWindow && (leftSide != windows.count - 1 || activeWindow > 0) || activeWindow - leftSide > 1 {
            leftSide = mod(leftSide + 1, windows.count)
        }
        
        activate()
    }
    
    func activate(with: [Window]) {
        windows = with
        activate()
    }
    
    func getWindowsToResize() -> [Window] {
        if windows.count == 0 { return [] }
        var res = [windows[leftSide]]
        
        if windows.count > 1 {
            res.append(windows[mod(leftSide + 1, windows.count)])
        }
        
        return res
    }
    
    func getPositions() -> [ResizePosition] {
        let width = frame.width
        let height = frame.height
        let windSize = CGSize(width: width / 2, height: height)
        return [
            ResizePosition(position: frame.origin, size: windSize),
            ResizePosition(position: CGPoint(x: frame.origin.x + width / 2, y: frame.origin.y), size: windSize),
        ]
        
    }
    
    func activate() {
        windows = windows.filter({ (wind) -> Bool in
            return isWindow(wind.window)
        })
        activeWindow = max(0, min(activeWindow, windows.count - 1))
        leftSide = max(0, min(leftSide, windows.count - 1))
        let positions = getPositions()
        let opWindows = getWindowsToResize()
        
//        for window in windows {
//            AXUIElementSetAttributeValue(window.window, "AXFocused" as! CFString, 0 as AnyObject)
//            AXUIElementSetAttributeValue(window.window, "AXMain" as! CFString, 0 as AnyObject)
//        }
        
        for i in (0..<min(numWindows, windows.count)) {
            moveWindow(windowWrapper: opWindows[i], with: positions[i])
        }
        if windows.count > 0 {
            activateWindow(window: windows[activeWindow].window, owner: windows[activeWindow].owner, activate: true)
        }
        let actives = getStatusIcons(windows: windows, leftSide: leftSide, activeWindow: activeWindow, numWindows: numWindows)
//        AppDelegate.createStatusImage(currApps: actives.0, w: 18, h: 18, activeInds: [actives.1, actives.1 + 1], activeWindow: actives.2)
        AppDelegate.createStatusImage(currApps: windows.map({ (w) -> String in
            w.owner
        }), w: 18, h: 18, activeInds: [leftSide, mod(leftSide + 1, windows.count)], activeWindow: activeWindow)
    }
    
    
    func disable() {
        for window in windows {
            AXUIElementSetAttributeValue(window.window, "AXFocused" as CFString, 0 as AnyObject)
            AXUIElementSetAttributeValue(window.window, "AXMain" as CFString, 0 as AnyObject)
        }
    }
}

class ThreeWindowLayout: Layout {
    var windows: [Window] = []
    var activeWindow = 0
    var frame: NSRect
    let numWindows = 3
    var leftSide = 0
    
    init(frame: NSRect, windows: [Window]) {
        self.frame = frame
        self.windows = windows
    }
    
    
    func removeActive() -> Window {
        let targ = windows[activeWindow]
        windows = windows.filter({ (wind) -> Bool in
            return wind != targ
        })
        return targ
    }
    
    func setActive(act: Int) {
        activeWindow = max(0, min(act, windows.count - 1))
        leftSide = activeWindow
    }
    
    func addWindow(window: Window, active: Bool) {
        if active {
            windows.insert(window, at: activeWindow)
            activate()
        } else {
            windows.append(window)
        }
    }
    
    func getWindows() -> [Window] {
        return windows
    }
    
    func changeWindowPos(by: Int) {
        let otherInd = mod(activeWindow + by, windows.count)
        let temp = windows[activeWindow]
        windows[activeWindow] = windows[otherInd]
        windows[otherInd] = temp
        shiftLayout(by: by)
    }
    
    
    func currActive() -> Int {
        return activeWindow
    }
    
    func shiftLayout(by: Int) {
        if windows.count == 0 { return }
        let same = leftSide == activeWindow
        activeWindow += by
        if activeWindow == windows.count { activeWindow = 0 }
        if activeWindow < 0 { activeWindow = windows.count - 1 }
        if by < 0 && same || leftSide == activeWindow {
            leftSide = activeWindow
        } else {
            
            var numsBetween = 0
            var left = mod(leftSide + 1, windows.count)
            while left != activeWindow {
                left = mod(left + 1, windows.count)
                numsBetween += 1
            }
            if numsBetween > 1 {
                leftSide = mod(leftSide + 1, windows.count)
            }
        }
        
        activate()
    }
    
    func activate(with: [Window]) {
        windows = with
        activate()
    }
    
    func getWindowsToResize() -> [Window] {
        if windows.count == 0 { return [] }
        var res = [windows[leftSide]]
        
        if windows.count > 1 {
            res.append(windows[mod(leftSide + 1, windows.count)])
        }
        if windows.count > 2 {
            res.append(windows[mod(leftSide + 2, windows.count)])
        }
        
        return res
    }
    
    func getPositions() -> [ResizePosition] {
        let width = frame.width
        let height = frame.height
        let windSize = CGSize(width: width / 3, height: height)
        return [
            ResizePosition(position: frame.origin, size: windSize),
            ResizePosition(position: CGPoint(x: frame.origin.x + width / 3, y: frame.origin.y), size: windSize),
            ResizePosition(position: CGPoint(x: frame.origin.x + width / 3 * 2, y: frame.origin.y), size: windSize),
        ]
        
    }
    
    func activate() {
        windows = windows.filter({ (wind) -> Bool in
            return isWindow(wind.window)
        })
        activeWindow = max(0, min(activeWindow, windows.count - 1))
        leftSide = max(0, min(leftSide, windows.count - 1))
        let positions = getPositions()
        let opWindows = getWindowsToResize()
        
//        for window in windows {
//            AXUIElementSetAttributeValue(window.window, "AXFocused" as! CFString, 0 as AnyObject)
//            AXUIElementSetAttributeValue(window.window, "AXMain" as! CFString, 0 as AnyObject)
//        }
        
        for i in (0..<min(numWindows, windows.count)).reversed() {
            moveWindow(windowWrapper: opWindows[i], with: positions[i])
        }
        if windows.count > 0 {
            activateWindow(window: windows[activeWindow].window, owner: windows[activeWindow].owner, activate: true)
        }

        let actives = getStatusIcons(windows: windows, leftSide: leftSide, activeWindow: activeWindow, numWindows: numWindows)
//        AppDelegate.createStatusImage(currApps: actives.0, w: 18, h: 18, activeInds: [actives.1, actives.1 + 1, actives.1 + 2], activeWindow: actives.2)
        AppDelegate.createStatusImage(currApps: windows.map({ (w) -> String in
            w.owner
        }), w: 18, h: 18, activeInds: [leftSide, mod(leftSide + 1, windows.count), mod(leftSide + 2, windows.count)], activeWindow: activeWindow)
    }
    
    
    
    func disable() {
        for window in windows {
            AXUIElementSetAttributeValue(window.window, "AXFocused" as CFString, 0 as AnyObject)
            AXUIElementSetAttributeValue(window.window, "AXMain" as CFString, 0 as AnyObject)
        }
    }
}

class SingleWindowLayout: Layout {
    var windows: [Window] = []
    var activeWindow = 0
    var leftSide = 0
    var frame: NSRect
    let numWindows = 1
    
    init(frame: NSRect, windows: [Window]) {
        self.frame = frame
        self.windows = windows
    }
    
    func addWindow(window: Window, active: Bool) {
        if active {
            windows.insert(window, at: activeWindow)
            activate()
        } else {
            windows.append(window)
        }
    }
    
    func getWindows() -> [Window] {
        return windows
    }
    
    func setActive(act: Int) {
        activeWindow = max(0, min(act, windows.count - 1))
        leftSide = activeWindow
    }
    
    func removeActive() -> Window {
        let targ = windows[activeWindow]
        windows = windows.filter({ (wind) -> Bool in
            return wind != targ
        })
        return targ
    }
    
    func currActive() -> Int {
        return activeWindow
    }
    
    func changeWindowPos(by: Int) {
        let otherInd = mod(activeWindow + by, windows.count)
        let temp = windows[activeWindow]
        windows[activeWindow] = windows[otherInd]
        windows[otherInd] = temp
        shiftLayout(by: by)
    }
    
    func shiftLayout(by: Int) {
        if windows.count == 0 { return }
        activeWindow = mod(activeWindow + by, windows.count)
        leftSide = activeWindow
        
        activate()
    }
    
    func activate(with: [Window]) {
        windows = with
        activate()
    }
    
    func getWindowsToResize() -> [Window] {
        if windows.count == 0 { return [] }
        if activeWindow < 0 || activeWindow >= windows.count {
            activeWindow = mod(activeWindow, windows.count)
        }
        return [windows[activeWindow]]
    }
    
    func getPositions() -> [ResizePosition] {
        let width = frame.width
        let height = frame.height
        let windSize = CGSize(width: width, height: height)
        return [
            ResizePosition(position: frame.origin
                           , size: windSize)
        ]
        
    }
    
    func activate() {
        windows = windows.filter({ (wind) -> Bool in
            return isWindow(wind.window)
        })
        activeWindow = max(0, min(activeWindow, windows.count - 1))
        leftSide = max(0, min(leftSide, windows.count - 1))
        
        
        let positions = getPositions()
        let opWindows = getWindowsToResize()
        
//        for window in windows {
//            AXUIElementSetAttributeValue(window.window, "AXFocused" as! CFString, 0 as AnyObject)
//            AXUIElementSetAttributeValue(window.window, "AXMain" as! CFString, 0 as AnyObject)
//        }
        for i in (0..<min(numWindows, windows.count)).reversed() {
            moveWindow(windowWrapper: opWindows[i], with: positions[i])
        }
        if windows.count > 0 {
            activateWindow(window: windows[activeWindow].window, owner: windows[activeWindow].owner, activate: true)
        }
        
        let actives = getStatusIcons(windows: windows, leftSide: leftSide, activeWindow: activeWindow, numWindows: numWindows)
//        AppDelegate.createStatusImage(currApps: actives.0, w: 18, h: 18, activeInds: [actives.1], activeWindow: actives.2)
        AppDelegate.createStatusImage(currApps: windows.map({ (w) -> String in
            w.owner
        }), w: 18, h: 18, activeInds: [leftSide, activeWindow], activeWindow: activeWindow)
    }
    
    func disable() {
        for window in windows {
            AXUIElementSetAttributeValue(window.window, "AXFocused" as CFString, 0 as AnyObject)
            AXUIElementSetAttributeValue(window.window, "AXMain" as CFString, 0 as AnyObject)
        }
    }
}
