//
//  MainViewController.swift
//  WireGuard
//
//  Created by Roopesh Chander on 11/08/18.
//  Copyright © 2018 Roopesh Chander. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {
    override func loadView() {
        let view = UIView()

        // A button that turns on our packet tunnel
        let button = UIButton(type: .system)
        button.setTitle("Turn On", for: .normal)
        button.addTarget(self, action: #selector(turnOnPacketTunnel), for: .touchUpInside)
        view.addSubview(button)

        // Center the button on the root view
        button.translatesAutoresizingMaskIntoConstraints = false
        button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true

        self.view = view
    }

    @objc func turnOnPacketTunnel() {
        print("turn on")
    }
}
