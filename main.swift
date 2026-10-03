// MirrorBar — muestra en la barra de menú el estado de un espejo (carpeta/disco virtual).
// Configuración (opcional):
//   defaults write com.joelveloz.mirrorbar Source     "/ruta/origen"
//   defaults write com.joelveloz.mirrorbar Mirror     "/ruta/espejo"
//   defaults write com.joelveloz.mirrorbar StatusFile "/ruta/estado.txt"   (líneas "Status:" y "Last sync:")
//   defaults write com.joelveloz.mirrorbar Volume     "/Volumes/MiDisco"   (disco a expulsar)
import AppKit
import UserNotifications

@discardableResult func sh(_ c: String) -> (Int32, String) {
    let p = Process(); p.launchPath = "/bin/zsh"; p.arguments = ["-c", c]
    let o = Pipe(); p.standardOutput = o; p.standardError = o
    try? p.run(); p.waitUntilExit()
    return (p.terminationStatus, String(data: o.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
}

func notify(_ title: String, _ body: String) {
    let c = UNUserNotificationCenter.current()
    c.requestAuthorization(options: [.alert, .sound]) { ok, _ in
        if ok { let n = UNMutableNotificationContent(); n.title = title; n.body = body; n.sound = .default
                c.add(UNNotificationRequest(identifier: UUID().uuidString, content: n, trigger: nil)) }
        else { sh("osascript -e 'display notification \"\(body)\" with title \"\(title)\"'") }
    }
}

let cfg = UserDefaults.standard   // dominio = com.joelveloz.mirrorbar
func path(_ k: String, _ d: String) -> String { (cfg.string(forKey: k) ?? d).replacingOccurrences(of: "~", with: NSHomeDirectory()) }

func size(_ p: String) -> Int64 {
    guard let e = FileManager.default.enumerator(atPath: p) else { return 0 }
    var t: Int64 = 0
    while let f = e.nextObject() as? String {
        t += (try? FileManager.default.attributesOfItem(atPath: p + "/" + f)[.size] as? Int64) ?? 0
    }
    return t
}

func field(_ text: String, _ key: String) -> String {
    text.split(separator: "\n").first { $0.hasPrefix(key) }
        .map { $0.dropFirst(key.count).trimmingCharacters(in: .whitespaces) } ?? "—"
}

class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    func applicationDidFinishLaunching(_ n: Notification) {
        refresh()
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in self.refresh() }
    }
    @objc func refresh() {
        let src = path("Source", "~/Discos/Joel Server.sparsebundle")
        let dst = path("Mirror", "/Volumes/JOEL CLOUD/Joel Server.sparsebundle")
        let txt = path("StatusFile", "/Volumes/JOEL CLOUD/Joel Server - LAST SYNC.txt")
        DispatchQueue.global().async {
            let connected = FileManager.default.fileExists(atPath: (dst as NSString).deletingLastPathComponent)
            let s = size(src), d = connected ? size(dst) : 0
            let pct = s > 0 ? min(100, Int(d * 100 / s)) : 0
            let status = (try? String(contentsOfFile: txt, encoding: .utf8)) ?? ""
            let st = field(status, "Status:"), last = field(status, "Last sync:")
            let (sym, label) = !connected ? ("externaldrive", "") :
                st.contains("SYNCING") ? ("arrow.triangle.2.circlepath", " \(pct)%") :
                st.contains("FAILED")  ? ("externaldrive.badge.exclamationmark", "") : ("externaldrive.badge.checkmark", "")
            DispatchQueue.main.async {
                let img = NSImage(systemSymbolName: sym, accessibilityDescription: "MirrorBar"); img?.isTemplate = true
                self.item.button?.image = img; self.item.button?.imagePosition = .imageLeading; self.item.button?.title = label
                let m = NSMenu()
                for t in [connected ? "Estado: \(st)" : "Disco del espejo no conectado",
                          "Última sincronización: \(last)",
                          String(format: "Copiado: %.0f de %.0f GB (%d%%)", Double(d)/1e9, Double(s)/1e9, pct)] {
                    m.addItem(withTitle: t, action: nil, keyEquivalent: "")
                }
                m.addItem(.separator())
                let o = m.addItem(withTitle: "Abrir estado", action: #selector(self.open), keyEquivalent: "o"); o.target = self
                let r = m.addItem(withTitle: "Actualizar", action: #selector(self.refresh), keyEquivalent: "r"); r.target = self
                if connected { let e = m.addItem(withTitle: "Expulsar disco de forma segura…", action: #selector(self.eject), keyEquivalent: "e"); e.target = self }
                m.addItem(withTitle: "Salir", action: #selector(NSApp.terminate), keyEquivalent: "q")
                self.item.menu = m
            }
        }
    }
    @objc func eject() {
        let vol = path("Volume", "/Volumes/JOEL CLOUD"), name = (vol as NSString).lastPathComponent
        let busy = sh("pgrep -fl '\(vol)' | grep -v pgrep").1.isEmpty == false
        let a = NSAlert(); a.messageText = "¿Expulsar \(name)?"
        a.informativeText = busy ? "Hay copias en curso hacia este disco. Se detendrán de forma segura (lo copiado no se pierde y se reanuda al reconectar)." : "Se cerrarán los discos virtuales guardados en él y luego se expulsará."
        a.addButton(withTitle: busy ? "Detener y expulsar" : "Expulsar"); a.addButton(withTitle: "Cancelar")
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        item.button?.image = NSImage(systemSymbolName: "eject", accessibilityDescription: nil); item.button?.title = ""
        DispatchQueue.global().async {
            // 1) detener lo que escribe en el disco y comprobarlo
            sh("pkill -f '\(vol)'; for i in {1..15}; do pgrep -f '\(vol)' >/dev/null || exit 0; sleep 1; done; exit 1")
            // 2) cerrar discos virtuales guardados en él  3) expulsar el disco
            let imgs = "hdiutil info | awk '/^image-path/{i=($0 ~ \"\(vol)/\")} i && /^\\/dev\\/disk[0-9]+[ \\t]/{print $1; i=0}'"
            let (rc, out) = sh("\(imgs) | while read d; do diskutil eject $d || exit 1; done && diskutil eject '\(vol)'")
            DispatchQueue.main.async {
                if rc == 0 { notify("✅ \(name) expulsado", "Ya puedes desconectar el cable.") }
                else { notify("⚠️ No se pudo expulsar \(name)", "NO desconectes el cable. Algo lo está usando. " + out.prefix(120)) }
                self.refresh()
            }
        }
    }
    @objc func open() { NSWorkspace.shared.open(URL(fileURLWithPath: path("StatusFile", "/Volumes/JOEL CLOUD/Joel Server - LAST SYNC.txt"))) }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
