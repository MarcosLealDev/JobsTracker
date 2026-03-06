//
//  OllamaService.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import Foundation

// Explicitly an actor to opt out of the project-wide @MainActor default,
// ensuring network I/O runs on the cooperative thread pool.
actor OllamaService {

    static let shared = OllamaService()

    private let baseURL = URL(string: "http://localhost:11434")!
    private let modelName = "llama3.2:latest"

    // MARK: - Public API

    func analyze(jobDescription: String) async throws -> JobAnalysisResult {
        let prompt = buildPrompt(for: jobDescription)
        let requestBody = OllamaGenerateRequest(
            model: modelName,
            prompt: prompt,
            stream: false,
            format: "json"
        )

        let endpoint = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(statusCode: httpResponse.statusCode)
        }

        let ollamaResponse = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
        guard ollamaResponse.done else {
            throw OllamaError.incomplete
        }

        return try parseResponse(ollamaResponse.response)
    }

    // MARK: - Prompt

    private func buildPrompt(for description: String) -> String {
        """
        You are a structured data extractor. Analyze the job posting below and return \
        ONLY valid JSON with exactly these fields (use null if the information is not present):
        {
          "companyName": "string or null",
          "companyAddress": "string or null",
          "companyWebsite": "string or null",
          "jobPosition": "string or null",
          "technicalSkills": ["skill1", "skill2"]
        }
        No explanation, no markdown, no text outside the JSON object.

        Job posting:
        \(description)
        """
    }

    // MARK: - 3-Tier JSON Parsing

    func parseResponse(_ rawString: String) throws -> JobAnalysisResult {
        // Tier 1: Direct parse
        if let data = rawString.data(using: .utf8),
           let result = try? JSONDecoder().decode(JobAnalysisResult.self, from: data) {
            return result
        }

        // Tier 2: Brace-balanced extraction
        if let extracted = extractBalancedJSON(from: rawString),
           let data = extracted.data(using: .utf8),
           let result = try? JSONDecoder().decode(JobAnalysisResult.self, from: data) {
            return result
        }

        // Tier 3: Regex field salvage — returns partial result, never throws
        return salvageFields(from: rawString)
    }

    private func extractBalancedJSON(from text: String) -> String? {
        var depth = 0
        var startIdx: String.Index?

        for idx in text.indices {
            switch text[idx] {
            case "{":
                if depth == 0 { startIdx = idx }
                depth += 1
            case "}":
                depth -= 1
                if depth == 0, let start = startIdx {
                    return String(text[start...idx])
                }
            default:
                break
            }
        }
        return nil
    }

    private func salvageFields(from text: String) -> JobAnalysisResult {
        func extractString(_ key: String) -> String? {
            let pattern = #""\#(key)"\s*:\s*"([^"]+)""#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text)
            else { return nil }
            return String(text[range])
        }

        var skills: [String] = []
        let arrayPattern = #""technicalSkills"\s*:\s*\[([^\]]*)\]"#
        if let arrayRegex = try? NSRegularExpression(pattern: arrayPattern),
           let arrayMatch = arrayRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let arrayRange = Range(arrayMatch.range(at: 1), in: text) {
            let inner = String(text[arrayRange])
            let itemRegex = try? NSRegularExpression(pattern: #""([^"]+)""#)
            let matches = itemRegex?.matches(in: inner, range: NSRange(inner.startIndex..., in: inner)) ?? []
            skills = matches.compactMap { m in
                guard let r = Range(m.range(at: 1), in: inner) else { return nil }
                return String(inner[r])
            }
        }

        return JobAnalysisResult(
            companyName: extractString("companyName"),
            companyAddress: extractString("companyAddress"),
            companyWebsite: extractString("companyWebsite"),
            jobPosition: extractString("jobPosition"),
            technicalSkills: skills
        )
    }
}

// MARK: - Network Types

// nonisolated conformances prevent actor-isolation warnings when these types
// are used inside OllamaService (which is not on the MainActor).
private struct OllamaGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
    let format: String

    private enum CodingKeys: String, CodingKey { case model, prompt, stream, format }

    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(model,  forKey: .model)
        try c.encode(prompt, forKey: .prompt)
        try c.encode(stream, forKey: .stream)
        try c.encode(format, forKey: .format)
    }
}

private struct OllamaGenerateResponse: Decodable {
    let response: String
    let done: Bool

    private enum CodingKeys: String, CodingKey { case response, done }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        response = try c.decode(String.self, forKey: .response)
        done     = try c.decode(Bool.self,   forKey: .done)
    }
}

struct JobAnalysisResult: Decodable {
    let companyName: String?
    let companyAddress: String?
    let companyWebsite: String?
    let jobPosition: String?
    let technicalSkills: [String]

    nonisolated init(
        companyName: String?,
        companyAddress: String?,
        companyWebsite: String?,
        jobPosition: String?,
        technicalSkills: [String]
    ) {
        self.companyName = companyName
        self.companyAddress = companyAddress
        self.companyWebsite = companyWebsite
        self.jobPosition = jobPosition
        self.technicalSkills = technicalSkills
    }

    private enum CodingKeys: String, CodingKey {
        case companyName, companyAddress, companyWebsite, jobPosition, technicalSkills
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        companyName     = try c.decodeIfPresent(String.self, forKey: .companyName)
        companyAddress  = try c.decodeIfPresent(String.self, forKey: .companyAddress)
        companyWebsite  = try c.decodeIfPresent(String.self, forKey: .companyWebsite)
        jobPosition     = try c.decodeIfPresent(String.self, forKey: .jobPosition)
        technicalSkills = (try? c.decode([String].self, forKey: .technicalSkills)) ?? []
    }
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case incomplete

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Received an invalid response from Ollama."
        case .httpError(let code):
            return "Ollama returned HTTP \(code). Is Ollama running on port 11434?"
        case .incomplete:
            return "Ollama response was incomplete. Please try again."
        }
    }
}
