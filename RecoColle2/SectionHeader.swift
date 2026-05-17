//
//  SectionHeader.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2024/02/25.
//

import UIKit

class SectionHeader: UICollectionReusableView {
    
    @IBOutlet weak var sectionHeader: UILabel!
    @IBOutlet weak var sortButton: UIButton!
    
    // ボタンが押されたら呼ばれる closure
    var sortAction: (() -> Void)?
    
    @IBAction func sortButtonTapped(_ sender: UIButton) {
        sortAction?()
    }
}
