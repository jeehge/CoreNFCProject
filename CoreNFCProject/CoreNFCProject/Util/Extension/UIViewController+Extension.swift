//
//  UIViewController+Extension.swift
//  CoreNFCProject
//
//  Created by JH on 2019/11/21.
//  Copyright © 2019 JH. All rights reserved.
//

import UIKit

protocol ViewControllerFromStoryBoard{}

extension ViewControllerFromStoryBoard where Self: UIViewController {
    static func viewController(name: String) -> Self {
        guard let viewController: Self = UIStoryboard(name: name, bundle: nil)
            .instantiateViewController(withIdentifier: String(describing: Self.self)) as? Self
            else { return Self() }
        return viewController
    }
}
