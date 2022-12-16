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

    override func viewDidLoad() {
        super.viewDidLoad()

        let titleImageView = UIImageView(image: UIImage(named: "Logo_Vaike"))
        titleImageView.isAccessibilityElement = true
        titleImageView.accessibilityLabel = L(.digidocImageAccessibility)
        titleImageView.accessibilityTraits = [.image]
        navigationItem.titleView = titleImageView
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
        let titleLabel = ScaledLabel()
        titleLabel.text = title
        titleLabel.textColor = UIColor.black
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.01

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
        view.layer.borderColor = UIColor.moppContentLine.cgColor
        view.layer.borderWidth = 1.0
    }

}
