import Foundation

enum DocumentError: Error, Equatable {
	case notAPackage
	case missingManifest
	case unsupportedVersion(Int)
}
