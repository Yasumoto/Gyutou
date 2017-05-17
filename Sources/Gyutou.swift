import Foundation
import Dispatch
import Security
import CryptoSwift

enum GyutouError: Error {
    case signingKeyError(message: String)
}

let chefAuthorizationHeaderTemplate = "X-Ops-Authorization-"

@available(OSX 10.12, *)
public class GyutouClient {
    public var sema = DispatchSemaphore(value: 0)
    public var jsonOutput: Any?

    public init() { }

    func sendChefRequest(path: String, body: String = "") throws {
        /*
         The docs at https://docs.chef.io/auth.html#other-options were quite helpful
         https://chef.github.io/chef-rfc/rfc065-sign-v1.3.html Gave more detail
         */
        let configuration = knifeConfigurationContents()

        if let server = configuration.serverUrl, let serverUrl = URL(string: "\(server)\(path)") {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let endpoint: String
            if let orgName = configuration.organizationName {
                endpoint = "/organizations/\(orgName)/\(path)"
            } else {
                endpoint = "/\(path)"
            }
            let hashedPath = Data(bytes: Digest.sha1(Array(endpoint.utf8))).base64EncodedString()
            let hashedBody = Data(bytes: Digest.sha1(Array(body.utf8))).base64EncodedString()
            let canonicalRequest = "Method:GET\nHashed Path:\(hashedPath)\nX-Ops-Content-Hash:\(hashedBody)\nX-Ops-Timestamp:\(timestamp)\nX-Ops-UserId:\(NSUserName())"

            let canonicalRequestData = canonicalRequest.data(using: String.Encoding.utf8)! as CFData
            var request = URLRequest(url: serverUrl)

            let key = try readPrivateKey(fileName: KnifeConfiguration().pemFile)
            // Thanks to https://developer.apple.com/library/content/documentation/Security/Conceptual/CertKeyTrustProgGuide/Signing.html#//apple_ref/doc/uid/TP40001358-CH213-SW1
            var error: Unmanaged<CFError>?
            if let encryptedCoreData = SecKeyCreateSignature(key, SecKeyAlgorithm.rsaSignatureDigestPKCS1v15Raw, canonicalRequestData, &error) {
                let encryptedData = encryptedCoreData as Data
                let encodedData = encryptedData.base64EncodedString()
                var iteration = 1
                while (iteration - 1) * 60 < encodedData.characters.count {
                    var headerString = ""
                    for i in 0..<60 {
                        let index = i + ((iteration - 1) * 60)
                        if index < encodedData.characters.count {
                            headerString.append(encodedData[encodedData.index(encodedData.startIndex, offsetBy: index)])
                        } else {
                            break
                        }
                    }
                    request.addValue(headerString, forHTTPHeaderField: "\(chefAuthorizationHeaderTemplate)\(iteration)")
                    iteration = iteration + 1
                }

            } else {
                print("Error: \(error!.takeRetainedValue())")
            }
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("0.10.4", forHTTPHeaderField: "X-Chef-Version")
            request.setValue(hashedBody, forHTTPHeaderField: "X-Ops-Content-Hash")
            request.setValue("version=1.0", forHTTPHeaderField: "X-Ops-Sign")
            request.setValue(timestamp, forHTTPHeaderField: "X-Ops-Timestamp")
            request.setValue(NSUserName(), forHTTPHeaderField: "X-Ops-UserId")

            let session = URLSession(configuration: URLSessionConfiguration.default)
            let task = session.dataTask(with: request, completionHandler: processChefResponse)
            task.resume()
        }
    }

    func processChefResponse(data: Data?, response: URLResponse?, error: Error?) -> Void {
        if let responded = response {
            print("The response was: \(responded)")
        }
        if let errored = error {
            print("Error: \(errored)")
            print("Code: \(errored._code)")
        } else if let dataz = data {
            do {
                let output = try JSONSerialization.jsonObject(with: dataz, options: .allowFragments)
                jsonOutput = output

            } catch {
                print("Warning, did not receive valid JSON!\n\(error)")
            }
        }
        sema.signal()
    }

    public func retrieveNodeAttributes(nodeName: String) throws {
        try sendChefRequest(path: "nodes/\(nodeName)")
    }
}
