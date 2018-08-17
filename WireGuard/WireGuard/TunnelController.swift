//
//  TunnelController.swift
//  WireGuard
//
//  Created by Roopesh Chander on 13/08/18.
//  Copyright © 2018 Roopesh Chander. All rights reserved.
//

import UIKit
import NetworkExtension

protocol TunnelControllerDelegate: class {
    func tunnelStatusChanged(isConnected: Bool)
}

class TunnelController {

    struct TunnelInterface {
        let name: String
        let localizedDescription: String
        let settings: String
        let serverAddress: String
        let address: String
        let subnetMask: String
        let dnsServers: [String]
    }

    weak var delegate: TunnelControllerDelegate?
    private var connectionObservationToken: AnyObject?
    private var currentSession: NETunnelProviderSession?

    var isTunnelConnected: Bool {
        if let currentSession = currentSession {
            if (currentSession.status == .connected) {
                return true
            }
        }
        return false
    }

    func startTunnel(interface: TunnelInterface) {
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
            config.serverAddress = interface.serverAddress
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
                    let options: [String: Any] = [
                        "name" : interface.name,
                        "settings" : interface.settings,
                        "address": interface.address,
                        "subnetMask": interface.subnetMask,
                        "dnsServers" : interface.dnsServers
                    ]
                    let session = tunnelProviderManager.connection as! NETunnelProviderSession
                    self.connectionObservationToken = NotificationCenter.default.addObserver(
                        forName: .NEVPNStatusDidChange, object: session, queue: nil) { [weak self] (notification) in
                            guard let s = self else { return }
                            s.delegate?.tunnelStatusChanged(isConnected: (session.status == .connected))
                            if (session.status == .disconnected) {
                                if let token = s.connectionObservationToken {
                                    NotificationCenter.default.removeObserver(token)
                                }
                                s.currentSession = nil
                                s.connectionObservationToken = nil
                            }
                    }
                    self.currentSession = session
                    do {
                        try session.startTunnel(options: options)
                    } catch (let e) {
                        print("Error starting tunnel: \(e)")
                    }
                }
            }
        }
    }

    func stopTunnel() {
        if let currentSession = currentSession {
            currentSession.stopTunnel()
        }
    }

    deinit {
        if let token = connectionObservationToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
