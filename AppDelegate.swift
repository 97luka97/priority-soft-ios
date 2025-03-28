//
//  AppDelegate.swift
//  priority-soft-ios
//
//  Created by Kostic on 26.3.25..
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let main = MainViewController(nibName: "MainViewController", bundle: nil)
        let navigationController = UINavigationController(rootViewController: main)
        navigationController.isNavigationBarHidden = true

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = navigationController

        window?.makeKeyAndVisible()

        return true
    }
}
