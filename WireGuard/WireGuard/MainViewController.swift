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
            let demoServerSettings = """
            private_key=98add04f289e76a2501c44926f4cfc761620de0baf5ff12d7c70b07ea2f3286d
            replace_peers=true
            public_key=25123c5dcd3328ff645e4f2a3fce0d754400d3887a0cb7c56f0267e20fbf3c5b
            endpoint=163.172.161.0:12912
            replace_allowed_ips=true
            allowed_ip=0.0.0.0/0
            """
            let interface = TunnelController.TunnelInterface(
                name: "wg0.conf",
                localizedDescription: "Demo server",
                settings: demoServerSettings,
                serverAddress: "demo.wireguard.com",
                address: "192.168.4.207",
                subnetMask: "255.255.255.0",
                dnsServers: ["8.8.8.8", "8.8.4.4", "1.1.1.1", "1.0.0.1"]
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
