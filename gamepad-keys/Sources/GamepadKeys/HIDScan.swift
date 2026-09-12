import Foundation
import IOKit.hid

/// Діагностика на випадок, коли GameController не бачить жодного контролера.
///
/// GameController працює лише з тим, що Apple вважає ігровим контролером:
/// MFi, Xbox, DualShock 4 / DualSense, Switch Pro. Довільний HID-геймпад
/// система бачить, але фреймворку не віддає. Це сканування показує різницю:
/// якщо пристрій тут є, а контролерів «0» — річ саме в непідтримуваній моделі.
enum HIDScan {

    static func report() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, nil)

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            log("HID: перелічити пристрої не вдалось")
            return
        }

        let gamepads = devices.filter { device in
            let page = number(device, kIOHIDPrimaryUsagePageKey)
            let usage = number(device, kIOHIDPrimaryUsageKey)
            // Generic Desktop → Joystick / Game Pad / Multi-axis Controller
            return page == 0x01 && [0x04, 0x05, 0x08].contains(usage ?? 0)
        }

        guard !gamepads.isEmpty else {
            log("HID: серед \(devices.count) пристроїв жодного джойстика — контролер не під'єднаний до Mac")
            return
        }

        for device in gamepads {
            let product = string(device, kIOHIDProductKey) ?? "без назви"
            let vendor = string(device, kIOHIDManufacturerKey) ?? "?"
            let vendorID = number(device, kIOHIDVendorIDKey) ?? 0
            let productID = number(device, kIOHIDProductIDKey) ?? 0
            let transport = string(device, kIOHIDTransportKey) ?? "?"
            log(String(format: "HID: «%@» (%@) VID:PID %04X:%04X через %@",
                       product, vendor, vendorID, productID, transport))
        }
        log("HID: система пристрій бачить, а GameController не віддає — найімовірніше, модель не підтримується")
    }

    private static func string(_ device: IOHIDDevice, _ key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private static func number(_ device: IOHIDDevice, _ key: String) -> Int? {
        IOHIDDeviceGetProperty(device, key as CFString) as? Int
    }
}
