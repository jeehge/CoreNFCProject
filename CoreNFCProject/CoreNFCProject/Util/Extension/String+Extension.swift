//
//  String+Extension.swift
//  CoreNFCProject
//
//  Created by JH on 2019/11/21.
//  Copyright © 2019 JH. All rights reserved.
//

import UIKit

extension String {
    // 다국어화
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }

    // 글자 치환
    func replace(_ target: String, _ withString: String) -> String {
        return self.replacingOccurrences(of: target, with: withString, options: NSString.CompareOptions.literal, range: nil)
    }
}
