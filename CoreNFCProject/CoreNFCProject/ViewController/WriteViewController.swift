//
//  WriteViewController.swift
//  CoreNFCProject
//
//  Created by JH on 2019/11/14.
//  Copyright © 2019 JH. All rights reserved.
//

import UIKit
import CoreNFC
import os

class WriteViewController: UIViewController {

    // MARK: - Properties
    @IBOutlet weak var tableView: UITableView!
    let reuseIdentifier = "reuseIdentifier"
    var messages = [NFCNDEFMessage]()
    var readerSession: NFCNDEFReaderSession?
    var ndefMessage: NFCNDEFMessage?
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initTableView()
        initMessagesSetting()
    }
    
    // MARK: - Initalize
    func initTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func initMessagesSetting() {
        
    }
    
    // MARK: - Actions
    @IBAction func addNFCInfo(_ sender: UIButton) {
        // write NFC 정보를 사용자가 셋팅할 수 있는 정보가 필요함
    }
    
    @IBAction func writeNFCInfo(_ sender: UIButton) {
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "지원하지 않습니다".localized,
                message: "이 장치는 스캔을 지원하지 않습니다.".localized,
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "확인".localized, style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        readerSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        readerSession?.alertMessage = "업데이트할 쓰기 가능한 NFC 태그 근처에 iPhone을 유지해주세요.".localized
        readerSession?.begin()
    }
    
    func updateWithCouponCode(_ code: String) {
        DispatchQueue.main.async {
//            self.couponText.text = code
        }
    }
    
    // MARK: - Private helper functions
    func readCouponCode(from tag: NFCTag) {
        guard case let .miFare(mifareTag) = tag else {
            return
        }
        
        DispatchQueue.global().async {

            // Block size of T2T tag is 4 bytes. Coupon code is stored starting
            // at block 04. Assume the maximum coupon code length is 16 bytes.
            // Coupon code data structure is as follow:
            // Block 04 => Header of the coupon. 2 bytes magic signature + 1 byte use counter + 1 byte length field.
            // Block 05 => Start of coupon code. Continues as indicated by the length field.
            
            let blockSize = 16
            // T2T Read command, returns 16 bytes in response.
            let readBlock4: [UInt8] = [0x30, 0x04]
            let magicSignature: [UInt8] = [0xFE, 0x01]
            let useCounterOffset = 2
            let lengthOffset = 3
            let headerLength = 4
            let maxCodeLength = 16
            
            mifareTag.sendMiFareCommand(commandPacket: Data(readBlock4)) { (responseBlock4: Data, error: Error?) in
                if error != nil {
                    self.readerSession?.invalidate(errorMessage: "Read tag error. Please try again.")
                    return
                }
                
                // Validate magic signature and use counter
                if !responseBlock4[0...1].elementsEqual(magicSignature) || responseBlock4[useCounterOffset] < 1 {
                    self.readerSession?.invalidate(errorMessage: "No valid coupon found.")
                    return
                }
                
                let length = Int(responseBlock4[lengthOffset])
                
                if length > maxCodeLength {
                    self.readerSession?.invalidate(errorMessage: "No valid coupon found.")
                    return
                } else if length < blockSize - headerLength {
                    let code = String(bytes: responseBlock4[headerLength ... headerLength + length], encoding: .ascii)
                    self.updateWithCouponCode(code!)
                    self.readerSession?.alertMessage = "Valid coupon found."
                    self.readerSession?.invalidate()
                } else {
                    var buffer = responseBlock4[headerLength ... headerLength + length]
                    let remain = length - buffer.count
                    let readBlock8: [UInt8] = [0x30, 0x08]
                    
                    mifareTag.sendMiFareCommand(commandPacket: Data(readBlock8)) { (responseBlock8: Data, error: Error?) in
                        if error != nil {
                            self.readerSession?.invalidate(errorMessage: "Read tag error. Please try again.")
                            return
                        }
                        buffer += responseBlock8[0 ... remain]
                        let code = String(bytes: buffer, encoding: .ascii)
                        self.updateWithCouponCode(code!)
                        self.readerSession?.alertMessage = "Valid coupon found."
                        self.readerSession?.invalidate()
                    }
                }
            }
        }
    }
    
    // MARK: - Private functions
    func createURLPayload() -> NFCNDEFPayload? {
        var dateString: String?
        var priceString: String?
        var kindString: String?
        
        DispatchQueue.main.sync {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            dateString = dateFormatter.string(from: Date())
            
            kindString = fishKinds[productKind.selectedRow(inComponent: 0)]
            
            priceString = priceBCD[productPrice.selectedSegmentIndex]
        }
        
        var urlComponent = URLComponents(string: "https://fishtagcreator.example.com/")
        
        urlComponent?.queryItems = [URLQueryItem(name: "date", value: dateString),
                                    URLQueryItem(name: "kind", value: kindString),
                                    URLQueryItem(name: "price", value: priceString)]
        
        os_log("url: %@", (urlComponent?.string)!)
        
        return NFCNDEFPayload.wellKnownTypeURIPayload(url: (urlComponent?.url)!)
    }
    
    func tagRemovalDetect(_ tag: NFCNDEFTag) {
        // In the tag removal procedure, you connect to the tag and query for
        // its availability. You restart RF polling when the tag becomes
        // unavailable; otherwise, wait for certain period of time and repeat
        // availability checking.
        self.readerSession?.connect(to: tag) { (error: Error?) in
            if error != nil || !tag.isAvailable {
                
                os_log("Restart polling")
                
                self.readerSession?.restartPolling()
                return
            }
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .milliseconds(500), execute: {
                self.tagRemovalDetect(tag)
            })
        }
    }

}

/// NDEF 리더 세션 대리자 역할을 하기 위해 개체가 구현하는 프로토콜
extension WriteViewController: UINavigationControllerDelegate, NFCNDEFReaderSessionDelegate {
    
    // MARK: - NFC Reader Session Delegate
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("readerSession:didDetectNDEFs")
        // Do not add code in this function. This method isn't called
        // when you provide `reader(_:didDetect:)`.
    }
    
    // 리더가 RF 필드에서 NDEF 태그를 감지하면 호출
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        print("readerSession:didDetect")
        
        if tags.count > 1 {
            session.alertMessage = "태그가 두개 이상 발견되었습니다. 태그 하나만 표시해주세요.".localized
            self.tagRemovalDetect(tags.first!)
        } else {
            // You connect to the desired tag.
            let tag = tags.first!
            session.connect(to: tag) { (error: Error?) in
                if error != nil {
                    session.restartPolling()
                    return
                }
                
                // You then query the NDEF status of tag.
                tag.queryNDEFStatus() { (status: NFCNDEFStatus, capacity: Int, error: Error?) in
                    if error != nil {
                        session.invalidate(errorMessage: "NDEF 상태를 확인하지 못 했습니다. 다시 시도해보세요.".localized)
                        return
                    }
                    
                    if status == .readOnly {
                        session.invalidate(errorMessage: "태그를 쓸 수 없습니다.".localized)
                    } else if status == .readWrite {
                        if self.ndefMessage!.length > capacity {
                            session.invalidate(errorMessage: "태그 용량이 너무 작습니다. 최소 크기 요구 사항은 [byte] 바이트입니다.".localized.replace("[byte]", "\(self.ndefMessage!.length)"))
                            return
                        }
                        
                        // When a tag is read-writable and has sufficient capacity,
                        // write an NDEF message to it.
                        tag.writeNDEF(self.ndefMessage!) { (error: Error?) in
                            if error != nil {
                                session.invalidate(errorMessage: "태그 업데이트에 실패했습니다. 다시 시도해주세요.".localized)
                            } else {
                                session.alertMessage = "업데이트 성공!".localized
                                session.invalidate()
                            }
                        }
                    } else {
                        session.invalidate(errorMessage: "태그가 NDEF 형식이 아닙니다.".localized)
                    }
                }
            }
        }
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("readerSessionDidBecomeActive")
        let textPayload = NFCNDEFPayload.wellKnownTypeTextPayload(
            string: "Brought to you by the Great Fish Company",
            locale: Locale.current
        )
        let urlPayload = createURLPayload()
        ndefMessage = NFCNDEFMessage(records: [urlPayload!, textPayload!])
        os_log("MessageSize=%d", ndefMessage!.length)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("readerSession:didInvalidateWithError")
        // If necessary, you may handle the error. Note session is no longer valid.
        // You must create a new session to restart RF polling.
    }
    
    
}

extension WriteViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        cell.backgroundColor = .red
        return cell
    }
}



