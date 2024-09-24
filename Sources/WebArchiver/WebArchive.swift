import Foundation

struct WebArchiveMainResource: Codable {
    
    enum CodingKeys: String, CodingKey {
        case url = "WebResourceURL"
        case data = "WebResourceData"
        case type = "WebResourceMIMEType"
        case encoding = "WebResourceTextEncodingName"
        case frame = "WebResourceFrameName"
    }
    
    let url: String
    let data: Data
    let type: String
    let encoding: String
    let frame: String
}


struct WebArchiveResource: Codable {
    
    enum CodingKeys: String, CodingKey {
        case url = "WebResourceURL"
        case data = "WebResourceData"
        case type = "WebResourceMIMEType"
    }
    
    let url: String
    let data: Data
    let type: String
}

struct WebArchive: Codable {
    
    enum CodingKeys: String, CodingKey {
        case main = "WebMainResource"
        case resources = "WebSubresources"
    }
    
    let main: WebArchiveMainResource
    let resources: [WebArchiveResource]
}
