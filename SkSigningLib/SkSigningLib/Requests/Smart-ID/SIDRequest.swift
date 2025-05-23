/*
 * SkSigningLib - SIDRequest.swift
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

protocol SIDRequestProtocol {
    /**
    Gets certificate info for Smart-ID

    - Parameters:
       - baseUrl: The base URL for Smart-ID. Path "/certificate/etsi/pno{country}-{nationalIdentityNumber}" will be added to the base URL
       - country:
       - nationalIdentityNumber:
       - requestParameters: Parameters that are sent to the service. Uses SIDCertificateRequestParameters struct
       - completionHandler: On request success, callbacks Result<SIDSessionResponse, SigningError>
    */
    func getCertificate(baseUrl: String, country: String, nationalIdentityNumber: String, requestParameters: SIDCertificateRequestParameters, trustedCertificates: [Data], manualProxyConf: Proxy, completionHandler: @escaping (Result<SIDSessionResponse, SigningError>) -> Void)

    /**
    Gets signature info for Smart-ID.

    - Parameters:
       - baseUrl: The base URL for Smart-ID. Path "/signature/document/{documentNumber}" will be added to the base URL
       - documentNumber:
       - allowedInteractionsOrder: Interaction order.
       - completionHandler: On request success, callbacks Result<SIDSessionResponse, SigningError>
    */
    func getSignature(baseUrl: String, documentNumber: String, allowedInteractionsOrder: SIDSignatureRequestParameters, trustedCertificates: [Data], manualProxyConf: Proxy, completionHandler: @escaping (Result<SIDSessionResponse, SigningError>) -> Void)

    /**
    Gets session status info for Smart-ID.

    - Parameters:
       - baseUrl: The base URL for Smart-ID. Path "/session/{sessionId}?timeoutMs={timeoutMs}" will be added to the base URL. Values are taken from requestParameters
       - sessionId: SessionID parameter that is used in URL
       - timeoutMs: TimeoutMs parameter that is used in URL
       - completionHandler: On request success, callbacks Result<SIDSessionStatusResponse, SigningError>
    */
    func getSessionStatus(baseUrl: String, sessionId: String, timeoutMs: Int?, trustedCertificates: [Data], manualProxyConf: Proxy, completionHandler: @escaping (Result<SIDSessionStatusResponse, SigningError>) -> Void)
}

/**
 Handles session and session status requests for Mobile-ID
*/
public class SIDRequest: NSObject, URLSessionDelegate, SIDRequestProtocol {

    public static let shared = SIDRequest()
    private var trustedCerts = [Data]()
    private weak var urlTask: URLSessionTask?

    public func getCertificate(baseUrl: String, country: String, nationalIdentityNumber: String, requestParameters: SIDCertificateRequestParameters, trustedCertificates: [Data], manualProxyConf: Proxy, completionHandler: @escaping (Result<SIDSessionResponse, SigningError>) -> Void) {
        let url = "\(baseUrl)/certificatechoice/etsi/PNO\(country)-\(nationalIdentityNumber)"
        guard UUID(uuidString: requestParameters.relyingPartyUUID) != nil else { completionHandler(.failure(.sidInvalidAccessRights)); return }
        exec(method: "Certificate", url: url, data: EncoderDecoder().encode(data: requestParameters), trustedCertificates: trustedCertificates, manualProxyConf: manualProxyConf, completionHandler: completionHandler)
    }
    
    public func getSignature(baseUrl: String, documentNumber: String, allowedInteractionsOrder: SIDSignatureRequestParameters, trustedCertificates: [Data], manualProxyConf: Proxy, completionHandler: @escaping (Result<SIDSessionResponse, SigningError>) -> Void) {
        let url = "\(baseUrl)/signature/document/\(documentNumber)"
        exec(method: allowedInteractionsOrder.relyingPartyName, url: url, data: allowedInteractionsOrder.asData, trustedCertificates: trustedCertificates, manualProxyConf: manualProxyConf, completionHandler: completionHandler)
    }

    public func getSessionStatus(baseUrl: String, sessionId: String, timeoutMs: Int?, trustedCertificates: [Data], manualProxyConf: Proxy, completionHandler: @escaping (Result<SIDSessionStatusResponse, SigningError>) -> Void) {
        let url = "\(baseUrl)/session/\(sessionId)?timeoutMs=\(timeoutMs ?? Constants.defaultTimeoutMs)"
        exec(method: "Session", url: url, data: nil, trustedCertificates: trustedCertificates, manualProxyConf: manualProxyConf, completionHandler: completionHandler)
    }

    private func exec<D: Decodable>(method: String, url: String, data: Data?, trustedCertificates: [Data], manualProxyConf: Proxy, completionHandler: @escaping (Result<D, SigningError>) -> Void) {
        guard let _url = URL(string: url) else {
            Logging.errorLog(forMethod: "RIA.SmartID - \(method)", httpResponse: nil, error: .invalidURL, extraInfo: "Invalid URL \(url)")
            return completionHandler(.failure(.invalidURL))
        }
        
        var request = URLRequest(url: _url)
        request.httpMethod = data == nil ? RequestMethod.GET.value : RequestMethod.POST.value
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        Logging.log(forMethod: "RIA.SmartID - exec - \(method)", info: "RIA.SmartID (\(method): \(url)\n" +
                    "Method: \(request.httpMethod ?? "Unable to get HTTP method")\n" +
                    "Data: \n" + String(decoding: data ?? Data(), as: UTF8.self)
        )

        trustedCerts = trustedCertificates
        var config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        let urlSession: URLSession
        if !trustedCertificates.isEmpty {
            ProxyUtil.configureURLSessionWithProxy(urlSessionConfiguration: &config, manualProxyConf: manualProxyConf)
            ProxyUtil.setProxyAuthorizationHeader(request: &request, urlSessionConfiguration: config, manualProxyConf: manualProxyConf)
            urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        } else {
            urlSession = URLSession.shared
        }

        let sessionTask = urlSession.dataTask(with: request) { data, response, error in

            let isRequestCancelled = CancelRequestUtil.isRequestCancellationHandled(urlSession: urlSession, urlSessionTask: self.urlTask, methodDescription: "RIA.SmartID - exec - \(method)")
            
            if isRequestCancelled {
                completionHandler(.failure(.cancelled))
            }
                
            switch error {
            case nil: break
            case let nsError as NSError where nsError.code == NSURLErrorCancelled || nsError.code == NSURLErrorSecureConnectionFailed:
                Logging.errorLog(forMethod: "RIA.SmartID - \(method)", httpResponse: nil, error: .invalidSSLCert, extraInfo: "Certificate pinning failed")
                return completionHandler(.failure(.invalidSSLCert))
            case let nsError as NSError where nsError.code == NSURLErrorNotConnectedToInternet:
                Logging.errorLog(forMethod: "RIA.SmartID - \(method)", httpResponse: nil, error: .noResponseError, extraInfo: "Error getting response. No Internet connection")
                return completionHandler(.failure(.noResponseError))
            case let nsError as NSError where nsError.code == 310:
                Logging.errorLog(forMethod: "RIA.SmartID - \(method)", httpResponse: nil, error: .invalidProxySettings, extraInfo: "Unable to connect with current proxy settings")
                return completionHandler(.failure(.invalidProxySettings))
            default:
                Logging.errorLog(forMethod: "RIA.SmartID - \(method)", httpResponse: nil, error: .generalError, extraInfo: error!.localizedDescription)
                return completionHandler(.failure(.generalError))
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                Logging.errorLog(forMethod: "RIA.SmartID - \(method)", httpResponse: nil, error: .noResponseError, extraInfo: "Error getting response")
                return completionHandler(.failure(.noResponseError))
            }
            if !(200...299).contains(httpResponse.statusCode) {
                let statusCode: SigningError = switch httpResponse.statusCode {
                case 400: .forbidden
                case 401, 403: .sidInvalidAccessRights
                case 404: method == "Session" ? .sessionIdNotFound : .accountNotFoundOrTimeout
                case 409: .exceededUnsuccessfulRequests
                case 429: .tooManyRequests(signingMethod: SigningType.smartId.rawValue)
                case 471: .notQualified
                case 480: .oldApi
                case 500: .internalError
                case 580: .underMaintenance
                default: .generalError
                }
                Logging.errorLog(forMethod: "RIA.SmartID - \(method)", httpResponse: httpResponse, error: statusCode, extraInfo: "")
                return completionHandler(.failure(statusCode))
            }
            if data == nil {
                Logging.errorLog(forMethod: "RIA.SmartID - \(method)", httpResponse: httpResponse, error: .generalError, extraInfo: "Error getting response. No data")
                return completionHandler(.failure(.generalError))
            }

            Logging.log(forMethod: "RIA.SmartID - exec - \(method)", info: "RIA.SmartID (\(method)):\n" +
                        "Response: \n \(String(data: data ?? Data(), encoding: .utf8) ?? "Unable to get response info")")

            EncoderDecoder().decode(data: data!, completionHandler: { response in completionHandler(.success(response)) })
        }
        sessionTask.resume()
        self.urlTask = sessionTask
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        CertificatePinning().certificatePinning(trustedCertificates: trustedCerts, challenge: challenge, completionHandler: completionHandler)
    }
}
