//
//  SubscriptionDetailsViewController.swift
//  windmill
//
//  Created by Markos Charatzas on 19/02/2019.
//  Copyright © 2019 Windmill. All rights reserved.
//

import UIKit

class SubscriptionDetailsViewController: UIViewController {

    class func make(storyboard: UIStoryboard = WindmillApp.Storyboard.subscriber()) -> SubscriptionDetailsViewController? {
        let viewController = storyboard.instantiateViewController(withIdentifier: String(describing: self)) as? SubscriptionDetailsViewController
        
        return viewController
    }
    
    @IBOutlet weak var subscriptionLabel: UILabel!
    @IBOutlet weak var youAreOnTrialLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
}
