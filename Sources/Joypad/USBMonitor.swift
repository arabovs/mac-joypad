import Foundation
import IOKit

enum USBMonitor {
    static func iPhoneConnected() -> Bool {
        match(className: "IOUSBHostDevice") || match(className: "IOUSBDevice")
    }

    private static func match(className: String) -> Bool {
        guard let matching = IOServiceMatching(className) else { return false }
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }

        var device = IOIteratorNext(iterator)
        while device != 0 {
            let found = isApplePhone(device)
            IOObjectRelease(device)
            if found { return true }
            device = IOIteratorNext(iterator)
        }
        return false
    }

    private static func isApplePhone(_ device: io_registry_entry_t) -> Bool {
        let product = (
            property(device, "USB Product Name")
            ?? property(device, "kUSBProductString")
            ?? property(device, "Product Name")
            ?? ""
        ).lowercased()

        if product.contains("iphone") || product.contains("ipad") || product.contains("ipod") {
            return true
        }

        let vendor = numberProperty(device, "idVendor") ?? numberProperty(device, "kUSBVendorID")
        return vendor == 0x05AC && (product.contains("phone") || product.contains("pad"))
    }

    private static func property(_ device: io_registry_entry_t, _ key: String) -> String? {
        guard let raw = IORegistryEntryCreateCFProperty(device, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return raw.takeRetainedValue() as? String
    }

    private static func numberProperty(_ device: io_registry_entry_t, _ key: String) -> Int? {
        guard let raw = IORegistryEntryCreateCFProperty(device, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return (raw.takeRetainedValue() as? NSNumber)?.intValue
    }
}
