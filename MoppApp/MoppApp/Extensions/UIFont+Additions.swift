//
//  UIFont+Additions.swift
//  MoppApp
//
/*
 * Copyright 2017 - 2021 Riigi Infosüsteemi Amet
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
import UIKit


enum MoppFontName : String {
    case light          = "Roboto-Light"
    case lightItalic    = "Roboto-LightItalic"
    case regular        = "Roboto-Regular"
    case italic         = "Roboto-Italic"
    case medium         = "Roboto-Medium"
    case bold           = "Roboto-Bold"
    case boldItalic     = "Roboto-BoldItalic"
    case allCapsRegular        = "RobotoCondensed-Regular"
    case allCapsItalic         = "RobotoCondensed-Italic"
    case allCapsBold           = "RobotoCondensed-Bold"
    case allCapsBoldItalic     = "RobotoCondensed-BoldItalic"
    case allCapsLight          = "RobotoCondensed-Light"
    case allCapsLightItalic    = "RobotoCondensed-LightItalic"
}

extension UIFont {
    class var moppHeadline: UIFont {
        return UIFont(name: MoppFontName.medium.rawValue, size: 16)!
    }
    
    class var moppText: UIFont {
        return UIFont(name: MoppFontName.regular.rawValue, size: 13)!
    }
    
    class var moppDescriptiveText: UIFont {
        return UIFont(name: MoppFontName.regular.rawValue, size: 10)!
    }
    
    class var moppMainMenu: UIFont {
        return UIFont(name: MoppFontName.allCapsRegular.rawValue, size: 10)!
    }
    
    class var moppButtonTitle: UIFont {
        return UIFont(name: MoppFontName.allCapsRegular.rawValue, size: 14)!
    }
    
    class var moppSmallButtonTitle: UIFont {
        return UIFont(name: MoppFontName.allCapsRegular.rawValue, size: 10)!
    }
    
    class var moppDatafieldLabel: UIFont {
        return UIFont(name: MoppFontName.allCapsRegular.rawValue, size: 10)!
    }
    
    class var moppAccordionLabel: UIFont {
        return UIFont(name: MoppFontName.allCapsRegular.rawValue, size: 13)!
    }

    class var moppTextField: UIFont {
        return UIFont(name: MoppFontName.medium.rawValue, size: 17)!
    }

    class var moppNavigationItemTitle: UIFont {
        return UIFont(name: MoppFontName.medium.rawValue, size: 20)!
    }
    
    class var moppRecentContainers: UIFont {
        return UIFont(name: MoppFontName.regular.rawValue, size: 16)!
    }
    
    class var moppRecentContainersSearchKeyword: UIFont {
        return UIFont(name: MoppFontName.bold.rawValue, size: 16)!
    }
}
