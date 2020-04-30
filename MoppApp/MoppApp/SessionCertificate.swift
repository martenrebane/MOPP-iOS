//
//  SessionCertificate.swift
//  MoppApp
//
/*
 * Copyright 2020 Riigi Infosüsteemide Amet
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
import SkSigningLib

class SessionCertificate {
    
    static let shared: SessionCertificate = SessionCertificate()
    
    func getCertificate(baseUrl: String, phoneNumber: String, nationalIdentityNumber: String, trustedCertificates: [String]?, completionHandler: @escaping (Result<CertificateResponse, MobileIDError>) -> Void) -> Void {
        do {
            _ = try RequestSignature.shared.getCertificate(baseUrl: baseUrl, requestParameters: CertificateRequestParameters(relyingPartyUUID: kRelyingPartyUUID, relyingPartyName: kRelyingPartyName, phoneNumber: "+\(phoneNumber)", nationalIdentityNumber: nationalIdentityNumber), trustedCertificates: trustedCertificates) { (result) in
                
                switch result {
                case .success(let response):
                    NSLog("Received certificate response: \(response.result?.rawValue ?? "-")")
                    return completionHandler(.success(response))
                case .failure(let error):
                    NSLog("Getting certificate error: \(error.mobileIDErrorDescription ?? error.rawValue)")
                    return completionHandler(.failure(error))
                }
            }
        } catch let error {
            NSLog("Error occurred while getting certificate: \(error.localizedDescription)")
            return completionHandler(.failure(.generalError))
        }
    }    
}
