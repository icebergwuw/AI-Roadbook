import XCTest
@testable import TravelAI

final class ChatViewModelTests: XCTestCase {

    func testInitialStateIsEmpty() {
        let vm = ChatViewModel()
        XCTAssertEqual(vm.inputText, "")
        XCTAssertFalse(vm.isLoading)
    }

    func testCannotSendEmptyMessage() {
        let vm = ChatViewModel()
        vm.inputText = "   "
        XCTAssertFalse(vm.canSend)
    }

    func testCannotSendWhenLoading() {
        let vm = ChatViewModel()
        vm.inputText = "推荐第二天去哪里"
        vm.isLoading = true
        XCTAssertFalse(vm.canSend)
    }

    func testCanSendNonEmptyMessage() {
        let vm = ChatViewModel()
        vm.inputText = "推荐第二天去哪里"
        XCTAssertTrue(vm.canSend)
    }

    func testBuildMessagesIncludesHistory() {
        let vm = ChatViewModel()
        let messages = [
            Message(role: "user", content: "你好"),
            Message(role: "assistant", content: "你好！")
        ]
        let result = vm.buildAPIMessages(from: messages, newMessage: "再推荐一个地方")
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0]["role"], "user")
        XCTAssertEqual(result[1]["role"], "assistant")
        XCTAssertEqual(result[2]["content"], "再推荐一个地方")
        XCTAssertEqual(result[2]["role"], "user")
    }

    func testBuildMessagesWithEmptyHistory() {
        let vm = ChatViewModel()
        let result = vm.buildAPIMessages(from: [], newMessage: "开始")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0]["content"], "开始")
    }
}
