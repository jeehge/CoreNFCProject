//
//  ScanViewController.swift
//  CoreNFCProject
//
//  Created by JH on 2019/11/14.
//  Copyright © 2019 JH. All rights reserved.
//

import UIKit
import CoreNFC

extension NFCTypeNameFormat: CustomStringConvertible {
    public var description: String {
        switch self {
        case .nfcWellKnown: return "NFC Well Known type"
        case .media: return "Media type"
        case .absoluteURI: return "Absolute URI type"
        case .nfcExternal: return "NFC External type"
        case .unknown: return "Unknown type"
        case .unchanged: return "Unchanged type"
        case .empty: return "Empty payload"
        @unknown default: return "Invalid data"
        }
    }
}

class ScanViewController: UIViewController {

    // MARK: - Properties
    @IBOutlet weak var tableView: UITableView!
    
    let reuseIdentifier = "reuseIdentifier"         // table view cell identifier
    var detectedMessages = [NFCNDEFMessage]()       // 읽은 정보 가지고 있는 배열
    var message: NFCNDEFMessage = .init(records: [])
    var session: NFCNDEFReaderSession?
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        initTableView()
    }
    
    // MARK: - Initalize
    private func initTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        // 테이블뷰 높이 동적으로 할당
        tableView.estimatedRowHeight = 70
        tableView.rowHeight = UITableView.automaticDimension
    }
    
    // MARK: - Actions
    @IBAction func beginScanning(_ sender: UIButton) {
        
        // 장치가 NFC 태그 읽기를 지원하는 경우 true
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

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "자세히 알아보려면 iPhone을 NFC 태그 근처에 두세요.".localized
        session?.begin()
    }
}

extension ScanViewController: UITableViewDataSource, UITableViewDelegate {

    // MARK: - Table View Functions
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detectedMessages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        guard let textLabel = cell.textLabel else { return cell }

        textLabel.text = "잘못된 데이터".localized
        textLabel.numberOfLines = 0

        let message = detectedMessages[indexPath.row]
        var resultString: String = "" // 셀에 입력될 텍스트를 가지고 있는 변수
        message.records.forEach { payload in
            switch payload.typeNameFormat {
            case .nfcWellKnown:
                if let type = String(data: payload.type, encoding: .utf8) {
                    if let url = payload.wellKnownTypeURIPayload() {
                        resultString += "\(payload.typeNameFormat.description): \(type), url : \(url.absoluteString)"
                    } else {
                        let (additionInfo, _) = payload.wellKnownTypeTextPayload()
                        if let text = additionInfo {
                            resultString += "\(payload.typeNameFormat.description): \(type), text : \(text)"
                        } else {
                            resultString += "\(payload.typeNameFormat.description): \(type)"
                        }
                    }
                }
            case .absoluteURI:
                if let text = String(data: payload.payload, encoding: .utf8) {
                    resultString += text
                }
            case .media:
                if let type = String(data: payload.type, encoding: .utf8) {
                    resultString += "\(payload.typeNameFormat.description): " + type
                }
            case .nfcExternal, .empty, .unknown, .unchanged:
                fallthrough
            @unknown default:
                resultString += payload.typeNameFormat.description
            }
        }
        
        textLabel.text = resultString
        return cell
    }
}

/// NDEF 리더 세션 대리자 역할을 하기 위해 개체가 구현하는 프로토콜
extension ScanViewController: NFCNDEFReaderSessionDelegate {
    
    // MARK: - NFC Reader Session Delegate
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("readerSession:didDetectNDEFs")
        /// ???: 왜 얘는 호출은 안되는데 필수인거죠?
    }
    
    // 리더가 RF 필드에서 NDEF 태그를 감지하면 호출
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        print("readerSession:didDetect")
        
        if tags.count > 1 {
            // Restart polling in 500ms
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "하나 이상의 태그가 감지되었으므로, 모든 태그를 제거하고 다시 시도하세요.".localized
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
        } else {
            guard let tag = tags.first else { return }
            session.connect(to: tag, completionHandler: { (error: Error?) in
                if nil != error {
                    session.alertMessage = "태그에 연결할 수 없습니다.".localized
                    session.invalidate()
                } else {
                    tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                        if .notSupported == ndefStatus {
                            session.alertMessage = "태그가 NDEF 호환되지 않습니다".localized
                            session.invalidate()
                            return
                        } else if nil != error {
                            session.alertMessage = "태그의 NDEF 상태를 조회 할 수 없습니다".localized
                            session.invalidate()
                            return
                        }
                        
                        tag.readNDEF(completionHandler: { (message: NFCNDEFMessage?, error: Error?) in
                            var statusMessage: String
                            if nil != error || nil == message {
                                statusMessage = "태그에서 NDEF를 읽지 못했습니다".localized
                            } else {
                                statusMessage = "NDEF 메시지를 찾았습니다".localized
                                DispatchQueue.main.async {
                                    if let msg = message { // message를 찾으면 추가!
                                        self.detectedMessages.append(msg)
                                        self.tableView.reloadData()
                                    }
                                }
                            }
                            session.alertMessage = statusMessage
                            session.invalidate()
                        })
                    })
                }
            })
        }
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("readerSessionDidBecomeActive")
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("readerSession:didInvalidateWithError")
        
        // 에러가 있으면 보여주도록 alert 띄움
        if let readerError = error as? NFCReaderError {
            // Show an alert when the invalidation reason is not because of a
            // successful read during a single-tag read session, or because the
            // user canceled a multiple-tag read session from the UI or
            // programmatically using the invalidate method call.
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
                let alertController = UIAlertController(
                    title: "유효하지 않은 세션".localized,
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "확인".localized, style: .default, handler: nil))
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }

        // 새 태그를 읽으려면 새 세션 인스턴스가 필요
        self.session = nil
    }
}
