import Foundation
import Commander
import SwiftyTextTable

let userDefaultDownloadFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]

func download(_ chapter: ChapterSummary, saveIn folder: URL) throws {
    let chapterDetails = try chapter.fetch()!

    let chapterFolder = folder.appendingPathComponent(chapter.name)
    try FileManager.default.createDirectory(at: chapterFolder,
                                            withIntermediateDirectories: true,
                                            attributes: nil)

    try chapterDetails.save(in: chapterFolder)
}

command(
    Argument<String>("url",
                     description: "Nettruyen Manga URL (e.g. http://www.nettruyen.com/truyen-tranh/thanh-guom-diet-quy-12523)"),
    Option("output", default: userDefaultDownloadFolder.path, description: "Output folder, default: User Downloads folder")
) { url, output in
    print("Connecting to \(url)...")
    let manga = try MangaSummary.fetch(from: url)!

    let colIndex = TextTableColumn(header: "Index")
    let colName = TextTableColumn(header: "Name")
    let colLastUpdated = TextTableColumn(header: "Last Updated")
    let colViewed = TextTableColumn(header: "Viewed")

    var table = TextTable(columns: [colIndex, colName, colLastUpdated, colViewed])

    table.header = "\(manga.name) - \(manga.author)"
    table.addRows(values: manga.chapters.enumerated().map { (index, elem) in
        return [index + 1, elem.name, elem.lastUpdated, elem.view]
    })

    print(table.render())

    print("Please enter an index number to download or enter `all` to download the whole chapters: ", terminator: "")
    let downloadItem = readLine() ?? ""


    let downloadFolder = URL(fileURLWithPath: output).appendingPathComponent("\(manga.author) - \(manga.name)")


    switch downloadItem.lowercased() {
    case "all":
        try manga.chapters.forEach { chapter in
            try download(chapter, saveIn: downloadFolder)
        }
    case _:
        let chapterIndex = (Int(downloadItem) ?? 0) - 1

        guard chapterIndex >= 0 && chapterIndex < manga.chapters.count else {
            print("Invalid chapter index!")
            return
        }

        print("Downloading chapter \(downloadItem)...")
        try download(manga.chapters[chapterIndex], saveIn: downloadFolder)
    }

    print("Download completed.")
}.run()
