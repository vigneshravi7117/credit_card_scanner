//
//  RecognizedText.swift
//  credit_card_scanner
//

import Foundation
import Vision

// Text read from one camera frame, shaped the way the scan filters walk it:
// one block per printed row, top to bottom, holding that row's pieces of
// text as lines, left to right.
struct RecognizedText {
    let blocks: [RecognizedTextBlock]

    init(observations: [VNRecognizedTextObservation]) {
        // Vision's bounding boxes have their origin at the bottom-left, so a
        // larger midY is higher up on the card.
        let topToBottom = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        var rows: [[VNRecognizedTextObservation]] = []
        for observation in topToBottom {
            if let rowStart = rows.last?.first,
               RecognizedText.isOnSameRow(observation.boundingBox, rowStart.boundingBox) {
                rows[rows.count - 1].append(observation)
            } else {
                rows.append([observation])
            }
        }

        blocks = rows.compactMap { row in
            let lines = row
                .sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first }
                .map { RecognizedTextLine(text: $0.string) }
            return lines.isEmpty ? nil : RecognizedTextBlock(lines: lines)
        }
    }

    private static func isOnSameRow(_ first: CGRect, _ second: CGRect) -> Bool {
        return abs(first.midY - second.midY) < min(first.height, second.height) / 2
    }
}

struct RecognizedTextBlock {
    let lines: [RecognizedTextLine]

    var text: String {
        return lines.map { $0.text }.joined(separator: "\n")
    }
}

struct RecognizedTextLine {
    let text: String
}
