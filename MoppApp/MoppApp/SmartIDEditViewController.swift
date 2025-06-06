/*
 * MoppApp - SmartIDEditViewController.swift
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

protocol SmartIDEditViewControllerDelegate : AnyObject {
    func smartIDEditViewControllerDidDismiss(cancelled: Bool, country: String?, idCode: String?)
}

class CountryTextField: MyTextField {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func caretRect(for position: UITextPosition) -> CGRect {
        return CGRect.zero
    }

    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        return []
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.copy(_:)) ||
            action == #selector(UIResponderStandardEditActions.selectAll(_:)) ||
            action == #selector(UIResponderStandardEditActions.paste(_:)) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
}

class SmartIDEditViewController : MoppViewController {
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var idCodeTextField: PersonalCodeField!
    @IBOutlet weak var countryTextField: UITextField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var countryLabel: UILabel!
    @IBOutlet weak var idCodeLabel: UILabel!
    @IBOutlet weak var personalCodeErrorLabel: UILabel!
    @IBOutlet weak var cancelButton: ScaledButton!
    @IBOutlet weak var signButton: ScaledButton!
    @IBOutlet weak var rememberLabel: UILabel!
    @IBOutlet weak var rememberSwitch: UISwitch!
    @IBOutlet weak var rememberStackView: UIStackView!
    @IBOutlet weak var actionButtonsStackView: UIStackView!

    weak var delegate: SmartIDEditViewControllerDelegate? = nil
    var tapGR: UITapGestureRecognizer!
    var countryViewPicker = UIPickerView()

    @IBAction func openCountryPicker(_ sender: Any) {
        UIAccessibility.post(notification: .layoutChanged, argument: countryViewPicker)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.text = L(.smartIdTitle)
        countryLabel.text = L(.smartIdCountryTitle)
        countryLabel.textColor = UIColor.moppText
        idCodeLabel.text = L(.signingIdcodeTitle)
        idCodeLabel.textColor = UIColor.moppText
        cancelButton.setTitle(L(.actionCancel).uppercased())
        signButton.setTitle(L(.actionSign).uppercased())
        rememberLabel.text = L(.signingRememberMe)

        cancelButton.adjustedFont()
        signButton.adjustedFont()
        
        rememberLabel.isAccessibilityElement = false
        rememberSwitch.accessibilityLabel = L(.signingRememberMe)

        countryLabel.isAccessibilityElement = false
        idCodeLabel.isAccessibilityElement = false
        rememberLabel.isAccessibilityElement = false

        countryTextField.accessibilityLabel = L(.smartIdCountryTitle)
        countryTextField.accessibilityUserInputLabels = [L(.voiceControlCountry)]
        idCodeTextField.accessibilityLabel = L(.signingIdcodeTitle)
        rememberSwitch.accessibilityLabel = rememberLabel.text

        idCodeTextField.layer.borderColor = UIColor.moppContentLine.cgColor
        idCodeTextField.layer.borderWidth = 1.0

        personalCodeErrorLabel.text = ""
        personalCodeErrorLabel.isHidden = true
        personalCodeErrorLabel.isAccessibilityElement = false

        countryViewPicker.dataSource = self
        countryViewPicker.delegate = self

        countryTextField.moppPresentDismissButton()
        countryTextField.inputView = countryViewPicker
        countryTextField.layer.borderColor = UIColor.moppContentLine.cgColor
        countryTextField.layer.borderWidth = 1.0
        
        rememberSwitch.addTarget(self, action: #selector(toggleRememberMe), for: .valueChanged)

        tapGR = UITapGestureRecognizer()
        tapGR.addTarget(self, action: #selector(cancelAction))
        view.addGestureRecognizer(tapGR)

        if UIAccessibility.isVoiceOverRunning {
            guard let titleUILabel = titleLabel, let countryUILabel = countryLabel, let countryUITextField = countryTextField, let idCodeUILabel = idCodeLabel, let idCodeUITextField = idCodeTextField, let personalCodeErrorUILabel = personalCodeErrorLabel, let rememberUILabel = rememberLabel, let rememberUISwitch = rememberSwitch, let cancelUIButton = cancelButton, let signUIButton = signButton else {
                printLog("Unable to get titleLabel, countryLabel, countryTextField, idCodeLabel, idCodeTextField, personalCodeErrorLabel, rememberLabel, rememberSwitch, cancelButton or signButton")
                return
            }
            
            self.view.accessibilityElements = [titleUILabel, countryUILabel, countryUITextField, idCodeUILabel, idCodeUITextField, personalCodeErrorUILabel, rememberUILabel, rememberUISwitch, cancelUIButton, signUIButton]
        }

        NotificationCenter.default.addObserver(self, selector: #selector(handleAccessibilityKeyboard), name: .focusedAccessibilityElement, object: nil)
    }

    @objc func dismissKeyboard(_ notification: NSNotification) {
        idCodeTextField.resignFirstResponder()
        countryTextField.resignFirstResponder()
    }

    @objc func pickerDoneButtonTapped() {
        self.countryTextField.endEditing(true)
    }

    @objc func codeDoneButtonTapped() {
        self.idCodeTextField.endEditing(true)
    }

    @objc func codeDashButtonTapped() {
        let text = self.idCodeTextField.text ?? ""
        self.idCodeTextField.text = text + "-"
    }

    @IBAction func editingChanged(_ sender: UITextField) {
        verifySigningCapability()
        let text = sender.text ?? String()
        if countryViewPicker.selectedRow(inComponent: 0) == 0 &&
            text.count >= 11 &&
            !PersonalCodeValidator.isPersonalCodeValid(personalCode: text) {
            TextUtil.deleteBackward(textField: sender)
            verifySigningCapability()
        }
    }

    @IBAction func cancelAction() {
        dismiss(animated: false) { [weak self] in
            guard let sself = self else { return }
            sself.delegate?.smartIDEditViewControllerDidDismiss(
                cancelled: true,
                country: nil,
                idCode: nil)
            UIAccessibility.post(notification: .screenChanged, argument: L(.signingCancelled))
        }
    }

    @IBAction func signAction() {
       
        if rememberSwitch.isOn {
            DefaultsHelper.sidIdCode = idCodeTextField.text ?? String()
            DefaultsHelper.sidCountry = getCountry()
            rememberSwitch.accessibilityUserInputLabels = ["Disable remember me"]
        }
        else {
            DefaultsHelper.sidIdCode = String()
            DefaultsHelper.sidCountry = String()
            rememberSwitch.accessibilityUserInputLabels = ["Enable remember me"]
        }
        if DefaultsHelper.isRoleAndAddressEnabled {
            let roleAndAddressView = UIStoryboard.tokenFlow.instantiateViewController(of: RoleAndAddressViewController.self)
            roleAndAddressView.modalPresentationStyle = .overCurrentContext
            roleAndAddressView.modalTransitionStyle = .crossDissolve
            roleAndAddressView.onComplete = { [weak self] in self?.sign() }
            present(roleAndAddressView, animated: true)
        } else {
            sign()
        }
    }

    @objc func toggleRememberMe(_ sender: UISwitch) {
        if sender.isOn {
            rememberSwitch.accessibilityUserInputLabels = ["Disable remember me"]
        } else {
            rememberSwitch.accessibilityUserInputLabels = ["Enable remember me"]
        }
    }
    
    func getCountry() -> String {
        return {
            switch countryViewPicker.selectedRow(inComponent: 0) {
            case 1: return "LT"
            case 2: return "LV"
            default: return "EE"
            }
        }()
    }

    func sign() {
        dismiss(animated: false) {
            self.delegate?.smartIDEditViewControllerDidDismiss(
                cancelled: false,
                country: self.getCountry(),
                idCode: self.idCodeTextField.text)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let row: Int = {
            switch DefaultsHelper.sidCountry {
            case "LT": return 1
            case "LV": return 2
            default: return 0
            }
        }()
        countryViewPicker.selectRow(row, inComponent: 0, animated: true)
        countryTextField.text = self.pickerView(countryViewPicker, titleForRow: row, forComponent: 0)
        idCodeTextField.attributedPlaceholder = NSAttributedString(string: L(.smartIdCountryTitle), attributes: [NSAttributedString.Key.foregroundColor: UIColor.moppPlaceholderDarker])
        idCodeTextField.text = DefaultsHelper.sidIdCode
        idCodeTextField.attributedPlaceholder = NSAttributedString(string: L(.settingsIdCodePlaceholder), attributes: [NSAttributedString.Key.foregroundColor: UIColor.moppPlaceholderDarker])
        
        idCodeTextField.moppPresentDismissButton()
        if row != 0 && idCodeTextField.inputAccessoryView is UIToolbar {
            setExtraToolbarButtons(idCodeTextField: idCodeTextField)
        }
        
        defaultRememberMeToggle()

        verifySigningCapability()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.backgroundColor = UIColor.black.withAlphaComponent(0.0)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func defaultRememberMeToggle() {
        rememberSwitch.setOn(DefaultsHelper.smartIdRememberMe, animated: true)
        rememberSwitch.accessibilityUserInputLabels = [DefaultsHelper.mobileIdRememberMe ? "Disable remember me" : "Enable remember me"]
    }
    
    @objc func handleAccessibilityKeyboard(_ notification: NSNotification) {
        if UIAccessibility.isVoiceOverRunning {
            dismissKeyboard(notification)
            ViewUtil.focusOnView(notification, mainView: self.view, scrollView: scrollView)
        }
    }

    func verifySigningCapability() {
        let codeTextField = idCodeTextField.text ?? String()
        signButton.isEnabled = countryViewPicker.selectedRow(inComponent: 0) != 0 || !TokenFlowUtil.isPersonalCodeInvalid(text: codeTextField)
        signButton.backgroundColor = signButton.isEnabled ? UIColor.moppBase : UIColor.moppLabel
    }

    override func keyboardWillShow(notification: NSNotification) {
        if countryTextField.isFirstResponder {
            showKeyboard(textFieldLabel: countryLabel, scrollView: scrollView)
        }

        if idCodeTextField.isFirstResponder {
            showKeyboard(textFieldLabel: idCodeLabel, scrollView: scrollView)
        }
    }

    override func keyboardWillHide(notification: NSNotification) {
        hideKeyboard(scrollView: scrollView)
    }
}

extension SmartIDEditViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 3
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch row {
        case 1: return L(.smartIdCountryLithuania)
        case 2: return L(.smartIdCountryLatvia)
        default: return L(.smartIdCountryEstonia)
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        countryTextField.text = self.pickerView(pickerView, titleForRow: row, forComponent: component)
        countryTextField.accessibilityLabel = ""
        UIAccessibility.post(notification: .announcement, argument: countryTextField.text)
        idCodeTextField.moppPresentDismissButton()
        if row != 0 && idCodeTextField.inputAccessoryView is UIToolbar {
            setExtraToolbarButtons(idCodeTextField: idCodeTextField)
        }

        idCodeTextField.reloadInputViews()

        if row == 0 {
            idCodeTextField.text = idCodeTextField.text?.filter("0123456789.".contains).substr(offset: 0, count: 11)
        }
        verifySigningCapability()
    }

    private func setExtraToolbarButtons(idCodeTextField: UITextField) {
        let toolbar: UIToolbar = idCodeTextField.inputAccessoryView as? UIToolbar ?? UIToolbar()
        toolbar.items?.insert(
            UIBarButtonItem(title: "-", style: .plain, target: self, action: #selector(codeDashButtonTapped)), at: 0)
        toolbar.items?.insert(
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil), at: 1)
        toolbar.sizeToFit()
        idCodeTextField.inputAccessoryView = toolbar
    }
}

extension SmartIDEditViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.moveCursorToEnd()
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Verify signing capability after user has deleted a number
        if let idCodeField = textField as? PersonalCodeField {
            idCodeField.onDeleteButtonClicked = {
                self.verifySigningCapability()
            }
        }
        
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if countryViewPicker.selectedRow(inComponent: 0) != 0 {
            return true
        }
        if let text = textField.text as NSString? {
            let textAfterUpdate = text.replacingCharacters(in: range, with: string)
            return textAfterUpdate.isNumeric || textAfterUpdate.isEmpty
        }
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.accessibilityIdentifier == "smartIDCodeField" {
            if let text = textField.text as String? {
                if TokenFlowUtil.isPersonalCodeInvalid(text: text) {
                    personalCodeErrorLabel.text = L(.signingErrorIncorrectPersonalCode)
                    personalCodeErrorLabel.isHidden = false
                    personalCodeErrorLabel.isAccessibilityElement = true
                    setViewBorder(view: textField, color: .moppError)
                    UIAccessibility.post(notification: .layoutChanged, argument: self.personalCodeErrorLabel)
                } else {
                    personalCodeErrorLabel.text = ""
                    personalCodeErrorLabel.isHidden = true
                    personalCodeErrorLabel.isAccessibilityElement = false
                    removeViewBorder(view: textField)
                    UIAccessibility.post(notification: .layoutChanged, argument: idCodeTextField)
                }
            }
        }
    }
}
