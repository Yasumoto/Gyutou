//
//  KnifeConfig.swift
//  Gyutou
//
//  Created by Joseph Mehdi Smith on 5/16/17.
//
//

import Foundation

struct ChefConfiguration {
    var clientKey: String?
    var validationKey: String?
    var serverUrl: String?
    var organizationName: String?
}

struct KnifeConfiguration {
    let filePath = "/Users/\(NSUserName())/.chef/knife.rb"
    let pemFile = "/Users/\(NSUserName())/.chef/\(NSUserName()).pem"
}

func parseStringFormat(value: String) -> String {
    var content = value.components(separatedBy: " ").filter { $0 != "" }[1]
    content = content.replacingOccurrences(of: "\"", with: "")
    content = content.replacingOccurrences(of: "#{ENV['", with: "$")
    content = content.replacingOccurrences(of: "']}", with: "")
    return content
}

func knifeConfigurationContents() -> ChefConfiguration {
    var clientKey: String? = nil
    var validationKey: String? = nil
    var serverUrl: String? = nil
    var organizationName: String? = nil
    let knifeConfig = KnifeConfiguration()
    if let data = FileManager.default.contents(atPath: knifeConfig.filePath),
        let txt = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
        for line in txt.components(separatedBy: "\n") {
            if line.contains("client_key") {
                clientKey = parseStringFormat(value:  line)
            } else if line.contains("validation_key") {
                validationKey = parseStringFormat(value: line)
            } else if line.contains("chef_server_url") {
                serverUrl = parseStringFormat(value: line)
                if serverUrl!.contains("organization") {
                    organizationName = serverUrl!.components(separatedBy: "/").filter { $0 != "" }[3]
                }
            }
        }
    }
    return ChefConfiguration(clientKey: clientKey, validationKey: validationKey, serverUrl: serverUrl, organizationName: organizationName)
}
