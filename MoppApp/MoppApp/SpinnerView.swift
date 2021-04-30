//
//  SpinnerView.swift
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
class SpinnerView : UIView {
    @IBOutlet weak var spinningElement: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        show(true)
    }

    func show(_ show: Bool) {
        
        isHidden = !show
        
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.toValue = Double.pi * 2
            rotation.duration = 1.0
            rotation.isCumulative = true
            rotation.repeatCount = .greatestFiniteMagnitude
        
        spinningElement.layer.add(rotation, forKey: "loaderRotation")
    }
    
    func updateFrame() {
        guard let superview = superview else { return }
        let newFrame = CGRect(x: 0, y: 0, width: superview.frame.width, height: superview.frame.height)
        frame = newFrame
    }
}
