//
//  TunnelController.swift
//  WireGuard
//
//  Created by Roopesh Chander on 13/08/18.
//  Copyright © 2018 Roopesh Chander. All rights reserved.
//

import UIKit
import NetworkExtension

class TunnelController {

    struct TunnelInterface {
        let name: String
        let localizedDescription: String
        let settings: String
        let address: String
        let dns: String
    }

    static func startTunnel(interface: TunnelInterface) {
        NETunnelProviderManager.loadAllFromPreferences { (tunnels, loadError) in
            if let loadError = loadError {
                print("Load error: \(loadError)")
                return
            }

            let tunnelProviderManager: NETunnelProviderManager
            if let tunnels = tunnels, tunnels.count > 0 {
                print("\(tunnels.count) tunnels already exist/s")
                tunnelProviderManager = tunnels.first!
            } else {
                tunnelProviderManager = NETunnelProviderManager()
            }

            // Configure our tunnel
            let config = NETunnelProviderProtocol()
            let appId = Bundle.main.bundleIdentifier!
            config.providerBundleIdentifier = "\(appId).PacketTunnelProvider"
            config.serverAddress = interface.address
            config.username = interface.name
            tunnelProviderManager.protocolConfiguration = config
            tunnelProviderManager.localizedDescription = interface.localizedDescription
            tunnelProviderManager.isEnabled = true

            // Save the configuration
            tunnelProviderManager.saveToPreferences { (saveError: Error?) in
                if let saveError = saveError {
                    print("Save error: \(saveError)")
                    return
                }

                // Load it back (see https://stackoverflow.com/q/47550706)
                tunnelProviderManager.loadFromPreferences { (loadError: Error?) in
                    if let loadError = loadError {
                        print("Load error 2: \(loadError)")
                        return
                    }

                    // Attempt to start the tunnel
                    let options: [String: String] = [
                        "name" : interface.name,
                        "settings" : interface.settings,
                        "address": interface.address,
                        "dns" : interface.dns
                    ]
                    let session = tunnelProviderManager.connection as! NETunnelProviderSession
                    do {
                        try session.startTunnel(options: options)
                    } catch (let e) {
                        print("Error starting tunnel: \(e)")
                    }
                }
            }
        }
    }
}
