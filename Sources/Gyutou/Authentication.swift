//
//  Authentication.swift
//  Gyutou
//
//  Created by Joseph Mehdi Smith on 5/16/17.
//
// Lots of inspiration from
// https://github.com/TakeScoop/SwiftyRSA/blob/7d62b80013863099a09a853477f8df65a6a382f1/SwiftyRSA/SwiftyRSA.swift
// and
// https://github.com/TakeScoop/SwiftyRSA/blob/7d62b80013863099a09a853477f8df65a6a382f1/SwiftyRSA/Key.swift

import Foundation
import Security

extension CFString: Hashable {
    public var hashValue: Int {
        return (self as String).hashValue
    }

    static public func == (lhs: CFString, rhs: CFString) -> Bool {
        return lhs as String == rhs as String
    }
}

func base64String(pemEncoded pemString: String) throws -> String {
    let lines = pemString.components(separatedBy: "\n").filter { line in
        return !line.hasPrefix("-----BEGIN") && !line.hasPrefix("-----END")
    }

    guard lines.count != 0 else {
        throw GyutouError.signingKeyError(message: "Couldn't get data from PEM key: no data available after stripping headers")
    }

    return lines.joined(separator: "")
}

// Load the key based on https://developer.apple.com/library/content/documentation/Security/Conceptual/CertKeyTrustProgGuide/Ident.html#//apple_ref/doc/uid/TP40001358-CH227-SW3
@available(OSX 10.12, *)
func parsePrivateKey(_ pemString: String) throws -> SecKey {
    let encodedString = try base64String(pemEncoded: pemString)
    guard let data = Data(base64Encoded: encodedString, options: [.ignoreUnknownCharacters]) else {
        throw GyutouError.signingKeyError(message: "Error decoding PEM string")
    }
    let sizeInBits = data.count * 8
    let keyDict: [CFString: Any] = [
        kSecAttrKeyType: kSecAttrKeyTypeRSA,
        kSecAttrKeyClass: kSecAttrKeyClassPrivate,
        kSecAttrKeySizeInBits: NSNumber(value: sizeInBits),
        kSecReturnPersistentRef: true
    ]

    var error: Unmanaged<CFError>?
    guard let key = SecKeyCreateWithData(data as CFData, keyDict as CFDictionary, &error) else {
        throw GyutouError.signingKeyError(message: "Error creating key: \(error!.takeRetainedValue())")
    }
    return key
}
