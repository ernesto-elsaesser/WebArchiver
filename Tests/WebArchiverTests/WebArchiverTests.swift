import XCTest
@testable import WebArchiver

final class WebArchiverTests: XCTestCase {
    
    func testArchiving() {
        
        let url = URL(string: "https://webkit.org/")!
        let decoder = PropertyListDecoder()
        
        let expectation = self.expectation(description: "Archiving job finishes")
        WebArchiver.archive(url: url) { result in
            
            expectation.fulfill()
            
            XCTAssertTrue(result.errors.isEmpty)
            
            guard let data = result.plistData else {
                XCTFail("No plist data returned!")
                return
            }
            
            guard let archive = try? decoder.decode(WebArchive.self, from: data) else {
                XCTFail("Plist data not decodable!")
                return
            }
            
            for resource in archive.resources {
                print("\(resource.type): \(resource.url)")
            }
        }
        
        waitForExpectations(timeout: 60, handler: nil)
    }

    static var allTests = [
        ("Test Archiving", testArchiving),
    ]
}
