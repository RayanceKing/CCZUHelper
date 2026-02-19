//
//  CompetitionModels.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/19.
//

import Foundation

struct CompetitionListItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let url: String
    let publishDate: String
    let college: String
    let category: String
    let level: String?
    let deadline: String?
    let organizer: String?
}

struct CompetitionListDTO: Decodable {
    let id: Int?
    let title: String?
    let url: String?
    let publishDate: String?
    let college: String?
    let category: String?
    let level: String?
    let deadline: String?
    let organizer: String?

    var asListItem: CompetitionListItem {
        let fallbackSeed = (url ?? "") + (title ?? "") + (publishDate ?? "")
        let fallbackID = abs(fallbackSeed.hashValue)

        return CompetitionListItem(
            id: id ?? fallbackID,
            title: title ?? "-",
            url: url ?? "",
            publishDate: publishDate ?? "-",
            college: college ?? "-",
            category: category ?? "-",
            level: level,
            deadline: deadline,
            organizer: organizer
        )
    }
}

struct CompetitionDetailDTO: Decodable {
    let id: Int?
    let title: String?
    let url: String?
    let content: String?
    let publishDate: String?
    let crawlTime: String?
    let college: String?
    let category: String?
    let level: String?
    let deadline: String?
    let organizer: String?
}

struct CompetitionOptionDTO: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let text = try? single.decode(String.self) {
            value = text
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        for key in ["name", "value", "label", "title"] {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            if let decoded = try container.decodeIfPresent(String.self, forKey: codingKey) {
                value = decoded
                return
            }
        }

        value = ""
    }
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
