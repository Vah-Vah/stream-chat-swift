//
// Copyright © 2022 Stream.io Inc. All rights reserved.
//

import XCTest

final class Replies_Tests: StreamTestCase {
    
    func testReplyInThread() throws {
        let message = "test message"
        let reply = "my reply"
        
        GIVEN("user opens the channel") {
            userRobot.login().openChannel()
        }
        AND("user sends the message: '\(message)'") {
            userRobot.sendMessage(message)
        }
        WHEN("user replies in thread") {
            userRobot.replyToMessageInThread(reply)
        }
        THEN("the reply is delivered") {
            userRobot.assertThreadReply(reply)
        }
    }
}
