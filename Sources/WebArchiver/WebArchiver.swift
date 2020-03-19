//
//  WebArchiver.swift
//  OfflineWebView
//
//  Created by Ernesto Elsäßer on 11.11.18.
//  Copyright © 2018 Ernesto Elsäßer. All rights reserved.
//

import Foundation
import Fuzi

public struct ArchivingResult {
    public let plistData: Data?
    public let errors: [Error]
}

public enum ArchivingError: LocalizedError {
    case unsupportedUrl
    case requestFailed(resource: URL, error: Error)
    case invalidResponse(resource: URL)
    case unsupportedEncoding
    case invalidReferenceUrl(string: String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedUrl: return "Unsupported URL"
        case .requestFailed(let res, _): return "Failed to load " + res.absoluteString
        case .invalidResponse(let res): return "Invalid response for " + res.absoluteString
        case .unsupportedEncoding: return "Unsupported encoding"
        case .invalidReferenceUrl(let string): return "Invalid reference URL: " + string
        }
    }
}

public class WebArchiver {
    
    public static func archive(url: URL, cookies: [HTTPCookie] = [], includeJavascript: Bool = true, skipCache: Bool = false, completion: @escaping (ArchivingResult) -> ()) {
        
        guard let scheme = url.scheme, scheme == "https" else {
            let result = ArchivingResult(plistData: nil, errors: [ArchivingError.unsupportedUrl])
            completion(result)
            return
        }
        
        let cachePolicy: URLRequest.CachePolicy = skipCache ? .reloadIgnoringLocalAndRemoteCacheData : .returnCacheDataElseLoad
        let session = ArchivingSession(cachePolicy: cachePolicy, cookies: cookies, completion: completion)
        
        session.load(url: url, fallback: nil) { mainResource in
            
            var archive = WebArchive(resource: mainResource)
            
            let references = try self.extractHTMLReferences(from: mainResource, includeJavascript: includeJavascript)
            for reference in references {
                
                session.load(url: reference, fallback: archive) { resource in
                    
                    archive.addSubresource(resource)
                    
                    if reference.pathExtension == "css" {
                        
                        let cssReferences = try self.extractCSSReferences(from: resource)
                        for cssReference in cssReferences {
                            
                            session.load(url: cssReference, fallback: archive) { cssResource in
                                
                                archive.addSubresource(cssResource)
                                return archive
                            }
                        }
                    }
                    
                    return archive
                }
            }
            
            return archive
        }
    }
    
    private static func extractHTMLReferences(from resource: WebArchiveResource, includeJavascript: Bool) throws -> Set<URL> {
        
        guard let htmlString = String(data: resource.data, encoding: .utf8) else {
            throw ArchivingError.unsupportedEncoding
        }
        
        let doc = try HTMLDocument(string: htmlString, encoding: .utf8)
        
        var references: [String] = []
        references += doc.xpath("//img[@src]").compactMap{ $0["src"] } // images
        references += doc.xpath("//link[@rel='stylesheet'][@href]").compactMap{ $0["href"] } // css
        if includeJavascript {
            references += doc.xpath("//script[@src]").compactMap{ $0["src"] } // javascript
        }
        
        return self.absoluteUniqueUrls(references: references, resource: resource)
    }
    
    private static func extractCSSReferences(from resource: WebArchiveResource) throws -> Set<URL> {
        
        guard let cssString = String(data: resource.data, encoding: .utf8) else {
            throw ArchivingError.unsupportedEncoding
        }
        
        let regex = try NSRegularExpression(pattern: "url\\(\\'(.+?)\\'\\)", options: [])
        let fullRange = NSRange(location: 0, length: cssString.count)
        let matches = regex.matches(in: cssString, options: [], range: fullRange)
        
        let objcString = cssString as NSString
        let references = matches.map{ objcString.substring(with: $0.range(at: 1)) }
        
        return self.absoluteUniqueUrls(references: references, resource: resource)
    }
    
    private static func absoluteUniqueUrls(references: [String], resource: WebArchiveResource) -> Set<URL> {
        let absoluteReferences = references.compactMap { URL(string: $0, relativeTo: resource.url) }
        return Set(absoluteReferences)
    }
}
