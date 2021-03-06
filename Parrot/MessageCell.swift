import Foundation
import AppKit
import Mocha
import MochaUI
import AddressBook
import protocol ParrotServiceExtension.Message

/* TODO: Use NSPanGestureRecognizer or Force Touch to expand links. */

public class MessageCell: NSCollectionViewItem, NSTextViewDelegate {
    
    private var token: Subscription? = nil
    
    private lazy var photoView: NSImageView = {
        let v = NSImageView().modernize(wantsLayer: true)
        v.allowsCutCopyPaste = false
        v.isEditable = false
        v.animates = true
        return v
    }()
    
    private lazy var textLabel: ExtendedTextView = {
        let v = ExtendedTextView().modernize(wantsLayer: true)
        v.isEditable = false
        v.isSelectable = true
        v.drawsBackground = false
        v.backgroundColor = NSColor.clear
        v.textColor = NSColor.labelColor
        v.textContainerInset = NSSize(width: 4, height: 4)
        
        //v.setContentCompressionResistancePriority(1000, for: .vertical)
        //v.setContentHuggingPriority(1, for: .vertical)
        
        v.isAutomaticDataDetectionEnabled = true
        v.isAutomaticLinkDetectionEnabled = true
        v.isAutomaticTextReplacementEnabled = true
        
        v.delegate = self
        return v
    }()
    
	private var orientation: NSUserInterfaceLayoutDirection = .rightToLeft
    
    // Constraint setup here.
    public override func loadView() {
        self.view = NSVibrantView()
        self.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.wantsLayer = true
        self.token = AutoSubscription(from: nil, kind: Notification.Name("com.avaidyam.Parrot.UpdateColors")) { _ in
            self.setColors()
        }
        
        self.view.add(subviews: [self.photoView, self.textLabel])
        
        // Install constraints.
        self.photoView.left == self.view.left + 8.0
        self.photoView.bottom == self.view.bottom - 4.0
        self.photoView.height == 24.0
        self.photoView.width == 24.0
        self.textLabel.left == self.photoView.right + 8.0
        self.textLabel.right == self.view.right - 8.0
        self.textLabel.top == self.view.top + 4.0
        self.textLabel.bottom == self.view.bottom - 4.0
        
        // So, since the photoView can be hidden (height = 0), we should manually
        // declare the height minimum constraint here.
        self.textLabel.height >= 24.0 /* photoView.height */
    }
    
    deinit {
        self.token = nil
    }
    
	/// Upon assignment of the represented object, configure the subview contents.
	public override var representedObject: Any? {
        didSet {
            guard let b = self.representedObject as? EventStreamItemBundle else { return }
            guard let o = b.current as? Message else { return }
			
			let user = o.sender
            self.orientation = o.sender!.me ? .rightToLeft : .leftToRight // FIXME
			//self.color = o.color
			self.textLabel.string = o.text as String
			self.textLabel.toolTip = "\((o.timestamp /*?? .origin*/).fullString())"
			self.photoView.image = user!.image
			//self.photoView?.toolTip = o.caption
            
            // Hide your own icon and hide the icon of a repeating message.
            self.photoView.isHidden = /*(o.sender?.me ?? false) || */(b.previous?.sender?.identifier == o.sender?.identifier)
            //self.textLabel.alignment = (o.sender?.me ?? false) ? .right : .left
            
            // Enable automatic links and data detectors.
            self.textLabel.isEditable = true
            self.textLabel.checkTextInDocument(nil)
            self.textLabel.isEditable = false
            
            let text = self.textLabel
            let appearance: NSAppearance = self.view.appearance ?? NSAppearance.current
            text.textColor = NSColor.labelColor
            //self.setColors()
            
            // NSTextView doesn't automatically change its text color when the
            // backing view's appearance changes, so we need to set it each time.
            // In addition, make sure links aren't blue as usual.
            // Also, expand the text size if it's purely emoji.
            text.font = NSFont.systemFont(ofSize: 12.0 * (text.string.isEmoji ? 4 : 1))
            text.invalidateIntrinsicContentSize()
            
            text.typingAttributes = [
                NSAttributedStringKey.foregroundColor: text.textColor!,
                NSAttributedStringKey.font: text.font!
            ]
            text.linkTextAttributes = [
                NSAttributedStringKey.foregroundColor: NSColor.labelColor,
                NSAttributedStringKey.cursor: NSCursor.pointingHand,
                NSAttributedStringKey.underlineStyle: 1,
            ]
            text.selectedTextAttributes = [
                NSAttributedStringKey.backgroundColor: NSColor.lightOverlay(forAppearance: appearance),
                NSAttributedStringKey.foregroundColor: NSColor.labelColor,
                NSAttributedStringKey.underlineStyle: 0,
            ]
            text.markedTextAttributes = [
                NSAttributedStringKey.backgroundColor: NSColor.lightOverlay(forAppearance: appearance),
                NSAttributedStringKey.foregroundColor: NSColor.labelColor,
                NSAttributedStringKey.underlineStyle: 0,
            ]
		}
	}
    
    private func setColors() {
        guard let b = self.representedObject as? EventStreamItemBundle else { return }
        guard let o = b.current as? Message else { return }
        let text = self.textLabel
        
        // Only clip the text if the text isn't purely Emoji.
        if !text.string.isEmoji {
            var color = NSColor.darkOverlay(forAppearance: self.view.effectiveAppearance)//NSColor.secondaryLabelColor
            let setting = "com.avaidyam.Parrot.Conversation" + ((o.sender?.me ?? false) ? "OutgoingColor" : "IncomingColor")
            if  let q = Settings[setting] as? Data,
                let c = NSUnarchiver.unarchiveObject(with: q) as? NSColor,
                c.alphaComponent > 0.0 {
                color = c
                
                // This automatically adjusts labelColor to the right XOR mask.
                text.appearance = color.isLight() ? .light : .dark
            } else {
                text.appearance = self.view.effectiveAppearance//self.appearance
            }
            text.layer?.backgroundColor = color.cgColor
        } else {
            text.layer?.backgroundColor = #colorLiteral(red: 0.9999960065, green: 1, blue: 1, alpha: 0).cgColor
        }
    }
    
    public override func viewWillAppear() {
        self.setColors()
    }
    
	/// Allows the circle crop and masking to dynamically change.
	public override func viewDidLayout() {
		if let layer = self.photoView.layer {
			layer.masksToBounds = true
			layer.cornerRadius = layer.bounds.width / 2.0
		}
        
        self.textLabel.layer?.masksToBounds = true
        self.textLabel.layer?.cornerRadius = 10.0
	}
    
    /// If we're right-clicked outside of the text view, just popUp the textView's menu.
    /// Note: make sure we SELECT ALL and then DESELECT ALL after the popUp menu.
    public func menu(for event: NSEvent) -> NSMenu? {
        self.textLabel.selectAll(nil)
        return self.textLabel.menu(for: event)
        //self.textLabel?.setSelectedRange(NSRange())
    }
    
    /// Modify the textView menu to display the message's time.
    public func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        menu.insertItem(NSMenuItem(title: "Sent at " + (self.textLabel.toolTip ?? ""), action: nil, keyEquivalent: ""), at: 0)
        menu.insertItem(NSMenuItem.separator(), at: 1)
        return menu
    }
    
    /*
    private static var _text: ExtendedTextView = {
        let v = ExtendedTextView()
        v.isEditable = false
        v.isSelectable = true
        v.textContainerInset = NSSize(width: 4, height: 4)
        return v
    }()
    
    // Given a string, a font size, and a base width, return the measured height of the cell.
    public static func measure(_ string: String, _ width: CGFloat) -> Double {
        MessageCell._text.frame = NSRect(x: 0, y: 0, width: width - 48.0 /* padding + image */, height: CGFloat.greatestFiniteMagnitude)
        MessageCell._text.string = string
        MessageCell._text.font = NSFont.systemFont(ofSize: 12.0 * (string.isEmoji ? 4 : 1))
        let h = Double(MessageCell._text.layoutRect().size.height)
        return ((h < 24.0) ? 24.0 : h) + 8.0 /* add padding to max(h, 24) */
    }
    */
    
    static func lineSize(_ string: String, _ font: NSFont, _ width: CGFloat) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = font.leading
        let attr = NSAttributedString(string: string, attributes: [
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.paragraphStyle: paragraphStyle
        ])
        
        let framesetter = CTFramesetterCreateWithAttributedString(attr)
        let constraints = NSSize(width: width, height: .greatestFiniteMagnitude)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), nil, constraints, nil)
        return size.height
    }
    
    // Given a string, a font size, and a base width, return the measured height of the cell.
    public static func measure(_ string: String, _ width: CGFloat) -> CGFloat {
        let h = lineSize(string,
                         NSFont.systemFont(ofSize: 12.0 * (string.isEmoji ? 4 : 1)),
                         width - (24.0 + 24.0 + 16.0)) + 8.0
        return ((h < 24.0) ? 24.0 : h) + 8.0 /* add padding to max(h, 24) */
    }
}
