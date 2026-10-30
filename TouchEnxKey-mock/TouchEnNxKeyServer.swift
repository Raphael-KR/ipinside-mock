import Foundation

/// T-money installation-check compatibility, independent of IPinside capture data.
final class TouchEnNxKeyServer {
    static let port = 34581
    private let process = PythonServerProcess()
    private(set) var lastError: String?

    var isRunning: Bool { process.isRunning }
    var onExit: (() -> Void)? {
        get { process.onExit }
        set { process.onExit = newValue }
    }

    func start() -> Bool {
        lastError = nil
        let missing = [certPath, keyPath].filter { !FileManager.default.fileExists(atPath: $0) }
        guard missing.isEmpty else {
            lastError = "공통 TLS 인증서가 필요합니다. 메뉴의 ‘공통 인증서 설정…’을 실행하세요."
            NSLog("TouchEnNxKey TLS files missing; expected=2 missing=%@", missing.joined(separator: ", "))
            return false
        }
        guard let script = Bundle.main.url(forResource: "touchen_nxkey_server", withExtension: "py") else {
            lastError = "앱에 TouchEn nxKey 서버 파일이 없습니다. 앱을 다시 빌드하세요."
            NSLog("TouchEnNxKey resource missing; expected=touchen_nxkey_server.py bundle=%@", Bundle.main.bundlePath)
            return false
        }
        let started = process.start(scriptURL: script, arguments: [
            "--cert", certPath, "--key", keyPath,
            "--port", String(Self.port),
            "--parent-pid", String(ProcessInfo.processInfo.processIdentifier)
        ])
        if !started { lastError = process.lastError }
        return started
    }

    var failureDescription: String {
        lastError ?? process.lastError ?? "포트 \(Self.port) 사용 여부와 공통 TLS 인증서를 확인하세요."
    }

    func stop() { process.stop() }
}
