import Cocoa
import Foundation

// MARK: - Data Directory

let dataDir: URL = {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let dir = appSupport.appendingPathComponent("IPinsideMock")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}()

let certPath = dataDir.appendingPathComponent("interezen.crt").path
let keyPath  = dataDir.appendingPathComponent("interezen.key").path
let dataPath = dataDir.appendingPathComponent("captured.json").path

// MARK: - IPinside Request Parameters (from IBK's IPinside_v6_config.js)

let captureRequestValue: String = {
    let params = [
        "3.0.0.1",  // versionMac
        "VmstAAAAAC1kZmV4ZGRheGRlZHhnZmxuZmx5IDQ3OD0JZmd4PCU1bAkfGAUfEhMJFw4JHmvM",  // real_config
        "Z", "Z", "Z",  // web, pc, key (all empty string options)
        "11", "31", "21",  // secuCd mac
        "2",    // vpn
        "200",  // NATLoopCnt
        "3000", // timeout
        "qcxIAAAAAEj9zMjE/8DM3szb9u3M2sLdxtmHzNHM1dvK2szEztvch8zRzNXbyszHzsTO29yHzNHM1d3MyMTfwMzezNv27czawt3G2YfM0cxE",  // cWinRemote
        "1",    // isHSNRevers
        "fUgCAAAAAAJMSMw=",  // cOpt
        "13",   // sUdata mac
        "0",    // isTighten_security
        "30820122300d06092a864886f70d01010105000382010f003082010a0282010100a5803559c1dbe885c16a497de17b8576323cff26aabab92403c0f8fffd70a5ebb093b54745917757e73a2053aa7de284942039c59922c9682d6a126622ca2414f497d76dfe0862db37f5bfdfd0c1050f838a54acd543ef759cafd2d37552b36741c662c9d5f22a33648ccacbb8ad16787822e04bf35c6cca898464cbb4d5e6e1964e4986b761e75465faeb556ccca7d0021a702118a08dc3fefaed4c275b2f56db860abf8237582a6c8b49677888193e0c5c4c1994cdc508d20d5e800eac4a92607ebaad51ceab381368895271bfd245670d9222ba0f3263a45c641c25f70598a0eac8418cc6701161d524b93f48e698d8f6d87ef29e9661965043a3d2c5cc5f0203010001",  // cKey
        "1",    // isAllTightenSecurity
    ]
    return params.joined(separator: ":") + ":"
}()

// MARK: - Setup Manager

class SetupManager {

    var isSetupComplete: Bool {
        FileManager.default.fileExists(atPath: certPath) &&
        FileManager.default.fileExists(atPath: keyPath) &&
        FileManager.default.fileExists(atPath: dataPath)
    }

    /// Check if IPinside is currently installed
    var isIPinsideInstalled: Bool {
        FileManager.default.fileExists(atPath: "/Applications/IPinside.app")
    }

    /// Copy SSL certs from IPinside.app (key requires admin privileges)
    func copyCerts() -> Bool {
        let srcCrt = "/Applications/IPinside.app/Contents/Resources/interezen.crt"
        let srcKey = "/Applications/IPinside.app/Contents/Resources/interezen.key"

        guard FileManager.default.fileExists(atPath: srcCrt),
              FileManager.default.fileExists(atPath: srcKey) else { return false }

        // Copy cert (readable without sudo)
        if !FileManager.default.fileExists(atPath: certPath) {
            do {
                try FileManager.default.copyItem(atPath: srcCrt, toPath: certPath)
            } catch {
                NSLog("Failed to copy cert: \(error)")
                return false
            }
        }

        // Copy key (needs sudo)
        if !FileManager.default.fileExists(atPath: keyPath) {
            let script = "cp '\(srcKey)' '\(keyPath)' && chown $(whoami) '\(keyPath)'"
            let result = runWithAdmin(script)
            if !result {
                NSLog("Failed to copy key with admin privileges")
                return false
            }
        }

        return FileManager.default.fileExists(atPath: certPath) &&
               FileManager.default.fileExists(atPath: keyPath)
    }

    /// Capture response from running IPinside agent
    func captureResponse() -> Bool {
        let urlString = "https://127.0.0.1:21300/?t=A&value=\(captureRequestValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? captureRequestValue)"

        guard let url = URL(string: urlString) else { return false }

        let semaphore = DispatchSemaphore(value: 0)
        var capturedData: Data?

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config, delegate: TrustAllDelegate(), delegateQueue: nil)

        let task = session.dataTask(with: url) { data, response, error in
            if let data = data {
                capturedData = data
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        guard let data = capturedData,
              let responseStr = String(data: data, encoding: .utf8) else {
            NSLog("No response from IPinside agent")
            return false
        }

        // Parse JSONP response: ({"result":"I","wdata":"...","ndata":"...","udata":"..."});
        let cleaned = responseStr
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^\\s*\\(", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\);\\s*$", with: "", options: .regularExpression)

        // Validate it's proper JSON with result=I
        guard let jsonData = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String],
              json["result"] == "I",
              let wdata = json["wdata"], !wdata.isEmpty else {
            NSLog("Invalid response from IPinside agent")
            return false
        }

        // Save captured JSON
        do {
            try cleaned.write(toFile: dataPath, atomically: true, encoding: .utf8)
            return true
        } catch {
            NSLog("Failed to save captured data: \(error)")
            return false
        }
    }

    private func runWithAdmin(_ command: String) -> Bool {
        let script = "do shell script \"\(command.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        guard let appleScript = NSAppleScript(source: script) else { return false }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
        return error == nil
    }
}

/// Trust all SSL certs for capturing from the local IPinside agent
class TrustAllDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - Mock Server

class IPinsideMockServer {
    private var serverProcess: Process?

    var isRunning: Bool {
        serverProcess?.isRunning ?? false
    }

    func start() -> Bool {
        guard FileManager.default.fileExists(atPath: dataPath),
              FileManager.default.fileExists(atPath: certPath),
              FileManager.default.fileExists(atPath: keyPath) else {
            NSLog("Missing data or certs")
            return false
        }

        let scriptPath = NSTemporaryDirectory() + "ipinside_mock_server.py"
        let script = createServerScript()
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        } catch {
            NSLog("Failed to write server script: \(error)")
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptPath]
        process.environment = ProcessInfo.processInfo.environment
        do {
            try process.run()
            serverProcess = process
            return true
        } catch {
            NSLog("Failed to start server: \(error)")
            return false
        }
    }

    func stop() {
        serverProcess?.terminate()
        serverProcess = nil
    }

    private func createServerScript() -> String {
        // Read captured data and embed in script
        let escaped_dataPath = dataPath.replacingOccurrences(of: "'", with: "\\'")
        let escaped_certPath = certPath.replacingOccurrences(of: "'", with: "\\'")
        let escaped_keyPath = keyPath.replacingOccurrences(of: "'", with: "\\'")

        return """
        import ssl, os
        from http.server import HTTPServer, BaseHTTPRequestHandler
        from urllib.parse import urlparse, parse_qs

        with open('\(escaped_dataPath)', 'r') as f:
            RESPONSE = f.read().strip()

        class H(BaseHTTPRequestHandler):
            def do_GET(self):
                p = parse_qs(urlparse(self.path).query)
                cb = p.get('callback', [''])[0]
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept')
                self.end_headers()
                self.wfile.write(f'{cb}({RESPONSE});'.encode())
            def do_POST(self):
                self.do_GET()
            def do_OPTIONS(self):
                self.send_response(200)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
                self.end_headers()
            def log_message(self, f, *a):
                pass

        s = HTTPServer(('127.0.0.1', 21300), H)
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain('\(escaped_certPath)', '\(escaped_keyPath)')
        s.socket = ctx.wrap_socket(s.socket, server_side=True)
        s.serve_forever()
        """
    }
}

// MARK: - Setup Window Controller

class SetupWindowController: NSObject {
    private let setup = SetupManager()
    private var window: NSWindow!
    private var stepLabel: NSTextField!
    private var statusLabel: NSTextField!
    private var actionButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    private var currentStep = 0
    var onComplete: (() -> Void)?

    func showWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = "IPinside Mock - 초기 설정"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        // Icon
        let iconLabel = NSTextField(labelWithString: "🛡️")
        iconLabel.font = NSFont.systemFont(ofSize: 48)
        iconLabel.frame = NSRect(x: 20, y: 220, width: 60, height: 60)
        contentView.addSubview(iconLabel)

        // Title
        let title = NSTextField(labelWithString: "IPinside Mock 초기 설정")
        title.font = NSFont.boldSystemFont(ofSize: 18)
        title.frame = NSRect(x: 88, y: 240, width: 380, height: 28)
        contentView.addSubview(title)

        let subtitle = NSTextField(labelWithString: "IPinside 응답 데이터를 한 번만 캡처하면, 이후엔 IPinside 없이 인터넷뱅킹을 사용할 수 있습니다.")
        subtitle.font = NSFont.systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 88, y: 210, width: 380, height: 32)
        subtitle.maximumNumberOfLines = 2
        subtitle.lineBreakMode = .byWordWrapping
        contentView.addSubview(subtitle)

        // Step label
        stepLabel = NSTextField(labelWithString: "")
        stepLabel.font = NSFont.systemFont(ofSize: 14)
        stepLabel.frame = NSRect(x: 30, y: 150, width: 420, height: 50)
        stepLabel.maximumNumberOfLines = 3
        stepLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(stepLabel)

        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 30, y: 120, width: 420, height: 20)
        contentView.addSubview(statusLabel)

        // Progress indicator
        progressIndicator = NSProgressIndicator(frame: NSRect(x: 30, y: 95, width: 420, height: 10))
        progressIndicator.isIndeterminate = true
        progressIndicator.style = .bar
        progressIndicator.isHidden = true
        contentView.addSubview(progressIndicator)

        // Action button
        actionButton = NSButton(title: "시작", target: self, action: #selector(actionButtonClicked))
        actionButton.bezelStyle = .rounded
        actionButton.frame = NSRect(x: 340, y: 20, width: 120, height: 32)
        contentView.addSubview(actionButton)

        updateStep()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateStep() {
        if setup.isSetupComplete {
            stepLabel.stringValue = "✅ 설정이 완료되었습니다!\n이제 메뉴바에서 서버를 켜고 끌 수 있습니다."
            statusLabel.stringValue = ""
            actionButton.title = "완료"
            currentStep = 99
            return
        }

        let hasCerts = FileManager.default.fileExists(atPath: certPath) &&
                       FileManager.default.fileExists(atPath: keyPath)

        if !setup.isIPinsideInstalled {
            currentStep = 0
            stepLabel.stringValue = "① IPinside를 설치하세요.\n은행 사이트(예: IBK)의 보안프로그램 설치 페이지에서 다운로드할 수 있습니다."
            statusLabel.stringValue = "설치 후 아래 버튼을 눌러주세요."
            actionButton.title = "설치 확인"
        } else if !hasCerts {
            currentStep = 1
            stepLabel.stringValue = "② SSL 인증서를 복사합니다.\n관리자 비밀번호 입력이 필요합니다 (1회만)."
            statusLabel.stringValue = "IPinside가 설치된 것을 확인했습니다."
            actionButton.title = "인증서 복사"
        } else {
            currentStep = 2
            stepLabel.stringValue = "③ IPinside 응답 데이터를 캡처합니다.\nIPinside 데몬이 실행 중이어야 합니다."
            statusLabel.stringValue = ""
            actionButton.title = "캡처 시작"
        }
    }

    @objc private func actionButtonClicked() {
        if currentStep == 99 {
            window.close()
            onComplete?()
            return
        }

        actionButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var success = false

            switch self.currentStep {
            case 0:
                success = self.setup.isIPinsideInstalled
            case 1:
                success = self.setup.copyCerts()
            case 2:
                success = self.setup.captureResponse()
            default:
                break
            }

            DispatchQueue.main.async {
                self.progressIndicator.stopAnimation(nil)
                self.progressIndicator.isHidden = true
                self.actionButton.isEnabled = true

                if success {
                    self.updateStep()
                    if self.setup.isSetupComplete {
                        self.showUninstallGuide()
                    }
                } else {
                    self.showError()
                }
            }
        }
    }

    private func showError() {
        switch currentStep {
        case 0:
            statusLabel.stringValue = "⚠️ IPinside가 설치되지 않았습니다."
        case 1:
            statusLabel.stringValue = "⚠️ 인증서 복사에 실패했습니다."
        case 2:
            statusLabel.stringValue = "⚠️ 캡처 실패. IPinside 데몬이 실행 중인지 확인하세요."
        default:
            break
        }
        statusLabel.textColor = .systemRed
    }

    private func showUninstallGuide() {
        let alert = NSAlert()
        alert.messageText = "캡처 완료!"
        alert.informativeText = "이제 IPinside를 삭제해도 됩니다.\n\n/Applications/IPinside.app 을 휴지통으로 이동하세요.\n\n(선택사항) 시스템 설정 → 일반 → 로그인 항목에서 IPinside Mock을 추가하면 부팅 시 자동 실행됩니다."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }
}

// MARK: - Menu Bar App

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let server = IPinsideMockServer()
    private let setup = SetupManager()
    private var toggleItem: NSMenuItem!
    private var statusMenuItem: NSMenuItem!
    private var setupController: SetupWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        rebuildMenu()
        updateIcon(running: false)

        // Check if setup is needed
        if !setup.isSetupComplete {
            showSetup()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        server.stop()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "상태: 꺼짐", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        if setup.isSetupComplete {
            toggleItem = NSMenuItem(title: "서버 시작", action: #selector(toggleServer), keyEquivalent: "t")
            toggleItem.target = self
            menu.addItem(toggleItem)
        } else {
            let setupItem = NSMenuItem(title: "초기 설정...", action: #selector(showSetup), keyEquivalent: "s")
            setupItem.target = self
            menu.addItem(setupItem)
        }

        menu.addItem(NSMenuItem.separator())

        let resetItem = NSMenuItem(title: "데이터 재캡처...", action: #selector(resetData), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "종료", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func showSetup() {
        setupController = SetupWindowController()
        setupController?.onComplete = { [weak self] in
            self?.rebuildMenu()
            self?.updateUI(running: false)
        }
        setupController?.showWindow()
    }

    @objc private func resetData() {
        let alert = NSAlert()
        alert.messageText = "데이터를 재캡처하시겠습니까?"
        alert.informativeText = "IPinside가 설치되어 있어야 합니다. 기존 캡처 데이터는 삭제됩니다."
        alert.addButton(withTitle: "재캡처")
        alert.addButton(withTitle: "취소")
        if alert.runModal() == .alertFirstButtonReturn {
            try? FileManager.default.removeItem(atPath: dataPath)
            server.stop()
            updateUI(running: false)
            rebuildMenu()
            showSetup()
        }
    }

    @objc private func toggleServer() {
        if server.isRunning {
            server.stop()
            updateUI(running: false)
        } else {
            if server.start() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    if self?.server.isRunning == true {
                        self?.updateUI(running: true)
                    } else {
                        self?.updateUI(running: false)
                        let alert = NSAlert()
                        alert.messageText = "서버 시작 실패"
                        alert.informativeText = "포트 21300이 이미 사용 중이거나 인증서에 문제가 있을 수 있습니다."
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
            }
        }
    }

    private func updateUI(running: Bool) {
        updateIcon(running: running)
        statusMenuItem?.title = running ? "상태: 켜짐 (포트 21300)" : "상태: 꺼짐"
        toggleItem?.title = running ? "서버 중지" : "서버 시작"
    }

    private func updateIcon(running: Bool) {
        if let button = statusItem.button {
            let title = "IP"
            let color: NSColor = !setup.isSetupComplete ? .systemOrange :
                                  running ? .systemGreen : .systemGray
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: 12, weight: .bold)
            ]
            button.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        }
    }

    @objc private func quitApp() {
        server.stop()
        NSApp.terminate(nil)
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
