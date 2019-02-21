//
//  AccountViewController.swift
//  windmill
//
//  Created by Markos Charatzas on 11/02/2019.
//  Copyright © 2019 Windmill. All rights reserved.
//

import UIKit
import CloudKit

/**
    The AccountViewController guarantees that a user has logged in their Apple ID and has iCloud Drive for Windmill turned on.
 
 - precondition: to show this view controller, make sure that the user is logged in their Apple ID and has iCloud Drive for Windmill turned on.
 */
class AccountViewController: UIViewController {

    enum Section: String, CodingKey {
        static var allValues: [Section] = [.subscription]
        
        case subscription = "Subscription"
    }
    
    enum Setting: String, CodingKey {
        static var allValues: [Setting] = [.subscription, .refreshSubscription, .restorePurchases]
        
        case subscription = "Individual Monthly"
        case refreshSubscription = "Refresh Subscription"
        case restorePurchases = "Restore Purchases"
        
        static func settings(for status: SubscriptionStatus) -> [Setting] {
            switch status {
            case .active:
                return [.subscription, .refreshSubscription, .restorePurchases]
            case .none:
                return [.refreshSubscription, .restorePurchases]
            }
        }
    }

    @IBOutlet weak var tableView: UITableView! {
        didSet{
            self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AccountTableViewCell")
            self.tableView.rowHeight = UITableView.automaticDimension
            self.tableView.dataSource = self.dataSource
            self.tableView.delegate = self.delegate
            self.tableView.alwaysBounceVertical = false
            self.tableView.tableFooterView = UITableViewHeaderFooterView()
        }
    }

    var dataSource = AccountTableViewDataSource(settings: []) {
        didSet {
            dataSource.controller = self
            self.tableView?.dataSource = dataSource
        }
    }
    
    lazy var delegate: AccountTableViewDelegate = { [unowned self] in
        let delegate = AccountTableViewDelegate(settings: [])
        delegate.controller = self
        return delegate
    }()
    
    var subscriptionStatus: SubscriptionStatus? {
        didSet {
            if oldValue == nil, let subscriptionStatus = subscriptionStatus {
                self.subscriptionStatus(subscriptionStatus)
            }
            
            if let subscriptionStatus = subscriptionStatus {
                self.dataSource = AccountTableViewDataSource(settings: Setting.settings(for: subscriptionStatus))
                self.delegate = AccountTableViewDelegate(settings: Setting.settings(for: subscriptionStatus))
                self.tableView?.reloadData()
            }
        }
    }

    let subscriptionManager: SubscriptionManager = SubscriptionManager()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(subscriptionActive(notification:)), name: SubscriptionManager.SubscriptionActive, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(subscriptionActive(notification:)), name: SubscriptionManager.SubscriptionActive, object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.subscriptionStatus = SubscriptionStatus.shared
    }

    func subscriptionStatus(_ subscriptionStatus: SubscriptionStatus) {
        CKContainer.default().fetchUserRecordID { (id, error) in
            debugPrint("\(#function), id:\(String(describing: id?.recordName))")
        }
    }
    
    @objc func subscriptionActive(notification: NSNotification) {
        self.subscriptionStatus = SubscriptionStatus.shared
    }

    func cell(_ cell: UITableViewCell, for setting: Setting) {
        switch setting {
        case .subscription:
            cell.accessoryType = .detailButton
        default:
            return
        }
    }

    func accessoryButtonTapped(setting: Setting) {
        guard let subscriptionDetailsViewController = SubscriptionDetailsViewController.make() else {
            return
        }
        
        self.show(subscriptionDetailsViewController, sender: self)
    }
    
    func didSelect(setting: Setting) {
        switch setting {
        case .subscription:
            guard let manageSubscriptionsURL = URL(string: "itms-apps://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/manageSubscriptions") else {
                return
            }
            UIApplication.shared.open(manageSubscriptionsURL, options: [:], completionHandler: nil)
        case .restorePurchases:
            
            self.subscriptionManager.restoreSubscriptions()
        default:
            return
        }
    }
}
