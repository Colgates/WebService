import Foundation
import Combine

public class WebService {
    
    public static let shared = WebService()
    
    private init() {}
    
    // MARK: - Completion Method
    
    public func dataTask<T: Codable>(for resource: Resource<T>, completion: @escaping (Result<T, NetworkError>) -> Void ) {
        
        do {
            guard let request = try? createRequest(resource) else { throw NetworkError.badRequest(code: 0, error: "Bad request") }
            
            createSession().dataTask(with: request) { data, response, error in
                
                guard let data = data, error == nil else {
                    return completion(.failure(NetworkError.badRequest(code: 0, error: "\(String(describing: error))")))
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    return completion(.failure(NetworkError.badRequest(code: 0, error: "\(String(describing: error))")))
                }
                
                do {
                    let result = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(result))
                } catch {
                    completion(.failure(NetworkError.invalidJSON("Invalid JSON: \(error)")))
                }
            }
            .resume()
        } catch {
            completion(.failure(NetworkError.badRequest(code: 0, error: "Bad request: \(error)")))
        }
    }
    
    // MARK: - Async/Await Method
    @available(macOS 12.0, *)
    @available(macCatalyst 15.0, *)
    @available(iOS 13.0, *)
    public func dataTask<T: Codable>(for resource: Resource<T>) async throws -> T {
        
        guard let request = try? createRequest(resource) else { throw NetworkError.badRequest(code: 0, error: "Bad request") }
        
        guard let (data, response) = try? await createSession().data(for: request) else { throw NetworkError.serverError(code: 0, error: "Bad response") }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(code: 0, error: "Server error")}

        guard let result = try? JSONDecoder().decode(T.self, from: data) else { throw NetworkError.invalidJSON("Invalid JSON") }
        return result
    }
    
    // MARK: - Combine Method
    @available(macOS 10.15, *)
    @available(iOS 13.0, *)
    public func dataTaskPublisher<T: Codable>(for resource: Resource<T>) -> AnyPublisher<T, NetworkError> {
        
        guard let request = try? createRequest(resource) else { return AnyPublisher(Fail<T, NetworkError>(error: NetworkError.badRequest(code: 0, error: "Request error"))) }
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .subscribe(on: DispatchQueue.global(qos: .default))
            .tryMap { output in
                guard output.response is HTTPURLResponse else {
                    throw NetworkError.serverError(code: 0, error: "Server error")
                }
                return output.data
            }
            .receive(on: DispatchQueue.main)
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                NetworkError.invalidJSON(String(describing: error))
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Create Session
    private func createSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Content-Type": "application/json"]
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        let session = URLSession(configuration: configuration)
        return session
    }
    
    // MARK: - Create Request
    private func createRequest<T:Codable>(_ resource: Resource<T>) throws -> URLRequest {
        var request = URLRequest(url: resource.url)
        request.httpMethod = resource.method.name
        
        switch resource.method {
        case .post(let data):
            request.httpBody = data
        
        case .get(let queryItems):
            var components = URLComponents(url: resource.url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            guard let url = components?.url else { throw NetworkError.badURL("Invalid url: \(resource.url)") }
            request = URLRequest(url: url)
            
        case .patch(let id, let data), .put(let id, let data):
            request.url?.appendPathComponent(String(id))
            request.httpBody = data
        case .delete(let id):
            request.url?.appendPathComponent(String(id))
        }
        return request
    }
    
    public func encode<T:Encodable>(data: T) throws -> Data? {
        do {
            let jsonData = try JSONEncoder().encode(data)
            return jsonData
        } catch {
            throw NetworkError.unknown(code: 0, error: "Error: Trying to convert model to JSON data")
        }
    }

    public func decode<T:Decodable>(type: T.Type, data: Data) throws -> T?  {
        do {
            let decodedData = try JSONDecoder().decode(type, from: data)
            return decodedData
        } catch let error as DecodingError {
            switch error {
            case .typeMismatch(let any, let context):
                throw NetworkError.unknown(code: 0, error: "Error: \(any) \(context)")
            case .valueNotFound(let any, let context):
                throw NetworkError.unknown(code: 0, error: "Error: \(any) \(context)")
            case .keyNotFound(let codingKey, let context):
                throw NetworkError.unknown(code: 0, error: "Error: \(codingKey) \(context)")
            case .dataCorrupted(let context):
                throw NetworkError.unknown(code: 0, error: "Error: \(context)")
            default:
                throw NetworkError.unknown(code: 0, error: "Unknown decoding error")
            }
        }
    }
    
    public func createURL(scheme: String = "https", host: String, path: String = "", queryItems:[URLQueryItem] = []) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        components.queryItems = queryItems
        return components.url
    }
}
