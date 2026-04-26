import XCTest
@testable import UltraKiosk

// MARK: - Helpers

private func makeHTTPResponse(url: URL = URL(string: "http://test.local")!,
                               statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

/// Builds a URLDataLoader that always returns the given data + status code.
private func mockLoader(data: Data, statusCode: Int = 200) -> URLDataLoader {
    { request in
        (data, makeHTTPResponse(url: request.url ?? URL(string: "http://test.local")!,
                                statusCode: statusCode))
    }
}

/// Builds a URLDataLoader that always throws the given error.
private func errorLoader(_ error: Error) -> URLDataLoader {
    { _ in throw error }
}

// MARK: - AudioManagerTests

final class AudioManagerTests: XCTestCase {

    private var sut: AudioManager!

    override func setUp() {
        super.setUp()
        sut = AudioManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - convertFloatToInt16 — boundary values

    func testConvertFloatToInt16_zero_producesZero() {
        XCTAssertEqual(sut.convertFloatToInt16(floatSamples: [0.0]), [0])
    }

    func testConvertFloatToInt16_positiveOne_producesInt16Max() {
        XCTAssertEqual(sut.convertFloatToInt16(floatSamples: [1.0]), [Int16.max])
    }

    func testConvertFloatToInt16_negativeOne_producesNegativeInt16Max() {
        // Scaling: -1.0 * 32767 = -32767  (NOT Int16.min = -32768)
        XCTAssertEqual(sut.convertFloatToInt16(floatSamples: [-1.0]), [-Int16.max])
    }

    func testConvertFloatToInt16_aboveOne_clampedToInt16Max() {
        XCTAssertEqual(sut.convertFloatToInt16(floatSamples: [2.0]), [Int16.max])
    }

    func testConvertFloatToInt16_belowMinusOne_clampedToNegativeInt16Max() {
        XCTAssertEqual(sut.convertFloatToInt16(floatSamples: [-2.0]), [-Int16.max])
    }

    func testConvertFloatToInt16_largePositive_clampedToInt16Max() {
        XCTAssertEqual(sut.convertFloatToInt16(floatSamples: [100.0]), [Int16.max])
    }

    // MARK: - convertFloatToInt16 — scaling

    func testConvertFloatToInt16_halfPositive_correctScaling() {
        let expected = Int16(0.5 * Float(Int16.max))
        XCTAssertEqual(sut.convertFloatToInt16(floatSamples: [0.5]), [expected])
    }

    func testConvertFloatToInt16_halfNegative_correctScaling() {
        let expected = Int16(-0.5 * Float(Int16.max))
        XCTAssertEqual(sut.convertFloatToInt16(floatSamples: [-0.5]), [expected])
    }

    func testConvertFloatToInt16_quarterPositive_correctScaling() {
        let expected = Int16(0.25 * Float(Int16.max))
        XCTAssertEqual(sut.convertFloatToInt16(floatSamples: [0.25]), [expected])
    }

    // MARK: - convertFloatToInt16 — multi-sample & edge cases

    func testConvertFloatToInt16_emptyInput_returnsEmpty() {
        XCTAssertTrue(sut.convertFloatToInt16(floatSamples: []).isEmpty)
    }

    func testConvertFloatToInt16_multipleValues_correctCount() {
        let result = sut.convertFloatToInt16(floatSamples: [0.0, 1.0, -1.0, 0.5, -0.5])
        XCTAssertEqual(result.count, 5)
    }

    func testConvertFloatToInt16_multipleValues_correctOrder() {
        let result = sut.convertFloatToInt16(floatSamples: [0.0, 1.0, -1.0])
        XCTAssertEqual(result[0], 0)
        XCTAssertEqual(result[1], Int16.max)
        XCTAssertEqual(result[2], -Int16.max)
    }

    func testConvertFloatToInt16_singleSample_returnsSingleElement() {
        XCTAssertEqual(sut.convertFloatToInt16(floatSamples: [0.3]).count, 1)
    }

    // MARK: - sendHomeAssistantConversation — success

    func testSendConversation_validResponse_extractsSpeechText() async throws {
        let json = """
        {
          "response": {
            "speech": {
              "plain": {
                "speech": "Lights turned on"
              }
            }
          }
        }
        """
        let result = try await sut.sendHomeAssistantConversation(
            text: "turn on the lights",
            language: "en",
            urlLoader: mockLoader(data: Data(json.utf8))
        )
        XCTAssertEqual(result, "Lights turned on")
    }

    func testSendConversation_emptyResponseText_returnsEmptyString() async throws {
        let json = """
        {"response":{"speech":{"plain":{"speech":""}}}}
        """
        let result = try await sut.sendHomeAssistantConversation(
            text: "test",
            language: "de",
            urlLoader: mockLoader(data: Data(json.utf8))
        )
        XCTAssertEqual(result, "")
    }

    // MARK: - sendHomeAssistantConversation — HTTP errors

    func testSendConversation_http401_throwsHTTPError401() async {
        do {
            _ = try await sut.sendHomeAssistantConversation(
                text: "test", language: "de",
                urlLoader: mockLoader(data: Data(), statusCode: 401)
            )
            XCTFail("Expected APIError.httpError(401)")
        } catch APIError.httpError(let code) {
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendConversation_http500_throwsHTTPError500() async {
        do {
            _ = try await sut.sendHomeAssistantConversation(
                text: "test", language: "de",
                urlLoader: mockLoader(data: Data(), statusCode: 500)
            )
            XCTFail("Expected APIError.httpError(500)")
        } catch APIError.httpError(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendConversation_http404_throwsHTTPError404() async {
        do {
            _ = try await sut.sendHomeAssistantConversation(
                text: "test", language: "de",
                urlLoader: mockLoader(data: Data(), statusCode: 404)
            )
            XCTFail("Expected APIError.httpError(404)")
        } catch APIError.httpError(let code) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendConversation_http200_doesNotThrow() async throws {
        let json = """
        {"response":{"speech":{"plain":{"speech":"ok"}}}}
        """
        _ = try await sut.sendHomeAssistantConversation(
            text: "test", language: "de",
            urlLoader: mockLoader(data: Data(json.utf8), statusCode: 200)
        )
    }

    func testSendConversation_http299_doesNotThrow() async throws {
        // 299 is in the valid 200–299 range
        let json = """
        {"response":{"speech":{"plain":{"speech":"ok"}}}}
        """
        _ = try await sut.sendHomeAssistantConversation(
            text: "test", language: "de",
            urlLoader: mockLoader(data: Data(json.utf8), statusCode: 299)
        )
    }

    // MARK: - sendHomeAssistantConversation — malformed JSON

    func testSendConversation_notJSON_throwsInvalidResponse() async {
        do {
            _ = try await sut.sendHomeAssistantConversation(
                text: "test", language: "de",
                urlLoader: mockLoader(data: Data("not json at all".utf8))
            )
            XCTFail("Expected APIError.invalidResponse")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendConversation_missingResponseKey_throwsInvalidResponse() async {
        let json = """
        {"other": "data"}
        """
        do {
            _ = try await sut.sendHomeAssistantConversation(
                text: "test", language: "de",
                urlLoader: mockLoader(data: Data(json.utf8))
            )
            XCTFail("Expected APIError.invalidResponse")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendConversation_missingSpeechKey_throwsInvalidResponse() async {
        let json = """
        {"response": {"no_speech": {}}}
        """
        do {
            _ = try await sut.sendHomeAssistantConversation(
                text: "test", language: "de",
                urlLoader: mockLoader(data: Data(json.utf8))
            )
            XCTFail("Expected APIError.invalidResponse")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendConversation_missingPlainKey_throwsInvalidResponse() async {
        let json = """
        {"response": {"speech": {"no_plain": {}}}}
        """
        do {
            _ = try await sut.sendHomeAssistantConversation(
                text: "test", language: "de",
                urlLoader: mockLoader(data: Data(json.utf8))
            )
            XCTFail("Expected APIError.invalidResponse")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendConversation_emptyJSON_throwsInvalidResponse() async {
        let json = "{}"
        do {
            _ = try await sut.sendHomeAssistantConversation(
                text: "test", language: "de",
                urlLoader: mockLoader(data: Data(json.utf8))
            )
            XCTFail("Expected APIError.invalidResponse")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - sendHomeAssistantConversation — network error

    func testSendConversation_networkError_propagatesError() async {
        let networkError = URLError(.notConnectedToInternet)
        do {
            _ = try await sut.sendHomeAssistantConversation(
                text: "test", language: "de",
                urlLoader: errorLoader(networkError)
            )
            XCTFail("Expected URLError to be thrown")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendConversation_timeoutError_propagatesError() async {
        let timeoutError = URLError(.timedOut)
        do {
            _ = try await sut.sendHomeAssistantConversation(
                text: "test", language: "de",
                urlLoader: errorLoader(timeoutError)
            )
            XCTFail("Expected URLError to be thrown")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - APIError.errorDescription

    func testAPIError_invalidURL_localizedDescription() {
        XCTAssertEqual(APIError.invalidURL.errorDescription, "Invalid URL")
    }

    func testAPIError_httpError_containsStatusCode() {
        let error = APIError.httpError(403)
        XCTAssertTrue(error.errorDescription?.contains("403") ?? false)
    }

    func testAPIError_invalidResponse_localizedDescription() {
        XCTAssertEqual(APIError.invalidResponse.errorDescription, "Invalid response format")
    }

    func testAPIError_equatable_sameCase_isEqual() {
        XCTAssertEqual(APIError.invalidURL, APIError.invalidURL)
        XCTAssertEqual(APIError.invalidResponse, APIError.invalidResponse)
        XCTAssertEqual(APIError.httpError(404), APIError.httpError(404))
    }

    func testAPIError_equatable_differentHTTPCodes_notEqual() {
        XCTAssertNotEqual(APIError.httpError(404), APIError.httpError(500))
    }

    func testAPIError_equatable_differentCases_notEqual() {
        XCTAssertNotEqual(APIError.invalidURL, APIError.invalidResponse)
    }
}
