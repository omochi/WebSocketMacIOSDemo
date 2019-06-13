//
//  AppDelegate.swift
//  WebSocketClient
//
//  Created by omochimetaru on 2019/06/13.
//  Copyright © 2019 omochimetaru. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        window.makeKeyAndVisible()
        
        let vc = MainViewController()
        let nc = UINavigationController(rootViewController: vc)
        
        window.rootViewController = nc
        
        return true
    }

}

