//
//  Graphique.swift
//  BonSang
//
//  Created by Brereton Hurley Eoin on 17/03/2026.
//

import UIKit

class Graphique: UIView {

    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
        let path = UIBezierPath()

        let graphHeight: CGFloat = 250
        let graphWidth = self.bounds.width - 40

        let startX: CGFloat = 20
        let bottomY = self.bounds.height - 120

        //let valueRange = maxValue - minValue == 0 ? 1 : maxValue - minValue
    }
    

}
