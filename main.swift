// edgeneon: an animated neon glow along the edges of the screen. The macOS
// menu bar is transparent, so a window placed underneath it shows through;
// the same window extends past the menu bar and fades out, and three more
// windows do the left, right and bottom edges.
// Build: swiftc -O main.swift -o edgeneon
import AppKit

// Replaced at build time with the CalVer string (see package.nix).
// Kept as "dev" so a plain `swiftc main.swift` still builds standalone.
let edgeneonVersion = "dev"

let usage = """
  usage: edgeneon [options]
    --colors <hex,...>  gradient colors (default: rainbow)
    --duration <sec>    how long to glow. 0 stays until killed (default: 0)
    --width <px>        how far the glow spills from the screen edge (default: 30)
    --saturation <0-1>  rainbow saturation. lower is more pastel (default: 0.45)
    --cycle <sec>       seconds for the colors to travel one full loop (default: 8)
    --blur <px>         how soft the glow is (default: 6)
    --opacity <0-1>     overall strength (default: 1)
    --fade <sec>        fade in and out time (default: 0.4)
    --version           print the version
    --help              print this help

  examples:
    edgeneon                                  rainbow, stays until killed
    edgeneon --colors 22c55e --duration 3     green for 3 seconds, e.g. on success
    edgeneon --colors eb3583,dddccc           crimson and white
    edgeneon --colors 8de0cd,bcc7e4,f699f2    mint, lavender and pink
  """
if CommandLine.arguments.contains("--help") {
  print(usage)
  exit(0)
}
if CommandLine.arguments.contains("--version") {
  print("edgeneon \(edgeneonVersion)")
  exit(0)
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("edgeneon: \(message)\n".utf8))
  exit(1)
}

func opt(_ name: String, _ fallback: Double) -> Double {
  guard let i = CommandLine.arguments.firstIndex(of: "--\(name)"),
    let value = CommandLine.arguments.dropFirst(i + 1).first.flatMap(Double.init)
  else { return fallback }
  return value
}

let duration = opt("duration", 0)
let spillWidth = opt("width", 30)
let saturation = opt("saturation", 0.45)
let cycleSeconds = opt("cycle", 8)
let blurRadius = opt("blur", 6)
let glowOpacity = Float(opt("opacity", 1))
let fadeSeconds = opt("fade", 0.4)

func hexColor(_ spec: Substring) -> CGColor? {
  var hex = spec.trimmingCharacters(in: .whitespaces)
  if hex.hasPrefix("#") { hex.removeFirst() }
  guard hex.count == 6, let v = UInt32(hex, radix: 16) else { return nil }
  return NSColor(
    srgbRed: CGFloat(v >> 16 & 0xff) / 255, green: CGFloat(v >> 8 & 0xff) / 255,
    blue: CGFloat(v & 0xff) / 255, alpha: 1
  ).cgColor
}

let palette: [CGColor] =
  if let i = CommandLine.arguments.firstIndex(of: "--colors"),
    let spec = CommandLine.arguments.dropFirst(i + 1).first
  {
    spec.split(separator: ",").map {
      guard let color = hexColor($0) else { fail("colors must be #rrggbb: \($0)") }
      return color
    }
  } else {
    stride(from: 0.0, to: 1.0, by: 1.0 / 6).map {
      NSColor(hue: $0, saturation: saturation, brightness: 1, alpha: 1).cgColor
    }
  }

if palette.isEmpty { fail("--colors needs at least one color") }

enum Edge: CaseIterable {
  /// The menu bar strip itself, drawn as its own window above the menu bar and
  /// blended into it. It cannot be drawn underneath: a notched display paints
  /// its menu bar opaquely, so nothing below the menu bar level shows through.
  /// Being above costs nothing, because no ordinary window may enter the strip.
  case menuBar
  case top, bottom, left, right

  var isHorizontal: Bool { self != .left && self != .right }

  var level: Int {
    self == .menuBar ? Int(CGWindowLevelForKey(.mainMenuWindow)) + 1 : -1
  }

  func frame(in screen: NSScreen) -> NSRect {
    let f = screen.frame
    let bar = f.maxY - screen.visibleFrame.maxY
    switch self {
    case .menuBar:
      return NSRect(x: f.minX, y: f.maxY - bar, width: f.width, height: bar)
    case .top:
      return NSRect(x: f.minX, y: f.maxY - bar - spillWidth, width: f.width, height: spillWidth)
    case .bottom:
      return NSRect(x: f.minX, y: f.minY, width: f.width, height: spillWidth)
    case .left:
      return NSRect(x: f.minX, y: f.minY, width: spillWidth, height: f.height)
    case .right:
      return NSRect(x: f.maxX - spillWidth, y: f.minY, width: spillWidth, height: f.height)
    }
  }

  /// Mask axis as (transparent end, opaque end): screen inwards to screen edge.
  /// The menu bar band fills its strip evenly and does not fade.
  var fadeAxis: (CGPoint, CGPoint)? {
    switch self {
    case .menuBar: nil
    case .top: (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1))
    case .bottom: (CGPoint(x: 0.5, y: 1), CGPoint(x: 0.5, y: 0))
    case .left: (CGPoint(x: 1, y: 0.5), CGPoint(x: 0, y: 0.5))
    case .right: (CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5))
    }
  }
}

final class NeonView: NSView {
  init(frame: NSRect, edge: Edge) {
    super.init(frame: frame)
    wantsLayer = true
    layerUsesCoreImageFilters = true
    layer?.masksToBounds = true

    let g = CAGradientLayer()
    g.colors = palette + palette + [palette[0]]
    g.opacity = glowOpacity
    g.filters = [CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": blurRadius])]
      .compactMap { $0 }

    // Two cycles of color scrolled by exactly one cycle, so the loop is seamless.
    // ponytail: each edge loops on its own, so colors do not line up at the
    //           corners. Fixing that means treating the perimeter as one
    //           gradient and giving each edge its share of phase and speed.
    let scroll = CABasicAnimation()
    if edge.isHorizontal {
      g.frame = CGRect(x: 0, y: -20, width: frame.width * 2, height: frame.height + 40)
      g.startPoint = CGPoint(x: 0, y: 0.5)
      g.endPoint = CGPoint(x: 1, y: 0.5)
      scroll.keyPath = "position.x"
      scroll.byValue = -frame.width
    } else {
      g.frame = CGRect(x: -20, y: 0, width: frame.width + 40, height: frame.height * 2)
      g.startPoint = CGPoint(x: 0.5, y: 0)
      g.endPoint = CGPoint(x: 0.5, y: 1)
      scroll.keyPath = "position.y"
      scroll.byValue = -frame.height
    }
    scroll.duration = cycleSeconds
    scroll.repeatCount = .infinity
    g.add(scroll, forKey: "scroll")
    layer?.addSublayer(g)

    // Recolor the menu bar rather than paint over it: colorBlendMode keeps the
    // luminance of whatever is beneath, so the menu titles, the Apple logo and
    // the status items stay exactly as legible as they were.
    guard let (clearPoint, solidPoint) = edge.fadeAxis else {
      layer?.compositingFilter = "colorBlendMode"
      return
    }

    // Opaque at the screen edge, fading to transparent towards the middle.
    let mask = CAGradientLayer()
    mask.frame = bounds
    mask.startPoint = clearPoint
    mask.endPoint = solidPoint
    mask.colors = [NSColor.clear, NSColor.black.withAlphaComponent(0.4), NSColor.black]
      .map(\.cgColor)
    mask.locations = [0, 0.5, 1].map { NSNumber(value: $0) }
    layer?.mask = mask
  }
  required init?(coder: NSCoder) { fatalError() }
}

final class NeonWindow: NSWindow {
  init(screen: NSScreen, edge: Edge) {
    super.init(
      contentRect: edge.frame(in: screen),
      styleMask: .borderless, backing: .buffered, defer: false)
    level = NSWindow.Level(rawValue: edge.level)
    collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    ignoresMouseEvents = true
    alphaValue = 0
    contentView = NeonView(frame: NSRect(origin: .zero, size: frame.size), edge: edge)
    orderFrontRegardless()
  }

  // AppKit would otherwise push the window down below the menu bar.
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    frameRect
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

var windows: [NeonWindow] = []
func fade(to alpha: CGFloat) {
  NSAnimationContext.runAnimationGroup {
    $0.duration = fadeSeconds
    for window in windows { window.animator().alphaValue = alpha }
  }
}
func rebuild() {
  for window in windows { window.orderOut(nil) }
  windows = NSScreen.screens.flatMap { screen in
    // A screen showing no menu bar (auto-hidden) gets no band.
    let hasMenuBar = screen.frame.maxY > screen.visibleFrame.maxY
    return Edge.allCases
      .filter { hasMenuBar || $0 != .menuBar }
      .map { NeonWindow(screen: screen, edge: $0) }
  }
  fade(to: 1)
}
rebuild()
NotificationCenter.default.addObserver(
  forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
) { _ in rebuild() }

if duration > 0 {
  // Exit on a timer, not on runAnimationGroup's completion handler: that
  // handler does not reliably fire for a window alphaValue animation, and the
  // process must exit no matter what.
  Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
    fade(to: 0)
    Timer.scheduledTimer(withTimeInterval: fadeSeconds, repeats: false) { _ in
      app.terminate(nil)
    }
  }
}

app.run()
