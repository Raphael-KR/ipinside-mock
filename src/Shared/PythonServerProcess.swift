import Foundation

/// Shared lifecycle for the app's local Python servers.
final class PythonServerProcess {
    private var process: Process?
    private(set) var lastError: String?
    var onExit: (() -> Void)?

    var isRunning: Bool { process?.isRunning ?? false }

    func start(script: String, filename: String) -> Bool {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            lastError = "서버 스크립트 저장 실패: \(error.localizedDescription)"
            NSLog("PythonServerProcess write failed; file=%@ error=%@", filename, error.localizedDescription)
            return false
        }
        return start(scriptURL: url)
    }

    func start(scriptURL: URL, arguments: [String] = []) -> Bool {
        if isRunning { return true }
        lastError = nil
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        child.arguments = [scriptURL.path] + arguments
        child.environment = ProcessInfo.processInfo.environment
        child.terminationHandler = { [weak self] ended in
            DispatchQueue.main.async {
                guard let self = self, self.process === ended else { return }
                self.lastError = "서버가 종료되었습니다 (종료 코드 \(ended.terminationStatus))."
                NSLog("PythonServerProcess exited; script=%@ status=%d", scriptURL.lastPathComponent, ended.terminationStatus)
                self.onExit?()
            }
        }
        do {
            try child.run()
            process = child
            return true
        } catch {
            lastError = "Python 실행 실패: \(error.localizedDescription)"
            NSLog("PythonServerProcess launch failed; executable=/usr/bin/python3 script=%@ error=%@", scriptURL.lastPathComponent, error.localizedDescription)
            return false
        }
    }

    func stop() {
        let child = process
        process = nil
        if child?.isRunning == true { child?.terminate() }
    }

    deinit { stop() }
}
