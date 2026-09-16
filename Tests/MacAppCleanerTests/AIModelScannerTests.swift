import XCTest
@testable import MacAppCleanerKit

final class AIModelScannerTests: XCTestCase {
    let fileManager = FileManager.default
    var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempDirectory)
    }

    func testOllamaManifestModelScanning() async throws {
        let manifestsDir = tempDirectory.appendingPathComponent("manifests/registry.ollama.ai/library/qwen-test")
        try fileManager.createDirectory(at: manifestsDir, withIntermediateDirectories: true)

        let manifestFile = manifestsDir.appendingPathComponent("7b")
        let manifestJSON = """
        {
            "schemaVersion": 2,
            "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
            "config": {
                "digest": "sha256:config123",
                "size": 500
            },
            "layers": [
                {
                    "mediaType": "application/vnd.ollama.image.model",
                    "digest": "sha256:layer1",
                    "size": 2500000
                },
                {
                    "mediaType": "application/vnd.ollama.image.template",
                    "digest": "sha256:layer2",
                    "size": 1500
                }
            ]
        }
        """
        try manifestJSON.data(using: .utf8)!.write(to: manifestFile)

        let scanner = AIModelScanner(
            ollamaManifestsPath: tempDirectory.appendingPathComponent("manifests"),
            huggingFaceHubPath: tempDirectory.appendingPathComponent("nonexistent_hf"),
            lmStudioPath: tempDirectory.appendingPathComponent("nonexistent_lm")
        )

        let libraries = await scanner.scanLibraries()
        XCTAssertEqual(libraries.count, 1)

        let model = try XCTUnwrap(libraries.first)
        XCTAssertEqual(model.name, "qwen-test:7b")
        XCTAssertEqual(model.category, .aiModels)
        XCTAssertEqual(model.size, 500 + 2500000 + 1500)
        XCTAssertEqual(model.riskLevel, .safe)
        XCTAssertFalse(model.isSystemProtected)
    }

    func testHuggingFaceHubModelScanning() async throws {
        let hfHubDir = tempDirectory.appendingPathComponent("huggingface/hub")
        let modelDir = hfHubDir.appendingPathComponent("models--testorg--test-llm")
        try fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true)

        let weightFile = modelDir.appendingPathComponent("model.safetensors")
        try Data(repeating: 0x42, count: 50000).write(to: weightFile)

        let scanner = AIModelScanner(
            ollamaManifestsPath: tempDirectory.appendingPathComponent("nonexistent_ollama"),
            huggingFaceHubPath: hfHubDir,
            lmStudioPath: tempDirectory.appendingPathComponent("nonexistent_lm")
        )

        let libraries = await scanner.scanLibraries()
        XCTAssertEqual(libraries.count, 1)

        let model = try XCTUnwrap(libraries.first)
        XCTAssertEqual(model.name, "testorg/test-llm")
        XCTAssertEqual(model.category, .aiModels)
        XCTAssertEqual(model.size, 50000)
        XCTAssertEqual(model.riskLevel, .safe)
    }

    func testLMStudioModelScanning() async throws {
        let lmDir = tempDirectory.appendingPathComponent("lm-studio/models")
        let modelDir = lmDir.appendingPathComponent("meta-llama-3-8b")
        try fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true)

        let ggufFile = modelDir.appendingPathComponent("llama3.gguf")
        try Data(repeating: 0x55, count: 12000).write(to: ggufFile)

        let scanner = AIModelScanner(
            ollamaManifestsPath: tempDirectory.appendingPathComponent("nonexistent_ollama"),
            huggingFaceHubPath: tempDirectory.appendingPathComponent("nonexistent_hf"),
            lmStudioPath: lmDir
        )

        let libraries = await scanner.scanLibraries()
        XCTAssertEqual(libraries.count, 1)

        let model = try XCTUnwrap(libraries.first)
        XCTAssertEqual(model.name, "lm-studio/meta-llama-3-8b")
        XCTAssertEqual(model.category, .aiModels)
        XCTAssertEqual(model.size, 12000)
        XCTAssertEqual(model.riskLevel, .safe)
    }
}
