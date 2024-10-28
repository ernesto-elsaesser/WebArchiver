import Foundation
import Fuzi

public struct ArchivingResult {
    public var plistData: Data?
    public var errors: [ArchivingError] = []
}

public enum ArchivingError: LocalizedError {
    case requestFailed(url: URL, error: Error)
    case encodingFailed(error: Error)
    
    public var errorDescription: String? {
        switch self {
        case .requestFailed(let url, _): return "Failed to load " + url.absoluteString
        case .encodingFailed: return "Failed to create web archive!"
        }
    }
}

public class WebArchiver {
    
    // Using NSRegularExpression as Swift Regex requires iOS 16+
    private static let cssUrlRegex = try! NSRegularExpression(pattern: "url\\(['\"](.+?)['\"]\\)", options: [])
    
    public static func archive(url: URL, cookies: [HTTPCookie] = [], includeJavascript: Bool = true, skipCache: Bool = false, completion: @escaping (ArchivingResult) -> ()) {
        
        var mainResource: WebArchiveMainResource?
        var subResources: [WebArchiveResource] = []
        
        let session = ArchivingSession(cookies: cookies, skipCache: skipCache) { errors in
            
            var result = ArchivingResult()
            
            for (url, error) in errors {
                result.errors.append(.requestFailed(url: url, error: error))
            }
            
            if let main = mainResource {
                
                let archive = WebArchive(main: main, resources: subResources)
                
                let encoder = PropertyListEncoder()
                encoder.outputFormat = .binary
                
                do {
                    result.plistData = try encoder.encode(archive)
                } catch {
                    result.errors.append(.encodingFailed(error: error))
                }
            }
            
            completion(result)
        }
        
        session.load(url: url) { data in
            
            mainResource = WebArchiveMainResource(
                url: url.absoluteString,
                data: data,
                type: "text/html",
                encoding: "UTF-8",
                frame: ""
            )
            
            let imageUrls = self.extractCSSReferences(from: data, base: url)
            for imageUrl in imageUrls {
                session.load(url: imageUrl) { data in
                    let resource = WebArchiveResource(
                        url: imageUrl.absoluteString,
                        data: data,
                        type: "image/" + imageUrl.pathExtension
                    )
                    subResources.append(resource)
                }
            }
            
            let refTypes = try self.extractHTMLReferences(from: data, base: url, includeScripts: includeJavascript)
            
            for (refUrl, mime) in refTypes {
                
                session.load(url: refUrl) { data in
                    let resource = WebArchiveResource(
                        url: refUrl.absoluteString,
                        data: data,
                        type: mime
                    )
                    subResources.append(resource)
                    
                    if mime != "text/css" {
                        return
                    }
                    
                    let resImageUrls = self.extractCSSReferences(from: data, base: refUrl)
                    for imageUrl in resImageUrls {
                        session.load(url: imageUrl) { data in
                            let resource = WebArchiveResource(
                                url: imageUrl.absoluteString,
                                data: data,
                                type: "image/" + imageUrl.pathExtension
                            )
                            subResources.append(resource)
                        }
                    }
                }
            }
        }
    }
    
    private static func extractHTMLReferences(from data: Data, base: URL, includeScripts: Bool) throws -> [URL:String] {
        
        let doc = try HTMLDocument(data: data)
        
        // best guess MIME types
        var refTypes: [URL:String] = [:]
        
        for node in doc.xpath("//img[@src]") {
            if let src = node["src"], let url = URL(string: src, relativeTo: base) {
                refTypes[url] = "image/" + url.pathExtension
            }
        }
        
        for node in doc.xpath("//link[@rel='stylesheet'][@href]") {
            if let href = node["href"], let url = URL(string: href, relativeTo: base) {
                refTypes[url] = "text/css"
            }
        }
        
        if includeScripts {
            for node in doc.xpath("//script[@src]") {
                if let src = node["src"], let url = URL(string: src, relativeTo: base) {
                    refTypes[url] = "text/javascript"
                }
            }
        }
        
        return refTypes
    }
    
    private static func extractCSSReferences(from data: Data, base: URL) -> [URL] {
        
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }
        
        let fullRange = NSRange(location: 0, length: text.count)
        let matches = cssUrlRegex.matches(in: text, options: [], range: fullRange)
        let nsText = (text as NSString)
        var urls: [URL] = []
        for match in matches {
            let nsRange = match.range(at: 1)
            let reference = nsText.substring(with: nsRange)
            if reference.hasPrefix("data:") {
                continue
            }
            guard let url = URL(string: reference, relativeTo: base) else {
                continue
            }
            urls.append(url)
        }
        return urls
    }
}
