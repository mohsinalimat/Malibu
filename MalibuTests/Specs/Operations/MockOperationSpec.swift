@testable import Malibu
import Quick
import Nimble
import When

class MockOperationSpec: QuickSpec {

  override func spec() {
    describe("MockOperation") {
      var operation: MockOperation!
      var mock: Mock!
      var request: Requestable!
      var urlRequest: URLRequest!
      var response: HTTPURLResponse!
      var ride: Ride!
      let data = "test".data(using: String.Encoding.utf32)
      let error = Error.JSONArraySerializationFailed

      beforeEach {
        request = GETRequest()
        URLRequest = try! request.toURLRequest()
        response = HTTPURLResponse(url: URL(string: "http://hyper.no")!,
          statusCode: 200, httpVersion: "HTTP/2.0", headerFields: nil)!
        ride = Ride()
      }

      describe("#init") {
        beforeEach {
          mock = Mock(request: request, response: response, data: data, error: error)
          operation = MockOperation(mock: mock, URLRequest: URLRequest, ride: ride)
        }

        it("sets properties") {
          expect(operation.mock === mock).to(beTrue())
          expect(operation.URLRequest).to(equal(URLRequest))
          expect(operation.ride === ride).to(beTrue())
        }
      }

      describe("#execute") {
        context("when response is nil") {
          it("rejects promise with an error") {
            let expectation = self.expectation(withDescription: "No response failure")

            mock = Mock(request: request, response: nil, data: data, error: nil)
            operation = MockOperation(mock: mock, URLRequest: urlRequest, ride: ride)

            operation.ride.fail({ error in
              expect(error as! Error == Error.NoResponseReceived).to(beTrue())
              expectation.fulfill()
            })

            operation.execute()

            self.waitForExpectations(withTimeout: 4.0, handler:nil)
          }
        }

        context("when there is an error") {
          it("rejects promise with an error") {
            let expectation = self.expectation(withDescription: "Error failure")

            mock = Mock(request: request, response: response, data: data, error: error)
            operation = MockOperation(mock: mock, URLRequest: urlRequest, ride: ride)

            operation.ride.fail({ error in
              expect(error as! Error == Error.JSONArraySerializationFailed).to(beTrue())
              expectation.fulfill()
            })

            operation.execute()

            self.waitForExpectations(withTimeout: 4.0, handler:nil)
          }
        }

        context("when there is no data") {
          it("rejects promise with an error") {
            let expectation = self.expectation(withDescription: "No data failure")

            mock = Mock(request: request, response: response, data: nil, error: nil)
            operation = MockOperation(mock: mock, URLRequest: urlRequest, ride: ride)

            operation.ride.fail({ error in
              expect(error as! Error == Error.NoDataInResponse).to(beTrue())
              expectation.fulfill()
            })

            operation.execute()

            self.waitForExpectations(withTimeout: 4.0, handler:nil)
          }
        }

        context("when validation succeeded") {
          it("resolves promise with a result") {
            let expectation = self.expectation(withDescription: "Validation succeeded")

            mock = Mock(request: request, response: response, data: data, error: nil)
            operation = MockOperation(mock: mock, URLRequest: urlRequest, ride: ride)

            operation.ride.done({ result in
              expect(result.data).to(equal(operation.mock.data))
              expect(result.request).to(equal(operation.URLRequest))
              expect(result.response).to(equal(operation.mock.response))

              expectation.fulfill()
            })

            operation.execute()

            self.waitForExpectations(withTimeout: 4.0, handler:nil)
          }
        }
      }
    }
  }
}
