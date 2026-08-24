import Foundation

enum ImageCoderError: Error, Equatable {
	case unrecognizedFormat
	case decodeFailed
	case encodeFailed
}
