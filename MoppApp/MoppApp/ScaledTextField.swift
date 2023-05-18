//
//  ScaledTextField.swift
//  MoppApp
//
/*
 * Copyright 2017 - 2023 Riigi Infosüsteemi Amet
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

import Foundation

class ScaledTextField: UITextField {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        scaleFont()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        scaleFont()
    }
    
    func scaleFont() {
        let currentFont = self.font ?? UIFont(name: "Roboto-Bold", size: 16) ?? UIFont()
        if UIAccessibility.isBoldTextEnabled {
            self.font = FontUtil.boldFont(font: currentFont)
        } else {
            self.font = FontUtil.scaleFont(font: currentFont)
            self.attributedPlaceholder = NSAttributedString(string: self.placeholder ?? "", attributes: [NSAttributedString.Key.foregroundColor: UIColor.gray])
        }
        
        self.adjustsFontForContentSizeCategory = true
        self.adjustsFontSizeToFitWidth = true
        self.sizeToFit()
    }
    
    override func accessibilityElementDidBecomeFocused() {
        NotificationCenter.default.post(name: .hideKeyboardAccessibility, object: nil, userInfo: ["view": self])
    }
    
    override func deleteBackward() {
        guard var currentText = self.text, !currentText.isEmpty else { return }
        currentText.removeLast()
        self.text = currentText
        self.moveCursorToEnd()
    }
}
