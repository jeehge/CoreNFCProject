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
    var readerSession: NFCNDEFReaderSession?
    var ndefMessage: NFCNDEFMessage?
    var resultPayload: Array<NFCNDEFPayload> = [] // write value
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        initPayload()
    }
    
    // MARK: - Initalize
    func initPayload() {
        resultPayload = []
    }
    
    // MARK: - Actions
    @IBAction func writeNFCInfo(_ sender: UIButton) {
        let alertController: UIAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let textWrite: UIAlertAction = UIAlertAction(title: "TEXT", style: .default) { _ in
            guard let textPayload = NFCNDEFPayload.wellKnownTypeTextPayload(
                string: "쫘잔 여기다가 글쒸를 쓰면 나오지령",
                locale: Locale.current
                ) else { return }
            self.resultPayload.append(textPayload)
            self.checkedNFCTagAvailable()
        }
        
        let urlWrite: UIAlertAction = UIAlertAction(title: "URL", style: .default) { _ in
            if  let urlComponent = URLComponents(string: "https://www.naver.com"),
                let url = urlComponent.url,
                let urlPayload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) {
                
                self.resultPayload.append(urlPayload)
                self.checkedNFCTagAvailable()
            }
        }
        
        let cancel: UIAlertAction = UIAlertAction(title: "cancel", style: .cancel, handler: nil)
        
        alertController.addAction(textWrite)
        alertController.addAction(urlWrite)
        alertController.addAction(cancel)
        present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - Private helper functions
    private func checkedNFCTagAvailable() {
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
    
    private func tagRemovalDetect(_ tag: NFCNDEFTag) {
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
            guard let tag = tags.first else { return }
            session.connect(to: tag) { (error: Error?) in
                if error != nil {
                    session.restartPolling()
                } else {
                    // You then query the NDEF status of tag.
                    tag.queryNDEFStatus() { (status: NFCNDEFStatus, capacity: Int, error: Error?) in
                        if error != nil {
                            session.invalidate(errorMessage: "NDEF 상태를 확인하지 못 했습니다. 다시 시도해주세요.".localized)
                        } else {
                            if status == .readOnly {
                                session.invalidate(errorMessage: "태그를 쓸 수 없습니다.".localized)
                            } else if status == .readWrite {
                                if self.ndefMessage!.length > capacity {
                                    session.invalidate(errorMessage: "태그 용량이 너무 작습니다. 최소 크기 요구 사항은 [byte] 바이트입니다.".localized.replace("[byte]", "\(self.ndefMessage!.length)"))
                                } else {
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
                                }
                            } else {
                                session.invalidate(errorMessage: "태그가 NDEF 형식이 아닙니다.".localized)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("readerSessionDidBecomeActive")
        ndefMessage = NFCNDEFMessage(records: resultPayload)
        os_log("MessageSize=%d", ndefMessage!.length)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("readerSession:didInvalidateWithError")
        // If necessary, you may handle the error. Note session is no longer valid.
        // You must create a new session to restart RF polling.
    }
}
