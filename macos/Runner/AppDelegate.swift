import Cocoa
import FlutterMacOS
import IOKit
import IOKit.usb

@main
class AppDelegate: FlutterAppDelegate {
    private let channelName = "com.avarstudio.android_file_manager/mtp"

    private let mtpOpOpenSession: UInt16 = 0x1002
    private let mtpOpGetStorageIDs: UInt16 = 0x1004
    private let mtpOpGetObjectHandles: UInt16 = 0x1007
    private let mtpOpGetObjectInfo: UInt16 = 0x1008
    private let mtpOpGetObject: UInt16 = 0x1009
    private let mtpOpSendObjectInfo: UInt16 = 0x100C
    private let mtpOpSendObject: UInt16 = 0x100D

    private let mtpContainerCommand: UInt16 = 1
    private let mtpContainerData: UInt16 = 2
    private let mtpContainerResponse: UInt16 = 3
    private let mtpRespOk: UInt16 = 0x2001

    private var transactionId: UInt32 = 1

    private let kIOCFPlugInInterfaceUUID = CFUUIDGetConstantUUIDWithBytes(
        nil,
        0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
        0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F
    )
    private let kIOUSBDeviceUserClientTypeUUID = CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x9d, 0xc7, 0xb7, 0x80, 0x9e, 0xc0, 0x11, 0xD4,
        0xa5, 0x4f, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61
    )
    private let kIOUSBDeviceInterfaceUUID = CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x5c, 0x81, 0x87, 0xd0, 0x9e, 0xf3, 0x11, 0xD4,
        0x8b, 0x45, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61
    )
    private let kIOUSBInterfaceUserClientTypeUUID = CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x2d, 0x97, 0x86, 0xc6, 0x9e, 0xf3, 0x11, 0xD4,
        0xad, 0x51, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61
    )
    private let kIOUSBInterfaceInterfaceUUID = CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x73, 0xc9, 0x7a, 0xe8, 0x9e, 0xf3, 0x11, 0xD4,
        0xb1, 0xd0, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61
    )

    override func applicationDidFinishLaunching(_ notification: Notification) {
        if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
            let mtpChannel = FlutterMethodChannel(
                name: channelName,
                binaryMessenger: controller.engine.binaryMessenger
            )

            mtpChannel.setMethodCallHandler { [weak self] call, result in
                guard let self = self else { return }

                switch call.method {
                case "listDevices":
                    result(self.scanUsbDevices())

                case "listDirectory":
                    guard let args = call.arguments as? [String: Any],
                          let deviceId = args["deviceId"] as? String else {
                        result(FlutterError(
                            code: "INVALID_ARGS",
                            message: "deviceId is required",
                            details: nil
                        ))
                        return
                    }
                    let path = (args["path"] as? String) ?? "/sdcard"
                    self.runAsync(result: result) {
                        try self.listMtpDirectory(deviceId: deviceId, path: path)
                    }

                case "pullFile":
                    guard let args = call.arguments as? [String: Any],
                          let deviceId = args["deviceId"] as? String,
                          let remotePath = args["remotePath"] as? String,
                          let localDestinationPath = args["localDestinationPath"] as? String else {
                        result(FlutterError(
                            code: "INVALID_ARGS",
                            message: "deviceId, remotePath and localDestinationPath are required",
                            details: nil
                        ))
                        return
                    }
                    self.runAsync(result: result) {
                        try self.pullMtpFile(
                            deviceId: deviceId,
                            remotePath: remotePath,
                            localDestinationPath: localDestinationPath
                        )
                        return nil
                    }

                case "pushFile":
                    guard let args = call.arguments as? [String: Any],
                          let deviceId = args["deviceId"] as? String,
                          let localSourcePath = args["localSourcePath"] as? String,
                          let remoteDestinationPath = args["remoteDestinationPath"] as? String else {
                        result(FlutterError(
                            code: "INVALID_ARGS",
                            message: "deviceId, localSourcePath and remoteDestinationPath are required",
                            details: nil
                        ))
                        return
                    }
                    self.runAsync(result: result) {
                        try self.pushMtpFile(
                            deviceId: deviceId,
                            localSourcePath: localSourcePath,
                            remoteDestinationPath: remoteDestinationPath
                        )
                        return nil
                    }


                case "createDirectory":
                    guard let args = call.arguments as? [String: Any],
                          let deviceId = args["deviceId"] as? String else {
                        result(FlutterError(
                            code: "INVALID_ARGS",
                            message: "deviceId is required",
                            details: nil
                        ))
                        return
                    }
                    let parentPath = (args["parentPath"] as? String) ?? "/sdcard"
                    let folderName = (args["folderName"] as? String) ?? ""
                    let targetPath = (args["path"] as? String) ?? ""
                    self.runAsync(result: result) {
                        try self.createMtpDirectory(
                            deviceId: deviceId,
                            parentPath: parentPath,
                            folderName: folderName,
                            targetPath: targetPath
                        )
                        return nil
                    }

                case "renameEntry":
                    guard let args = call.arguments as? [String: Any],
                          let deviceId = args["deviceId"] as? String,
                          let oldPath = args["oldPath"] as? String,
                          let newName = args["newName"] as? String else {
                        result(FlutterError(
                            code: "INVALID_ARGS",
                            message: "deviceId, oldPath and newName are required",
                            details: nil
                        ))
                        return
                    }
                    let newPath = (args["newPath"] as? String) ?? ""
                    self.runAsync(result: result) {
                        try self.renameMtpEntry(
                            deviceId: deviceId,
                            oldPath: oldPath,
                            newName: newName,
                            newPath: newPath
                        )
                        return nil
                    }

                case "deleteEntry":
                    guard let args = call.arguments as? [String: Any],
                          let deviceId = args["deviceId"] as? String,
                          let targetPath = args["path"] as? String else {
                        result(FlutterError(
                            code: "INVALID_ARGS",
                            message: "deviceId and path are required",
                            details: nil
                        ))
                        return
                    }
                    let isDirectory = (args["isDirectory"] as? Bool) ?? false
                    self.runAsync(result: result) {
                        try self.deleteMtpEntry(
                            deviceId: deviceId,
                            targetPath: targetPath,
                            isDirectory: isDirectory
                        )
                        return nil
                    }

                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        super.applicationDidFinishLaunching(notification)
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func runAsync(result: @escaping FlutterResult, work: @escaping () throws -> Any?) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let value = try work()
                DispatchQueue.main.async {
                    result(value)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "MTP_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    private func scanUsbDevices() -> [[String: Any]] {
        var results: [[String: Any]] = []

        guard let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) else {
            return results
        }

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard kr == KERN_SUCCESS else {
            return results
        }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            let vendorId = intProperty(from: service, key: kUSBVendorID) ?? 0
            let productId = intProperty(from: service, key: kUSBProductID) ?? 0
            let locationId = intProperty(from: service, key: kUSBDevicePropertyLocationID) ?? 0
            let productName = stringProperty(from: service, key: kUSBProductString)
                ?? "USB Device"

            if vendorId == 0 && productId == 0 {
                continue
            }

            // Yalnızca MTP/bulk arayüzü sunan USB cihazları dahil et
            var hasMtpInterface = false
            if let devInterface = try? createDeviceInterface(service: service) {
                defer {
                    _ = devInterface.pointee.pointee.Release(devInterface)
                }
                if let mtpIface = try? findMtpInterface(deviceInterface: devInterface) {
                    hasMtpInterface = true
                    _ = mtpIface.pointee.pointee.Release(mtpIface)
                }
            }
            guard hasMtpInterface else { continue }

            let idString = locationId > 0
                ? "usb-\(locationId)"
                : String(format: "%04x:%04x", vendorId, productId)

            results.append([
                "id": idString,
                "name": "\(productName) (\(String(format: "%04x:%04x", vendorId, productId)))",
                "state": "device",
                "vendorId": vendorId,
                "productId": productId,
                "locationId": locationId
            ])
        }

        return results
    }

    private func resolveLocationId(for deviceId: String) -> UInt32? {
        if deviceId.hasPrefix("usb-"), let parsed = UInt32(deviceId.dropFirst(4)) {
            return parsed
        }
        let devices = scanUsbDevices()
        for dev in devices {
            if (dev["id"] as? String) == deviceId, let loc = dev["locationId"] as? Int, loc > 0 {
                return UInt32(loc)
            }
        }
        return nil
    }

    private func withMtpSession<T>(
        deviceId: String,
        body: (
            _ interface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>>,
            _ bulkInPipe: UInt8,
            _ bulkOutPipe: UInt8,
            _ storageId: UInt32
        ) throws -> T
    ) throws -> T {
        guard let targetLocationId = resolveLocationId(for: deviceId) else {
            throw NSError(
                domain: "MtpService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "USB device not found for id: \(deviceId)"]
            )
        }

        guard let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) else {
            throw NSError(domain: "MtpService", code: 2, userInfo: [NSLocalizedDescriptionKey: "IOServiceMatching failed"])
        }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            throw NSError(domain: "MtpService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to enumerate USB devices"])
        }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            let loc = UInt32(intProperty(from: service, key: kUSBDevicePropertyLocationID) ?? 0)
            guard loc == targetLocationId else { continue }

            let deviceInterface = try createDeviceInterface(service: service)
            defer {
                _ = deviceInterface.pointee.pointee.USBDeviceClose(deviceInterface)
                _ = deviceInterface.pointee.pointee.Release(deviceInterface)
            }

            let openKr = deviceInterface.pointee.pointee.USBDeviceOpen(deviceInterface)
            if openKr != kIOReturnSuccess && openKr != kIOReturnExclusiveAccess {
                throw NSError(
                    domain: "MtpService",
                    code: Int(openKr),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to open USB device (0x\(String(openKr, radix: 16)))"]
                )
            }

            let mtpInterface = try findMtpInterface(deviceInterface: deviceInterface)
            defer {
                _ = mtpInterface.pointee.pointee.USBInterfaceClose(mtpInterface)
                _ = mtpInterface.pointee.pointee.Release(mtpInterface)
            }

            let ifaceKr = mtpInterface.pointee.pointee.USBInterfaceOpen(mtpInterface)
            if ifaceKr != kIOReturnSuccess && ifaceKr != kIOReturnExclusiveAccess {
                throw NSError(
                    domain: "MtpService",
                    code: Int(ifaceKr),
                    userInfo: [NSLocalizedDescriptionKey: "Switch phone USB mode to File Transfer (MTP). Interface open error: 0x\(String(ifaceKr, radix: 16))"]
                )
            }

            let (bulkInPipe, bulkOutPipe) = try findBulkPipes(interface: mtpInterface)

            let (_, openRespCode, _) = try sendMtpCommand(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                code: mtpOpOpenSession,
                params: [1]
            )
            if openRespCode != mtpRespOk && openRespCode != 0x201E {
                throw NSError(
                    domain: "MtpService",
                    code: Int(openRespCode),
                    userInfo: [NSLocalizedDescriptionKey: "MTP OpenSession failed (0x\(String(openRespCode, radix: 16)))"]
                )
            }

            let (storageData, storageResp, _) = try sendMtpCommand(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                code: mtpOpGetStorageIDs,
                params: []
            )
            guard storageResp == mtpRespOk else {
                throw NSError(
                    domain: "MtpService",
                    code: Int(storageResp),
                    userInfo: [NSLocalizedDescriptionKey: "MTP GetStorageIDs failed (0x\(String(storageResp, radix: 16)))"]
                )
            }

            let storageIds = parseUInt32Array(from: storageData)
            guard let primaryStorageId = storageIds.first else {
                throw NSError(domain: "MtpService", code: 7, userInfo: [NSLocalizedDescriptionKey: "No MTP storage found on device"])
            }

            return try body(mtpInterface, bulkInPipe, bulkOutPipe, primaryStorageId)
        }

        throw NSError(
            domain: "MtpService",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Target USB device not found"]
        )
    }

    private func listMtpDirectory(deviceId: String, path: String) throws -> [[String: Any]] {
        return try withMtpSession(deviceId: deviceId) { mtpInterface, bulkInPipe, bulkOutPipe, primaryStorageId in
            let parentHandle = try resolveParentHandle(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                storageId: primaryStorageId,
                path: path
            )

            let (handlesData, handlesResp, _) = try sendMtpCommand(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                code: mtpOpGetObjectHandles,
                params: [primaryStorageId, 0, parentHandle]
            )
            guard handlesResp == mtpRespOk else {
                throw NSError(
                    domain: "MtpService",
                    code: Int(handlesResp),
                    userInfo: [NSLocalizedDescriptionKey: "MTP GetObjectHandles failed (0x\(String(handlesResp, radix: 16)))"]
                )
            }

            let handles = parseUInt32Array(from: handlesData)
            let normalizedBase = (path == "/" || path.isEmpty)
                ? "/sdcard"
                : path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).prependedSlash()

            var entries: [[String: Any]] = []
            for handle in handles {
                let (infoData, infoResp, _) = try sendMtpCommand(
                    interface: mtpInterface,
                    bulkInPipe: bulkInPipe,
                    bulkOutPipe: bulkOutPipe,
                    code: mtpOpGetObjectInfo,
                    params: [handle]
                )
                guard infoResp == mtpRespOk else { continue }
                if let info = parseObjectInfo(from: infoData) {
                    let entryPath = normalizedBase == "/" ? "/\(info.filename)" : "\(normalizedBase)/\(info.filename)"
                    entries.append([
                        "name": info.filename,
                        "path": entryPath,
                        "isDirectory": info.isDirectory,
                        "size": info.objectCompressedSize,
                        "handle": handle
                    ])
                }
            }

            entries.sort { a, b in
                let aDir = (a["isDirectory"] as? Bool) ?? false
                let bDir = (b["isDirectory"] as? Bool) ?? false
                if aDir != bDir { return aDir && !bDir }
                let aName = ((a["name"] as? String) ?? "").lowercased()
                let bName = ((b["name"] as? String) ?? "").lowercased()
                return aName < bName
            }

            return entries
        }
    }

    private func pullMtpFile(deviceId: String, remotePath: String, localDestinationPath: String) throws {
        try withMtpSession(deviceId: deviceId) { mtpInterface, bulkInPipe, bulkOutPipe, primaryStorageId in
            let cleaned = remotePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let parts = cleaned.split(separator: "/").map(String.init)
            guard let targetName = parts.last, !targetName.isEmpty else {
                throw NSError(domain: "MtpService", code: 10, userInfo: [NSLocalizedDescriptionKey: "Invalid remotePath: \(remotePath)"])
            }

            let parentPath = parts.dropLast().joined(separator: "/")
            let parentHandle = try resolveParentHandle(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                storageId: primaryStorageId,
                path: parentPath.isEmpty ? "/sdcard" : "/\(parentPath)"
            )

            let (handlesData, handlesResp, _) = try sendMtpCommand(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                code: mtpOpGetObjectHandles,
                params: [primaryStorageId, 0, parentHandle]
            )
            guard handlesResp == mtpRespOk else {
                throw NSError(domain: "MtpService", code: Int(handlesResp), userInfo: [NSLocalizedDescriptionKey: "GetObjectHandles failed for pull (0x\(String(handlesResp, radix: 16)))"])
            }

            let handles = parseUInt32Array(from: handlesData)
            var matchedHandle: UInt32?
            for handle in handles {
                let (infoData, infoResp, _) = try sendMtpCommand(
                    interface: mtpInterface,
                    bulkInPipe: bulkInPipe,
                    bulkOutPipe: bulkOutPipe,
                    code: mtpOpGetObjectInfo,
                    params: [handle]
                )
                if infoResp == mtpRespOk, let info = parseObjectInfo(from: infoData), !info.isDirectory, info.filename == targetName {
                    matchedHandle = handle
                    break
                }
            }

            guard let objectHandle = matchedHandle else {
                throw NSError(domain: "MtpService", code: 11, userInfo: [NSLocalizedDescriptionKey: "Remote file not found: \(remotePath)"])
            }

            let (fileData, objResp, _) = try sendMtpCommand(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                code: mtpOpGetObject,
                params: [objectHandle]
            )
            guard objResp == mtpRespOk else {
                throw NSError(domain: "MtpService", code: Int(objResp), userInfo: [NSLocalizedDescriptionKey: "MTP GetObject failed (0x\(String(objResp, radix: 16)))"])
            }

            let destURL = URL(fileURLWithPath: localDestinationPath)
            try FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileData.write(to: destURL, options: .atomic)
        }
    }

    private func pushMtpFile(deviceId: String, localSourcePath: String, remoteDestinationPath: String) throws {
        let sourceURL = URL(fileURLWithPath: localSourcePath)
        let fileData = try Data(contentsOf: sourceURL)

        let cleanedDest = remoteDestinationPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = cleanedDest.split(separator: "/").map(String.init)
        let remoteFileName = (parts.last?.isEmpty == false) ? parts.last! : sourceURL.lastPathComponent
        let parentPath = parts.dropLast().joined(separator: "/")

        try withMtpSession(deviceId: deviceId) { mtpInterface, bulkInPipe, bulkOutPipe, primaryStorageId in
            let parentHandle = try resolveParentHandle(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                storageId: primaryStorageId,
                path: parentPath.isEmpty ? "/sdcard" : "/\(parentPath)"
            )

            let objectFormat = guessMtpObjectFormat(filename: remoteFileName)
            let infoPayload = buildObjectInfoPayload(
                storageId: primaryStorageId,
                objectFormat: objectFormat,
                compressedSize: UInt32(clamping: fileData.count),
                parentObject: parentHandle == 0xFFFFFFFF ? 0 : parentHandle,
                filename: remoteFileName
            )

            let (_, sendInfoResp, respParams) = try sendMtpCommand(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                code: mtpOpSendObjectInfo,
                params: [primaryStorageId, parentHandle],
                dataToSend: infoPayload
            )
            guard sendInfoResp == mtpRespOk else {
                throw NSError(domain: "MtpService", code: Int(sendInfoResp), userInfo: [NSLocalizedDescriptionKey: "MTP SendObjectInfo failed (0x\(String(sendInfoResp, radix: 16)))"])
            }

            let newHandle = respParams.count >= 3 ? respParams[2] : (respParams.last ?? 0)
            guard newHandle != 0 else {
                throw NSError(domain: "MtpService", code: 12, userInfo: [NSLocalizedDescriptionKey: "SendObjectInfo returned invalid object handle"])
            }

            let (_, sendObjResp, _) = try sendMtpCommand(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                code: mtpOpSendObject,
                params: [],
                dataToSend: fileData
            )
            guard sendObjResp == mtpRespOk else {
                throw NSError(domain: "MtpService", code: Int(sendObjResp), userInfo: [NSLocalizedDescriptionKey: "MTP SendObject failed (0x\(String(sendObjResp, radix: 16)))"])
            }
        }
    }

    private func buildObjectInfoPayload(
        storageId: UInt32,
        objectFormat: UInt16,
        compressedSize: UInt32,
        parentObject: UInt32,
        filename: String
    ) -> Data {
        var data = Data()
        appendUInt32LE(&data, storageId)
        appendUInt16LE(&data, objectFormat)
        appendUInt16LE(&data, 0) // ProtectionStatus
        appendUInt32LE(&data, compressedSize)
        appendUInt16LE(&data, 0) // ThumbFormat
        appendUInt32LE(&data, 0) // ThumbCompressedSize
        appendUInt32LE(&data, 0) // ThumbPixWidth
        appendUInt32LE(&data, 0) // ThumbPixHeight
        appendUInt32LE(&data, 0) // ImagePixWidth
        appendUInt32LE(&data, 0) // ImagePixHeight
        appendUInt32LE(&data, 0) // ImageBitDepth
        appendUInt32LE(&data, parentObject)
        appendUInt16LE(&data, 0) // AssociationType
        appendUInt32LE(&data, 0) // AssociationDesc
        appendUInt32LE(&data, 0) // SequenceNumber
        appendMtpString(&data, filename)
        appendMtpString(&data, "") // DateCreated
        appendMtpString(&data, "") // DateModified
        appendMtpString(&data, "") // Keywords
        return data
    }

    private func appendMtpString(_ data: inout Data, _ value: String) {
        let utf16Units = Array(value.utf16)
        if utf16Units.isEmpty {
            data.append(0)
            return
        }
        let countWithNull = min(254, utf16Units.count + 1)
        data.append(UInt8(countWithNull))
        for i in 0..<(countWithNull - 1) {
            appendUInt16LE(&data, utf16Units[i])
        }
        appendUInt16LE(&data, 0)
    }

    private func guessMtpObjectFormat(filename: String) -> UInt16 {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return 0x3801
        case "png": return 0x380B
        case "gif": return 0x3807
        case "mp3": return 0x3009
        case "wav": return 0x3008
        case "mp4", "m4v": return 0x300A
        case "txt", "log", "json", "xml", "csv": return 0x3004
        default: return 0x3000 // Undefined object
        }
    }


    private func createMtpDirectory(
        deviceId: String,
        parentPath: String,
        folderName: String,
        targetPath: String
    ) throws {
        let resolvedFolderName: String
        let resolvedParentPath: String
        if !folderName.isEmpty {
            resolvedFolderName = folderName
            resolvedParentPath = parentPath
        } else {
            let cleaned = targetPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let parts = cleaned.split(separator: "/").map(String.init)
            guard let last = parts.last, !last.isEmpty else {
                throw NSError(domain: "MtpService", code: 20, userInfo: [NSLocalizedDescriptionKey: "Invalid folder name"])
            }
            resolvedFolderName = last
            resolvedParentPath = parts.dropLast().joined(separator: "/")
        }

        try withMtpSession(deviceId: deviceId) { mtpInterface, bulkInPipe, bulkOutPipe, primaryStorageId in
            let parentHandle = try resolveParentHandle(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                storageId: primaryStorageId,
                path: resolvedParentPath.isEmpty ? "/sdcard" : resolvedParentPath
            )
            let infoPayload = buildObjectInfoPayload(
                storageId: primaryStorageId,
                objectFormat: 0x3001,
                compressedSize: 0,
                parentObject: parentHandle,
                filename: resolvedFolderName
            )
            let (_, sendInfoResp, _) = try sendMtpCommand(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                code: mtpOpSendObjectInfo,
                params: [primaryStorageId, parentHandle],
                dataToSend: infoPayload
            )
            guard sendInfoResp == mtpRespOk else {
                throw NSError(
                    domain: "MtpService",
                    code: Int(sendInfoResp),
                    userInfo: [NSLocalizedDescriptionKey: "MTP createDirectory failed (0x\(String(sendInfoResp, radix: 16)))"]
                )
            }
        }
    }

    private func renameMtpEntry(
        deviceId: String,
        oldPath: String,
        newName: String,
        newPath: String
    ) throws {
        throw NSError(
            domain: "MtpService",
            code: 21,
            userInfo: [NSLocalizedDescriptionKey: "Direct MTP rename is not supported over standard USB MTP without recreating object"]
        )
    }

    private func deleteMtpEntry(
        deviceId: String,
        targetPath: String,
        isDirectory: Bool
    ) throws {
        let mtpOpDeleteObject: UInt16 = 0x100B
        let cleaned = targetPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = cleaned.split(separator: "/").map(String.init)
        guard let targetName = parts.last, !targetName.isEmpty else {
            throw NSError(domain: "MtpService", code: 22, userInfo: [NSLocalizedDescriptionKey: "Invalid targetPath: \(targetPath)"])
        }
        let parentPath = parts.dropLast().joined(separator: "/")

        try withMtpSession(deviceId: deviceId) { mtpInterface, bulkInPipe, bulkOutPipe, primaryStorageId in
            let parentHandle = try resolveParentHandle(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                storageId: primaryStorageId,
                path: parentPath.isEmpty ? "/sdcard" : "/\(parentPath)"
            )
            let (handlesData, handlesResp, _) = try sendMtpCommand(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                code: mtpOpGetObjectHandles,
                params: [primaryStorageId, 0, parentHandle]
            )
            guard handlesResp == mtpRespOk else {
                throw NSError(
                    domain: "MtpService",
                    code: Int(handlesResp),
                    userInfo: [NSLocalizedDescriptionKey: "GetObjectHandles failed for delete (0x\(String(handlesResp, radix: 16)))"]
                )
            }
            let handles = parseUInt32Array(from: handlesData)
            var matchedHandle: UInt32?
            for handle in handles {
                let (infoData, infoResp, _) = try sendMtpCommand(
                    interface: mtpInterface,
                    bulkInPipe: bulkInPipe,
                    bulkOutPipe: bulkOutPipe,
                    code: mtpOpGetObjectInfo,
                    params: [handle]
                )
                if infoResp == mtpRespOk, let info = parseObjectInfo(from: infoData), info.filename == targetName {
                    matchedHandle = handle
                    break
                }
            }
            guard let objectHandle = matchedHandle else {
                throw NSError(domain: "MtpService", code: 23, userInfo: [NSLocalizedDescriptionKey: "Remote entry not found: \(targetPath)"])
            }
            let (_, delResp, _) = try sendMtpCommand(
                interface: mtpInterface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                code: mtpOpDeleteObject,
                params: [objectHandle, 0]
            )
            guard delResp == mtpRespOk else {
                throw NSError(
                    domain: "MtpService",
                    code: Int(delResp),
                    userInfo: [NSLocalizedDescriptionKey: "MTP DeleteObject failed (0x\(String(delResp, radix: 16)))"]
                )
            }
        }
    }

    private func resolveParentHandle(
        interface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>>,
        bulkInPipe: UInt8,
        bulkOutPipe: UInt8,
        storageId: UInt32,
        path: String
    ) throws -> UInt32 {
        let cleaned = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if cleaned.isEmpty || cleaned == "sdcard" || cleaned == "0" {
            return 0xFFFFFFFF
        }

        let parts = cleaned.split(separator: "/").map(String.init)
        let startIndex = (parts.first == "sdcard") ? 1 : 0
        var currentParent: UInt32 = 0xFFFFFFFF

        for idx in startIndex..<parts.count {
            let segment = parts[idx]
            let (handlesData, resp, _) = try sendMtpCommand(
                interface: interface,
                bulkInPipe: bulkInPipe,
                bulkOutPipe: bulkOutPipe,
                code: mtpOpGetObjectHandles,
                params: [storageId, 0, currentParent]
            )
            guard resp == mtpRespOk else { break }
            let handles = parseUInt32Array(from: handlesData)
            var foundHandle: UInt32?
            for h in handles {
                let (infoData, infoResp, _) = try sendMtpCommand(
                    interface: interface,
                    bulkInPipe: bulkInPipe,
                    bulkOutPipe: bulkOutPipe,
                    code: mtpOpGetObjectInfo,
                    params: [h]
                )
                if infoResp == mtpRespOk, let info = parseObjectInfo(from: infoData), info.isDirectory, info.filename == segment {
                    foundHandle = h
                    break
                }
            }
            if let matched = foundHandle {
                currentParent = matched
            } else {
                break
            }
        }

        return currentParent
    }

    private struct ObjectInfo {
        let objectFormat: UInt16
        let objectCompressedSize: UInt64
        let filename: String

        var isDirectory: Bool {
            objectFormat == 0x3001
        }
    }

    private func parseObjectInfo(from data: Data) -> ObjectInfo? {
        guard data.count >= 53 else { return nil }
        let objectFormat = readUInt16LE(data, offset: 4)
        let size32 = UInt64(readUInt32LE(data, offset: 8))
        let (filename, _) = readMtpString(data, offset: 52)
        guard !filename.isEmpty else { return nil }
        return ObjectInfo(
            objectFormat: objectFormat,
            objectCompressedSize: size32,
            filename: filename
        )
    }

    private func readMtpString(_ data: Data, offset: Int) -> (String, Int) {
        guard offset < data.count else { return ("", offset) }
        let charCount = Int(data[offset])
        var cursor = offset + 1
        if charCount == 0 {
            return ("", cursor)
        }
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(charCount)
        for _ in 0..<charCount {
            guard cursor + 1 < data.count else { break }
            let codeUnit = readUInt16LE(data, offset: cursor)
            cursor += 2
            if codeUnit != 0, let scalar = UnicodeScalar(codeUnit) {
                scalars.append(scalar)
            }
        }
        return (String(String.UnicodeScalarView(scalars)), cursor)
    }

    private func parseUInt32Array(from data: Data) -> [UInt32] {
        guard data.count >= 4 else { return [] }
        let count = Int(readUInt32LE(data, offset: 0))
        var result: [UInt32] = []
        result.reserveCapacity(count)
        var offset = 4
        for _ in 0..<count {
            guard offset + 3 < data.count else { break }
            result.append(readUInt32LE(data, offset: offset))
            offset += 4
        }
        return result
    }

    private func sendMtpCommand(
        interface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>>,
        bulkInPipe: UInt8,
        bulkOutPipe: UInt8,
        code: UInt16,
        params: [UInt32],
        dataToSend: Data? = nil
    ) throws -> (Data, UInt16, [UInt32]) {
        let txId = transactionId
        transactionId &+= 1

        let totalLength = UInt32(12 + params.count * 4)
        var cmdPacket = Data(capacity: Int(totalLength))
        appendUInt32LE(&cmdPacket, totalLength)
        appendUInt16LE(&cmdPacket, mtpContainerCommand)
        appendUInt16LE(&cmdPacket, code)
        appendUInt32LE(&cmdPacket, txId)
        for p in params {
            appendUInt32LE(&cmdPacket, p)
        }

        try writeBulk(interface: interface, pipeRef: bulkOutPipe, data: cmdPacket)

        if let outgoingPayload = dataToSend {
            let dataPacketLen = UInt32(12 + outgoingPayload.count)
            var dataPacket = Data(capacity: Int(dataPacketLen))
            appendUInt32LE(&dataPacket, dataPacketLen)
            appendUInt16LE(&dataPacket, mtpContainerData)
            appendUInt16LE(&dataPacket, code)
            appendUInt32LE(&dataPacket, txId)
            dataPacket.append(outgoingPayload)
            try writeBulk(interface: interface, pipeRef: bulkOutPipe, data: dataPacket)
        }

        var payloadData = Data()
        var responseCode: UInt16 = 0
        var responseParams: [UInt32] = []

        for _ in 0..<2 {
            let chunk = try readBulk(interface: interface, pipeRef: bulkInPipe, maxLength: 65536)
            guard chunk.count >= 12 else { continue }
            let pktLen = Int(readUInt32LE(chunk, offset: 0))
            let pktType = readUInt16LE(chunk, offset: 4)
            let pktCode = readUInt16LE(chunk, offset: 6)

            if pktType == mtpContainerData {
                var fullData = chunk
                let targetLen = max(pktLen, chunk.count)
                while fullData.count < targetLen {
                    let more = try readBulk(interface: interface, pipeRef: bulkInPipe, maxLength: 65536)
                    if more.isEmpty { break }
                    fullData.append(more)
                }
                if fullData.count > 12 {
                    payloadData.append(fullData.subdata(in: 12..<min(fullData.count, pktLen > 12 ? pktLen : fullData.count)))
                }
            } else if pktType == mtpContainerResponse {
                responseCode = pktCode
                var off = 12
                while off + 3 < min(chunk.count, pktLen > 0 ? pktLen : chunk.count) {
                    responseParams.append(readUInt32LE(chunk, offset: off))
                    off += 4
                }
                break
            }
        }

        if responseCode == 0 {
            let respChunk = try readBulk(interface: interface, pipeRef: bulkInPipe, maxLength: 512)
            if respChunk.count >= 8 {
                responseCode = readUInt16LE(respChunk, offset: 6)
                var off = 12
                while off + 3 < respChunk.count {
                    responseParams.append(readUInt32LE(respChunk, offset: off))
                    off += 4
                }
            }
        }

        return (payloadData, responseCode, responseParams)
    }

    private func writeBulk(
        interface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>>,
        pipeRef: UInt8,
        data: Data
    ) throws {
        var mutable = Data(data)
        let kr = mutable.withUnsafeMutableBytes { rawBuf -> IOReturn in
            guard let base = rawBuf.baseAddress else { return kIOReturnBadArgument }
            let size = UInt32(rawBuf.count)
            return interface.pointee.pointee.WritePipe(interface, pipeRef, base, size)
        }
        if kr != kIOReturnSuccess {
            throw NSError(
                domain: "MtpService",
                code: Int(kr),
                userInfo: [NSLocalizedDescriptionKey: "USB bulk write failed (0x\(String(kr, radix: 16)))"]
            )
        }
    }

    private func readBulk(
        interface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>>,
        pipeRef: UInt8,
        maxLength: Int
    ) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: maxLength)
        var size = UInt32(maxLength)
        let kr = interface.pointee.pointee.ReadPipe(interface, pipeRef, &buffer, &size)
        if kr != kIOReturnSuccess {
            throw NSError(
                domain: "MtpService",
                code: Int(kr),
                userInfo: [NSLocalizedDescriptionKey: "USB bulk read failed (0x\(String(kr, radix: 16)))"]
            )
        }
        return Data(buffer.prefix(Int(size)))
    }

    private func createDeviceInterface(
        service: io_object_t
    ) throws -> UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>> {
        var plugInInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var score: Int32 = 0
        let pluginKr = IOCreatePlugInInterfaceForService(
            service,
            kIOUSBDeviceUserClientTypeUUID,
            kIOCFPlugInInterfaceUUID,
            &plugInInterface,
            &score
        )
        guard pluginKr == kIOReturnSuccess, let plugin = plugInInterface else {
            throw NSError(domain: "MtpService", code: Int(pluginKr), userInfo: [NSLocalizedDescriptionKey: "IOCreatePlugInInterfaceForService failed"])
        }
        defer { _ = plugin.pointee!.pointee.Release(plugin) }

        var devInterface: UnsafeMutableRawPointer?
        let uuid = CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceUUID)
        let queryKr = withUnsafePointer(to: uuid) { uuidPtr in
            plugin.pointee!.pointee.QueryInterface(plugin, uuidPtr.withMemoryRebound(to: REFIID.self, capacity: 1) { $0 }.pointee, &devInterface)
        }
        guard queryKr == S_OK, let rawDev = devInterface else {
            throw NSError(domain: "MtpService", code: Int(queryKr), userInfo: [NSLocalizedDescriptionKey: "QueryInterface for IOUSBDeviceInterface failed"])
        }
        return rawDev.assumingMemoryBound(to: UnsafeMutablePointer<IOUSBDeviceInterface>.self)
    }

    private func findMtpInterface(
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>>
    ) throws -> UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>> {
        let dontCare = UInt16(0xFFFF)
        var request = IOUSBFindInterfaceRequest(
            bInterfaceClass: dontCare,
            bInterfaceSubClass: dontCare,
            bInterfaceProtocol: dontCare,
            bAlternateSetting: dontCare
        )
        var iter: io_iterator_t = 0
        let kr = deviceInterface.pointee.pointee.CreateInterfaceIterator(deviceInterface, &request, &iter)
        guard kr == kIOReturnSuccess else {
            throw NSError(domain: "MtpService", code: Int(kr), userInfo: [NSLocalizedDescriptionKey: "CreateInterfaceIterator failed"])
        }
        defer { IOObjectRelease(iter) }

        while case let ifaceService = IOIteratorNext(iter), ifaceService != 0 {
            defer { IOObjectRelease(ifaceService) }

            var plugIn: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
            var score: Int32 = 0
            guard IOCreatePlugInInterfaceForService(
                ifaceService,
                kIOUSBInterfaceUserClientTypeUUID,
                kIOCFPlugInInterfaceUUID,
                &plugIn,
                &score
            ) == kIOReturnSuccess, let p = plugIn else { continue }
            defer { _ = p.pointee!.pointee.Release(p) }

            var rawIface: UnsafeMutableRawPointer?
            let uuid = CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceUUID)
            let qKr = withUnsafePointer(to: uuid) { uuidPtr in
                p.pointee!.pointee.QueryInterface(p, uuidPtr.withMemoryRebound(to: REFIID.self, capacity: 1) { $0 }.pointee, &rawIface)
            }
            guard qKr == S_OK, let ifacePtr = rawIface else { continue }
            let typedIface = ifacePtr.assumingMemoryBound(to: UnsafeMutablePointer<IOUSBInterfaceInterface>.self)

            var ifaceClass: UInt8 = 0
            var ifaceSubClass: UInt8 = 0
            var ifaceProto: UInt8 = 0
            _ = typedIface.pointee.pointee.GetInterfaceClass(typedIface, &ifaceClass)
            _ = typedIface.pointee.pointee.GetInterfaceSubClass(typedIface, &ifaceSubClass)
            _ = typedIface.pointee.pointee.GetInterfaceProtocol(typedIface, &ifaceProto)

            if (ifaceClass == 0x06 && ifaceSubClass == 0x01) || (ifaceClass == 0xFF && ifaceSubClass == 0xFF && ifaceProto == 0x00) {
                return typedIface
            }
            if ifaceClass == 0xFF && ifaceSubClass == 0xFF {
                return typedIface
            }

            _ = typedIface.pointee.pointee.Release(typedIface)
        }

        throw NSError(
            domain: "MtpService",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "No MTP USB interface found. Select File Transfer (MTP) on your phone."]
        )
    }

    private func findBulkPipes(
        interface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>>
    ) throws -> (UInt8, UInt8) {
        var numEndpoints: UInt8 = 0
        let kr = interface.pointee.pointee.GetNumEndpoints(interface, &numEndpoints)
        guard kr == kIOReturnSuccess else {
            throw NSError(domain: "MtpService", code: Int(kr), userInfo: [NSLocalizedDescriptionKey: "GetNumEndpoints failed"])
        }

        var bulkIn: UInt8?
        var bulkOut: UInt8?

        if numEndpoints >= 1 {
            for pipeRef in 1...numEndpoints {
                var dir: UInt8 = 0
                var epNum: UInt8 = 0
                var transferType: UInt8 = 0
                var maxPacket: UInt16 = 0
                var interval: UInt8 = 0
                if interface.pointee.pointee.GetPipeProperties(interface, pipeRef, &dir, &epNum, &transferType, &maxPacket, &interval) == kIOReturnSuccess {
                    if transferType == UInt8(kUSBBulk) {
                        if dir == UInt8(kUSBIn) && bulkIn == nil {
                            bulkIn = pipeRef
                        } else if dir == UInt8(kUSBOut) && bulkOut == nil {
                            bulkOut = pipeRef
                        }
                    }
                }
            }
        }

        guard let inPipe = bulkIn, let outPipe = bulkOut else {
            throw NSError(domain: "MtpService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Bulk IN/OUT endpoints not found"])
        }
        return (inPipe, outPipe)
    }

    private func readUInt16LE(_ data: Data, offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private func appendUInt16LE(_ data: inout Data, _ value: UInt16) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
    }

    private func appendUInt32LE(_ data: inout Data, _ value: UInt32) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
    }

    private func intProperty(from service: io_object_t, key: String) -> Int? {
        guard let cfNum = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber else {
            return nil
        }
        return cfNum.intValue
    }

    private func stringProperty(from service: io_object_t, key: String) -> String? {
        guard let cfStr = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return nil
        }
        let trimmed = cfStr.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String {
    func prependedSlash() -> String {
        hasPrefix("/") ? self : "/\(self)"
    }
}
