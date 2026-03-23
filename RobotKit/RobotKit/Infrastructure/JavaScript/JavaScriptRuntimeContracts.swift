import Foundation

struct RuntimeBootInfo: Equatable {
    let engineNames: [String]
    let runtimeName: String
    let transport: String
}

struct RuntimeLoadInfo: Equatable {
    let boardID: String
    let programBytes: Int
    let demoID: String
}

struct RuntimeProjectLoadRequest: Encodable {
    let project: RobotProject
}

struct RuntimeFrameInfo: Equatable {
    let frame: Int
    let cycles: Int
}

struct RuntimePinEvent: Decodable, Equatable {
    let boardID: String
    let pin: String
    let value: Int
    let cycles: Int

    enum CodingKeys: String, CodingKey {
        case boardID = "boardId"
        case pin
        case value
        case cycles
    }
}

struct RuntimeSerialEvent: Decodable, Equatable {
    let text: String
    let baudRate: Int
}
