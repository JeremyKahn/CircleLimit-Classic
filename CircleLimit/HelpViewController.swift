//
//  HelpViewController.swift
//  CircleLimitClassic
//
//  Created by Kahn on 5/28/18.
//  Copyright © 2018 Jeremy Kahn. All rights reserved.
//

import UIKit

class HelpViewController: UIViewController {
    
    var presentingCVC: CircleViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func returnToMain(_ sender: Any) {
        print("Returning to the main view")
        // presentingCVC.doNothing = false
        presentingCVC.cancelEffectOfTouches()
//        let cvc = presentingViewController as! CircleViewController
//        cvc.cancelEffectOfTouches()
        dismiss(animated: true, completion: nil)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
