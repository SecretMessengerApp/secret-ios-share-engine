

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = .red
        window?.makeKeyAndVisible()
        let vc = UIViewController()
        let textView = UITextView()
        textView.text = "This is the test host application for WireShareEngine tests."
        vc.view.addSubview(textView)
        textView.backgroundColor = .green
        textView.textContainerInset = .init(top: 22, left: 22, bottom: 22, right: 22)
        textView.isEditable = false
        textView.frame = vc.view.frame.insetBy(dx: 22, dy: 44)
        window?.rootViewController = vc
        
        return true
    }
}
