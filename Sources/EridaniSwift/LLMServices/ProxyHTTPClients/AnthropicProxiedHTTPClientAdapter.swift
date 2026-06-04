//
//  AnthropicProxiedHTTPClientAdapter.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 10/8/25.
//

import Foundation
import SwiftAnthropic

/// Adapter that implements HTTPClient protocol using URLSession
class AnthropicProxiedHTTPClientAdapter: BaseProxyHandler, HTTPClient {
    
    static let errorStartData = { "{\"type\":\"error\",".data(using: .ascii)! }()
    
    override init(proxyDetails: BaseProxyHandler.ProxyAPIDetails, sessionRefreshHandler: any ProxySessionHandler) {
        super.init(proxyDetails: proxyDetails, sessionRefreshHandler: sessionRefreshHandler)
    }
    
    /// Fetches data for a given HTTP request
    /// - Parameter request: The HTTP request to perform
    /// - Returns: A tuple containing the data and HTTP response
    public func data(for request: HTTPRequest) async throws -> (Data, HTTPResponse) {
        
        let urlRequest = try createURLRequest(from: request)
        
        let urlSession = URLSession.init(configuration: try await config)
        let (data, urlResponse) = try await urlSession.data(for: urlRequest)
        
        func collateResponse() throws -> (Data, HTTPResponse) {
            guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
                throw URLError(.badServerResponse) // Or a custom error
            }
            
            let response = HTTPResponse(statusCode: httpURLResponse.statusCode, headers: convertHeaders(httpURLResponse.allHeaderFields))
            return (data, response)
        }
        
        
        // Check if there's an error. This checks to see if the data starts with the string "{\"type\":\"error\",
        if data.prefix(Self.errorStartData.count) == Self.errorStartData {
            guard let proxyError = try extractProxyError(data: data) else {
                return try collateResponse()
            }
            if case ProxyError.tokenExpired = proxyError {
                try await sessionRefreshHandler.refresh()
                // Call self to retry
                if retryCount < Self.maxRetries {
                    
                    retryCount += 1
                    
                    let result = try await self.data(for: request)
                    
                    // Reset retry count on success
                    retryCount = 0
                    
                    return result
                }
            }
            else {
                throw proxyError
            }
        }
        
        return try collateResponse()
    }
    
    /// Fetches a byte stream for a given HTTP request
    /// - Parameter request: The HTTP request to perform
    /// - Returns: A tuple containing the byte stream and HTTP response
    public func bytes(for request: HTTPRequest) async throws -> (HTTPByteStream, HTTPResponse) {
        let urlRequest = try createURLRequest(from: request)
        
        let urlSession = URLSession.init(configuration: try await config)
        let (asyncBytes, urlResponse) = try await urlSession.bytes(for: urlRequest)
        
        guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse) // Or a custom error
        }
        
        let response = HTTPResponse(
            statusCode: httpURLResponse.statusCode,
            headers: convertHeaders(httpURLResponse.allHeaderFields))
        
        let stream = AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    for try await line in asyncBytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        
        return (.lines(stream), response)
    }
    
    /// Converts our HTTPRequest to URLRequest
    /// - Parameter request: Our HTTPRequest
    /// - Returns: URLRequest
    private func createURLRequest(from originalRequest: HTTPRequest) throws -> URLRequest {
        
        guard let request = reflectHTTPRequest(originalRequest) else {
            throw SimpleError.message("Can't decide request")
        }
        
        let path = request.url.path()
        let fullUrl = proxyUrl.appending(path: path)
        var urlRequest = URLRequest(url: fullUrl)
        urlRequest.httpMethod = request.method.rawValue
        
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        urlRequest.httpBody = request.body
        
        return urlRequest
    }
    
    // Reads all stored properties from HTTPRequest using reflection.
    private func reflectHTTPRequest(_ req: HTTPRequest) -> (url: URL, method: SwiftAnthropic.HTTPMethod, headers: [String: String], body: Data?)? {
        let mirror = Mirror(reflecting: req)
        
        // Prefer matching by property name.
        let url = mirror.children.first { $0.label == "url" }?.value as? URL
        let method = mirror.children.first { $0.label == "method" }?.value as? SwiftAnthropic.HTTPMethod
        let headers = mirror.children.first { $0.label == "headers" }?.value as? [String: String]
        // body is Optional<Data>; casting to Data yields nil when body == nil
        let body = mirror.children.first { $0.label == "body" }?.value as? Data
        
        if let url, let method, let headers {
            return (url, method, headers, body)
        }
        
        // Fallback: rely on declaration order (url, method, headers, body)
        let children = Array(mirror.children)
        guard children.count >= 4,
              let url2 = children[0].value as? URL,
              let method2 = children[1].value as? SwiftAnthropic.HTTPMethod,
              let headers2 = children[2].value as? [String: String]
        else {
            return nil
        }
        let body2 = children[3].value as? Data
        return (url2, method2, headers2, body2)
    }
    
    /// Converts HTTPURLResponse headers to a dictionary [String: String]
    /// - Parameter headers: The headers from HTTPURLResponse (i.e. `allHeaderFields`)
    /// - Returns: Dictionary of header name-value pairs
    private func convertHeaders(_ headers: [AnyHashable: Any]) -> [String: String] {
        var result = [String: String]()
        for (key, value) in headers {
            if let keyString = key as? String, let valueString = value as? String {
                result[keyString] = valueString
            }
        }
        return result
    }
}
