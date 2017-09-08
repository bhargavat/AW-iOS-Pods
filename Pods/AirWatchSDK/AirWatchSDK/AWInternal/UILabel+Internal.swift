
//
//  UIView+Helper
//  AWSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import UIKit

var countdownTimerCounter = 10
struct CountdownLabelInfo{
    var timerCompletionBlock:((Bool) -> Void)?  = nil
    var timer: Timer? = nil
    var timerLabel: UILabel? = nil
    var timerCompleted = true
}

var countdownLabel: CountdownLabelInfo = CountdownLabelInfo()

internal extension UILabel {

    internal class func showCountdownInKeyWindow(seconds: Int, message: String, completionBlock:@escaping (Bool) -> Void) {
        guard let window = UIApplication.shared.keyWindow else {
            completionBlock(false)
            return
        }
        if countdownLabel.timerCompleted == false {
            countdownLabel.timerLabel?.removeFromSuperview()
            countdownLabel.timerLabel = nil
            
            countdownLabel.timer?.invalidate()
            countdownLabel.timer = nil

            countdownLabel.timerCompletionBlock?(false)
            countdownLabel.timerCompleted = true
        }

        let view = UILabel(frame: window.bounds)
        view.textAlignment = .center
        view.numberOfLines = 0
        view.textColor = UIColor.white
        view.backgroundColor = UIColor(white: 0, alpha: 0.75)
        countdownTimerCounter = seconds
        view.text = String(format: message, countdownTimerCounter)
        window.addSubview(view)
        window.bringSubview(toFront: view)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to:nil, from:nil, for:nil)
        }
        countdownLabel.timerLabel = view
        countdownLabel.timerCompletionBlock = completionBlock
        countdownLabel.timerCompleted = false
        countdownLabel.timer = Timer.scheduledTimer(timeInterval: 1, target: view, selector: #selector(updateLabel(timer:)), userInfo: message, repeats: true)
    }

    @objc func updateLabel(timer: Timer) {
        countdownTimerCounter -= 1
        guard countdownTimerCounter > 0, let message = timer.userInfo as? String else {
            timer.invalidate()
            self.removeFromSuperview()
            countdownLabel.timerCompletionBlock?(true)
            countdownLabel.timerCompleted = true
            countdownLabel.timer = nil
            countdownLabel.timerLabel = nil
            return
        }

        DispatchQueue.main.async {
            self.text = String(format: message, countdownTimerCounter)
        }
    }
    
}
