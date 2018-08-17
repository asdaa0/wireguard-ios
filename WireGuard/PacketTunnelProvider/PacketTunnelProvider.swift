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

    var wgHandle: Int32?
    var wgContext: WireGuardContext? = nil

    override func startTunnel(options: [String : NSObject]?,
                              completionHandler startTunnelCompletionHandler: @escaping (Error?) -> Void) {
        let name = (options?["name"] as? String) ?? "NO_NAME"
        let settings = (options?["settings"] as? String) ?? "NO_SETTINGS"
        let address = (options?["address"] as? String) ?? "NO_ADDRESS"
        let subnetMask = (options?["subnetMask"] as? String) ?? "NO_SUBNET_MASK"
        let dnsServers = (options?["dnsServers"] as? [String]) ?? ["NO_DNS"]
        NSLog("startTunnel:")
        NSLog("  Name: \(name)")
        NSLog("  Settings: \(settings)")
        NSLog("  Address: \(address)")
        NSLog("  Subnet mask: \(subnetMask)")
        NSLog("  DNS servers: \(dnsServers)")

        wgSetLogger { (level, tagCStr, msgCStr) in
            let tag = (tagCStr != nil) ? String(cString: tagCStr!) : ""
            let msg = (msgCStr != nil) ? String(cString: msgCStr!) : ""
            NSLog("wg log: \(level): \(tag): \(msg)")
        }

        wgContext = WireGuardContext(packetFlow: self.packetFlow)

        let handle = withStringsAsGoStrings(name, settings) { (nameGoStr, settingsGoStr) -> Int32 in
            return withUnsafeMutablePointer(to: &wgContext) { (wgCtxPtr) -> Int32 in
                return wgTurnOn(nameGoStr, settingsGoStr,
                    // read_fn: Read from the TUN interface and pass it on to WireGuard
                    { (wgCtxPtr, buf, len) -> Int in
                        guard let wgCtxPtr = wgCtxPtr else { return 0 }
                        guard let buf = buf else { return 0 }
                        let wgContext = wgCtxPtr.bindMemory(to: WireGuardContext.self, capacity: 1).pointee
                        var isTunnelClosed = false
                        guard let packet = wgContext.readPacket(isTunnelClosed: &isTunnelClosed) else { return 0 }
                        if (isTunnelClosed) { return -1 }
                        let packetData = packet.data
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
                        guard (len > 0) else { return 0 }
                        let wgContext = wgCtxPtr.bindMemory(to: WireGuardContext.self, capacity: 1).pointee
                        let ipVersionBits = (buf[0] & 0xf0) >> 4
                        let ipVersion: sa_family_t? = {
                            if (ipVersionBits == 4) { return sa_family_t(AF_INET) } // IPv4
                            if (ipVersionBits == 6) { return sa_family_t(AF_INET6) } // IPv6
                            return nil
                        }()
                        guard let protocolFamily = ipVersion else { fatalError("Unknown IP version") }
                        let packet = NEPacket(data: Data(bytes: buf, count: len), protocolFamily: protocolFamily)
                        var isTunnelClosed = false
                        let isWritten = wgContext.writePacket(packet: packet, isTunnelClosed: &isTunnelClosed)
                        if (isTunnelClosed) { return -1 }
                        if (isWritten) {
                            return len
                        }
                        return 0
                    },
                    wgCtxPtr)
            }
        }

        if (handle < 0) {
            startTunnelCompletionHandler(PacketTunnelProviderError.cannotTurnOnTunnel)
            return
        }

        wgHandle = handle

        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: address)
        let ipv4Settings = NEIPv4Settings(addresses: [address], subnetMasks: [subnetMask])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()] // Use tunnel for all network traffic
        networkSettings.ipv4Settings = ipv4Settings
        // WireGuard's overhead is 60 bytes for IPv4 and 80 bytes for IPv6
        networkSettings.tunnelOverheadBytes = 80
        networkSettings.dnsSettings = NEDNSSettings(servers: dnsServers)
        setTunnelNetworkSettings(networkSettings) { (error) in
            if let error = error {
                NSLog("Error setting network settings: \(error)")
                startTunnelCompletionHandler(PacketTunnelProviderError.cannotTurnOnTunnel)
            } else {
                startTunnelCompletionHandler(nil /* No errors */)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        if let handle = wgHandle {
            wgTurnOff(handle)
        }
        wgContext?.closeTunnel()
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
    private var packetFlow: NEPacketTunnelFlow
    private var outboundPackets: [NEPacket] = []
    private var isTunnelClosed: Bool = false
    private let readPacketCondition = NSCondition()

    init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }

    func closeTunnel() {
        isTunnelClosed = true
        readPacketCondition.signal()
    }

    func readPacket(isTunnelClosed: inout Bool) -> NEPacket? {
        if (outboundPackets.isEmpty) {
            let readPacketCondition = NSCondition()
            readPacketCondition.lock()
            var packetsObtained: [NEPacket]? = nil
            packetFlow.readPacketObjects { (packets: [NEPacket]) in
                packetsObtained = packets
                readPacketCondition.signal()
            }
            // Wait till the completion handler of packetFlow.readPacketObjects() finishes
            while (packetsObtained == nil && !self.isTunnelClosed) {
                readPacketCondition.wait()
            }
            if let packetsObtained = packetsObtained {
                outboundPackets = packetsObtained
            }
            readPacketCondition.unlock()
        }
        isTunnelClosed = self.isTunnelClosed
        if (outboundPackets.isEmpty) {
            return nil
        } else {
            return outboundPackets.removeFirst()
        }
    }

    func writePacket(packet: NEPacket, isTunnelClosed: inout Bool) -> Bool {
        isTunnelClosed = self.isTunnelClosed
        return packetFlow.writePacketObjects([packet])
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
