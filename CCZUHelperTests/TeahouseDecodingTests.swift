//
//  TeahouseDecodingTests.swift
//  CCZUHelperTests
//
//  Created by Codex on 2026/3/14.
//

import XCTest
@testable import CCZUHelper

final class TeahouseDecodingTests: XCTestCase {
    func testFlexibleDateDecoderAcceptsSupabaseTimestamps() throws {
        struct Payload: Decodable {
            let createdAt: Date

            enum CodingKeys: String, CodingKey {
                case createdAt = "created_at"
            }
        }

        let samples: [(raw: String, expected: TimeInterval)] = [
            ("2026-03-14T08:30:45+00:00", 1_773_483_045),
            ("2026-03-14T08:30:45.123456+00:00", 1_773_483_045.123),
            ("2026-03-14T08:30:45.9Z", 1_773_483_045.9)
        ]

        for sample in samples {
            let data = Data("{\"created_at\":\"\(sample.raw)\"}".utf8)
            let payload = try TeahouseDecoding.decode(Payload.self, from: data)
            XCTAssertEqual(payload.createdAt.timeIntervalSince1970, sample.expected, accuracy: 0.001)
        }
    }
}
