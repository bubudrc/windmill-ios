//
//  Button.swift
//  windmill
//
//  Created by Markos Charatzas (markos@qnoid.com) on 25/10/2017.
//  Copyright © 2014-2020 qnoid.com. All rights reserved.
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation is required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source distribution.
//

import UIKit
import QuartzCore

@IBDesignable
class Button: UIButton {
    
    @IBInspectable var cornerRadius:CGFloat = 5.0 {
        didSet{
            self.setNeedsLayout()
        }
    }

    @IBInspectable var borderWidth:CGFloat = 1.0 {
        didSet{
            self.setNeedsLayout()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.layer.borderColor = self.titleColor(for: .normal)?.cgColor
        self.layer.borderWidth = self.borderWidth
        self.layer.cornerRadius = self.cornerRadius
        self.layer.masksToBounds = true
    }
}
