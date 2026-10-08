import XCTest
import CryptoKit
@testable import MicroRemoteDemo

final class RemoteBoundaryTests: XCTestCase {
    func testPairPayloadRequiresCompleteOutOfBandIdentity() throws {
        let fp = String(repeating:"a",count:64)
        let value = try PairPayload("aimicro://pair?url=https%3A%2F%2F192.0.2.1%3A9443&fingerprint=\(fp)&code=123456")
        XCTAssertEqual(value.url.host,"192.0.2.1")
        for raw in ["https://192.0.2.1:9443", "aimicro://pair?url=http://192.0.2.1&fingerprint=\(fp)&code=123456", "aimicro://pair?url=https://user:pass@192.0.2.1&fingerprint=\(fp)&code=123456", "aimicro://pair?url=https://192.0.2.1&fingerprint=\(fp)&code=123456&code=654321", "aimicro://pair?url=https://192.0.2.1&fingerprint=aa&code=123456"] { XCTAssertThrowsError(try PairPayload(raw)) }
    }
    func testLeafFingerprintMatchesOnlyExactCertificateBytes() {
        let leaf = Data([1,2,3,4]); let fingerprint = SHA256.hash(data:leaf).map { String(format:"%02x",$0) }.joined()
        XCTAssertTrue(PinnedSessionDelegate.matches(leaf,fingerprint:fingerprint.uppercased()))
        XCTAssertFalse(PinnedSessionDelegate.matches(Data([1,2,3,5]),fingerprint:fingerprint))
        XCTAssertFalse(PinnedSessionDelegate.matches(leaf,fingerprint:String(repeating:"0",count:64)))
    }
    func testActionEncodingPreservesExactTargetRevisionAndApproval() throws {
        let command = ActionRequest(commandId:"unique",hostId:"hostA",sessionId:"sessionB",expectedRevision:47,action:"decline",text:nil,requestId:"approvalC",parameters:[:])
        let decoded = try JSONDecoder().decode(ActionRequest.self,from:JSONEncoder().encode(command))
        XCTAssertEqual(decoded.hostId,"hostA"); XCTAssertEqual(decoded.sessionId,"sessionB"); XCTAssertEqual(decoded.expectedRevision,47); XCTAssertEqual(decoded.requestId,"approvalC")
    }
    func testProfilesRoundTripEveryControlBinding() throws {
        var profiles = ControlProfile.defaults; profiles[4].left = "focus"; profiles[4].dialMode = "model"
        let decoded = try JSONDecoder().decode([ControlProfile].self,from:JSONEncoder().encode(profiles))
        XCTAssertEqual(decoded.count,6); XCTAssertEqual(decoded[4].left,"focus"); XCTAssertEqual(decoded[4].dialMode,"model")
    }
    func testWrongHostMissingTargetAndApprovalCannotCreateAction() throws {
        let state = HostState(version:1,hostId:"hostA",hostName:"Mac",revision:7,connected:true,accessibilityTrusted:true,
            sessions:[RemoteSession(id:"exactID",provider:"codex",title:"Same title",selected:true,status:"needsInput",unread:false,capabilities:["send","approve"],approval:Approval(requestId:"requestA",title:nil,detail:"npm test",scopeHash:"scopeA"))],
            actions:[RemoteAction(id:"send",title:"Send",requiresSession:true),RemoteAction(id:"approve",title:"Approve",requiresSession:true),RemoteAction(id:"stop",title:"Stop",requiresSession:true)],issues:[])
        XCTAssertThrowsError(try ActionBinding.create(state:state,expectedHostID:"otherHost",sessionID:"exactID",action:"send",text:"hi",parameters:[:]))
        XCTAssertThrowsError(try ActionBinding.create(state:state,expectedHostID:"hostA",sessionID:"Same title",action:"send",text:"hi",parameters:[:]))
        XCTAssertThrowsError(try ActionBinding.create(state:state,expectedHostID:"hostA",sessionID:"exactID",action:"stop",text:nil,parameters:[:]))
        XCTAssertThrowsError(try ActionBinding.create(state:state,expectedHostID:"hostA",sessionID:"exactID",action:"send",text:String(repeating:"x",count:32001),parameters:[:]))
        let request = try ActionBinding.create(state:state,expectedHostID:"hostA",sessionID:"exactID",action:"approve",text:nil,parameters:[:])
        XCTAssertEqual(request.requestId,"requestA"); XCTAssertEqual(request.sessionId,"exactID"); XCTAssertEqual(request.expectedRevision,7)
    }

    func testApprovalDetailScopeAndMissingRequestArePreservedOrRejected() throws {
        let approval = try JSONDecoder().decode(Approval.self,from:Data(#"{"requestId":"reqA","title":"Run tests","detail":"npm test","scopeHash":"scopeA"}"#.utf8))
        XCTAssertEqual(approval.detail,"npm test"); XCTAssertEqual(approval.scopeHash,"scopeA")
        let state = HostState(version:1,hostId:"host",hostName:"Mac",revision:1,connected:true,accessibilityTrusted:true,
            sessions:[RemoteSession(id:"id",provider:"claude",title:"CLI",selected:true,status:"needsInput",unread:false,capabilities:["approve"],approval:nil)],
            actions:[RemoteAction(id:"approve",title:"Approve",requiresSession:true)],issues:[])
        XCTAssertThrowsError(try ActionBinding.create(state:state,expectedHostID:"host",sessionID:"id",action:"approve",text:nil,parameters:[:]))
    }

}
