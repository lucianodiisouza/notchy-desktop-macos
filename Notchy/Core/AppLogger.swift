import Foundation
import os

/// Log para diagnóstico: aparece no Console.app (filtrar por "Notchy") e em relatórios de crash/diagnóstico.
enum AppLogger {
    private static let log = Logger(subsystem: "com.notchy.scripts", category: "app")

    /// Editor de roteiro: abrindo script
    static func scriptEditorDidOpen(scriptId: String, title: String, bodyLength: Int) {
        log.info("ScriptEditor opened script id=\(scriptId) title=\(title) bodyLength=\(bodyLength)")
    }

    /// Editor de roteiro: script não encontrado (currentScript nil)
    static func scriptEditorScriptNotFound(scriptId: String) {
        log.warning("ScriptEditor script not found id=\(scriptId)")
    }

    /// Editor: body commit (save) para o store
    static func scriptEditorDidCommitBody(scriptId: String, bodyLength: Int) {
        log.debug("ScriptEditor committed body id=\(scriptId) bodyLength=\(bodyLength)")
    }

    /// Qualquer erro / estado inesperado
    static func error(_ message: String) {
        log.error("\(message)")
    }

    // MARK: - NSTextView lifecycle (para diagnosticar crash no makeView/updateView)

    static func nsTextMakeViewStart(textLength: Int) {
        log.info("NSText makeNSView start textLength=\(textLength)")
    }

    static func nsTextMakeViewAfterSetString() {
        log.info("NSText makeNSView after set string")
    }

    static func nsTextMakeViewAfterAttributes() {
        log.info("NSText makeNSView after apply attributes")
    }

    static func nsTextMakeViewDone() {
        log.info("NSText makeNSView done")
    }

    static func nsTextUpdateViewStart(textLength: Int) {
        log.debug("NSText updateNSView start textLength=\(textLength)")
    }

    static func nsTextUpdateViewSetString() {
        log.debug("NSText updateNSView set string")
    }

    static func nsTextUpdateViewDone() {
        log.debug("NSText updateNSView done")
    }

    static func nsTextCoordinatorFormatWrap() {
        log.debug("NSText coordinator applyWrap")
    }

    static func nsTextCoordinatorLinePrefix() {
        log.debug("NSText coordinator applyLinePrefix")
    }

    static func nsTextDidChange(length: Int) {
        log.debug("NSText textDidChange length=\(length)")
    }
}
