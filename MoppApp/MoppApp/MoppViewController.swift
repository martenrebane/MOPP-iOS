//
//  MoppViewController.swift
//  MoppApp
//
/*
 * Copyright 2017 - 2022 Riigi Infosüsteemi Amet
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
class MoppViewController : UIViewController {
    var lightContentStatusBarStyle : Bool = false
    
    var isShowingKeyboard = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleImageView = UIImageView(image: UIImage(named: "Logo_Vaike"))
        navigationItem.titleView = titleImageView
        titleImageView.accessibilityElementsHidden = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setNeedsStatusBarAppearanceUpdate()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        spinnerView?.updateFrame()
    }
    
    var spinnerView: SpinnerView? {
        get {
            return view.subviews.first(where: { $0 is SpinnerView }) as? SpinnerView
        }
    }
    
    func showLoading(show: Bool, forFrame: CGRect? = nil) {
        if show {
            if let spinnerView = spinnerView {
                spinnerView.show(true)
            } else {
                if let spinnerView = MoppApp.instance.nibs[.customElements]?.instantiate(withOwner: self, type: SpinnerView.self) {
                    spinnerView.show(true)
                    spinnerView.frame = forFrame ?? view.frame
                    view.addSubview(spinnerView)
                }
            }
        } else {
            if let spinnerView = spinnerView {
                spinnerView.show(false)
                spinnerView.removeFromSuperview()
            }
        }
    }
    
    func refreshLoadingAnimation() {
        if let spinnerView = view.subviews.first(where: { $0 is SpinnerView }) as? SpinnerView {
            spinnerView.show(true)
        }
    }
    
    func setupNavigationItemForPushedViewController(title: String, filePath: String = "") {
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
        if isBoldTextEnabled() { titleLabel.font = UIFont.boldSystemFont(ofSize: titleLabel.font.pointSize) }
        if isNonDefaultPreferredContentSizeCategoryBigger() {
            titleLabel.font = UIFont.setCustomFont(font: .medium, 22, .body)
            titleLabel.numberOfLines = 3
        } else if !isNonDefaultPreferredContentSizeCategory() {
            titleLabel.font = UIFont.setCustomFont(font: .medium, 20, .body)
        }
        titleLabel.text = title
        titleLabel.textColor = UIColor.black
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingMiddle
        
        
        navigationItem.titleView = titleLabel
        
        let backBarButtonItem = UIBarButtonItem(image: UIImage(named: "navBarBack"), style: .plain, target: self, action: #selector(backAction))
        backBarButtonItem.accessibilityLabel = L(.backButton)
        navigationItem.setLeftBarButton(backBarButtonItem, animated: true)
        if !filePath.isEmpty {
            let shareBarButtonItem = WrapperUIBarButtonItem(image: UIImage(named: "navBarShare"), style: .plain, target: self, action: #selector(shareAction(sender:)))
            shareBarButtonItem.filePath = filePath
            navigationItem.setRightBarButton(shareBarButtonItem, animated: true)
        }
    }

    @objc func backAction() {
        _ = navigationController?.popViewController(animated: true)
    }
    @objc func shareAction(sender: WrapperUIBarButtonItem) {
        LandingViewController.shared.shareFile(using: URL(fileURLWithPath: sender.filePath!), sender: self.view, completion: { bool in })
    }
    
    func setViewBorder(view: UIView, color: UIColor) {
        view.layer.borderColor = color.cgColor
        view.layer.borderWidth = 1.0
    }
    
    func removeViewBorder(view: UIView) {
        view.layer.borderColor = UIColor.lightGray.cgColor
        view.layer.borderWidth = 0.2
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {}
    
    @objc func keyboardWillShow(notification: NSNotification) {}
    
    func showKeyboard(notification: NSNotification, selectedTextField: UITextField, buttonsBottomConstraint: NSLayoutConstraint?) {
        if let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            
            let keyboardHeight = keyboardFrame.height
            let keyboardYOrigin = keyboardFrame.origin.y
            
            if selectedTextField.isFirstResponder {
                if let bottomConstraint = buttonsBottomConstraint {
                    bottomConstraint.constant += (keyboardHeight / 2 + selectedTextField.frame.height)
                }
                if !isShowingKeyboard && selectedTextField.frame.origin.y > keyboardYOrigin - keyboardHeight {
                    if isDeviceOrientationLandscape() {
                        setParentViewControllerFrameOrigin(TokenFlowSelectionViewController.self, yOrigin: -keyboardYOrigin)
                        isShowingKeyboard = true
                    } else {
                        view.frame.origin.y -= (keyboardHeight / 2 - selectedTextField.frame.height)
                        isShowingKeyboard = true
                    }
                }
            }
        }
    }
    
    func hideKeyboard(_ uiView: UIView, buttonsBottomConstraint: NSLayoutConstraint?, buttonsBottomConstraintConstant: CGFloat?) {
        if let bottomConstraint = buttonsBottomConstraint, let bottomConstraintConstant = buttonsBottomConstraintConstant {
            bottomConstraint.constant = bottomConstraintConstant
        }
        setParentViewControllerFrameOrigin(TokenFlowSelectionViewController.self, yOrigin: 0)
        uiView.frame.origin.y = 0
        isShowingKeyboard = false
    }
    
    private func setParentViewControllerFrameOrigin<T: UIViewController>(_: T.Type, yOrigin: CGFloat) {
        if let parentViewController = self.parent as? T {
            parentViewController.view.frame.origin.y = yOrigin
        }
    }
}
