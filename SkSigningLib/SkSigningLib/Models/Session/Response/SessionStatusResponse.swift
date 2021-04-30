//
//  SessionStatusResponse.swift
//  SkSigningLib
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

public enum SessionResponseState: String, Decodable {
    case RUNNING
    case COMPLETE
}

public struct SessionStatusResponse: Decodable {
    public let state: SessionResponseState
    public let result: SessionResultCode?
    public let signature: SessionResponseSignature?
    public let cert: String?
    public let time: String?
    public let traceId: String?
    public let error: String?
    
    public enum CodingKeys: String, CodingKey {
        case state
        case result
        case signature
        case cert
        case time
        case traceId
        case error
    }
    
    public init(state: SessionResponseState,
                result: SessionResultCode? = nil,
                signature: SessionResponseSignature? = nil,
                cert: String? = nil,
                time: String? = nil,
                traceId: String? = nil) {
        
        self.state = state
        self.result = result
        self.signature = signature
        self.cert = cert
        self.time = time
        self.traceId = traceId
        self.error = nil
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        state = try values.decode(SessionResponseState.self, forKey: .state)
        result = try values.decodeIfPresent(SessionResultCode.self, forKey: .result)
        signature = try values.decodeIfPresent(SessionResponseSignature.self, forKey: .signature)
        cert = try values.decodeIfPresent(String.self, forKey: .cert)
        time = try values.decodeIfPresent(String.self, forKey: .time)
        traceId = try values.decodeIfPresent(String.self, forKey: .traceId)
        error = try values.decodeIfPresent(String.self, forKey: .error)
    }
}
