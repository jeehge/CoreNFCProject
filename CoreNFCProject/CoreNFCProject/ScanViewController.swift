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
    
    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCNDEFReaderSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initTableView()
//        pushTest()
        
    }
    
    func initTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func pushTest() {
        var bibletext = ""
            // 1. 전송할 값 준비
            // 2. JSON 객체로 변환할 딕셔너리 준비
            //let parameter = ["create_name" : "kkkkkkkk", "create_age" : "909090"]
            //let postString = "create_name=13&create_age=Jack"
            // 3. URL 객체 정의
            guard let url = URL(string: "http://106.255.240.211:55509/postTest") else { return }
            
            // 3. URLRequest 객체 정의 및 요청 내용 담기
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            // 4. HTTP 메시지에 포함될 헤더 설정
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            //request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let dictionary = ["한글": "11111", "test12":7677676] as [String : Any]
            
            let body: Data = try! JSONSerialization.data(withJSONObject: dictionary, options: JSONSerialization.WritingOptions.prettyPrinted)
            request.httpBody = body
            
            
            // 5. URLSession 객체를 통해 전송 및 응답값 처리 로직 작성
            let session = URLSession.shared
            session.dataTask(with: request) { (data, response, error) in
                if let res = response {
                    print(res)
                }
                
                if let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: [])
                        
                        let test = json as! [String: Any]
                        print(test)
                        
                        guard let newValue = json as? Array<Any> else {
                            print("invalid format")
                            return
                        }
                        
                        for item in newValue{
                            if let data = item as? [String:Any] {
                                if let book = data["book"] , let chapter = data["chapter"] ,let verse = data["verse"] ,let content = data["content"] {
                                    
                            print( String(describing: book) + String(describing: chapter) + String(describing: verse) + String(describing: content))
                                    print(book)
                                    print(chapter)
                                    print(verse)
                                    print(content)
                                    bibletext += String(describing: book) + String(describing: chapter) + String(describing: verse) + String(describing: content)
                                }
        
                            }
                        }
                        print("test : \(bibletext)")
        
                    } catch {
                        print("error : \(error)")
                    }
                }
                // 6. POST 전송
                }.resume()
    }
    
    // MARK: - Actions

    /// - Tag: beginScanning
    @IBAction func beginScanning(_ sender: UIButton) {
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning Not Supported",
                message: "This device doesn't support tag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the item to learn more about it."
        session?.begin()
    }

    // MARK: - addMessage(fromUserActivity:)

    func addMessage(fromUserActivity message: NFCNDEFMessage) {
        DispatchQueue.main.async {
            self.detectedMessages.append(message)
            self.tableView.reloadData()
        }
    }
}

extension ScanViewController: UITableViewDataSource, UITableViewDelegate {

    // MARK: - Table View Functions
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detectedMessages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        guard let textLabel = cell.textLabel else {
            return cell
        }

        textLabel.text = "Invalid data"

        let payload = detectedMessages[indexPath.row].records[0]
        switch payload.typeNameFormat {
        case .nfcWellKnown:
            if let type = String(data: payload.type, encoding: .utf8) {
                if let url = payload.wellKnownTypeURIPayload() {
                    textLabel.text = "\(payload.typeNameFormat.description): \(type), \(url.absoluteString)"
                } else {
                    textLabel.text = "\(payload.typeNameFormat.description): \(type)"
                }
            }
        case .absoluteURI:
            if let text = String(data: payload.payload, encoding: .utf8) {
                textLabel.text = text
            }
        case .media:
            if let type = String(data: payload.type, encoding: .utf8) {
                textLabel.text = "\(payload.typeNameFormat.description): " + type
            }
        case .nfcExternal, .empty, .unknown, .unchanged:
            fallthrough
        @unknown default:
            textLabel.text = payload.typeNameFormat.description
        }

        return cell
    }
}

extension ScanViewController: NFCNDEFReaderSessionDelegate {
    
    // MARK: - NFCNDEFReaderSessionDelegate

    /// - Tag: processingTagData
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async {
            // Process detected NFCNDEFMessage objects.
            self.detectedMessages.append(contentsOf: messages)
            self.tableView.reloadData()
        }
    }

    /// - Tag: processingNDEFTag
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            // Restart polling in 500ms
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected, please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        // Connect to the found tag and perform NDEF message reading
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                if .notSupported == ndefStatus {
                    session.alertMessage = "Tag is not NDEF compliant"
                    session.invalidate()
                    return
                } else if nil != error {
                    session.alertMessage = "Unable to query NDEF status of tag"
                    session.invalidate()
                    return
                }
                
                tag.readNDEF(completionHandler: { (message: NFCNDEFMessage?, error: Error?) in
                    var statusMessage: String
                    if nil != error || nil == message {
                        statusMessage = "Fail to read NDEF from tag"
                    } else {
                        statusMessage = "Found 1 NDEF message"
                        DispatchQueue.main.async {
                            // Process detected NFCNDEFMessage objects.
                            self.detectedMessages.append(message!)
                            self.tableView.reloadData()
                        }
                    }
                    
                    session.alertMessage = statusMessage
                    session.invalidate()
                })
            })
        })
    }
    
    /// - Tag: sessionBecomeActive
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        
    }
    
    /// - Tag: endScanning
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Check the invalidation reason from the returned error.
        if let readerError = error as? NFCReaderError {
            // Show an alert when the invalidation reason is not because of a
            // successful read during a single-tag read session, or because the
            // user canceled a multiple-tag read session from the UI or
            // programmatically using the invalidate method call.
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
                let alertController = UIAlertController(
                    title: "Session Invalidated",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }

        // To read new tags, a new session instance is required.
        self.session = nil
    }
}
