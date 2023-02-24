//
//  File.swift
//  
//
//  Created by Lucca Beurmann on 24/02/23.
//

import Foundation

public protocol CaravelClientProtocol {
    
    func sendRequest<T: Decodable>(data: EndpointProtocol) async throws -> T
    
}

public class CaravelClient: CaravelClientProtocol {
    
    public static let instance = CaravelClient()
    
    private init() { }
    
    public func sendRequest<T>(data: EndpointProtocol) async throws -> T where T : Decodable {
        let urlComponent = try buildUrlComponent(from: data)
        let request = try buildUrlRequest(from: data, with: urlComponent)
        return try await doRequest(request: request)
    }
    
    private func buildUrlComponent(from endpoint: EndpointProtocol) throws -> URLComponents {
        guard var urlComponent = URLComponents(string: endpoint.baseURL + endpoint.path) else {
            throw RequestError.invalidURL(url: "\(endpoint.baseURL)\(endpoint.path)")
        }
        
        var queries : [URLQueryItem] = []
        endpoint.queries.forEach { query in
            queries.append(URLQueryItem(name: query.key, value: query.value))
        }
        
        urlComponent.queryItems = queries
        return urlComponent
    }
    
    private func buildUrlRequest(
        from endpoint: EndpointProtocol,
        with component: URLComponents
    ) throws -> URLRequest {
        
        guard let url = component.url else {
            throw RequestError.invalidURL(url: component.url?.absoluteURL.absoluteString ?? "Url is Null")
        }
        
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = endpoint.headers
        request.httpMethod = endpoint.method.rawValue
    
        return request
    }
    
    private func doRequest<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request, delegate: nil)
        
        guard let responseData = response as? HTTPURLResponse else {
            throw RequestError.noResponse
        }
        
        switch responseData.statusCode {
        case 200...299:
            do {
                let decode = try JSONDecoder().decode(T.self, from: data)
                return decode
                
            } catch let error {
                throw RequestError.decode(error: error)
            }
        case 401:
            throw RequestError.unauthorized
        default:
            throw RequestError.serverError(statusCode: responseData.statusCode)
        }
    }
    
    
    
}


