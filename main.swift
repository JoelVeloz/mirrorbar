// MirrorBar — barra de menú nativa que muestra el estado de un espejo (carpeta o disco virtual)
// y expulsa el disco del espejo de forma segura.
// La primera vez pide elegir ORIGEN y ESPEJO y lo guarda (UserDefaults: com.joelveloz.mirrorbar).
// Opcional: archivo de estado de tu script de sync con líneas "Status:" y "Last sync:"
//   (por defecto: "<carpeta del espejo>/<nombre> - LAST SYNC.txt").
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
func path(_ k: String) -> String { (cfg.string(forKey: k) ?? "").replacingOccurrences(of: "~", with: NSHomeDirectory()) }
var configured: Bool { !path("Source").isEmpty && !path("Mirror").isEmpty }
func volumeOf(_ p: String) -> String {            // "/Volumes/X/..." -> "/Volumes/X"
    let c = (p as NSString).pathComponents
    return c.count > 2 && c[1] == "Volumes" ? "/Volumes/" + c[2] : (p as NSString).deletingLastPathComponent
}
func statusFile() -> String {
    let m = path("Mirror"); if !path("StatusFile").isEmpty { return path("StatusFile") }
    let name = ((m as NSString).lastPathComponent as NSString).deletingPathExtension
    return ((m as NSString).deletingLastPathComponent as NSString).appendingPathComponent("\(name) - LAST SYNC.txt")
}
func choose(_ title: String) -> String? {
    let p = NSOpenPanel(); p.message = title; p.prompt = "Elegir"
    p.canChooseFiles = true; p.canChooseDirectories = true; p.allowsMultipleSelection = false
    NSApp.activate(ignoringOtherApps: true)
    return p.runModal() == .OK ? p.url?.path : nil
}

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
    var lastD: Int64 = -1, lastT = Date(), rate = 0.0          // bytes/s (promedio suavizado) para el ETA
    func applicationDidFinishLaunching(_ n: Notification) {
        let img = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "MirrorBar"); img?.isTemplate = true
        item.button?.image = img; item.button?.title = " …"; item.isVisible = true   // visible al instante
        item.autosaveName = "MirrorBar"
        refresh()
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in self.refresh() }
    }
    @objc func refresh() {
        guard configured else { setup(); return }
        let src = path("Source"), dst = path("Mirror"), txt = statusFile()
        DispatchQueue.global().async {
            let connected = FileManager.default.fileExists(atPath: volumeOf(dst))
            let s = size(src), d = connected ? size(dst) : 0
            let pct = s > 0 ? min(100, Int(d * 100 / s)) : 0
            let now = Date(), dt = now.timeIntervalSince(self.lastT)
            if self.lastD >= 0, dt > 5, d >= self.lastD {
                let r = Double(d - self.lastD) / dt
                self.rate = self.rate == 0 ? r : 0.7 * self.rate + 0.3 * r
            }
            self.lastD = d; self.lastT = now
            let left = Double(max(0, s - d))
            let eta: String = {
                guard self.rate > 50_000, left > 0 else { return left > 0 ? "calculando…" : "—" }
                let m = Int(left / self.rate / 60)
                return m < 1 ? "< 1 min" : m < 60 ? "\(m) min" : "\(m / 60) h \(m % 60) min"
            }()
            let status = (try? String(contentsOfFile: txt, encoding: .utf8)) ?? ""
            let st = field(status, "Status:"), last = field(status, "Last sync:")
            let syncing = st == "—" ? pct < 100 : st.contains("SYNCING")
            let (sym, label) = !connected ? ("externaldrive", "") :
                syncing ? ("arrow.triangle.2.circlepath", " \(pct)%" + (eta.hasSuffix("min") ? " · " + eta.replacingOccurrences(of: " min", with: "m").replacingOccurrences(of: " h ", with: "h ") : "")) :
                st.contains("FAILED")  ? ("externaldrive.badge.exclamationmark", "") : ("externaldrive.badge.checkmark", "")
            DispatchQueue.main.async {
                let img = NSImage(systemSymbolName: sym, accessibilityDescription: "MirrorBar"); img?.isTemplate = true
                self.item.button?.image = img; self.item.button?.imagePosition = .imageLeading; self.item.button?.title = label
                let m = NSMenu()
                for t in [connected ? "Estado: \(st)" : "Disco del espejo no conectado",
                          "Última sincronización: \(last)",
                          String(format: "Copiado: %.0f de %.0f GB (%d%%)", Double(d)/1e9, Double(s)/1e9, pct),
                          String(format: "Velocidad: %.1f MB/s · Tiempo restante: ", self.rate/1e6) + eta] {
                    m.addItem(withTitle: t, action: nil, keyEquivalent: "")
                }
                m.addItem(.separator())
                let o = m.addItem(withTitle: "Abrir estado", action: #selector(self.open), keyEquivalent: "o"); o.target = self
                let r = m.addItem(withTitle: "Actualizar", action: #selector(self.refresh), keyEquivalent: "r"); r.target = self
                if connected { let e = m.addItem(withTitle: "Expulsar disco de forma segura…", action: #selector(self.eject), keyEquivalent: "e"); e.target = self }
                let c = m.addItem(withTitle: "Configurar…", action: #selector(self.setup), keyEquivalent: ","); c.target = self
                m.addItem(withTitle: "Salir", action: #selector(NSApp.terminate), keyEquivalent: "q")
                self.item.menu = m
            }
        }
    }
    @objc func eject() {
        let vol = path("Volume").isEmpty ? volumeOf(path("Mirror")) : path("Volume"), name = (vol as NSString).lastPathComponent
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
    @objc func open() { NSWorkspace.shared.open(URL(fileURLWithPath: statusFile())) }
    @objc func setup() {
        guard let src = choose("1/2 — Elige el ORIGEN (la carpeta o disco virtual principal)"),
              let dst = choose("2/2 — Elige el ESPEJO (la copia en el disco de respaldo)") else {
            if !configured { item.button?.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
                let m = NSMenu(); let c = m.addItem(withTitle: "Configurar…", action: #selector(setup), keyEquivalent: ","); c.target = self
                m.addItem(withTitle: "Salir", action: #selector(NSApp.terminate), keyEquivalent: "q"); item.menu = m }
            return }
        cfg.set(src, forKey: "Source"); cfg.set(dst, forKey: "Mirror")
        notify("MirrorBar configurado", "Origen: \((src as NSString).lastPathComponent) → Espejo: \((dst as NSString).lastPathComponent)")
        refresh()
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
