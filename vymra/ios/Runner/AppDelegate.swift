import Flutter
import UIKit
import AVFoundation
import Speech
import Security
import AdjustSdk

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let speechBridge = IosSpeechInputBridge()
  private let appDeviceInfoBridge = AppDeviceInfoBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    AdjustLifecycleCoordinator.shared.applicationDidFinishLaunching(application)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    speechBridge.register(with: engineBridge.applicationRegistrar.messenger())
    appDeviceInfoBridge.register(with: engineBridge.applicationRegistrar.messenger())
  }
}

final class AppDeviceInfoBridge: NSObject {
  private let channelName = "vymra/app_device_info"

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInfo":
      result(currentInfo())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func currentInfo() -> [String: String] {
    let bundle = Bundle.main
    let locale = Locale.current
    return [
      "appName": bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "vymra",
      "appVersion": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "1.0.0",
      "bundleId": bundle.bundleIdentifier ?? "unknown",
      "osVersion": UIDevice.current.systemVersion,
      "deviceModel": machineIdentifier(),
      "lang": locale.languageCode ?? "en",
      "region": locale.regionCode ?? "US",
      "locale": locale.identifier.replacingOccurrences(of: "_", with: "-"),
    ]
  }

  private func machineIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    let identifier = mirror.children.reduce(into: "") { partialResult, element in
      guard let value = element.value as? Int8, value != 0 else {
        return
      }
      partialResult.append(Character(UnicodeScalar(UInt8(value))))
    }
    return identifier.isEmpty ? "iPhone" : identifier
  }
}

final class IosSpeechInputBridge: NSObject, FlutterStreamHandler {
  private let methodChannelName = "vymra/ios_speech_input/methods"
  private let eventChannelName = "vymra/ios_speech_input/events"

  private var eventSink: FlutterEventSink?
  private var audioEngine: AVAudioEngine?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var speechRecognizer: SFSpeechRecognizer?

  func register(with messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler(handle)

    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(SFSpeechRecognizer.authorizationStatus() != .restricted)
    case "requestPermissions":
      requestPermissions(result: result)
    case "startListening":
      let arguments = call.arguments as? [String: Any]
      let localeId = arguments?["localeId"] as? String
      startListening(localeId: localeId, result: result)
    case "stopListening":
      stopListening(finalizeAudio: true)
      result(nil)
    case "cancelListening":
      stopListening(finalizeAudio: false)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestPermissions(result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { speechStatus in
      AVAudioSession.sharedInstance().requestRecordPermission { microphoneGranted in
        DispatchQueue.main.async {
          let speechGranted = speechStatus == .authorized
          result(speechGranted && microphoneGranted)
        }
      }
    }
  }

  private func startListening(localeId: String?, result: @escaping FlutterResult) {
    stopListening(finalizeAudio: false)

    let locale = localeId.flatMap(Locale.init(identifier:))
    speechRecognizer = locale.flatMap(SFSpeechRecognizer.init(locale:)) ?? SFSpeechRecognizer()

    guard let speechRecognizer, speechRecognizer.isAvailable else {
      sendError("Speech recognition is unavailable.")
      result(false)
      return
    }

    let audioEngine = AVAudioEngine()
    let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    recognitionRequest.shouldReportPartialResults = true

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setPreferredSampleRate(44_100)
      try session.setActive(true, options: .notifyOthersOnDeactivation)

      let inputNode = audioEngine.inputNode
      guard let format = validatedInputFormat(for: inputNode) else {
        sendError("Microphone input is unavailable.")
        stopListening(finalizeAudio: false)
        result(false)
        return
      }

      inputNode.removeTap(onBus: 0)
      inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        recognitionRequest.append(buffer)
      }

      self.audioEngine = audioEngine
      self.recognitionRequest = recognitionRequest
      sendState(isListening: true)

      recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) {
        [weak self] recognitionResult, error in
        guard let self else {
          return
        }

        if let recognitionResult {
          self.eventSink?([
            "type": "result",
            "text": recognitionResult.bestTranscription.formattedString,
            "isFinal": recognitionResult.isFinal,
          ])

          if recognitionResult.isFinal {
            self.stopListening(finalizeAudio: true)
          }
        }

        if error != nil {
          self.sendError("Speech recognition stopped unexpectedly.")
          self.stopListening(finalizeAudio: false)
        }
      }

      audioEngine.prepare()
      try audioEngine.start()
      result(true)
    } catch {
      sendError("Speech recognition could not start.")
      stopListening(finalizeAudio: false)
      result(false)
    }
  }

  private func stopListening(finalizeAudio: Bool) {
    if finalizeAudio {
      recognitionRequest?.endAudio()
    } else {
      recognitionTask?.cancel()
    }

    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil
    audioEngine = nil

    do {
      try AVAudioSession.sharedInstance().setActive(
        false,
        options: .notifyOthersOnDeactivation
      )
    } catch {
      // Ignore audio session cleanup failures.
    }

    sendState(isListening: false)
  }

  private func sendState(isListening: Bool) {
    eventSink?(["type": "state", "isListening": isListening])
  }

  private func sendError(_ message: String) {
    eventSink?(["type": "error", "message": message])
  }

  private func validatedInputFormat(
    for inputNode: AVAudioInputNode
  ) -> AVAudioFormat? {
    let candidateFormats = [
      inputNode.outputFormat(forBus: 0),
      inputNode.inputFormat(forBus: 0),
    ]

    for format in candidateFormats {
      if isValidRecordingFormat(format) {
        return format
      }
    }

    return nil
  }

  private func isValidRecordingFormat(_ format: AVAudioFormat) -> Bool {
    format.sampleRate > 0 && format.channelCount > 0
  }
}

final class AdjustLifecycleCoordinator {
  static let shared = AdjustLifecycleCoordinator()

  private var hasInitializedSdk = false
  private var hasRequestedAtt = false

  private init() {}

  func applicationDidFinishLaunching(_ application: UIApplication) {
    initializeAdjustSdkIfNeeded()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleApplicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleSceneDidActivate(_:)),
      name: UIScene.didActivateNotification,
      object: nil
    )

    requestTrackingAuthorizationIfEligible()
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    requestTrackingAuthorizationIfEligible(activeScene: scene)
  }

  @objc private func handleApplicationDidBecomeActive() {
    requestTrackingAuthorizationIfEligible()
  }

  @objc private func handleSceneDidActivate(_ notification: Notification) {
    let scene = notification.object as? UIScene
    requestTrackingAuthorizationIfEligible(activeScene: scene)
  }

  private func initializeAdjustSdkIfNeeded() {
    guard !hasInitializedSdk else {
      return
    }

//    guard let appToken = Bundle.main.object(forInfoDictionaryKey: "AdjustAppToken") as? String,
//      !appToken.isEmpty,
//      appToken != "YOUR_ADJUST_APP_TOKEN"
//    else {
//      NSLog("Adjust SDK skipped: set AdjustAppToken in Info.plist before shipping.")
//      return
//    }

    let environment: String
    #if DEBUG
      environment = ADJEnvironmentSandbox
    #else
      environment = ADJEnvironmentProduction
    #endif

    guard let config = ADJConfig(appToken: "875q28634yo0", environment: environment) else {
      NSLog("Adjust SDK skipped: failed to create ADJConfig.")
      return
    }

    config.externalDeviceId = AdjustExternalDeviceIdStore.shared.getOrCreateDeviceId()

    #if DEBUG
      config.logLevel = ADJLogLevel.verbose
    #else
      config.logLevel = ADJLogLevel.verbose
    #endif

    Adjust.initSdk(config)
    hasInitializedSdk = true
  }

  private func requestTrackingAuthorizationIfEligible(activeScene: UIScene? = nil) {
    guard !hasRequestedAtt else {
      return
    }

    let status = Adjust.appTrackingAuthorizationStatus()
    guard status == 0 else {
      hasRequestedAtt = true
      return
    }

    guard UIApplication.shared.applicationState == .active else {
      return
    }

    let scene = activeScene ?? UIApplication.shared.connectedScenes.first {
      $0.activationState == .foregroundActive
    }
    guard scene?.activationState == .foregroundActive else {
      return
    }

    hasRequestedAtt = true
    DispatchQueue.main.async {
      Adjust.requestAppTrackingAuthorization { _ in }
    }
  }
}

private final class AdjustExternalDeviceIdStore {
  static let shared = AdjustExternalDeviceIdStore()

  private let flutterSecureStorageService = "flutter_secure_storage_service"
  private let account = "vymra_device_id"
  private let accessGroup: String? = nil

  private init() {}

  func getOrCreateDeviceId() -> String {
    if let existing = normalizedValidDeviceId(from: readFlutterSecureStorageDeviceId()) {
      return existing
    }

    if let legacy = normalizedValidDeviceId(from: readLegacyDeviceId()) {
      writeFlutterSecureStorageDeviceId(legacy)
      return legacy
    }

    let created = UUID().uuidString.lowercased()
    writeFlutterSecureStorageDeviceId(created)
    return created
  }

  private func normalizedValidDeviceId(from value: String?) -> String? {
    guard let value, UUID(uuidString: value) != nil else {
      return nil
    }
    return value.lowercased()
  }

  private func readFlutterSecureStorageDeviceId() -> String? {
    var query = flutterSecureStorageQuery()
    query[kSecReturnData as String] = kCFBooleanTrue
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess,
      let data = result as? Data,
      let value = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    return value
  }

  private func readLegacyDeviceId() -> String? {
    var query = legacyQuery()
    query[kSecReturnData as String] = kCFBooleanTrue
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess,
      let data = result as? Data,
      let value = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    return value
  }

  private func writeFlutterSecureStorageDeviceId(_ value: String) {
    let data = Data(value.utf8)
    let query = flutterSecureStorageQuery()

    let updateStatus = SecItemUpdate(
      query as CFDictionary,
      [kSecValueData as String: data] as CFDictionary
    )
    if updateStatus == errSecSuccess {
      return
    }

    var addQuery = query
    addQuery[kSecValueData as String] = data

    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
      NSLog("Adjust device id keychain write failed with status: %d", addStatus)
      return
    }
  }

  private func flutterSecureStorageQuery() -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: flutterSecureStorageService,
      kSecAttrAccount as String: account,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
    ]

    if let accessGroup {
      query[kSecAttrAccessGroup as String] = accessGroup
    }

    return query
  }

  private func legacyQuery() -> [String: Any] {
    var query = flutterSecureStorageQuery()
    query[kSecAttrService as String] = Bundle.main.bundleIdentifier ?? "vymra.adjust"
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    if let accessGroup {
      query[kSecAttrAccessGroup as String] = accessGroup
    }

    return query
  }
}
