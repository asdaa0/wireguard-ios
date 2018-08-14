//
//  PacketTunnelProvider.swift
//  PacketTunnelProvider
//
//  Created by Roopesh Chander on 13/08/18.
//  Copyright © 2018 Roopesh Chander. All rights reserved.
//

import NetworkExtension

enum PacketTunnelProviderError : Error {
    case tunnelUnimplementedError
}

class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let name = (options?["name"] as? String) ?? "NO_NAME"
        let settings = (options?["settings"] as? String) ?? "NO_SETTINGS"
        let address = (options?["address"] as? String) ?? "NO_ADDRESS"
        let dns = (options?["dns"] as? String) ?? "NO_DNS"
        NSLog("startTunnel:")
        NSLog("  Name: \(name)")
        NSLog("  Settings: \(settings)")
        NSLog("  Address: \(address)")
        NSLog("  DNS: \(dns)")
        completionHandler(PacketTunnelProviderError.tunnelUnimplementedError)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
}
