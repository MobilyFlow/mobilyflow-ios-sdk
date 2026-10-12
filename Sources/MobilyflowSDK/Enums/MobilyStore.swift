import Foundation

@objc public class MobilyStore: NSObject {
	@objc public static let APP_STORE = "app-store"
	@objc public static let PLAY_STORE = "play-store"
	
	@objc public static let values = [APP_STORE,PLAY_STORE]
	
	override private init() {}
	
	/// Returns nil for nil or an unknown store (new stores may be added backend-side; never crash on them).
	@objc public static func parse(_ value: String?) -> String? {
		guard let value = value else { return nil }
		guard values.contains(value) else {
			Logger.w("Unknown MobilyStore: \(value)")
			return nil
		}
		return value
	}
}
