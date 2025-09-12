import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Set minimum window size for better UI experience
    self.minSize = NSSize(width: 900, height: 700)
    
    // Set default window size
    if windowFrame.width < 1200 || windowFrame.height < 800 {
      let newFrame = NSRect(x: windowFrame.origin.x, y: windowFrame.origin.y, width: 1200, height: 800)
      self.setFrame(newFrame, display: true)
    }
    
    // Center the window
    self.center()
    
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
