//
//  File.swift
//  
//
//  Created by Evgenii Kolgin on 13.09.2022.
//

import Foundation

public struct Resource<T: Codable> {
    public let url: URL
    public let method: HTTPMethod
    
    public init(url: URL, method: HTTPMethod = .get([])) {
        self.url = url
        self.method = method
    }
}
