import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    AdjustLifecycleCoordinator.shared.sceneDidBecomeActive(scene)
  }
}
