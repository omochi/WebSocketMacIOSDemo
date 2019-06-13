//
//  AppDelegate.swift
//  WebSocketServer
//
//  Created by omochimetaru on 2019/06/13.
//  Copyright © 2019 omochimetaru. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    var mainWindowController: MainWindowController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let wc = MainWindowController(windowNibName: "MainWindowController")
        self.mainWindowController = wc
        self.window = wc.window!
        wc.showWindow(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    {
        return true
    }

}

