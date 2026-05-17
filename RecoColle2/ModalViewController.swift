//
//  ModalViewController.swift
//  RecoColle2
//
//  Created by 丸田信一 on 2024/08/04.
//

import UIKit

class ModalViewController: UIViewController {

    @IBOutlet weak var modalView: UITableView!
    @IBAction func tapButton(_ sender: UIButton) {
        // クロージャで選択したもののインデックス番号を返却
        closure(pickerView.selectedRow(inComponent: 0))
        self.dismiss(animated: true, completion: nil)
    }
    // ここにリストを収める
    var list: Array<String>!

    // クロージャー
    var closure: ((Int) -> Void)!

    var pickerView: UIPickerView! // ピッカー
    var OKButton:   UIButton!     // OKボタン

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        // Viewの設定
        modalView.delegate   = self
        modalView.dataSource = self
        modalView.separatorStyle  = .none
        modalView.isScrollEnabled = false
        modalView.allowsSelection = false
        modalView.layer.cornerRadius = 10
        
        pickerView = UIPickerView()
        pickerView.delegate = self
        pickerView.dataSource = self
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
extension ModalViewController: UITableViewDelegate, UITableViewDataSource{
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // セル数
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "PickerViewCell", for: indexPath)
        // ピッカー
        if(indexPath.row == 0){
            pickerView.frame = CGRect(x: 10, y: 10, width: tableView.frame.width - 20, height: 210)
            
            cell.addSubview(pickerView)
        // ボタン
        }else{
            OKButton = UIButton(frame: CGRect(x: 10, y: 10, width: tableView.frame.width - 20, height: 50))
            OKButton.backgroundColor = UIColor.systemBlue
            OKButton.layer.cornerRadius = 10
            OKButton.setTitle("OK", for: .normal)
            OKButton.addTarget(self, action: #selector(tapButton(_:)), for: .touchUpInside)
            cell.addSubview(OKButton)
            
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        // ピッカー
        if(indexPath.row == 0){
            return 230
        // ボタン
        }else{
            return 230
        }
    }
    
//    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
//
//            return 250
//    }
}

extension ModalViewController: UIPickerViewDelegate, UIPickerViewDataSource{
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return list.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return list[row]
    }
    
    
}
