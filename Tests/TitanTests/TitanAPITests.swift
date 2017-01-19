import XCTest
import Titan

final class TitanAPITests: XCTestCase {
  var titanInstance: Titan!
  override func setUp() {
    titanInstance = Titan()
  }
  func testMutableParams() {
    let app = Titan()
    app.get("/init") { (req, res) -> Void in
      res.body = "Hello World"
      req.path = "/rewritten"
      res.code = 500
    }
    app.addFunction { (req, res) -> (RequestType, ResponseType) in
      XCTAssertEqual(req.path, "/rewritten")
      return (req, res)
    }
    let response = app.app(request: Request("GET", "/init"))
    XCTAssertEqual(response.code, 500)
    XCTAssertEqual(response.body, "Hello World")
  }

  func testFunctionalMutableParams() {
    let app = Titan()
    app.get("/init") { (req: inout Request, res: inout Response) -> (RequestType, ResponseType) in
      var newReq = req
      var newRes = res
      newRes.body = "Hello World"
      newReq.path = "/rewritten"
      newRes.code = 500
      // Check that mutating the inout params has no effect on the function chain – ONLY the returned values should matter
      res.code = 400
      res.body = "Should not ever come into the response"
      return (newReq, newRes)
    }
    app.addFunction { (req, res) -> (RequestType, ResponseType) in
      XCTAssertEqual(req.path, "/rewritten")
      return (req, res)
    }
    let response = app.app(request: Request("GET", "/init"))
    XCTAssertEqual(response.code, 500)
    XCTAssertEqual(response.body, "Hello World")
  }
  func testTitanGet() {
    titanInstance.get("/username") { req, _ in
      return (req, Response(200, "swizzlr", headers: []))
    }
    XCTAssertEqual(titanInstance.app(request: Request("GET", "/username")).body, "swizzlr")
  }

  func testTitanEcho() {
    titanInstance.get("/echoMyBody") { req, _ in
      return (req, Response(200, req.body, headers: []))
    }
    XCTAssertEqual(titanInstance.app(request: Request("GET", "/echoMyBody", "hello, this is my body")).body,
                   "hello, this is my body")
  }

  func testMultipleRoutes() {
    titanInstance.get("/username") { req, _ in
      return (req, Response(200, "swizzlr", headers: []))
    }

    titanInstance.get("/echoMyBody") { req, _ in
      return (req, Response(200, req.body, headers: []))
    }
    XCTAssertEqual(titanInstance.app(request: Request("GET", "/echoMyBody", "hello, this is my body")).body,
                   "hello, this is my body")
    XCTAssertEqual(titanInstance.app(request: Request("GET", "/username")).body, "swizzlr")
  }

  func testTitanSugar() {
    let somePremadeFunction: Function = { req, res in
      return (req, res)
    }
    titanInstance.get(path: "/username", handler: somePremadeFunction)
    titanInstance.get("/username", somePremadeFunction)
  }

  func testFunctionFunction() {
    var start = Date()
    var end = start
    titanInstance.addFunction("*") { (req: RequestType, res: ResponseType) -> (RequestType, ResponseType) in
      start = Date()
      return (req, res)
    }
    titanInstance.get("/username") { req, _ in
      return (req, Response(200, "swizzlr", headers: []))
    }
    titanInstance.addFunction("*") { (req: RequestType, res: ResponseType) -> (RequestType, ResponseType) in
      end = Date()
      return (req, res)
    }
    _ = titanInstance.app(request: Request("GET", "/username"))
    XCTAssertLessThan(start, end)
  }

  func testDifferentMethods() {
    titanInstance.get("/getSomething") { req, _ in
      return (req, Response(200, "swizzlrGotSomething!", headers: []))
    }

    titanInstance.post("/postSomething") { req, _ in
      return (req, Response(200, "something posted", headers: []))
    }

    titanInstance.put("/putSomething") { req, _ in
      return (req, Response(200, "i can confirm that stupid stuff is now on the server", headers: []))
    }

    titanInstance.patch("/patchSomething") { req, _ in
      return (req, Response(200, "i guess we don't have a flat tire anymore?", headers: []))
    }

    titanInstance.delete("/deleteSomething") { req, _ in
      return (req, Response(200, "error: could not find the USA or its principles", headers: []))
    }

    titanInstance.options("/optionSomething") { req, _ in
      return (req, Response(200, "I sold movie rights!", headers: []))
    }

    titanInstance.head("/headSomething") { req, _ in
      return (req, Response(200, "OWN GOAL!!", headers: []))
    }

  }

  func testErrorsAreCaught() {
    let t = Titan()
    let errorHandler: (Error) -> ResponseType = { (err: Error) in
      let desc = String(describing: err)
      return Response(500, desc)
    }
    t.addFunction(errorHandler: errorHandler) { (req, res) throws -> (RequestType, ResponseType) in
      throw "Oh no"
    }
    XCTAssertEqual(t.app(request: Request("", "")).body, "Oh no")
  }


  func testSamePathDifferentiationByMethod() {
    var username = ""

    titanInstance.get("/username") { req, _ in
      return (req, Response(200, username, headers: []))
    }

    titanInstance.post("/username") { (req: RequestType, _) in
      username = req.body
      return (req, Response(201, "", headers: []))
    }

    let resp = titanInstance.app(request: Request("POST", "/username", "Lisa"))
    XCTAssertEqual(resp.code, 201)
    XCTAssertEqual(titanInstance.app(request: Request("GET", "/username")).body, "Lisa")
  }

  func testCanAccessJSONBody() {
    let jsonBody = "{\"data\": [1, 2, 3]}"
    let req: RequestType = Request("POST", "/ingest", jsonBody, headers: [])
    guard let json = req.json as? Dictionary<String, Array<Int>> else {
      XCTFail("Received: \(req.json)")
      return
    }
    XCTAssertEqual(json["data"]!, [1, 2, 3])
  }

  func testCanAccessFormURLEncodedBody() {
    let requestBody = "foo=bar&baz=&favorite+flavor=flies&resume=when+i+was+young%0D%0Ai+went+to+school"
    let request = Request("POST", "/submit", requestBody, headers: [])
    let parsed = request.formURLEncodedBody
    // Simple
    XCTAssertEqual(parsed[0].key, "foo")
    XCTAssertEqual(parsed[0].value, "bar")
    // Missing value
    XCTAssertEqual(parsed[1].key, "baz")
    XCTAssertEqual(parsed[1].value, "")
    // Spaces
    XCTAssertEqual(parsed[2].key, "favorite flavor")
    XCTAssertEqual(parsed[2].value, "flies")
    // Percent encoded new lines
    XCTAssertEqual(parsed[3].key, "resume")
    XCTAssertEqual(parsed[3].value, "when i was young\r\ni went to school")
  }

  func testCanAccessQueryString() {
    let path = "/users?verified=true&q=thomas%20catterall"
    let request: RequestType = Request("GET", path, "", headers: [])
    let parsedQuery = request.query
    guard parsedQuery.count == 2 else {
      XCTFail()
      return
    }
    XCTAssertEqual(parsedQuery[0].key, "verified")
    XCTAssertEqual(parsedQuery[0].value, "true")

    XCTAssertEqual(parsedQuery[1].key, "q")
    XCTAssertEqual(parsedQuery[1].value, "thomas catterall")
  }

  static var allTests: [(String, (TitanAPITests) -> () throws -> Void)] {
    return [
      ("testTitanGet", testTitanGet),
    ]
  }
}

extension String: Error {}
