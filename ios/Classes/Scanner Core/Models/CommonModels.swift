//
//  CommonModels.swift
//  credit_card_scanner
//
//  Created by Abhinav Kumar on 12/02/21.
//

import Foundation

class ScanFilterResult {
    private var visionText: RecognizedText
    private var textBlockIndex: Int
    private var textBlock: RecognizedTextBlock
    private var data: ScanResultData
    
    init(visionText: RecognizedText, textBlockIndex: Int, textBlock: RecognizedTextBlock, data: ScanResultData) {
        self.visionText = visionText
        self.textBlockIndex = textBlockIndex
        self.textBlock = textBlock
        self.data = data
    }
}

class ScanResultData {
    var data: String
    var elementType: CardElementType
    
    init(data: String, elementType: CardElementType) {
        self.data = data
        self.elementType = elementType
    }
}

enum CardElementType {
    case cardNumber
    case expiryDate
    case cardHolderName
}

class CardNumberScanResult : ScanFilterResult {
    var visionText: RecognizedText
    var textBlockIndex: Int
    var textBlock: RecognizedTextBlock
    var cardNumber: String
    
    init(visionText: RecognizedText, textBlockIndex: Int, textBlock: RecognizedTextBlock, cardNumber: String){
        self.visionText = visionText
        self.textBlockIndex = textBlockIndex
        self.textBlock = textBlock
        self.cardNumber = cardNumber
        
        super.init(
            visionText: visionText,
            textBlockIndex: textBlockIndex,
            textBlock: textBlock,
            data: ScanResultData(data: cardNumber, elementType: CardElementType.cardNumber)
        )
        
    }
}

class ExpiryDateScanResult : ScanFilterResult {
    var visionText: RecognizedText
    var textBlockIndex: Int
    var textBlock: RecognizedTextBlock
    var expiryDate: String
    
    init(visionText: RecognizedText, textBlockIndex: Int, textBlock: RecognizedTextBlock, expiryDate: String) {
        self.visionText = visionText
        self.textBlockIndex = textBlockIndex
        self.textBlock = textBlock
        self.expiryDate = expiryDate
        
        super.init(visionText: visionText, textBlockIndex: textBlockIndex, textBlock: textBlock, data: ScanResultData(data: expiryDate, elementType: CardElementType.expiryDate))
    }
}

class CardHolderNameScanResult : ScanFilterResult {
    var visionText: RecognizedText
    var textBlockIndex: Int
    var textBlock: RecognizedTextBlock
    var cardHolderName: String
    
    init(visionText: RecognizedText, textBlockIndex: Int, textBlock: RecognizedTextBlock, cardHolderName: String){
        self.visionText = visionText
        self.textBlockIndex = textBlockIndex
        self.textBlock = textBlock
        self.cardHolderName = cardHolderName
        
        super.init(visionText: visionText, textBlockIndex: textBlockIndex, textBlock: textBlock, data: ScanResultData(data: cardHolderName, elementType: CardElementType.cardHolderName))
    }
}

protocol ScanFilter {
    func filter() -> ScanFilterResult?
}

enum CardHolderNameScanPositions: String {
    case belowCardNumber = "belowCardNumber"
    case aboveCardNumber = "aboveCardNumber"
    
    init?(value: String) {
        switch value {
        case "belowCardNumber":
            self = .belowCardNumber
        case "aboveCardNumber":
            self = .aboveCardNumber
        default:
            return nil
        }
    }
}

extension String {
    var isNotEmpty: Bool {
        return !isEmpty
    }
    
    var sanitized: String {
        let newLineRemoved = replacingOccurrences(of: "\n", with: "")
        let newLineAndSpacesRemoved = newLineRemoved.replacingOccurrences(of: " ", with: "")
        return newLineAndSpacesRemoved
    }
    
    var cardNumberSized: String {
        return ((self as NSString).substring(to: count >= 16 ? 16 : count) as String)
    }
}


extension Dictionary where Key == String, Value == Int {
    var mostFrequentData: String? {
        return self.sorted { (first, second) -> Bool in
            first.value > second.value
        }.first?.key
    }
}
