import PromiseKit
import XCTest

class ErrorUnhandlerTests: XCTestCase {

    func testHandlerIsCalledIfErrorIsNotHandled() {
        twice { promise, ex in
            InjectedErrorUnhandler = { err in
                ex.fulfill()
            }
        }
    }

    func testCanOnlyCallSetUnhandlerOnce() {
        // we call PMKSetUnhandledErrorHandler initially in setUp()
        PMKSetUnhandledErrorHandler({ _ in XCTFail() })
        testHandlerIsCalledIfErrorIsNotHandled()
    }

    func testHandlerIsNotCalledIfErrorIsCaught() {
        twice { promise, ex in
            InjectedErrorUnhandler = { err in
                XCTFail()
            }
            promise.catch { error in
                ex.fulfill()
            }
        }
    }

    func testHandlerIsNotCalledIfErrorIsRecovered() {
        twice { promise, ex in
            InjectedErrorUnhandler = { err in
                XCTFail()
            }
            _ = promise.recover { _ in 1 }.ensure(that: ex.fulfill)
        }
    }

    func testHandlerIsStillCalledIfErrorIsNotRecovered() {
        twice { promise, ex in
            InjectedErrorUnhandler = { err in
                ex.fulfill()
            }
            _ = promise.recover { error -> Int in
                throw error
            }
        }
    }

    func testHandlerIsCalledOnceIfRecoveryFailsWithADifferentError() {
        twice { promise, ex in
            InjectedErrorUnhandler = { err in
                ex.fulfill()
            }
            promise.recover { _ -> Promise<Int> in
                firstly { _ -> Int in throw Error.dummy }
            }
        }
    }

    func testHandlerIsNotCalledIfErrorRecoveryFailsWithSameErrorButEventuallyErrorIsCaught() {
        twice { promise, ex2 in
            let ex1 = expectation(description: "")

            InjectedErrorUnhandler = { err in
                XCTFail()
            }
            promise.recover { error -> Int in
                throw error
            }.then { _ in
                XCTFail()
            }.ensure {
                ex1.fulfill()
            }.catch { err in
                ex2.fulfill()
            }
        }
    }

    func testDoubleRejectDoesNotTriggerUnhandler() {
        enum Error: Swift.Error {
            case test
        }

        InjectedErrorUnhandler = { err in
            XCTFail()
        }

        let (p, _, r) = Promise<Void>.pending()

        let ex1 = expectation(description: "")
        let ex2 = expectation(description: "")
        let ex3 = expectation(description: "")
        let ex4 = expectation(description: "")

        after(interval: 0.10).then { r(Error.test); ex1.fulfill() }
        after(interval: 0.15).then { r(Error.test); ex2.fulfill() }.ensure(that: ex3.fulfill)

        p.catch { error in
            ex4.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testPassThrough() {
        let ex = expectation(description: "")

        InjectedErrorUnhandler = { err in
            ex.fulfill()
        }

        enum Error: Swift.Error {
            case test
        }

        Promise<Void> { _, reject in
            after(interval: 0.1).then {
                throw Error.test
            }.catch(handler: reject)
        }

        waitForExpectations(timeout: 1)
    }

    func testConsumedPromiseStaysConsumedAsAnyPromise() {
        enum Error: Swift.Error {
            case test
        }

        InjectedErrorUnhandler = { err in
            XCTFail()
        }

        let ex1 = expectation(description: "")

        let p: Promise<Int> = firstly { _ -> Int in
            throw Error.test
        }

        XCTAssertTrue(p.isRejected)

        let anyp = AnyPromise(p)

        p.catch { err in
            ex1.fulfill()
        }

        waitForExpectations(timeout: 1)

        print(anyp)
    }


//MARK: helpers

    private func twice(body: (Promise<Int>, XCTestExpectation) -> Void) {
        autoreleasepool {
            let ex = expectation(description: "Sealed")
            body(Promise<Int>(error: Error.dummy), ex)
        }
        waitForExpectations(timeout: 1)

        autoreleasepool {
            let ex = expectation(description: "Unsealed")
            let p = Promise { fulfill, _ in
                fulfill(1)
            }.then { (_: Int) -> Int in
                throw Error.dummy
            }
            body(p, ex)
        }
        waitForExpectations(timeout: 1)
    }

}

private enum Error: Swift.Error {
    case dummy
}
