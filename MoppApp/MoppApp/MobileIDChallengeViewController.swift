//
//  MobileIDChallengeViewController.swift
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

import SkSigningLib

private var kRequestTimeout: Double = 120.0


class MobileIDChallengeViewController : UIViewController {
    
    @IBOutlet weak var codeLabel: UILabel!
    @IBOutlet weak var timeoutProgressView: UIProgressView!
    @IBOutlet weak var helpLabel: UILabel!
    
    var challengeID = String()
    var sessCode = String()

    var currentProgress: Double = 0.0
    var sessionTimer: Timer?
    
    var isAnnouncementMade: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        helpLabel.text = L(.mobileIdSignHelpTitle)
        codeLabel.isHidden = true
        timeoutProgressView.progress = 0

        NotificationCenter.default.addObserver(self, selector: #selector(receiveCreateSignatureStatus), name: .signatureAddedToContainerNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveErrorNotification), name: .errorNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveStatusPendingNotification), name: .signatureMobileIDPendingRequestNotificationName, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(receiveMobileCreateSignatureNotification),
            name: .createSignatureNotificationName,
            object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didFinishAnnouncement(_:)),
            name: NSNotification.Name.UIAccessibilityAnnouncementDidFinish,
            object: nil)
    }
    
    @objc func didFinishAnnouncement(_ notification: Notification) {
        let announcementValue: String? = notification.userInfo?[UIAccessibilityAnnouncementKeyStringValue] as? String
        let isAnnouncementSuccessful: Bool? = notification.userInfo?[UIAccessibilityAnnouncementKeyWasSuccessful] as? Bool
        
        guard let isSuccessful = isAnnouncementSuccessful else {
            return
        }
        
        if !isSuccessful {
            NSLog("Control code announcement was not successful, retrying...")
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, announcementValue)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func receiveStatusPendingNotification(_ notification: Notification) {
        if UIAccessibilityIsVoiceOverRunning() {
            if !isAnnouncementMade {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: { [weak self] in
                    let challengeIdNumbers = Array<Character>(self!.challengeID)
                    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, L(LocKey.challengeCodeLabel, ["\(challengeIdNumbers[0]), \(challengeIdNumbers[1]), \(challengeIdNumbers[2]), \(challengeIdNumbers[3]). \(self!.helpLabel.text!)"]))
                    self?.isAnnouncementMade = true
                })
            }
        }
    }

    @objc func receiveCreateSignatureStatus(_ notification: Notification) {
        sessionTimer?.invalidate()
        NotificationCenter.default.post(name: .signatureCreatedFinishedNotificationName, object: nil)
        dismiss(animated: false)
    }
    
    @objc func receiveMobileCreateSignatureNotification(_ notification: Notification) {

        guard let response = notification.userInfo?[kCreateSignatureResponseKey] as? MoppLibMobileCreateSignatureResponse else {
            return
        }
    
        challengeID = response.challengeId!
        sessCode = "\(Int(response.sessCode))"
        let challengeIdNumbers = Array<Character>(challengeID)
        let challengeIdAccessibilityLabel: String = "\((L(LocKey.challengeCodeLabelAccessibility, [String(challengeIdNumbers[0]), String(challengeIdNumbers[1]), String(challengeIdNumbers[2]), String(challengeIdNumbers[3])]))). \(self.helpLabel.text!)"
        codeLabel.accessibilityLabel = challengeIdAccessibilityLabel
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, challengeIdAccessibilityLabel)
    
        codeLabel.isHidden = false
        codeLabel.text = L(LocKey.challengeCodeLabel, [challengeID])
        
        currentProgress = 0.0
        
        sessionTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateSessionProgress), userInfo: nil, repeats: true)
    }
  
    @objc func receiveErrorNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let error = userInfo[kErrorKey] as? NSError
        let signingErrorMessage = error?.userInfo[NSLocalizedDescriptionKey] as? SigningError
        let errorMessage = userInfo[kErrorMessage] as? String ?? SigningError.generalError.signingErrorDescription ?? L(.genericErrorMessage)
        return showErrorDialog(errorMessage: SkSigningLib_LocalizedString(signingErrorMessage?.signingErrorDescription ?? errorMessage))
    }
  
    func showErrorDialog(errorMessage: String) -> Void {
        DispatchQueue.main.async {
            self.dismiss(animated: false) {
                let topViewController = self.getTopViewController()
                
                let errorMessageNoLink: String? = errorMessage.removeFirstLinkFromMessage()
                
                let alert = UIAlertController(title: L(.errorAlertTitleGeneral), message: errorMessageNoLink, preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                if let linkInUrl: String = errorMessage.getFirstLinkInMessage() {
                    if let alertActionUrl: UIAlertAction = UIAlertAction().getLinkAlert(message: linkInUrl) {
                        alert.addAction(alertActionUrl)
                    }
                }
                
                topViewController.present(alert, animated: true, completion: nil)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        UIView.animate(withDuration: 0.35) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionTimer?.invalidate()
    }

    @objc func updateSessionProgress(_ timer: Timer) {
        if currentProgress < 1.0 {
            let step: Double = 1.0 / kRequestTimeout
            currentProgress = currentProgress + step
            timeoutProgressView.progress = Float(currentProgress)
        }
        else {
            timer.invalidate()
            dismiss(animated: false, completion: nil)
        }
    }

}
