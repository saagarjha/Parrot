import Foundation

/**
Allows the use of a shorthand notification syntax:
	`Notifications.post("MyNote")`
Also has the benefit of not dealing with NSNotification.
*/

public typealias TokenObserver = NSObjectProtocol
public typealias Notification = (name: String, object: AnyObject?, userInfo: [NSObject: AnyObject]?)

// 99% of the time, you don't need to create your own notification center.
// Here's a quick alias for the default one, which is shorter to type.
public let Notifications = NSNotificationCenter.defaultCenter()

public extension NSNotificationCenter {
	
	public func post(name: String, object: AnyObject? = nil, userInfo: [NSObject: AnyObject]? = nil) {
		self.postNotificationName(name, object: object, userInfo: userInfo)
	}
	
	public func subscribe(name: String, block: (Notification -> Void)) -> TokenObserver {
		return self.addObserverForName(name, object: nil, queue: nil) { n in
			block((n.name, n.object, n.userInfo))
		}
	}
	
	public func unsubscribe(observer: AnyObject, name: String? = nil, object: AnyObject? = nil) {
		self.removeObserver(observer, name: name, object: object)
	}
	
	// Utility for subscribing multiple notifications at a time.
	public func subscribe(notifications: [String: (Notification -> Void)]) -> [TokenObserver] {
		return notifications.map {
			self.subscribe($0, block: $1)
		}
	}
	
	// Utility for unsubscribing multiple notifications at a time.
	public func unsubscribe(observer: AnyObject, _ names: [String]) {
		names.forEach {
			self.unsubscribe(observer, name: $0)
		}
	}
}

// Post a notification like so:  Notifications <- ("Test", self, ["a": 42])
// CAUTION: USE SPARINGLY! Makes little to no sense what's going on in code.
infix operator <- { associativity left precedence 160 }
func <- (inout left: NSNotificationCenter, right: String) {
	left.postNotificationName(right, object: nil, userInfo: nil)
}
func <- (inout left: NSNotificationCenter, right: Notification) {
	left.postNotificationName(right.name, object: right.object, userInfo: right.userInfo)
}
