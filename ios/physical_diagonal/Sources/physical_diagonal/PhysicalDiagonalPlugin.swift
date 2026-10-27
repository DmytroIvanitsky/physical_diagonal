import Flutter
import UIKit

public class PhysicalDiagonalPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "physical_diagonal", binaryMessenger: registrar.messenger())
    let instance = PhysicalDiagonalPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getMetrics":
      let metrics = currentMetrics()
      result([
        "deviceDiagonal": metrics.device,
        "windowDiagonal": metrics.window,
        "screenLogicalDiagonal": metrics.screenLogicalDiagonal,
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// device: physical diagonal of the hardware screen, in inches — from the
  /// static identifier table, falling back to userInterfaceIdiom for
  /// unrecognized machine identifiers (never reports "phone" for an
  /// unrecognized iPad).
  /// window: physical diagonal of the current app window, in inches.
  /// screenLogicalDiagonal: diagonal of the full screen bounds tied to the
  /// active UIWindowScene, in points. Passed to Dart so window-resize
  /// tracking (Split View / Stage Manager) can compute a logical-diagonal
  /// ratio client-side, without a hardcoded points-per-inch constant.
  private func currentMetrics() -> (device: Double, window: Double, screenLogicalDiagonal: Double) {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let bestScene = scenes.first(where: { $0.activationState == .foregroundActive })
      ?? scenes.first(where: { $0.activationState == .foregroundInactive })
      ?? scenes.first(where: { $0.activationState == .unattached })
      ?? scenes.first(where: { $0.activationState == .background })

    let screenSize: CGSize
    let windowSize: CGSize

    if let scene = bestScene {
      screenSize = scene.screen.bounds.size
      windowSize = scene.coordinateSpace.bounds.size
    } else {
      screenSize = UIScreen.main.bounds.size
      windowSize = screenSize
    }

    let device = hardwareDiagonalInches(screenSize: screenSize)
    let screenLogicalDiagonal = diagonal(of: screenSize)
    let windowLogicalDiagonal = diagonal(of: windowSize)

    guard screenLogicalDiagonal > 0 else {
      return (device, device, 0)
    }

    let ratio = windowLogicalDiagonal > 0 ? (windowLogicalDiagonal / screenLogicalDiagonal) : 1.0
    return (device, device * ratio, screenLogicalDiagonal)
  }

  private func diagonal(of size: CGSize) -> Double {
    return (pow(size.width, 2) + pow(size.height, 2)).squareRoot()
  }

  private func machineIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let rawIdentifier = machineMirror.children.reduce("") { partial, element in
      guard let value = element.value as? Int8, value != 0 else { return partial }
      return partial + String(UnicodeScalar(UInt8(value)))
    }

    if rawIdentifier == "x86_64" || rawIdentifier == "arm64",
       let simIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
      return simIdentifier
    }
    return rawIdentifier
  }

  /// Static machine-identifier table grouped by physical screen diagonal.
  /// Unrecognized identifiers fall back to userInterfaceIdiom (phone vs pad).
  private func hardwareDiagonalInches(screenSize: CGSize) -> Double {
    let identifier = machineIdentifier()

    switch identifier {
    // =========================================================================
    // iPhone
    // =========================================================================

    // --- 4.7" (SE 2nd & 3rd gen) ---
    case "iPhone12,8", "iPhone14,6":
      return 4.7

    // --- 5.4" (12 mini, 13 mini) ---
    case "iPhone13,1", "iPhone14,4":
      return 5.4

    // --- 6.1" (12/12 Pro, 13/13 Pro, 14/14 Pro, 15/15 Pro, 16, 16e, 17e) ---
    case "iPhone13,2", "iPhone13,3",
         "iPhone14,2", "iPhone14,5", "iPhone14,7",
         "iPhone15,2", "iPhone15,4",
         "iPhone16,1",
         "iPhone17,3", "iPhone17,5",
         "iPhone18,5":
      return 6.1

    // --- 6.3" (16 Pro, 17, 17 Pro, 18, 18 Pro) ---
    case "iPhone17,1",
         "iPhone18,1", "iPhone18,3",
         "iPhone19,1", "iPhone19,2":
      return 6.3

    // --- 6.5" (iPhone Air) ---
    case "iPhone18,4":
      return 6.5

    // --- 6.7" (12/13/14/15 Pro Max, 14/15/16 Plus) ---
    case "iPhone13,4",
         "iPhone14,3", "iPhone14,8",
         "iPhone15,3", "iPhone15,5",
         "iPhone16,2",
         "iPhone17,4":
      return 6.7

    // --- 6.9" (16 Pro Max, 17 Pro Max, 18 Pro Max) ---
    case "iPhone17,2", "iPhone18,2", "iPhone19,3":
      return 6.9

    // --- iPhone Duo (5.4" outer @ 466x678pt / 7.6" inner @ 626x890pt) ---
    case "iPhone19,4":
      let minSide = min(screenSize.width, screenSize.height)
      return minSide > 550.0 ? 7.6 : 5.4

    // =========================================================================
    // iPad
    // =========================================================================

    // --- 8.3" (iPad mini 6th gen, iPad mini A17 Pro) ---
    case "iPad14,1", "iPad14,2",
         "iPad16,1", "iPad16,2":
      return 8.3

    // --- 10.2" (iPad 8th & 9th gen) ---
    case "iPad11,6", "iPad11,7",
         "iPad12,1", "iPad12,2":
      return 10.2

    // --- 10.9" (Air 4th & 5th gen, iPad 10th gen, iPad A16 11th gen) ---
    case "iPad13,1", "iPad13,2",
         "iPad13,16", "iPad13,17",
         "iPad13,18", "iPad13,19",
         "iPad15,7", "iPad15,8":
      return 10.9

    // --- 11.0" (Pro 11" M1/M2/M4/M5, Air 11" M2/M3/M4) ---
    case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7",
         "iPad14,3", "iPad14,4",
         "iPad14,8", "iPad14,9",
         "iPad15,3", "iPad15,4",
         "iPad16,3", "iPad16,4",
         "iPad16,8", "iPad16,9",
         "iPad17,1", "iPad17,2":
      return 11.0

    // --- 12.9" (Pro 12.9" 5th & 6th gen M1/M2) ---
    case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11",
         "iPad14,5", "iPad14,6":
      return 12.9

    // --- 13.0" (Air 13" M2/M3/M4, Pro 13" M4/M5) ---
    case "iPad14,10", "iPad14,11",
         "iPad15,5", "iPad15,6",
         "iPad16,5", "iPad16,6",
         "iPad16,10", "iPad16,11",
         "iPad17,3", "iPad17,4":
      return 13.0

    default:
      return UIDevice.current.userInterfaceIdiom == .pad ? 11.0 : 6.1
    }
  }
}