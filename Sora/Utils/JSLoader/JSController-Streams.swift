//
//  JSLoader-Streams.swift
//  Sulfur
//
//  Created by Francesco on 30/03/25.
//

import JavaScriptCore

extension JSController {
    
    func fetchStreamUrl(episodeUrl: String, softsub: Bool = false, completion: @escaping ((streams: [String]?, subtitles: [String]?)) -> Void) {
        guard let url = URL(string: episodeUrl) else {
            completion((nil, nil))
            return
        }
        
        URLSession.custom.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.shared.log("Network error: \(error)", type: "Error")
                DispatchQueue.main.async { completion((nil, nil)) }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Failed to decode HTML", type: "Error")
                DispatchQueue.main.async { completion((nil, nil)) }
                return
            }
            
            Logger.shared.log(html, type: "HTMLStrings")
            if let parseFunction = self.context.objectForKeyedSubscript("extractStreamUrl"),
               let resultString = parseFunction.call(withArguments: [html]).toString() {
                if softsub {
                    if let data = resultString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        let moduleMetadata = self.context.objectForKeyedSubscript("module")?.objectForKeyedSubscript("metadata")
                        let isMultiStream = moduleMetadata?.objectForKeyedSubscript("multiStream")?.toBool() == true
                        let isMultiSubs = moduleMetadata?.objectForKeyedSubscript("multiSubs")?.toBool() == true
                        
                        var streamUrls: [String]?
                        if isMultiStream, let streamsArray = json["streams"] as? [String] {
                            streamUrls = streamsArray
                            Logger.shared.log("Found \(streamsArray.count) streams", type: "Stream")
                        } else if let streamUrl = json["stream"] as? String {
                            streamUrls = [streamUrl]
                            Logger.shared.log("Found single stream", type: "Stream")
                        }
                        
                        var subtitleUrls: [String]?
                        if isMultiSubs, let subsArray = json["subtitles"] as? [String] {
                            subtitleUrls = subsArray
                            Logger.shared.log("Found \(subsArray.count) subtitle tracks", type: "Stream")
                        } else if let subtitleUrl = json["subtitles"] as? String {
                            subtitleUrls = [subtitleUrl]
                            Logger.shared.log("Found single subtitle track", type: "Stream")
                        }
                        
                        Logger.shared.log("Starting stream with \(streamUrls?.count ?? 0) sources and \(subtitleUrls?.count ?? 0) subtitles", type: "Stream")
                        DispatchQueue.main.async {
                            completion((streamUrls, subtitleUrls))
                        }
                    } else {
                        Logger.shared.log("Failed to parse softsub JSON", type: "Error")
                        DispatchQueue.main.async { completion((nil, nil)) }
                    }
                } else {
                    let moduleMetadata = self.context.objectForKeyedSubscript("module")?.objectForKeyedSubscript("metadata")
                    let isMultiStream = moduleMetadata?.objectForKeyedSubscript("multiStream")?.toBool() == true
                    
                    if isMultiStream {
                        if let data = resultString.data(using: .utf8),
                           let streamsArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [String] {
                            Logger.shared.log("Starting multi-stream with \(streamsArray.count) sources", type: "Stream")
                            DispatchQueue.main.async { completion((streamsArray, nil)) }
                        } else {
                            Logger.shared.log("Failed to parse multi-stream JSON array", type: "Error")
                            DispatchQueue.main.async { completion((nil, nil)) }
                        }
                    } else {
                        Logger.shared.log("Starting stream from: \(resultString)", type: "Stream")
                        DispatchQueue.main.async { completion(([resultString], nil)) }
                    }
                }
            } else {
                Logger.shared.log("Failed to extract stream URL", type: "Error")
                DispatchQueue.main.async { completion((nil, nil)) }
            }
        }.resume()
    }
    
    func fetchStreamUrlJS(episodeUrl: String, softsub: Bool = false, completion: @escaping ((streams: [String]?, subtitles: [String]?)) -> Void) {
        if let exception = context.exception {
            Logger.shared.log("JavaScript exception: \(exception)", type: "Error")
            completion((nil, nil))
            return
        }
        
        guard let extractStreamUrlFunction = context.objectForKeyedSubscript("extractStreamUrl") else {
            Logger.shared.log("No JavaScript function extractStreamUrl found", type: "Error")
            completion((nil, nil))
            return
        }
        
        let promiseValue = extractStreamUrlFunction.call(withArguments: [episodeUrl])
        guard let promise = promiseValue else {
            Logger.shared.log("extractStreamUrl did not return a Promise", type: "Error")
            completion((nil, nil))
            return
        }
        
        let thenBlock: @convention(block) (JSValue) -> Void = { [weak self] result in
            guard let self = self else { return }
            
            if softsub {
                if let jsonString = result.toString(),
                   let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    let moduleMetadata = self.context.objectForKeyedSubscript("module")?.objectForKeyedSubscript("metadata")
                    let isMultiStream = moduleMetadata?.objectForKeyedSubscript("multiStream")?.toBool() == true
                    let isMultiSubs = moduleMetadata?.objectForKeyedSubscript("multiSubs")?.toBool() == true
                    
                    var streamUrls: [String]?
                    if isMultiStream, let streamsArray = json["streams"] as? [String] {
                        streamUrls = streamsArray
                        Logger.shared.log("Found \(streamsArray.count) streams", type: "Stream")
                    } else if let streamUrl = json["stream"] as? String {
                        streamUrls = [streamUrl]
                        Logger.shared.log("Found single stream", type: "Stream")
                    }
                    
                    var subtitleUrls: [String]?
                    if isMultiSubs, let subsArray = json["subtitles"] as? [String] {
                        subtitleUrls = subsArray
                        Logger.shared.log("Found \(subsArray.count) subtitle tracks", type: "Stream")
                    } else if let subtitleUrl = json["subtitles"] as? String {
                        subtitleUrls = [subtitleUrl]
                        Logger.shared.log("Found single subtitle track", type: "Stream")
                    }
                    
                    Logger.shared.log("Starting stream with \(streamUrls?.count ?? 0) sources and \(subtitleUrls?.count ?? 0) subtitles", type: "Stream")
                    DispatchQueue.main.async {
                        completion((streamUrls, subtitleUrls))
                    }
                } else {
                    Logger.shared.log("Failed to parse softsub JSON in JS", type: "Error")
                    DispatchQueue.main.async {
                        completion((nil, nil))
                    }
                }
            } else {
                let moduleMetadata = self.context.objectForKeyedSubscript("module")?.objectForKeyedSubscript("metadata")
                let isMultiStream = moduleMetadata?.objectForKeyedSubscript("multiStream")?.toBool() == true
                
                if isMultiStream {
                    if let jsonString = result.toString(),
                       let data = jsonString.data(using: .utf8),
                       let streamsArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [String] {
                        Logger.shared.log("Starting multi-stream with \(streamsArray.count) sources", type: "Stream")
                        DispatchQueue.main.async { completion((streamsArray, nil)) }
                    } else {
                        Logger.shared.log("Failed to parse multi-stream JSON array", type: "Error")
                        DispatchQueue.main.async { completion((nil, nil)) }
                    }
                } else {
                    let streamUrl = result.toString()
                    Logger.shared.log("Starting stream from: \(streamUrl ?? "nil")", type: "Stream")
                    DispatchQueue.main.async {
                        completion((streamUrl != nil ? [streamUrl!] : nil, nil))
                    }
                }
            }
        }
        
        let catchBlock: @convention(block) (JSValue) -> Void = { error in
            Logger.shared.log("Promise rejected: \(String(describing: error.toString()))", type: "Error")
            DispatchQueue.main.async {
                completion((nil, nil))
            }
        }
        
        let thenFunction = JSValue(object: thenBlock, in: context)
        let catchFunction = JSValue(object: catchBlock, in: context)
        
        promise.invokeMethod("then", withArguments: [thenFunction as Any])
        promise.invokeMethod("catch", withArguments: [catchFunction as Any])
    }
    
    func fetchStreamUrlJSSecond(episodeUrl: String, softsub: Bool = false, completion: @escaping ((streams: [String]?, subtitles: [String]?)) -> Void) {
        let url = URL(string: episodeUrl)!
        let task = URLSession.custom.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.shared.log("URLSession error: \(error.localizedDescription)", type: "Error")
                DispatchQueue.main.async { completion((nil, nil)) }
                return
            }
            
            guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                Logger.shared.log("Failed to fetch HTML data", type: "Error")
                DispatchQueue.main.async { completion((nil, nil)) }
                return
            }
            
            DispatchQueue.main.async {
                if let exception = self.context.exception {
                    Logger.shared.log("JavaScript exception: \(exception)", type: "Error")
                    completion((nil, nil))
                    return
                }
                
                guard let extractStreamUrlFunction = self.context.objectForKeyedSubscript("extractStreamUrl") else {
                    Logger.shared.log("No JavaScript function extractStreamUrl found", type: "Error")
                    completion((nil, nil))
                    return
                }
                
                let promiseValue = extractStreamUrlFunction.call(withArguments: [htmlString])
                guard let promise = promiseValue else {
                    Logger.shared.log("extractStreamUrl did not return a Promise", type: "Error")
                    completion((nil, nil))
                    return
                }
                
                let thenBlock: @convention(block) (JSValue) -> Void = { [weak self] result in
                    guard let self = self else { return }
                    
                    if softsub {
                        if let jsonString = result.toString(),
                           let data = jsonString.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            let moduleMetadata = self.context.objectForKeyedSubscript("module")?.objectForKeyedSubscript("metadata")
                            let isMultiStream = moduleMetadata?.objectForKeyedSubscript("multiStream")?.toBool() == true
                            let isMultiSubs = moduleMetadata?.objectForKeyedSubscript("multiSubs")?.toBool() == true
                            
                            var streamUrls: [String]?
                            if isMultiStream, let streamsArray = json["streams"] as? [String] {
                                streamUrls = streamsArray
                                Logger.shared.log("Found \(streamsArray.count) streams", type: "Stream")
                            } else if let streamUrl = json["stream"] as? String {
                                streamUrls = [streamUrl]
                                Logger.shared.log("Found single stream", type: "Stream")
                            }
                            
                            var subtitleUrls: [String]?
                            if isMultiSubs, let subsArray = json["subtitles"] as? [String] {
                                subtitleUrls = subsArray
                                Logger.shared.log("Found \(subsArray.count) subtitle tracks", type: "Stream")
                            } else if let subtitleUrl = json["subtitles"] as? String {
                                subtitleUrls = [subtitleUrl]
                                Logger.shared.log("Found single subtitle track", type: "Stream")
                            }
                            
                            Logger.shared.log("Starting stream with \(streamUrls?.count ?? 0) sources and \(subtitleUrls?.count ?? 0) subtitles", type: "Stream")
                            DispatchQueue.main.async {
                                completion((streamUrls, subtitleUrls))
                            }
                        } else {
                            Logger.shared.log("Failed to parse softsub JSON in JSSecond", type: "Error")
                            DispatchQueue.main.async {
                                completion((nil, nil))
                            }
                        }
                    } else {
                        let moduleMetadata = self.context.objectForKeyedSubscript("module")?.objectForKeyedSubscript("metadata")
                        let isMultiStream = moduleMetadata?.objectForKeyedSubscript("multiStream")?.toBool() == true
                        
                        if isMultiStream {
                            if let jsonString = result.toString(),
                               let data = jsonString.data(using: .utf8),
                               let streamsArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [String] {
                                Logger.shared.log("Starting multi-stream with \(streamsArray.count) sources", type: "Stream")
                                DispatchQueue.main.async { completion((streamsArray, nil)) }
                            } else {
                                Logger.shared.log("Failed to parse multi-stream JSON array", type: "Error")
                                DispatchQueue.main.async { completion((nil, nil)) }
                            }
                        } else {
                            let streamUrl = result.toString()
                            Logger.shared.log("Starting stream from: \(streamUrl ?? "nil")", type: "Stream")
                            DispatchQueue.main.async {
                                completion((streamUrl != nil ? [streamUrl!] : nil, nil))
                            }
                        }
                    }
                }
                
                let catchBlock: @convention(block) (JSValue) -> Void = { error in
                    Logger.shared.log("Promise rejected: \(String(describing: error.toString()))", type: "Error")
                    DispatchQueue.main.async {
                        completion((nil, nil))
                    }
                }
                
                let thenFunction = JSValue(object: thenBlock, in: self.context)
                let catchFunction = JSValue(object: catchBlock, in: self.context)
                
                promise.invokeMethod("then", withArguments: [thenFunction as Any])
                promise.invokeMethod("catch", withArguments: [catchFunction as Any])
            }
        }
        task.resume()
    }
}
