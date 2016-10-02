@testable import Malibu
import Quick
import Nimble

class RequestableSpec: QuickSpec {

  override func spec() {
    describe("Requestable") {
      var request: Requestable!
      var urlRequest: URLRequest!

      beforeEach {
        request = POSTRequest(parameters: ["key": "value"], headers: ["key": "value"])
        ETagStorage().clear()
      }

      afterSuite {
        do {
          try FileManager.defaultManager().removeItemAtPath(Utils.storageDirectory)
        } catch {}
      }

      describe("#storePolicy") {
        it("has default value") {
          expect(request.storePolicy).to(equal(StorePolicy.Unspecified))
        }
      }

      describe("#cachePolicy") {
        it("has default value") {
          expect(request.cachePolicy).to(equal(NSURLRequest.CachePolicy.UseProtocolCachePolicy))
        }
      }

      describe("#toURLRequest") {
        context("when request URL is invalid") {
          it("throws an error") {
            request.message.resource = "not an URL"
            expect{ try request.toURLRequest() }.to(throwError(Error.InvalidRequestURL))
          }
        }

        context("when there are no errors") {
          context("without base URL") {
            it("does not throw an error and returns created NSMutableURLRequest") {
              expect{ urlRequest = try request.toURLRequest() }.toNot(throwError())
              expect(URLRequest.URL).to(equal(URL(string: request.message.resource.URLString)))
              expect(urlRequest.httpMethod).to(equal(Method.POST.rawValue))
              expect(urlRequest.cachePolicy).to(equal(request.cachePolicy))
              expect(urlRequest.allHTTPHeaderFields?["Content-Type"]).to(equal(request.contentType.header))
              expect(urlRequest.HTTPBody).to(equal(
                try! request.contentType.encoder?.encode(request.message.parameters)))
              expect(urlRequest.allHTTPHeaderFields?["key"]).to(equal("value"))
            }
          }

          context("with base URL") {
            it("does not throw an error and returns created NSMutableURLRequest") {
              request.message.resource = "/about"

              expect { urlRequest = try request.toURLRequest("http://hyper.no") }.toNot(throwError())
              expect(urlRequest.url?.absoluteString).to(equal("http://hyper.no/about"))
            }
          }

          context("with additional headers") {
            it("returns created NSMutableURLRequest with new header added") {
              let headers = ["foo": "bar", "key": "bar"]
              request.message.resource = "/about"

              expect { urlRequest = try request.toURLRequest("http://hyper.no", additionalHeaders: headers) }.toNot(throwError())

              expect(urlRequest.allHTTPHeaderFields?["foo"]).to(equal("bar"))
              expect(urlRequest.allHTTPHeaderFields?["key"]).to(equal("value"))
            }
          }

          context("with ETagPolicy enabled") {
            beforeEach {
              request = GETRequest(parameters: ["key": "value"], headers: ["key": "value"])
            }

            context("when we have ETag stored") {
              it("adds If-None-Match header") {
                let storage = ETagStorage()
                let etag = "W/\"123456789"

                storage.add(etag, forKey: request.etagKey())

                let urlRequest = try! request.toURLRequest()

                expect(urlRequest.allHTTPHeaderFields?["If-None-Match"]).to(equal(etag))
              }
            }

            context("when we do not have ETag stored") {
              it("does not add If-None-Match header") {
                let urlRequest = try! request.toURLRequest()
                expect(urlRequest.allHTTPHeaderFields?["If-None-Match"]).to(beNil())
              }
            }
          }

          context("with ETagPolicy disabled") {
            context("when we have ETag stored") {
              it("does not add If-None-Match header") {
                let storage = ETagStorage()
                let etag = "W/\"123456789"

                storage.add(etag, forKey: request.etagKey())

                let urlRequest = try! request.toURLRequest()

                expect(urlRequest.allHTTPHeaderFields?["If-None-Match"]).to(beNil())
              }
            }

            context("when we do not have ETag stored") {
              it("does not add If-None-Match header") {
                let urlRequest = try! request.toURLRequest()
                expect(urlRequest.allHTTPHeaderFields?["If-None-Match"]).to(beNil())
              }
            }
          }

          context("with Query content type") {
            beforeEach {
              request = GETRequest(parameters: ["key": "value", "number": 1])
            }

            it("does not set Content-Type header") {
              expect{ urlRequest = try request.toURLRequest() }.toNot(throwError())
              expect(urlRequest.allHTTPHeaderFields?["Content-Type"]).to(beNil())
            }

            it("does not set body") {
              expect{ urlRequest = try request.toURLRequest() }.toNot(throwError())
              expect(urlRequest.httpBody).to(beNil())
            }
          }

          context("with MultipartFormData content type") {
            beforeEach {
              request = POSTRequest(parameters: ["key": "value", "number": 1],
                contentType: .MultipartFormData)
            }

            it("sets Content-Type header") {
              expect{ urlRequest = try request.toURLRequest() }.toNot(throwError())
              expect(urlRequest.allHTTPHeaderFields?["Content-Type"]).to(
                equal("multipart/form-data; boundary=\(boundary)")
              )
            }

            it("sets Content-Length header") {
              expect{ urlRequest = try request.toURLRequest() }.toNot(throwError())
              expect(urlRequest.allHTTPHeaderFields?["Content-Length"]).to(
                equal("\(urlRequest.httpBody!.count)")
              )
            }
          }
        }

        describe("#buildURL") {
          context("when request URL is invalid") {
            it("throws an error") {
              expect{ try request.buildURL("not an URL") }.to(throwError(Error.InvalidRequestURL))
            }
          }

          context("when content type is not Query") {
            beforeEach {
              request = POSTRequest(parameters: ["key": "value"])
            }

            it("returns URL") {
              let urlString = "http://hyper.no"
              let result = URL(string: urLString)
              expect(try! request.buildURL(urLString)).to(equal(result))
            }
          }

          context("when content type is Query but there are no parameters") {
            beforeEach {
              request = POSTRequest(parameters: [:])
            }

            it("returns URL") {
              let URLString = "http://hyper.no"
              let result = URL(string: urLString)

              expect(try! request.buildURL(urLString)).to(equal(result))
            }
          }

          context("when content type is Query and request has parameters") {
            beforeEach {
              request = GETRequest(parameters: ["key": "value", "number": 1])
            }

            it("returns URL") {
              let URLString = "http://hyper.no"
              let result1 = URL(string: "http://hyper.no?key=value&number=1")
              let result2 = URL(string: "http://hyper.no?number=1&key=value")

              let URL = try! request.buildURL(urlRequest)

              expect(URL == result1 || URL == result2).to(beTrue())
            }
          }
        }

        describe("#etagKey") {
          it("returns ETag key built from method, prefix, resource and parameters") {
            let result = "\(request.method)\(request.message.resource.URLString)\(request.message.parameters.description)"
            expect(request.etagKey()).to(equal(result))
          }
        }

        describe("#key") {
          it("bulds a description based on rmethod and request URL") {
            expect(request.key).to(equal("POST http://hyper.no"))
          }
        }
      }
    }
  }
}
