//
//

import Foundation
import WireTesting
import WireRequestStrategy
@testable import WireShareEngine

class RequestGeneratorStoreTests : ZMTBaseTest {
    
    class MockStrategy : NSObject, ZMRequestGeneratorSource, ZMContextChangeTrackerSource {
        public var requestGenerators: [ZMRequestGenerator] = []
        public var contextChangeTrackers: [ZMContextChangeTracker] = []
    }

    typealias RequestBlock = () -> ZMTransportRequest?
    
    class DummyGenerator: NSObject, ZMRequestGenerator {

        let requestBlock : RequestBlock
        
        init(requestBlock: @escaping RequestBlock ) {
            self.requestBlock = requestBlock
        }
        
        internal func nextRequest() -> ZMTransportRequest? {
            return requestBlock()
        }
    }

    class MockRequestStrategy: NSObject, RequestStrategy {

        let request: ZMTransportRequest

        init(request: ZMTransportRequest) {
            self.request = request
        }

        @objc public func nextRequest() -> ZMTransportRequest? {
            return request
        }

    }
    
    
    var mockStrategy = MockStrategy()
    var sut : RequestGeneratorStore! = nil
    
    func testThatItDoesNOTReturnARequestIfNoGeneratorsGiven() {
        sut = RequestGeneratorStore(strategies:[])
        XCTAssertNil(sut.nextRequest())
    }
    
    func testThatItCallsTheGivenGenerator() {
        
        let expectation = self.expectation(description: "calledGenerator")
        let generator = DummyGenerator(requestBlock: {
            expectation.fulfill()
            return nil
        })
        
        mockStrategy.requestGenerators.append(generator)
        
        sut = RequestGeneratorStore(strategies: [mockStrategy])
        
        XCTAssertNil(sut.nextRequest())
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatItReturnAProperRequest() {
        
        let sourceRequest = ZMTransportRequest(path: "some path", method: .methodGET, payload: nil)
        
        let generator = DummyGenerator(requestBlock: {
            return sourceRequest
        })
        
        mockStrategy.requestGenerators.append(generator)
        
        sut = RequestGeneratorStore(strategies: [mockStrategy])
        
        let request = sut.nextRequest()
        XCTAssertNotNil(request)
        XCTAssertEqual(request, sourceRequest)
    }

    func testThatItReturnARequestWhenARequestGeneratorIsAddedDirectly() {
        // Given
        let sourceRequest = ZMTransportRequest(path: "/path", method: .methodGET, payload: nil)
        let strategy = MockRequestStrategy(request: sourceRequest)
        sut = RequestGeneratorStore(strategies: [strategy])

        // When
        let request = sut.nextRequest()

        // Then
        XCTAssertNotNil(request)
        XCTAssertEqual(request, sourceRequest)
    }
    
    func testThatItReturnAProperRequestAndNoRequestAfter() {
        
        let sourceRequest = ZMTransportRequest(path: "some path", method: .methodGET, payload: nil)
        
        var requestCalled = false
        
        let generator = DummyGenerator(requestBlock: {
            if !requestCalled {
                requestCalled = true
                return sourceRequest
            }
            
            return nil
        })
        
        mockStrategy.requestGenerators.append(generator)
        
        sut = RequestGeneratorStore(strategies: [mockStrategy])
        
        let request = sut.nextRequest()
        XCTAssertNotNil(request)
        XCTAssertEqual(request, sourceRequest)
        
        
        let secondRequest = sut.nextRequest()
        XCTAssertNil(secondRequest)
    }
    
    func testThatItReturnsRequestFromMultipleGenerators() {
        
        let sourceRequest = ZMTransportRequest(path: "some path", method: .methodGET, payload: nil)
        let sourceRequest2 = ZMTransportRequest(path: "some path 2", method: .methodPOST, payload: nil)
        
        var requestCalled = false
        
        let generator = DummyGenerator(requestBlock: {
            if !requestCalled {
                requestCalled = true
                return sourceRequest
            }
            return nil
        })
        
        let secondGenerator = DummyGenerator(requestBlock: {
            return sourceRequest2
        })
        
        mockStrategy.requestGenerators.append(generator)
        mockStrategy.requestGenerators.append(secondGenerator)
        
        sut = RequestGeneratorStore(strategies: [mockStrategy])
        
        let request = sut.nextRequest()
        XCTAssertNotNil(request)
        XCTAssertEqual(request, sourceRequest)
        
        let secondRequest = sut.nextRequest()
        XCTAssertNotNil(sourceRequest)
        XCTAssertEqual(sourceRequest2, secondRequest)
    }
    
}
