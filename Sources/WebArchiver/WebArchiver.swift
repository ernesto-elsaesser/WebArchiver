import Foundation

public struct ArchivingResult {
    public var plistData: Data?
    public var errors: [ArchivingError] = []
}

public enum ArchivingError: LocalizedError {
    case requestFailed(url: URL, error: Error?)
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
            
            let collector = ReferenceCollector()
            collector.parse(data: data)
            
            for (reference, type) in collector.references {
                guard let refUrl = URL(string: reference, relativeTo: url) else {
                    continue
                }
                
                // guess MIME types, as MIME types from HTTP responses are even less reliable
                let mime: String
                switch type {
                case .css:
                    mime = "text/css"
                case .script:
                    mime = "text/javascript"
                case .image:
                    mime = "image/" + refUrl.pathExtension
                }
                
                session.load(url: refUrl) { data in
                    let resource = WebArchiveResource(
                        url: refUrl.absoluteString,
                        data: data,
                        type: mime
                    )
                    subResources.append(resource)
                    
                    if type != .css {
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
