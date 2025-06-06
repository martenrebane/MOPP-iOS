//
//  MoppLibConfiguration.swift
//  MoppLib
//
/*
 * Copyright 2017 - 2024 Riigi Infosüsteemi Amet
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

@objcMembers
public class MoppLibConfiguration: NSObject {
    static public var sivaURL: String?
    static public var sivaCert: URL?
    static public var tslURL: String?
    static public var tslCerts: [Data]?
    static public var tsaURL: String?
    static public var tsaCert: URL?
    static public var ocspIssuers: [String: String]?
    static public var certBundle: [Data]?

    private override init() {
        super.init()
    }
}
