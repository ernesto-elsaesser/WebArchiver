import Foundation

class ArchivingSession {
    
    private let urlSession: URLSession
    private let completion: ([URL:Error]) -> ()
    private let cachePolicy: URLRequest.CachePolicy
    private let cookies: [HTTPCookie]
    private var loadedUrls: Set<URL> = Set()
    private var errors: [URL:Error] = [:]
    private var pendingTaskCount: Int = 0
    
    init(cookies: [HTTPCookie], skipCache: Bool, completion: @escaping ([URL:Error]) -> ()) {
        
        let sessionQueue = OperationQueue()
        sessionQueue.maxConcurrentOperationCount = 1
        sessionQueue.name = "WebArchiverWorkQueue"
        
        self.urlSession = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: sessionQueue)
        self.cachePolicy = skipCache ? .reloadIgnoringLocalAndRemoteCacheData : .returnCacheDataElseLoad
        self.cookies = cookies
        self.completion = completion
    }
    
    func load(url: URL, handler: @escaping (Data) -> () ) {
        
        if self.loadedUrls.contains(url) {
            return
        }
        
        loadedUrls.insert(url)
        pendingTaskCount += 1
        
        var request = URLRequest(url: url)
        request.cachePolicy = cachePolicy
        urlSession.configuration.httpCookieStorage?.setCookies(cookies, for: url, mainDocumentURL: nil)
        
        let task = urlSession.dataTask(with: request) { (data, response, error) in
            
            if let error = error {
                self.errors[url] = error
            } else if let data = data {
                // might trigger additional load tasks
                handler(data)
            }
            
            self.pendingTaskCount -= 1
            if self.pendingTaskCount == 0 {
                DispatchQueue.main.async {
                    self.completion(self.errors)
                }
            }
        }
        task.resume()
    }
}
