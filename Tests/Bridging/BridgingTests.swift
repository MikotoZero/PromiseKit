import Foundation
import PromiseKit
import XCTest

extension AnyPromise {
    var objc_value: Any? { return value(forKey: "value") }
}

class BridgingTests: XCTestCase {

    func testCanBridgeAnyObject() {
        let sentinel = NSURLRequest()
        let p = Promise(sentinel)
        let ap = AnyPromise(p)

        XCTAssertEqual(ap.objc_value as? NSURLRequest, sentinel)
    }

    func testCanBridgeOptional() {
        let sentinel: NSURLRequest? = NSURLRequest()
        let p = Promise(sentinel)
        let ap = AnyPromise(p)
        let value = ap.objc_value

        XCTAssertEqual(value as? NSURLRequest, sentinel!)
    }

    func testCanBridgeSwiftArray() {
        let sentinel = [NSString(), NSString(), NSString()]
        let p = Promise(sentinel)
        let ap = AnyPromise(p)

        XCTAssertEqual(ap.objc_value as! [NSString], sentinel)
    }

    func testCanBridgeSwiftDictionary() {
        let sentinel = [NSString(): NSString()]
        let p = Promise(sentinel)
        let ap = AnyPromise(p)

        XCTAssertEqual(ap.objc_value as! [NSString: NSString], sentinel)
    }

    func testCanBridgeInt() {
        let sentinel = 3
        let p = Promise(sentinel)
        let ap = AnyPromise(p)
        XCTAssertEqual(ap.objc_value as? Int, sentinel)
    }

    func testCanBridgeString() {
        let sentinel = "a"
        let p = Promise(sentinel)
        let ap = AnyPromise(p)
        XCTAssertEqual(ap.objc_value as? String, sentinel)
    }

    func testCanBridgeBool() {
        let sentinel = true
        let p = Promise(sentinel)
        let ap = AnyPromise(p)
        XCTAssertEqual(ap.objc_value as? Bool, sentinel)
    }

    func testCanChainOffAnyPromiseFromObjC() {
        let ex = expectation(description: "")

        firstly {
            Promise(1)
        }.then { _ -> AnyPromise in
            return PromiseBridgeHelper().value(forKey: "bridge2") as! AnyPromise
        }.done { value in
            XCTAssertEqual(123, value as? Int)
            ex.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testCanThenOffAnyPromise() {
        let ex = expectation(description: "")

        PMKDummyAnyPromise_YES().done { obj in
            if let value = obj as? NSNumber {
                XCTAssertEqual(value, NSNumber(value: true))
                ex.fulfill()
            }
        }

        waitForExpectations(timeout: 1)
    }

    func testCanThenOffManifoldAnyPromise() {
        let ex = expectation(description: "")

        PMKDummyAnyPromise_Manifold().done { obj in
            guard let value = obj as? Bool else { return XCTFail() }
            XCTAssertEqual(value, true)
            ex.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testCanAlwaysOffAnyPromise() {
        let ex = expectation(description: "")

        PMKDummyAnyPromise_YES().done { obj in
            ex.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testCanCatchOffAnyPromise() {
        let ex = expectation(description: "")
        PMKDummyAnyPromise_Error().catch { err in
            ex.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testFirstlyReturningAnyPromiseSuccess() {
        let ex = expectation(description: "")
        let p = firstly {
            PMKDummyAnyPromise_Error()
        }

        p.done { obj in
            print(obj)
            XCTFail()
        }.catch { error in
            ex.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testFirstlyReturningAnyPromiseError() {
        let ex = expectation(description: "")
        firstly {
            PMKDummyAnyPromise_YES()
        }.done { _ in
            ex.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func test1() {
        let ex = expectation(description: "")

        // AnyPromise.then { return x }

        let input = after(interval: 0).then{ 1 }

        AnyPromise(input).then { obj -> Int in
            XCTAssertEqual(obj as? Int, 1)
            return 2
        }.done { value in
            XCTAssertEqual(value, 2)
            ex.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func test2() {
        let ex = expectation(description: "")

        // AnyPromise.then { return AnyPromise }

        let input = after(interval: 0).then{ 1 }

        AnyPromise(input).then { obj -> AnyPromise in
            XCTAssertEqual(obj as? Int, 1)
            return AnyPromise(after(interval: 0).then{ 2 })
        }.done { obj  in
            XCTAssertEqual(obj as? Int, 2)
            ex.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func test3() {
        let ex = expectation(description: "")

        // AnyPromise.then { return Promise<Int> }

        let input = after(interval: 0).then{ 1 }

        AnyPromise(input).then { obj -> Promise<Int> in
            XCTAssertEqual(obj as? Int, 1)
            return after(interval: 0).then{ 2 }
        }.done { value in
            XCTAssertEqual(value, 2)
            ex.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }


    // can return AnyPromise (that fulfills) in then handler
    func test4() {
        let ex = expectation(description: "")
        Promise(1).then { _ -> AnyPromise in
            return AnyPromise(after(interval: 0).then{ 1 })
        }.done { x in
            XCTAssertEqual(x as? Int, 1)
            ex.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    // can return AnyPromise (that rejects) in then handler
    func test5() {
        let ex = expectation(description: "")

        Promise(1).then { _ -> AnyPromise in
            let promise = after(interval: 0.1).done{ throw Error.dummy }
            return AnyPromise(promise)
        }.catch { err in
            ex.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
}

private enum Error: Swift.Error {
    case dummy
}
