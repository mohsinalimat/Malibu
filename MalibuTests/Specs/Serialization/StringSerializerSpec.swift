@testable import Malibu
import Quick
import Nimble

class StringSerializerSpec: QuickSpec {

  override func spec() {
    describe("StringSerializer") {
      var serializer: StringSerializer!
      let url = URL(string: "http://api.loc")!
      let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/2.0", headerFields: nil)!

      beforeEach {
        serializer = StringSerializer()
      }

      describe("#init") {
        it("sets default encoding") {
          expect(serializer.encoding).to(beNil())
        }

        it("sets parameter encoding to the instance var") {
          serializer = StringSerializer(encoding: String.Encoding.utf8)
          expect(serializer.encoding).to(equal(String.Encoding.utf8))
        }
      }

      describe("#serialize:data") {
        context("when there is no data in response") {
          it("throws an error") {
            let data = Data()
            expect {
              try serializer.serialize(data: data, response: response)
              }.to(throwError(NetworkError.noDataInResponse))
          }
        }

        context("when string could not be serialized with specified encoding") {
          it("throws an error") {
            serializer = StringSerializer(encoding: String.Encoding.utf8)
            let string = "string"
            let data = string.data(using: String.Encoding.utf32)!

            expect {
              try serializer.serialize(data: data, response: response)
              }.to(throwError(NetworkError.stringSerializationFailed(String.Encoding.utf8.rawValue)))
          }
        }

        context("when string could not be serialized with an encoding from the response") {
          it("throws an error") {
            let response = HTTPURLResponse(url: url, mimeType: nil, expectedContentLength: 10, textEncodingName: "utf-32")
            let string = "string"
            let data = string.data(using: String.Encoding.utf16BigEndian)!

            expect {
              try serializer.serialize(data: data, response: response)
              }.to(throwError(NetworkError.stringSerializationFailed(String.Encoding.utf32.rawValue)))
          }
        }

        context("when response status code is 204 No Content") {
          it("does not throw an error and returns an empty string") {
            let response = HTTPURLResponse(url: url, statusCode: 204,
              httpVersion: "HTTP/2.0", headerFields: nil)!
            let data = Data()
            var result: String?

            expect{ result = try serializer.serialize(data: data, response: response) }.toNot(throwError())
            expect(result).to(equal(""))
          }
        }

        context("when serialization succeeded") {
          it("does not throw an error and returns result") {
            let string = "string"
            let data = string.data(using: String.Encoding.utf8)!
            var result: String?

            expect{ result = try serializer.serialize(data: data, response: response) }.toNot(throwError())
            expect(result).to(equal(string))
          }
        }
      }
    }
  }
}
