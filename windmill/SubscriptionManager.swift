//
//  ProductsManager.swift
//  windmill
//
//  Created by Markos Charatzas on 06/02/2019.
//  Copyright © 2019 Windmill. All rights reserved.
//

import UIKit
import Alamofire
import StoreKit
import os

protocol SubscriptionManagerDelegate: NSObjectProtocol {
    
    func success(_ manager: SubscriptionManager, products: [SKProduct])
    func success(_ manager: SubscriptionManager, receipt: URL)
    func error(_ manager: SubscriptionManager, didFailWithError error: Error)
}

extension SubscriptionManagerDelegate {
    
    func success(_ manager: SubscriptionManager, products: [SKProduct]) {}
    func success(_ manager: SubscriptionManager, receipt: URL) {}
    func error(_ manager: SubscriptionManager, didFailWithError error: Error) {}
}

class SubscriptionManager: NSObject, SKProductsRequestDelegate {
    
    public static let SubscriptionPurchasing = Notification.Name("io.windmill.windmill.subscription.purchasing")
    public static let SubscriptionPurchased = Notification.Name("io.windmill.windmill.subscription.purchased")
    public static let SubscriptionFailed = Notification.Name("io.windmill.windmill.subscription.failed")
    public static let SubscriptionRestored: Notification.Name = Notification.Name(rawValue: "io.windmill.windmill.subscription.restored")
    public static let SubscriptionRestoreFailed: Notification.Name = Notification.Name(rawValue: "io.windmill.windmill.subscription.restore.failed")
    public static let SubscriptionActive = Notification.Name("io.windmill.windmill.subscription.active")


    struct Product {
        enum Identifier: String {
            case individualMonthly = "io.windmill.windmill.individual_monthly"
        }
        static let isIndividualMonthly: (SKProduct) -> Bool = { SubscriptionManager.Product.Identifier(rawValue: $0.productIdentifier) == .individualMonthly }
        
        static let individualMonthly = Product(identifier: .individualMonthly, duration: "month")
        
        let identifier: Product.Identifier
        let duration: String
    }
    
    
    //This `SubscriptionManager` is meant to be used as a reasonable default. You shouldn't assume ownership when using this instance. i.e. Don't set its `delegate` and expect it to remain.
    static let shared: SubscriptionManager = SubscriptionManager()
    
    let subscriptionResource = SubscriptionResource()
    let paymentQueue: PaymentQueue
    
    var products: [SKProduct]? {
        didSet {
            if let products = products {
                self.delegate?.success(self, products: products)
            }
        }
    }
    
    var delegate: SubscriptionManagerDelegate?
    
    init(paymentQueue: PaymentQueue = PaymentQueue.default) {
        self.paymentQueue = paymentQueue
        super.init()
        self.paymentQueue.subscriptionManager = self
        NotificationCenter.default.addObserver(self, selector: #selector(transactionPurchased(notification:)), name: PaymentQueue.TransactionPurchased, object: paymentQueue)
        NotificationCenter.default.addObserver(self, selector: #selector(transactionPurchasing(notification:)), name: PaymentQueue.TransactionPurchasing, object: paymentQueue)
        NotificationCenter.default.addObserver(self, selector: #selector(transactionError(notification:)), name: PaymentQueue.TransactionError, object: paymentQueue)
        NotificationCenter.default.addObserver(self, selector: #selector(restoreCompletedTransactionsFinished(notification:)), name: PaymentQueue.RestoreCompletedTransactionsFinished, object: paymentQueue)
        NotificationCenter.default.addObserver(self, selector: #selector(restoreCompletedTransactionsFailed(notification:)), name: PaymentQueue.RestoreCompletedTransactionsFailed, object: paymentQueue)
    }
    
    func purchaseSubscription(receiptData: String, completion: @escaping SubscriptionResource.TransactionsCompletion) {
        
        self.requestTransactions(receiptData: receiptData){ (account, token, error) in
            
            switch error {
            case let error as AFError where error.isResponseValidationError:
                switch error.responseCode {
                case 403:
                    os_log("The receipt was invalid: '%{public}@'", log: .default, type: .error, error.localizedDescription)
                default:
                    os_log("There was an unexpected error while purchasing/renewing a subscription: '%{public}@'", log: .default, type: .error, error.localizedDescription)
                    NotificationCenter.default.post(name: SubscriptionManager.SubscriptionFailed, object: self, userInfo: ["error": SubscriptionError.failed])
                }
            case let error as URLError:
                NotificationCenter.default.post(name: SubscriptionManager.SubscriptionFailed, object: self, userInfo: ["error": SubscriptionError.connectionError(error: error)])
            case .some(let error):
                NotificationCenter.default.post(name: SubscriptionManager.SubscriptionFailed, object: self, userInfo: ["error": error])
            case .none:
                NotificationCenter.default.post(Notification(name: SubscriptionManager.SubscriptionActive))
            }
            
            completion(account, token, error)
        }
    }
    
    func restoreSubscription(receiptData: String) {
        
        self.requestTransactions(receiptData: receiptData) { (account, receiptClaim, error) in
            
            switch error {
            case let error as AFError where error.isResponseValidationError:
                switch error.responseCode {
                case 403:
                    os_log("The receipt was invalid: '%{public}@'", log: .default, type: .error, error.localizedDescription)
                default:
                    os_log("There was an unexpected error while restoring a subscription: '%{public}@'", log: .default, type: .error, error.localizedDescription)
                    NotificationCenter.default.post(name: SubscriptionManager.SubscriptionRestoreFailed, object: self, userInfo: ["error": SubscriptionError.restoreFailed])
                }
            case let error as URLError:
                NotificationCenter.default.post(name: SubscriptionManager.SubscriptionRestoreFailed, object: self, userInfo: ["error": SubscriptionError.restoreConnectionError(error: error)])
            case .some(let error):
                NotificationCenter.default.post(name: SubscriptionManager.SubscriptionRestoreFailed, object: self, userInfo: ["error": error])
            case .none:
                NotificationCenter.default.post(Notification(name: SubscriptionManager.SubscriptionActive))
            }
        }
    }
    
    func productsRequest(productIdentifiers: [Product.Identifier] = [.individualMonthly]) -> SKProductsRequest {
        
        let productsRequest = SKProductsRequest(productIdentifiers: Set(productIdentifiers.compactMap{ $0.rawValue }))
        productsRequest.delegate = self
        productsRequest.start()
        
        return productsRequest
    }
    
    func receiptRefreshRequest() -> SKReceiptRefreshRequest {
        
        let receiptRefreshRequest = SKReceiptRefreshRequest()
        receiptRefreshRequest.delegate = self
        receiptRefreshRequest.start()
        
        return receiptRefreshRequest
    }
    
    // MARK: SKRequestDelegate
    func requestDidFinish(_ request: SKRequest) {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            return
        }
        
        self.delegate?.success(self, receipt: appStoreReceiptURL)
    }
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.products = response.products
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        self.delegate?.error(self, didFailWithError: error)
    }
    
    // MARK: private
    @objc func transactionPurchased(notification: NSNotification) {
        NotificationCenter.default.post(name: SubscriptionManager.SubscriptionPurchased, object: self, userInfo: notification.userInfo)
    }
    
    @objc func transactionPurchasing(notification: NSNotification) {
        NotificationCenter.default.post(name: SubscriptionManager.SubscriptionPurchasing, object: self, userInfo: notification.userInfo)
    }
    
    @objc func transactionError(notification: NSNotification) {
        NotificationCenter.default.post(name: SubscriptionManager.SubscriptionFailed, object: self, userInfo: notification.userInfo)
    }
    
    @objc func restoreCompletedTransactionsFinished(notification: Notification) {
        NotificationCenter.default.post(name: SubscriptionManager.SubscriptionRestored, object: self, userInfo: notification.userInfo)
    }
    
    @objc func restoreCompletedTransactionsFailed(notification: NSNotification) {
        NotificationCenter.default.post(name: SubscriptionManager.SubscriptionRestoreFailed, object: self, userInfo: notification.userInfo)
    }
    
    private func requestTransactions(receiptData: String, completion: @escaping SubscriptionResource.TransactionsCompletion) {
        
        self.subscriptionResource.requestTransactions(forReceipt: receiptData) { (account, receiptClaim, error) in
            
            switch error {
            case .some(let error):
                completion(account, receiptClaim, error)
            case .none:
                if let claim = receiptClaim?.value, let account = account?.identifier {
                    try? ApplicationStorage.default.write(value: claim,
                                                          key: .receiptClaim,
                                                          options: .completeFileProtectionUnlessOpen)
                    try? ApplicationStorage.default.write(value: account,
                                                          key: .account,
                                                          options: .completeFileProtectionUntilFirstUserAuthentication)
                }
                
                completion(account, receiptClaim, error)
            }
        }
    }
    
    // MARK: public
    public func startProcessingPayments() {
        self.paymentQueue.startObservingPaymentTransactions()
    }
    
    public func restoreSubscriptions() {
        self.paymentQueue.restoreCompletedTransactions()
    }
    
    public func purchase(_ product: SKProduct) {
        let payment = SKPayment(product: product)
        self.paymentQueue.add(payment)
    }
}