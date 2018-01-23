//
//  LoginViewController.swift
//  windmill
//
//  Created by Markos Charatzas on 26/10/2016.
//  Copyright © 2016 Windmill. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController {
    
    @IBOutlet weak var accountTextField: UITextField! {
        didSet {
            accountTextField.delegate = self
        }
    }
    @IBOutlet weak var continueButton: UIButton! {
        didSet {
            continueButton.titleLabel?.adjustsFontForContentSizeCategory = true
        }
    }
    
    @IBOutlet weak var questionImageView: UIImageView!
    
    var applicationStorage: ApplicationStorage = ApplicationStorage.default
    
    static func make(applicationStorage: ApplicationStorage = ApplicationStorage.default) -> LoginViewController? {
        
        let loginViewController = Storyboards.main().instantiateViewController(withIdentifier: String(describing: self)) as? LoginViewController
        
        loginViewController?.applicationStorage = applicationStorage
        
        return loginViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.questionImageView.tintColor = self.view.tintColor
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let navigationController = segue.destination as? UINavigationController else {
            return
        }
        
        guard let viewController = navigationController.topViewController as? MainViewController else {
            return
        }
        
        let account = self.accountTextField.text?.trimmingCharacters(in: CharacterSet.whitespaces) ?? ""
        viewController.account = account
        
        if let data = account.data(using: .utf8) {
            try? applicationStorage.write(value: data, key: "account")
        }
    }
}

extension LoginViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let navigationController = Storyboards.main().instantiateViewController(withIdentifier: "MainNavigationViewController") as? UINavigationController else {
            return false
        }
        
        guard let viewController = navigationController.topViewController as? MainViewController else {
            return false
        }

        let account = self.accountTextField.text?.trimmingCharacters(in: CharacterSet.whitespaces) ?? ""
        viewController.account = account
        
        present(navigationController, animated: true)
        
        if let data = account.data(using: .utf8) {
            try? applicationStorage.write(value: data, key: "account")
        }
        
        textField.resignFirstResponder()
        return true
    }
}