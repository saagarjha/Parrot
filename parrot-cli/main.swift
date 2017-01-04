import Hangouts

let runes: [UInt32] = [
    0x20,   // ' '
    0x2591, // '░'
    0x2592, // '▒'
    0x2593, // '▓'
    0x2588, // '█'
]

// TODO FIXME
public struct Window {
    
    public var frame: Rect
    public var foreground: Attributes
    public var background: Attributes
    
    public init(frame: Rect, foreground: Attributes, background: Attributes) {
        self.frame = frame
        self.foreground = foreground
        self.background = background
    }
    
    public func draw() {
        
    }
}

func updateHelp() {
    let lastY = Termbox.size.height - 1
    let content = [
        "Drawing [\(runes[4])]",
        "Press other character to change",
        "Use mouse to draw",
        "Press 'q' to quit"
    ].joined(separator: " ┊ ")
    let count = Termbox.size.width - content.unicodeScalars.count
    let filler = String(repeating: " ", count: count > 0 ? count : 0)
    (content + filler).draw(at: Point(x: 0, y: lastY), foreground: .white, background: .blue)
}

// Block CTRL-C in favor of our `q` action.
signal(SIGTERM) { _ in }
signal(SIGINT) { _ in }

Termbox.app(inputMode: [.esc, .mouse]) {
    
    // We let user select which character to paint with.
    var selectedRune: Int = 0 {
        didSet {
            updateHelp()
        }
    }
    updateHelp()
    
    // `put` only update the content in an internal buffer. We have to call
    // `present` each time we are satified with changes we made in the buffer so
    // that the terminal will actually display it.
    Termbox.refresh()
    outer: while true {
        guard let event = Event.poll() else { continue }
        
        // There are several types of events. User pressed key for a character,
        // a control key, or clicked with a mouse. Each type of event comes with
        // different kinds of data. For example, mouse click comes with
        // a position while character event comes with the character.
        switch event {
        case let .key(_, value) where value == .space:
            if selectedRune >= runes.count - 1 {
                selectedRune = 0
            } else {
                selectedRune += 1
            }
        case let .key(_, value) where value == .ctrlC:
            break outer
        case let .key(_, value) where value == .ctrlZ:
            Termbox.clear()
            updateHelp()
            
        case let .mouse(x, y) where y < Int32(Termbox.size.height - 1):
            // As promised, mouse clicks comes with an x and a y position. We
            // draw the selected character at this position.
            Termbox.put(x: x, y: y, character: UnicodeScalar(runes[selectedRune])!,
                        foreground: .red)
        
        case .resize(_, _):
            Termbox.refresh()
        default:
            continue
        }
        Termbox.refresh()
    }
}


/*
let sem = DispatchSemaphore(value: 0)
print("Initializing...")

// Authenticate and initialize the Hangouts client.
// Build the user and conversation lists.
var client: Client!
var userList: UserList!
var conversationList: ConversationList!

AuthenticatorCLI.authenticateClient {
	client = Client(configuration: $0)
	
	client.buildUserConversationList {
		userList = $0; conversationList = $1
		print("Obtained userList \(userList) and conversationList! \(conversationList)")
		sem.signal()
	}
}
_ = sem.wait(timeout: DispatchTime.distantFuture)
print("Continuing...")

print(conversationList.all_conversations.map { $0.conversation.conversationId })
*/
