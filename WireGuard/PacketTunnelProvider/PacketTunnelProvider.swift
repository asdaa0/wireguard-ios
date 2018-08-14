//
//  PacketTunnelProvider.swift
//  PacketTunnelProvider
//
//  Created by Roopesh Chander on 13/08/18.
//  Copyright © 2018 Roopesh Chander. All rights reserved.
//

import NetworkExtension

enum PacketTunnelProviderError : Error {
    case cannotTurnOnTunnel
}

class PacketTunnelProvider: NEPacketTunnelProvider {

    var wgContext = WireGuardContext()

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

        wgSetLogger { (level, tagCStr, msgCStr) in
            let tag = (tagCStr != nil) ? String(cString: tagCStr!) : ""
            let msg = (msgCStr != nil) ? String(cString: msgCStr!) : ""
            NSLog("wg log: \(level): \(tag): \(msg)")
        }

        let handle = withStringsAsGoStrings(name, settings) { (nameGoStr, settingsGoStr) -> Int32 in
            return withUnsafeMutablePointer(to: &wgContext) { (wgCtxPtr) -> Int32 in
                return wgTurnOn(nameGoStr, settingsGoStr,
                    // read_fn: Read from the TUN interface and pass it on to WireGuard
                    { (wgCtxPtr, buf, len) -> Int in
                        guard let wgCtxPtr = wgCtxPtr else { return 0 }
                        guard let buf = buf else { return 0 }
                        let wgContext = wgCtxPtr.bindMemory(to: WireGuardContext.self, capacity: 1).pointee
                        let packetData: Data = wgContext.readPacket()
                        if (packetData.count <= len) {
                            packetData.copyBytes(to: buf, count: packetData.count)
                            return packetData.count
                        }
                        return 0
                    },
                    // write_fn: Receive packets from WireGuard and write to the TUN interface
                    { (wgCtxPtr, buf, len) -> Int in
                        guard let wgCtxPtr = wgCtxPtr else { return 0 }
                        guard let buf = buf else { return 0 }
                        let wgContext = wgCtxPtr.bindMemory(to: WireGuardContext.self, capacity: 1).pointee
                        let packetData = Data(bytes: buf, count: len)
                        let isWritten = wgContext.writePacket(packetData: packetData)
                        if (isWritten) {
                            return packetData.count
                        }
                        return 0
                    },
                    wgCtxPtr)
            }
        }

        if (handle < 0) {
            completionHandler(PacketTunnelProviderError.cannotTurnOnTunnel)
            return
        }

        completionHandler(nil /* No errors */)
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

class WireGuardContext {
    func readPacket() -> Data {
        // TODO
        NSLog("readPacket")
        return Data()
    }
    func writePacket(packetData: Data) -> Bool {
        // TODO
        NSLog("writePacket")
        return false
    }
}

private func withStringsAsGoStrings<R>(_ s1: String, _ s2: String, closure: (gostring_t, gostring_t) -> R) -> R {
    return s1.withCString { (s1cStr) -> R in
        let g1 = gostring_t(p: s1cStr, n: s1.utf8.count)
        return s2.withCString { (s2cStr) -> R in
            let g2 = gostring_t(p: s2cStr, n: s2.utf8.count)
            return closure(g1, g2)
        }
    }
}
