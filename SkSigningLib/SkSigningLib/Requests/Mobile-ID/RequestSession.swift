//
//  RequestSession.swift
//  SkSigningLib
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

protocol SessionRequest {
    /**
    Gets session info for Mobile-ID. This method invokes SIM toolkit

    - Parameters:
       - baseUrl: The base URL for Mobile-ID. Path "/signature" will be added to the base URL
       - requestParameters: Parameters that are sent to the service.
       - completionHandler: On request success, callbacks Result<SessionResponse, SigningError>
    */
    func getSession(baseUrl: String, requestParameters: SessionRequestParameters, trustedCertificates: [Data], manualProxyConf: Proxy, completionHandler: @escaping (Result<SessionResponse, SigningError>) -> Void)

    /**
    Gets session status info for Mobile-ID. This method invokes SIM toolkit

    - Parameters:
       - baseUrl: The base URL for Mobile-ID. Path "/signature/session/{sessionId}?timeoutMs={timeoutMs}" will be added to the base URL. Values are taken from requestParameters
       - process: Determines if session is for authentication or signing
       - requestParameters: Parameters that are used in URL
       - completionHandler: On request success, callbacks Result<SessionStatusResponse, SigningError>
    */
    func getSessionStatus(baseUrl: String, process: PollingProcess, requestParameters: SessionStatusRequestParameters, trustedCertificates: [Data], manualProxyConf: Proxy, completionHandler: @escaping (Result<SessionStatusResponse, SigningError>) -> Void)
}

/**
 Handles session and session status requests for Mobile-ID
*/
public class RequestSession: NSObject, URLSessionDelegate, SessionRequest {
    
    public static let shared = RequestSession()
    
    private weak var urlTask: URLSessionTask?
    
    private var trustedCerts = [Data]()

    deinit {
        urlTask?.cancel()
    }
    
    public func getSession(baseUrl: String, requestParameters: SessionRequestParameters, trustedCertificates: [Data], manualProxyConf: Proxy, completionHandler: @escaping (Result<SessionResponse, SigningError>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/signature") else {
            completionHandler(.failure(.invalidURL))
            return
        }
        
        trustedCerts = trustedCertificates
        
        var request = URLRequest(url: url)
        request.httpMethod = RequestMethod.POST.value
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestParameters.asData
        
        Logging.log(forMethod: "RIA.MobileID - getSession", info: "RIA.MobileID (Session): \(url) \n" +
            "Method: \(request.httpMethod ?? "Unable to get HTTP method") \n" +
            "Parameters: \n" +
            "\trelyingPartyName: \(requestParameters.relyingPartyName) \n" +
            "\trelyingPartyUUID: \(requestParameters.relyingPartyUUID) \n" +
            "\tphoneNumber: \(requestParameters.phoneNumber)\n" +
            "\tnationalIdentityNumber: \(requestParameters.nationalIdentityNumber)\n" +
            "\thash: \(requestParameters.hash)\n" +
            "\thashType: \(requestParameters.hashType)\n" +
            "\tlanguage: \(requestParameters.language)\n" +
            "\tdisplayText: \(requestParameters.displayText ?? "")\n"
        )
        
        var urlSessionConfiguration: URLSessionConfiguration
        let urlSession: URLSession
        
        if !trustedCerts.isEmpty {
            urlSessionConfiguration = URLSessionConfiguration.default
            ProxyUtil.configureURLSessionWithProxy(urlSessionConfiguration: &urlSessionConfiguration, manualProxyConf: manualProxyConf)
            ProxyUtil.setProxyAuthorizationHeader(request: &request, urlSessionConfiguration: urlSessionConfiguration, manualProxyConf: manualProxyConf)
            urlSession = URLSession(configuration: urlSessionConfiguration, delegate: self, delegateQueue: nil)
        } else {
            urlSession = URLSession.shared
        }
        
        let sessionTask: URLSessionTask? = urlSession.dataTask(with: request as URLRequest) { data, response, error in
            
            let isRequestCancelled = CancelRequestUtil.isRequestCancellationHandled(urlSession: urlSession, urlSessionTask: self.urlTask, methodDescription: "RIA.MobileID - Session")
            
            if isRequestCancelled {
                completionHandler(.failure(.cancelled))
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logging.errorLog(forMethod: "RIA.MobileID - Session", httpResponse: response as? HTTPURLResponse ?? nil, error: .noResponseError, extraInfo: "")
                return completionHandler(.failure(.noResponseError))
            }
            
            if error != nil {
                Logging.errorLog(forMethod: "RIA.MobileID - Session", httpResponse: response as? HTTPURLResponse ?? nil, error: .generalError, extraInfo: error?.localizedDescription ?? "Error getting response")
                completionHandler(.failure(.generalError))
                return
            }
            
            if let data: Data = data {
                EncoderDecoder().decode(data: data, completionHandler: { (response: SessionResponse) in
                    Logging.log(forMethod: "RIA.MobileID - getSession", info: "Response: \n \(String(data: data, encoding: .utf8) ?? "Unable to get response info")")
                    if (response.sessionID != nil) {
                        completionHandler(.success(response))
                    } else {
                        Logging.errorLog(forMethod: "RIA.MobileID - Session", httpResponse: httpResponse, error: self.handleHTTPSessionResponseError(httpResponse: httpResponse), extraInfo: response.error ?? "Unknown error received")
                        completionHandler(.failure(self.handleHTTPSessionResponseError(httpResponse: httpResponse)))
                    }
                })
            }
        }
        sessionTask?.resume()
        self.urlTask = sessionTask
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        CertificatePinning().certificatePinning(trustedCertificates: trustedCerts, challenge: challenge, completionHandler: completionHandler)
    }
    
    public func getSessionStatus(baseUrl: String, process: PollingProcess, requestParameters: SessionStatusRequestParameters, trustedCertificates: [Data], manualProxyConf: Proxy, completionHandler: @escaping (Result<SessionStatusResponse, SigningError>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/signature/session/\(requestParameters.sessionId)?timeoutMs=\(requestParameters.timeoutMs ?? Constants.defaultTimeoutMs)") else {
            Logging.errorLog(forMethod: "RIA.MobileID - Session status", httpResponse: nil, error: .invalidURL, extraInfo: "Invalid URL \(baseUrl)/signature/session/\(requestParameters.sessionId)?timeoutMs=\(requestParameters.timeoutMs ?? Constants.defaultTimeoutMs)")
            return completionHandler(.failure(.invalidURL))
        }
        
        trustedCerts = trustedCertificates
        
        var request = URLRequest(url: url)
        request.httpMethod = RequestMethod.GET.value
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        Logging.log(forMethod: "RIA.MobileID - getSessionStatus", info: "RIA.MobileID (Session status): \(url) \n" +
                    "Method: \(request.httpMethod ?? "Unable to get HTTP method") \n" +
                    "Parameters: \n" +
                    "\tsessionId: \(requestParameters.sessionId)\n" +
                    "\ttimeoutMs: \(String(requestParameters.timeoutMs ?? Constants.defaultTimeoutMs)) \n"
        )
        
        var urlSessionConfiguration: URLSessionConfiguration
        let urlSession: URLSession
        
        if !trustedCerts.isEmpty {
            urlSessionConfiguration = URLSessionConfiguration.default
            urlSessionConfiguration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            ProxyUtil.configureURLSessionWithProxy(urlSessionConfiguration: &urlSessionConfiguration, manualProxyConf: manualProxyConf)
            ProxyUtil.setProxyAuthorizationHeader(request: &request, urlSessionConfiguration: urlSessionConfiguration, manualProxyConf: manualProxyConf)
            urlSession = URLSession(configuration: urlSessionConfiguration, delegate: self, delegateQueue: nil)
        } else {
            urlSession = URLSession.shared
        }
        let sessionTask: URLSessionTask? = urlSession.dataTask(with: request as URLRequest) { data, response, error in
            
            let isRequestCancelled = CancelRequestUtil.isRequestCancellationHandled(urlSession: urlSession, urlSessionTask: self.urlTask, methodDescription: "RIA.MobileID - Session status")
            
            if isRequestCancelled {
                return completionHandler(.failure(.cancelled))
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.urlTask?.cancel()
                Logging.errorLog(forMethod: "RIA.MobileID - Session status", httpResponse: response as? HTTPURLResponse ?? nil, error: .noResponseError, extraInfo: "")
                return completionHandler(.failure(.noResponseError))
            }
            
            if error != nil {
                self.urlTask?.cancel()
                Logging.errorLog(forMethod: "RIA.MobileID - Session status", httpResponse: response as? HTTPURLResponse ?? nil, error: .generalError, extraInfo: error?.localizedDescription ?? "Error getting response")
                return completionHandler(.failure(.generalError))
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                self.urlTask?.cancel()
                Logging.errorLog(forMethod: "RIA.MobileID - Session status", httpResponse: httpResponse, error: self.handleHTTPSessionResponseError(httpResponse: httpResponse) , extraInfo: "Status code: \(httpResponse.statusCode)")
                return completionHandler(.failure(self.handleHTTPSessionStatusResponseError(httpResponse: httpResponse) ))
            }
            
            if let data: Data = data {
                self.urlTask?.cancel()
                EncoderDecoder().decode(data: data, completionHandler: { (response: SessionStatusResponse) in
                    Logging.log(forMethod: "RIA.MobileID - getSessionStatus", info: "Response: \n \(String(data: data, encoding: .utf8) ?? "Unable to get response info")")
                    if (response.error == nil) {
                        if response.state == SessionResponseState.COMPLETE {
                            Logging.log(forMethod: "RIA.MobileID - getSessionStatus", info: "Polling cancelled")
                            return completionHandler(.success(response))
                        } else {
                            // Poll again as SessionResponseState is not COMPLETE
                            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.defaultTimeoutS) {
                                self.getSessionStatus(baseUrl: baseUrl, process: process, requestParameters: requestParameters, trustedCertificates: trustedCertificates, manualProxyConf: manualProxyConf, completionHandler: completionHandler)
                            }
                        }
                    } else {
                        Logging.errorLog(forMethod: "RIA.MobileID - Session status", httpResponse: httpResponse, error: self.handleHTTPSessionResponseError(httpResponse: httpResponse) , extraInfo: response.error ?? "Unknown error received")
                        return completionHandler(.failure(self.handleHTTPSessionStatusResponseError(httpResponse: httpResponse) ))
                    }
                })
            }
        }
        sessionTask?.resume()
        self.urlTask = sessionTask
    }
    
    private func handleHTTPSessionResponseError(httpResponse: HTTPURLResponse) -> SigningError {
        switch httpResponse.statusCode {
        case 400:
            return .parameterNameNull
        case 401:
            return .userAuthorizationFailed
        case 405:
            return .methodNotAllowed
        case 500:
            return .internalError
        default:
            return .technicalError
        }
    }
    
    private func handleHTTPSessionStatusResponseError(httpResponse: HTTPURLResponse) -> SigningError {
        switch httpResponse.statusCode {
        case 400:
            return .sessionIdMissing
        case 401:
            return .userAuthorizationFailed
        case 403:
            return .midInvalidAccessRights
        case 404:
            return .sessionIdNotFound
        case 405:
            return .methodNotAllowed
        case 429:
            return .tooManyRequests(signingMethod: SigningType.mobileId.rawValue)
        case 500:
            return .internalError
        default:
            return .technicalError
        }
    }
}

