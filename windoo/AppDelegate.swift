//
//  AppDelegate.swift
//  windoo
//
//  Created by Kutvonen, Konsta on 9/24/20.
//

import Cocoa
import SwiftUI
import HotKey

class NSWindowKeypresser: NSWindow {
    var keyListener: (_: NSEvent) -> Bool? = { event in
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        if keyListener(event)! {
            super.keyDown(with: event)
        }
    }
}

func resize(image: NSImage, w: Int, h: Int) -> NSImage {
    var destSize = NSMakeSize(CGFloat(w), CGFloat(h))
    var newImage = NSImage(size: destSize)
    newImage.lockFocus()
    image.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height), from: NSMakeRect(0, 0, image.size.width, image.size.height), operation: NSCompositingOperation.sourceOver, fraction: CGFloat(1))
    newImage.unlockFocus()
    newImage.size = destSize
    return NSImage(data: newImage.tiffRepresentation!)!
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var window: NSWindowKeypresser!
    let windowManager = WindowManager()
    var keyboard: KeyboardListener!
    static var statusBarItem: NSStatusItem!
    var popover = NSPopover()
    
    
    static func createStatusImage(currApps: [String], w: Int, h: Int, activeInds: [Int], activeWindow: Int) {
        if statusBarItem == nil {
            AppDelegate.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            AppDelegate.statusBarItem?.button?.title = "💻"
        }
        var iconDict: [String: NSImage] = [:]
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            iconDict[app.localizedName!] = app.icon
            // Crashed here when closed
        }
        let icons = currApps.map { (name) -> NSImage in
            return iconDict[name]!
        }
        
        if icons.count == 0 {
            return
        }
        let destSize = NSMakeSize(CGFloat(w * icons.count), CGFloat(h))
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        for i in 0..<icons.count {
            let image = icons[i]

            if activeInds.contains(i) {
                let gradient = NSGradient(colors: [activeWindow == i ? NSColor.systemRed : NSColor.systemBlue])
                let rect = NSMakeRect(CGFloat(i * w), 0, CGFloat(w), newImage.size.height)
                let path = NSBezierPath(rect: rect)
                gradient!.draw(in: path, angle: 0.0)
            }

            image.draw(in: NSMakeRect(CGFloat(i * w), 0, CGFloat(w), CGFloat(h)), from: NSMakeRect(0, 0, image.size.width, image.size.height), operation: NSCompositingOperation.sourceOver, fraction: CGFloat(1))
        }
        newImage.unlockFocus()
        newImage.size = destSize

        if newImage.size.width > 0 {
            statusBarItem.button?.image = newImage
        }
    
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        AppDelegate.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        AppDelegate.statusBarItem?.button?.title = "💻"
    }
    
    func test() {
        print("test")
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("what is going on????")
        
        keyboard = KeyboardListener(wm: windowManager)
        // Create the SwiftUI view that provides the window contents.
        // Create the window and set the content view.
//        window = createWindow()
        createStatusBar()
    }
    
    func createStatusBar() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 400)
        popover.behavior = .transient
        self.popover = popover
        if let button = AppDelegate.statusBarItem.button {
            button.image = NSImage(named: "Icon")
//            button.action = #selector(togglePopover(_:))
        }
        
    }
    
    func createWindow() -> NSWindowKeypresser {
        let contentView = ContentView()
        
        let window = NSWindowKeypresser(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.keyListener = keyboard.keyDown
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    
}

