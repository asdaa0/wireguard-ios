//
//  MainViewController.swift
//  WireGuard
//
//  Created by Roopesh Chander on 11/08/18.
//  Copyright © 2018 Roopesh Chander. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {
    var turnOnButton: UIButton?
    let tunnelController = TunnelController()

    override func loadView() {
        let view = UIView()

        // A button that turns on our packet tunnel
        let button = UIButton(type: .system)
        let buttonText = tunnelController.isTunnelConnected ? "Turn off" : "Turn on"
        button.setTitle(buttonText, for: .normal)
        button.addTarget(self, action: #selector(togglePacketTunnel), for: .touchUpInside)
        view.addSubview(button)

        // Center the button on the root view
        button.translatesAutoresizingMaskIntoConstraints = false
        button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true

        self.view = view
        self.turnOnButton = button
    }

    @objc func togglePacketTunnel() {
        if (tunnelController.isTunnelConnected) {
            tunnelController.stopTunnel()
        } else {
            let interface = TunnelController.TunnelInterface(
                name: "wg0.conf",
                localizedDescription: "Test",
                settings: "settings_test",
                address: "address_test",
                subnetMask: "subnet_mask_test",
                dnsServers: ["dns_test"]
            )
            tunnelController.startTunnel(interface: interface)
            tunnelController.delegate = self
        }
    }
}

extension MainViewController: TunnelControllerDelegate {
    func tunnelStatusChanged(isConnected: Bool) {
        let buttonText = isConnected ? "Turn off" : "Turn on"
        turnOnButton?.setTitle(buttonText, for: .normal)
    }
}
