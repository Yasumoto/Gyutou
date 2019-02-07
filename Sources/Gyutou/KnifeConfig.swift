//
//  KnifeConfig.swift
//  Gyutou
//
//  Created by Joseph Mehdi Smith on 5/16/17.
//
//

import Foundation

public enum ConfigError: Error {
    case noClientKeyPathDefined
    case noConfigFound
    case pemKeyError
}

struct ChefConfiguration {
    var clientKeyPath: String?
    var validationKey: String?
    var serverUrl: String?
    var organizationName: String?
    var signingKey: SecKey
}

struct KnifeConfiguration {
    let localPemFile = "/Users/\(NSUserName())/.chef/\(NSUserName()).pem"
}

func readRemoteFile(hostname: String, path: String) -> String? {
    let task = Process()
    task.launchPath = "/usr/bin/ssh"
    task.arguments = [hostname, "cat \(path)"]
    task.launch()
    task.waitUntilExit()
    return task.standardOutput as? String
}

func parseStringFormat(value: String) -> String {
    var content = value.components(separatedBy: " ").filter { $0 != "" }[1]
    content = content.replacingOccurrences(of: "\"", with: "")
    content = content.replacingOccurrences(of: "#{ENV['", with: "$")
    content = content.replacingOccurrences(of: "']}", with: "")
    return content
}

func retrieveConfigFile(hostname: String? = nil) -> String? {
    if let data = FileManager.default.contents(atPath: "/Users/\(NSUserName())/.chef/knife.rb"),
        let txt = String(data: data, encoding: .utf8) {
        return txt
    }
    if let hostname = hostname {
        return readRemoteFile(hostname: hostname, path: "~/.chef/knife.rb")
    }
    return nil
}

@available(OSX 10.12, *)
func retrievePrivateKey(path: String, hostname: String?) throws -> SecKey {
    var keyString = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .ascii)
    if keyString == nil && hostname != nil {
        keyString = readRemoteFile(hostname: hostname!, path: path)
    }
    if keyString == nil {
        throw ConfigError.pemKeyError
    }
    return try parsePrivateKey(keyString!)
}

@available(OSX 10.12, *)
func knifeConfigurationContents(hostname: String? = nil) throws -> ChefConfiguration? {
    var clientKeyPath: String?
    var validationKey: String?
    var serverUrl: String?
    var organizationName: String?
    guard let configFile = retrieveConfigFile() else {
        throw ConfigError.noConfigFound
    }
    for line in configFile.components(separatedBy: "\n") {
        if line.contains("client_key") {
            clientKeyPath = parseStringFormat(value:  line)
        } else if line.contains("validation_key") {
            validationKey = parseStringFormat(value: line)
        } else if line.contains("chef_server_url") {
            serverUrl = parseStringFormat(value: line)
            if serverUrl!.contains("organization") {
                organizationName = serverUrl!.components(separatedBy: "/").filter { $0 != "" }[3]
            }
        }
    }
    if clientKeyPath == nil {
        throw ConfigError.noClientKeyPathDefined
    }
    let signingKey = try retrievePrivateKey(path: clientKeyPath!, hostname: hostname )
    return ChefConfiguration(clientKeyPath: clientKeyPath, validationKey: validationKey, serverUrl: serverUrl, organizationName: organizationName, signingKey: signingKey)
}
