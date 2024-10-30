# WebArchiver

A Swift package that compresses full web pages into single archive files that can later be loaded into a `WKWebView`. It may be used to implement offline reading features. 

The main method `WebArchiver.achive(...)` takes a URL and optionally a list of cookies. The archiver will download the main HTML document and all linked HTML, CSS, JavaScript (optionally) and image resources. All resources are then packed into a single `.webarchive` file. The archiver parallelizes HTTP requests, but works on a single serial queue to process the responses.

A sample project that demostrates how to combine the WebArchiver with `WKWebView` can be found here: [OfflineWebView](https://github.com/ernesto-elsaesser/OfflineWebView)

## Installation

This repository is a Swift Package Manager package. Use Xcode to add it as a dependency via `https://github.com/ernesto-elsaesser/WebArchiver`.

## Motivation

This package was created because `WKWebView` (in contrast to the deprecated `UIWebView`) does not offer a universal way to make arbritary web content available offline. WebKit's own HTTP caching unfortunately doesn't provide enough control for most use cases, and a lot of stuff happens "out-of-process" (see [here](https://stackoverflow.com/questions/24208229/wkwebview-and-nsurlprotocol-not-working) or [here](https://forums.developer.apple.com/thread/53573)). 

But `WKWebView` can import `.webarchive` files, which are binary PLIST files following a defined (undocumented) format. Being able to create `.webarchive` files therefore allows apps to save online content for offline reading. Such files can be loaded into the `WKWebView` via `loadFileURL(URL:allowingReadAccessTo:)`, where `URL` is a `file://...` URL.

## Limitations

The archiver will only work well with static content. As soon as a web page needs to dynamically load resources via JavaScript, there is no sane way to archive that page into a single file without virtually replicating the backend. The archiver also doesn't scan JavaScript for statically linked resources. It does scan CSS files for image URLs though.

The archiver is further limited to the common resource types of web pages, i.e. HTML, CSS, JavaScript and images. If a web page has statically linked resources of other types (i.e. audio, video, ...) these resources won't be included in the archive. If you need to support such pages, please fork the repo and extend the archiver to support the required types.
