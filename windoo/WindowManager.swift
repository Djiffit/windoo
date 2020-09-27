//
//  WIndowManager.swift
//  windoo
//
//  Created by Kutvonen, Konsta on 9/24/20.
//

import Foundation
import Cocoa
import HotKey

func isWindow(_ window: AXUIElement) -> Bool {
    var currSize : AnyObject?
    AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &currSize)
    return currSize != nil
}

class Display {
    var layouts: [Layout]!
    var activeLayout = 0
    var activePos = 0
    var frame: NSRect
    
    init(windows: [Window], frame: NSRect) {
        self.frame = frame
        print(frame)
        layouts = [SingleWindowLayout(frame: frame, windows: windows),
                   TwoWindowSideBySide(frame: frame, windows: windows),
                   ThreeWindowLayout(frame: frame, windows: windows),
        ]
    }
    
    func changeLayout(diff: Int) {
        print("changelayout \(activeLayout)")
        let currActive = layouts[activeLayout].currActive()
        let windows = layouts[activeLayout].getWindows()
        activeLayout = mod(activeLayout + diff, layouts.count)
        layouts[activeLayout].setActive(act: currActive)
        if layouts[activeLayout].getWindows().count > 0 {
            layouts[activeLayout].activate(with: windows)
        }
    }
    
    func changeWindowPos(by: Int) {
        if layouts[activeLayout].getWindows().count > 0 {
            layouts[activeLayout].changeWindowPos(by: by)
        }
    }
    
    func shiftWindows(change: Int) {
        if layouts[activeLayout].getWindows().count > 0 {
            layouts[activeLayout].shiftLayout(by: change)
        }
    }
    
    func activateWindow() {
        print("activating?")
        layouts[activeLayout].activate()
        print("Activated")
    }
}

class WindowManager {
    
    var activeDisplay = 0
    var displays: [Display] = []
    let forward = HotKey(key: .d, modifiers: [.option])
    let backward = HotKey(key: .a, modifiers: [.option])
    let windowForward = HotKey(key: .d, modifiers: [.option, .shift])
    let windowBackward = HotKey(key: .a, modifiers: [.option, .shift])
    let toggleLayout = HotKey(key: .c, modifiers: [.option])
    let up = HotKey(key: .w, modifiers: [.option])
    let down = HotKey(key: .s, modifiers: [.option])
    
    
    init() {
        
        
        forward.keyDownHandler = { [weak self] in
            self?.getDisplay().shiftWindows(change: 1)
        }
        backward.keyDownHandler = { [weak self] in
            self?.getDisplay().shiftWindows(change: -1)
        }
        windowForward.keyDownHandler = { [weak self] in
            self?.getDisplay().changeWindowPos(by: 1)
        }
        windowBackward.keyDownHandler = { [weak self] in
            self?.getDisplay().changeWindowPos(by: -1)
        }
        toggleLayout.keyDownHandler = { [weak self] in
            self?.getDisplay().changeLayout(diff: 1)
        }
        up.keyDownHandler = { [weak self] in
            self?.changeDisplay(by: -1)
        }
        down.keyDownHandler = { [weak self] in
            self?.changeDisplay(by: 1)
        }
        
        fetchWindows()
//        listDisplays()
    }
    
    func getDisplay() -> Display {
        return displays[activeDisplay]
    }
    
    func changeDisplay(by: Int) {
        activeDisplay = mod(activeDisplay + by, displays.count)
        getDisplay().activateWindow()
    }
    
    func activateDisplay() {
        getDisplay().activateWindow()
    }
    
    func listDisplays() {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        let infoList = windowsListInfo as! [[String:Any]]
        let visibleWindows = infoList.filter{ $0["kCGWindowLayer"] as! Int == 0 }
        var mainWindows: [String] = []
        var secWindows: [String] = []
        for entry in visibleWindows {
            let owner = entry[kCGWindowOwnerName as String] as! String
            var bounds = entry[kCGWindowBounds as String] as! [String: Int]
            let pid = entry[kCGWindowOwnerPID as String] as? Int32
            let rect = CGRect(x: bounds["X"]!, y: bounds["Y"]!, width: bounds["Width"]!, height: bounds["Height"]!)
            if ((NSScreen.screens[0].frame.contains(rect))) {
                mainWindows.append(owner)
            } else {
                secWindows.append(owner)
            }
            
        }
        print(NSScreen.screens.first?.deviceDescription)
        print(NSScreen.screens.first?.frame)
        print(NSEvent.mouseLocation, "mouse")
        
        for screen in NSScreen.screens {
            print(screen.frame, screen)
        }
        
        print(mainWindows, "first")
        print(secWindows, "sec")
    }
    
    
    
    func moveWindow(window: AXUIElement, to: CGPoint, size: CGSize) {
        var newPoint = to
        var newSize = size
        var position : CFTypeRef
        var size : CFTypeRef
        
//        AXUIElementSetAttributeValue(window, kAXFrontmostAttribute as CFString, true as CFBoolean)
//        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, true as CFBoolean)
        position = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!,&newPoint)!;
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position);
        
        size = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!,&newSize)!;
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size);
    }
    
    func checkPermissions() {
        let opt: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(opt)
        
        if !accessEnabled {
            print("Access Not Enabled")
        }
    }
    
    
    func fetchWindows() {
        print("Listing windows")
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        let infoList = windowsListInfo as! [[String:Any]]
        let visibleWindows = infoList.filter{ $0["kCGWindowLayer"] as! Int == 0 }
        var mainWindows: [Window] = []
        var secWindows: [Window] = []
        
        checkPermissions()
        
        print("Start from da top")
        for entry in visibleWindows {
            let owner = entry[kCGWindowOwnerName as String] as! String
            var bounds = entry[kCGWindowBounds as String] as! [String: Int]
            let pid = entry[kCGWindowOwnerPID as String] as? Int32
            let rect = CGRect(x: bounds["X"]!, y: bounds["Y"]!, width: bounds["Width"]!, height: bounds["Height"]!)
            let appRef = AXUIElementCreateApplication(pid!);
            var value: AnyObject?
            var windows: Set<AXUIElement> = []
            let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
            print(bounds, owner)
            if let windowList = value as? [AXUIElement] {
                for window in windowList.reversed()
                {
                    if isWindow(window) && !windows.contains(window) {
                        let windWrapper = (Window(pid: pid!, owner: owner, window: window))
                        
                        if ((NSScreen.screens[0].frame.contains(rect))) {
                            mainWindows.append(windWrapper)
                        } else {
                            secWindows.append(windWrapper)
                        }
                    }
                }
            }
            
        }
        
        print(NSScreen.screens[0].frame)
        print(NSScreen.screens[1].frame)
        var secFrame = NSScreen.screens[1].frame
        secFrame.origin.y = 2183
        print(mainWindows)
        displays = [Display(windows: mainWindows, frame: NSScreen.screens[0].frame), Display(windows: secWindows, frame: secFrame)]
        activateDisplay()

    }
    
    func switchToApp(withWindow windowNumber: Int32) {
        let options = CGWindowListOption(arrayLiteral: CGWindowListOption.excludeDesktopElements, CGWindowListOption.optionOnScreenOnly)
        let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        guard let infoList = windowListInfo as NSArray? as? [[String: AnyObject]] else { return }
        if let window = infoList.first(where: { ($0["kCGWindowNumber"] as? Int32) == windowNumber}), let pid = window["kCGWindowOwnerPID"] as? Int32 {
            let app = NSRunningApplication(processIdentifier: pid)
            app?.activate(options: .activateIgnoringOtherApps)
        }
    }
    
    func tryFocus() {
//        let i = Int.random(in: 0..<windows.count)
//        let window = windows[i].window
//        var res: CFArray?
//        AXUIElementCopyActionNames(window, &res)
//        AXUIElementPerformAction(window, "AXRaise" as CFString)
//        AXUIElementSetAttributeValue(window, kAXFrontmostAttribute as CFString, true as CFBoolean)
//        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, true as CFBoolean)
//        for app in NSWorkspace.shared.runningApplications {
//            if app.localizedName == windows[i].owner {
//                app.activate(options: .activateIgnoringOtherApps)
//            }
//        }
        
    }
    
}


extension CFArray: Sequence {
    
    public func makeIterator() -> Iterator {
        return Iterator(self)
    }
    
    public struct Iterator: IteratorProtocol {
        
        var array: NSArray
        var idx = 0
        
        init(_ array: CFArray){
            self.array = array as NSArray
        }
        
        public mutating func next() -> Any? {
            guard idx < array.count else { return nil }
            let value = array[idx]
            idx += 1
            return value
        }
        
    }
    
}


func requestAccess() {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
    let accessEnabled = AXIsProcessTrustedWithOptions(options)
    
    if !accessEnabled {
        print("Access Not Enabled")
    }
}

func describeWindows(options: CGWindowListOption) {
//    let visibleWindows = infoList.filter{ $0["kCGWindowLayer"] as! Int == 0 }
//
//
//    print(visibleWindows)
//    let screens = NSScreen.screens
//    let frame = screens[1].frame
//    moveWindow(window: (visibleWindows.first as! AXUIElement))
//
//    for window in visibleWindows {
//        let rect = NSRect(dictionaryRepresentation: window["kCGWindowBounds"] as! CFDictionary)!
//        print(rect)
//        for screen in screens {
//            if screen.frame.contains(rect) {
//                print(window["kCGWindowOwnerName"])
//                print(screens.first { $0.frame.contains(rect)})
//                print("CONTAINED !!!!!", screen)
//            }
//        }
//    }
}

func moveWindow(window: AXUIElement) {
    var position : CFTypeRef
    var size : CFTypeRef
    var newPoint = CGPoint(x: 0, y: 0)
    var newSize = CGSize(width: 300, height: 800)
    
    position = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!,&newPoint)!;
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position);
    
    size = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!,&newSize)!;
    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size);
}


//"kCGWindowOwnerName": Quip, "kCGWindowMemoryUsage": 1152, "kCGWindowOwnerPID": 901, "kCGWindowNumber": 291, "kCGWindowStoreType": 1, "kCGWindowSharingState": 0], ["kCGWindowSharingState": 0, "kCGWindowBounds": {
//    Height = 22;
//    Width = 1680;
//    X = 0;
//    Y = 0;
//},
//
//, "kCGWindowOwnerPID": 46114, "kCGWindowStoreType": 1, "kCGWindowLayer": 1000], ["kCGWindowSharingState": 0, "kCGWindowOwnerName": Safari, "kCGWindowMemoryUsage": 1152, "kCGWindowStoreType": 1, "kCGWindowBounds": {
//    Height = 30;
//    Width = 685;
//    X = 80;
//    Y = 0;
//},



//let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
//let infoList = windowsListInfo as! [[String:Any]]
//let applications = NSWorkspace.shared.runningApplications
////        print( NSRunningApplication.runningApplications(withBundleIdentifier: "org.mozilla.firefox").first.)
//
//print(NSApp.window(withWindowNumber: 13011))
//print(applications.count)
//for app in applications {
//    print(app.bundleIdentifier)
//}
//
//let screen = NSScreen.screens.first
//
//for window in visibleWindows {
//    print(window)
//}
