import Foundation
import Dispatch
import Security
import CryptoSwift

enum GyutouError: Error {
    case signingKeyError(message: String)
    case improperChefURLError
}

let chefAuthorizationHeaderTemplate = "X-Ops-Authorization-"

@available(OSX 10.12, *)
public class GyutouClient {
    var sema = DispatchSemaphore(value: 0)

    public init() { }

    func createEndpointURL(urlPath: String, organizationName: String? = nil) -> String{
        var endpoint: String
        if let orgName = organizationName {
            endpoint = "/organizations/\(orgName)/\(urlPath)"
        } else {
            endpoint = "/\(urlPath)"
        }
        return endpoint
    }

    func generateChefURL(server: String, path: String, parameters: [String:String]? = nil) throws -> URLRequest {
        var parameterString = "?"
        if let params = parameters {
            for (key, value) in params {
                if parameterString.characters.count > 1 {
                    parameterString.append("&")
                }
                parameterString.append("\(key)=\(value)")
            }
        }
        if parameterString.characters.count == 1 {
            parameterString = ""
        }

        guard let serverUrl = URL(string: "\(server)\(path)\(parameterString)") else { throw GyutouError.improperChefURLError }
        return URLRequest(url: serverUrl)
    }

    func createCanonicalRequestData(endpoint: String, hashedBody: String, timestamp: String) -> CFData {
        let hashedPath = Data(bytes: Digest.sha1(Array(endpoint.utf8))).base64EncodedString()
        let canonicalRequest = "Method:GET\nHashed Path:\(hashedPath)\nX-Ops-Content-Hash:\(hashedBody)\nX-Ops-Timestamp:\(timestamp)\nX-Ops-UserId:\(NSUserName())"

        return canonicalRequest.data(using: String.Encoding.utf8)! as CFData
    }

    func sendChefRequest(path: String, body: String = "", parameters: Dictionary<String, String>? = nil) throws -> Any? {
        /*
         The docs at https://docs.chef.io/auth.html#other-options were quite helpful
         https://chef.github.io/chef-rfc/rfc065-sign-v1.3.html Gave more detail
         */
        let configuration = knifeConfigurationContents()

        if let server = configuration.serverUrl {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let endpoint = createEndpointURL(urlPath: path, organizationName: configuration.organizationName)
            let hashedBody = Data(bytes: Digest.sha1(Array(body.utf8))).base64EncodedString()
            let canonicalRequestData = createCanonicalRequestData(endpoint: endpoint, hashedBody: hashedBody, timestamp: timestamp)

            var request = try generateChefURL(server: server, path: path, parameters: parameters)

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
            let data: Data?
            let response: URLResponse?
            let responseError: Error?
            var jsonOutput: Any?
            let task = session.dataTask(with: request) {
                /* Useful for debugging
                if let responded = $1 {
                    print("The response was: \(responded)")
                }*/
                if let responseError = $2 {
                    print("Error: \(responseError)")
                    print("Code: \(responseError._code)")
                } else if let data = $0 {
                    do {
                        let output = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                        jsonOutput = output

                    } catch {
                        print("Warning, did not receive valid JSON!\n\(error)")
                    }
                }
                self.sema.signal()
            }
            task.resume()
            sema.wait()
            return jsonOutput
        }
        return nil;
    }

    public func retrieveNodeAttributes(nodeName: String) throws -> Any? {
        if let response = try sendChefRequest(path: "nodes/\(nodeName)") {
            return response
        }
        return nil
    }

    public func nodeList() throws -> [String]? {
        if let response = try sendChefRequest(path: "nodes") as? [String:String] {
            return Array(response.keys)
        }
        return nil
    }

    public func searchNode(query: String) throws -> [String] {
        var hostnames = [String]()
        if let response = try sendChefRequest(path: "search/node", parameters: ["q": query]) as? [String: Any] {
            if let rows = response["rows"] as? Array<Any> {
                for row in rows {
                    if let node = row as? [String: Any] {
                        if let name = node["name"] {
                            hostnames.append(String(describing: name))
                        }
                    }
                }
            }
        }
        return hostnames
    }
}
