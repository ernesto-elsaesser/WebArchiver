import Foundation

enum ReferenceType {
    case css
    case image
    case script
}

class ReferenceCollector: NSObject, XMLParserDelegate {

    var references: [String:ReferenceType] = [:]
    
    func parse(data: Data) {
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        switch elementName {
        case "link":
            if let rel = attributeDict["rel"], rel == "stylesheet",
               let href = attributeDict["href"] {
                references[href] = .css
            }
        case "img":
            if let src = attributeDict["src"] {
                references[src] = .image
            }
        case "script":
            if let src = attributeDict["src"] {
                references[src] = .script
            }
        default:
            return
        }
    }
}
