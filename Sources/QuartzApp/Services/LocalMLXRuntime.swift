import Foundation

enum LocalMLXRuntimeError: LocalizedError {
    case appleSiliconRequired
    case executableMissing
    case modelMissing
    case invalidEndpoint
    case unexpectedServer
    case launchFailed
    case startupTimedOut

    var errorDescription: String? {
        switch self {
        case .appleSiliconRequired:
            "Le modèle local nécessite un Mac avec une puce Apple Silicon."
        case .executableMissing:
            "Le moteur MLX-LM n’est pas encore installé sur ce Mac."
        case .modelMissing:
            "Le petit modèle français de Quartz est introuvable."
        case .invalidEndpoint:
            "L’adresse locale de MLX est invalide."
        case .unexpectedServer:
            "Le port local de Quartz est déjà utilisé par un autre serveur de modèles."
        case .launchFailed:
            "Quartz n’a pas réussi à démarrer son moteur local."
        case .startupTimedOut:
            "Le modèle local met trop de temps à démarrer. Réessaie dans un instant."
        }
    }
}

/// Démarre MLX-LM sans Terminal et ne coupe que le processus créé par Quartz.
@MainActor
final class LocalMLXRuntime {
    static let shared = LocalMLXRuntime()

    private var process: Process?
    private var logHandle: FileHandle?

    private init() {}

    var isRuntimeInstalled: Bool {
#if arch(arm64)
        mlxExecutableURL() != nil && fusedModelURL() != nil
#else
        false
#endif
    }

    func ensureRunning(configuration: LLMConnectionConfiguration) async throws {
        switch await serverState(endpoint: configuration.endpoint) {
        case .compatible:
            return
        case .incompatible:
            throw LocalMLXRuntimeError.unexpectedServer
        case .unreachable:
            break
        }

        if process?.isRunning != true {
            try start(configuration: configuration)
        }

        for _ in 0..<120 {
            switch await serverState(endpoint: configuration.endpoint) {
            case .compatible:
                return
            case .incompatible:
                stop()
                throw LocalMLXRuntimeError.unexpectedServer
            case .unreachable:
                break
            }
            if process?.isRunning == false { throw LocalMLXRuntimeError.launchFailed }
            try await Task.sleep(for: .milliseconds(250))
        }

        stop()
        throw LocalMLXRuntimeError.startupTimedOut
    }

    func stop() {
        guard let process else { return }
        if process.isRunning {
            process.terminate()
        }
        self.process = nil
        try? logHandle?.close()
        logHandle = nil
    }

    private func start(configuration: LLMConnectionConfiguration) throws {
#if arch(arm64)
        guard let executable = mlxExecutableURL() else {
            throw LocalMLXRuntimeError.executableMissing
        }
        guard let model = fusedModelURL() else {
            throw LocalMLXRuntimeError.modelMissing
        }
        guard let port = localPort(from: configuration.endpoint) else {
            throw LocalMLXRuntimeError.invalidEndpoint
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "--model", model.path,
            "--host", "127.0.0.1",
            "--port", String(port),
        ]

        let logURL = applicationSupportURL().appendingPathComponent("mlx.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let handle = try? FileHandle(forWritingTo: logURL)
        try? handle?.truncate(atOffset: 0)
        process.standardOutput = handle ?? FileHandle.nullDevice
        process.standardError = handle ?? FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            try? handle?.close()
            throw LocalMLXRuntimeError.launchFailed
        }

        self.logHandle = handle
        self.process = process
#else
        throw LocalMLXRuntimeError.appleSiliconRequired
#endif
    }

    private enum ServerState {
        case unreachable
        case compatible
        case incompatible
    }

    private struct ModelList: Decodable {
        struct Model: Decodable {
            let id: String
        }

        let data: [Model]
    }

    private func serverState(endpoint: String) async -> ServerState {
        guard let url = modelsEndpoint(from: endpoint) else { return .unreachable }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else { return .unreachable }

        guard
            let modelList = try? JSONDecoder().decode(ModelList.self, from: data),
            modelList.data.count == 1,
            let identifier = modelList.data.first?.id.lowercased()
        else { return .incompatible }

        let recognized = identifier == "default_model"
            || identifier.contains("quartz-fr")
            || identifier.contains("smollm2-135m")
        return recognized ? .compatible : .incompatible
    }

    private func modelsEndpoint(from endpoint: String) -> URL? {
        guard var components = URLComponents(string: endpoint),
              components.scheme == "http",
              let host = components.host?.lowercased(),
              ["127.0.0.1", "localhost", "::1"].contains(host)
        else { return nil }

        let cleanPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !cleanPath.hasSuffix("models") {
            components.path = "/" + ([cleanPath, "models"].filter { !$0.isEmpty }.joined(separator: "/"))
        }
        return components.url
    }

    private func localPort(from endpoint: String) -> Int? {
        guard let components = URLComponents(string: endpoint),
              components.scheme == "http",
              let host = components.host?.lowercased(),
              ["127.0.0.1", "localhost", "::1"].contains(host)
        else { return nil }
        return components.port ?? 80
    }

    private func mlxExecutableURL() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        var candidates = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent("mlx_lm.server") }

        let home = FileManager.default.homeDirectoryForCurrentUser
        candidates += [
            home.appendingPathComponent(".local/bin/mlx_lm.server"),
            URL(fileURLWithPath: "/opt/homebrew/bin/mlx_lm.server"),
            URL(fileURLWithPath: "/usr/local/bin/mlx_lm.server"),
            URL(fileURLWithPath: "/Library/Frameworks/Python.framework/Versions/Current/bin/mlx_lm.server"),
        ]

        let versions = URL(fileURLWithPath: "/Library/Frameworks/Python.framework/Versions")
        if let children = try? FileManager.default.contentsOfDirectory(
            at: versions,
            includingPropertiesForKeys: nil
        ) {
            candidates += children.map { $0.appendingPathComponent("bin/mlx_lm.server") }
        }

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func fusedModelURL() -> URL? {
        let manager = FileManager.default
        var candidates: [URL] = []

        if let override = ProcessInfo.processInfo.environment["QUARTZ_MLX_MODEL"] {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let resources = QuartzResources.resourceURL {
            // SwiftPM aplatit les ressources traitées à la racine du bundle.
            candidates.append(resources)
            candidates.append(resources.appendingPathComponent("MLX/quartz-fr"))
            candidates.append(resources.appendingPathComponent("quartz-fr"))
        }

        // Chemin de développement du paquet Swift. Dans le futur .app, le modèle
        // sera copié dans Resources et sera trouvé par les deux candidats précédents.
        let sourceFile = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(
            projectRoot.appendingPathComponent("Sources/QuartzApp/Resources/MLX/quartz-fr")
        )

        return candidates.first {
            manager.fileExists(atPath: $0.appendingPathComponent("model.safetensors").path)
        }
    }

    private func applicationSupportURL() -> URL {
        let manager = FileManager.default
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("Quartz", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
