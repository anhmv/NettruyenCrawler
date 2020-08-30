//
//  MangaFetch.swift
//  NettruyenCrawler
//
//  Created by Mac Van Anh on 8/29/20.
//

import Foundation
import SwiftSoup

public struct Fetch {
    let url: URL

    init(_ url: URL) {
        self.url = url
    }

    init(_ url: String) {
        self.url = URL(string: url)!
    }

    public func document() throws -> SwiftSoup.Document? {
        guard let result = try get() else {
            return nil
        }

        guard let html = String(bytes: result, encoding: .utf8) else {
            return nil
        }

        return try SwiftSoup.parse(html)
    }

    public func get(with referer: String? = nil) throws -> Data? {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?

        var request = URLRequest(url: url)

        if let referer = referer {
            request.setValue(referer, forHTTPHeaderField: "referer")
        }

        let task = session.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }

            guard let responseData = data else {
                return
            }

            result = responseData

            semaphore.signal()
        }

        task.resume()
        semaphore.wait()

        return result
    }
}

extension MangaSummary {
    public static func fetch(from url: String) throws -> MangaSummary? {
        return try fetch(from: URL(string: url)!)
    }

    public static func fetch(from url: URL) throws -> MangaSummary? {
        guard let document = try Fetch(url).document() else {
            return nil
        }

        let name = try document.select("#item-detail .title-detail").text()
        let originalName = try document.select("#item-detail .other-name").text()
        let author = try document.select("#item-detail .author .col-xs-8").text()

        let chapterElements = try document.select(".list-chapter .row:not(.heading)")
        let chapters: [ChapterSummary] = try chapterElements.map {
            let name = try $0.select(".chapter a").text()
            let url = try $0.select(".chapter a").attr("href")
            let lastUpdated = try $0.select(".col-xs-4").text()
            let view = try $0.select(".col-xs-3").text()

            return ChapterSummary(name: name, url: url, lastUpdated: lastUpdated, view: view)
        }

        return MangaSummary(name: name, originalName: originalName, author: author, chapters: chapters.reversed())
    }
}

extension ChapterSummary {
    public func fetch() throws -> ChapterDetails? {
        guard let document = try Fetch(self.url).document() else {
            return nil
        }

        let pages: Elements = try document.select(".page-chapter")
        let imageURLs = try pages.map {
            try $0.select("img").attr("src")
        }

        return ChapterDetails(name: name, url: url, imageURLs: imageURLs)
    }
}

extension ChapterDetails {
    public func save(in folder: URL) throws {
        try imageURLs.forEach {
            let referer = url
            guard let data = try Fetch($0).get(with: referer) else {
                return
            }
            let fileName = URL(string: $0)!.lastPathComponent
            let filePath = folder.appendingPathComponent(fileName)

            print("Saving... \($0) -> \(folder.path)")

            try data.write(to: filePath)
        }
    }
}
