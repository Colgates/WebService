//
//  HttpMethod.swift
//  
//
//  Created by Evgenii Kolgin on 13.09.2022.
//

import Foundation

public enum HTTPMethod {
    
    case get([URLQueryItem])
    case post(Data?)
    case patch(Int, Data?)
    case put(Int, Data?)
    case delete(Int)
    
    var name: String {
        switch self {
        case .get: return "GET"
        case .post: return "POST"
        case .patch: return "PATCH"
        case .put: return "PUT"
        case .delete: return "DELETE"
        }
    }
}
