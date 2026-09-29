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

  private func currentMetrics() -> (device: Double, window: Double, screenLogicalDiagonal: Double) {
    let device = hardwareDiagonalInches()

    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let bestScene = scenes.first(where: { $0.activationState == .foregroundActive })
      ?? scenes.first(where: { $0.activationState == .foregroundInactive })
      ?? scenes.first(where: { $0.activationState == .unattached })
      ?? scenes.first(where: { $0.activationState == .background })

    let screenLogicalDiagonal: Double
    let windowLogicalDiagonal: Double

    if let scene = bestScene {
      screenLogicalDiagonal = diagonal(of: scene.screen.bounds.size)
      windowLogicalDiagonal = diagonal(of: scene.coordinateSpace.bounds.size)
    } else {
      screenLogicalDiagonal = diagonal(of: UIScreen.main.bounds.size)
      windowLogicalDiagonal = screenLogicalDiagonal
    }

    guard screenLogicalDiagonal > 0 else {
      return (device, device, 0)
    }

    let ratio = windowLogicalDiagonal > 0 ? (windowLogicalDiagonal / screenLogicalDiagonal) : 1.0
    return (device, device * ratio, screenLogicalDiagonal)
  }

  private func diagonal(of size: CGSize) -> Double {
    return (pow(size.width, 2) + pow(size.height, 2)).squareRoot()
  }

  private func hardwareDiagonalInches() -> Double {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { partial, element in
      guard let value = element.value as? Int8, value != 0 else { return partial }
      return partial + String(UnicodeScalar(UInt8(value)))
    }

    switch identifier {
    case "iPhone14,2", "iPhone15,2": return 6.1
    case "iPhone14,3", "iPhone15,3": return 6.7
    case "iPhone14,5", "iPhone14,6", "iPhone14,7": return 6.1
    case "iPad13,1", "iPad13,2": return 10.9
    case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return 11.0
    case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return 12.9
    case "iPad14,3", "iPad14,4": return 11.0
    case "iPad14,5", "iPad14,6": return 12.9
    default:
      return UIDevice.current.userInterfaceIdiom == .pad ? 11.0 : 6.1
    }
  }
}