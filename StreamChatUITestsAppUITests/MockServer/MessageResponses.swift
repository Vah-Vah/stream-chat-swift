//
// Copyright © 2022 Stream.io Inc. All rights reserved.
//

@testable import StreamChat
import Swifter
import XCTest

extension StreamMockServer {
    
    func configureMessagingEndpoints() {
        server[MockEndpoint.message] = { [weak self] request in
            self?.messageCreation(request: request) ?? .badRequest(nil)
        }
        server[MockEndpoint.messageUpdate] = { [weak self] request in
            self?.messageUpdate(request: request) ?? .badRequest(nil)
        }
        server[MockEndpoint.replies] = { [weak self] request in
            self?.mockMessageReplies(request: request) ?? .badRequest(nil)
        }
    }
    
    func mockDeletedMessage(_ message: [String: Any]) -> [String: Any] {
        var mockedMessage = message
        mockedMessage[MessagePayloadsCodingKeys.deletedAt.rawValue] = TestData.currentDate
        mockedMessage[MessagePayloadsCodingKeys.type.rawValue] = MessageType.deleted.rawValue
        return mockedMessage
    }
    
    func mockMessage(
        _ message: [String: Any],
        messageId: String?,
        text: String?,
        createdAt: String?,
        updatedAt: String?
    ) -> [String: Any] {
        var mockedMessage = message
        mockedMessage[MessagePayloadsCodingKeys.id.rawValue] = messageId
        mockedMessage[MessagePayloadsCodingKeys.createdAt.rawValue] = createdAt
        mockedMessage[MessagePayloadsCodingKeys.updatedAt.rawValue] = updatedAt
        mockedMessage[MessagePayloadsCodingKeys.text.rawValue] = text
        mockedMessage[MessagePayloadsCodingKeys.html.rawValue] = text?.html
        return mockedMessage
    }
    
    func mockMessageInThread(
        _ message: [String: Any],
        parentId: String,
        messageId: String,
        text: String?,
        createdAt: String?,
        updatedAt: String?,
        showInChannel: Bool = false
    ) -> [String: Any] {
        var mockedMessage = message
        mockedMessage[MessagePayloadsCodingKeys.parentId.rawValue] = parentId
        mockedMessage[MessagePayloadsCodingKeys.showReplyInChannel.rawValue] = showInChannel
        return mockMessage(
            mockedMessage,
            messageId: messageId,
            text: text,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func messageUpdate(request: HttpRequest) -> HttpResponse {
        if request.method == EndpointMethod.delete.rawValue {
            return messageDeletion(request: request)
        } else {
            return messageCreation(request: request, eventType: .messageUpdated)
        }
    }
    
    private func messageCreation(
        request: HttpRequest,
        eventType: EventType = .messageNew
    ) -> HttpResponse {
        let json = TestData.toJson(request.body)
        let message = json[TopLevelKey.message] as! [String: Any]
        let parentId = message[MessagePayloadsCodingKeys.parentId.rawValue] as? String
        let response = parentId == nil
            ? messageCreationInChannel(message: message, eventType: eventType)
            : messageCreationInThread(message: message)
        return response
    }
    
    private func messageCreationInChannel(
        message: [String: Any],
        eventType: EventType = .messageNew
    ) -> HttpResponse {
        let text = message[MessagePayloadsCodingKeys.text.rawValue] as! String
        let messageId = message[MessagePayloadsCodingKeys.id.rawValue] as! String
        var responseJson = TestData.toJson(.httpMessage)
        let responseMessage = responseJson[TopLevelKey.message] as! [String: Any]
        let timestamp: String = TestData.currentDate
        let user = setUpUser(
            responseMessage[MessagePayloadsCodingKeys.user.rawValue] as! [String: Any],
            userDetails: UserDetails.lukeSkywalker
        )
        
        websocketMessage(
            text,
            messageId: messageId,
            timestamp: timestamp,
            eventType: eventType,
            user: user
        )
        
        var mockedMessage = mockMessage(
            responseMessage,
            messageId: messageId,
            text: text,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        mockedMessage[MessagePayloadsCodingKeys.user.rawValue] = user
        responseJson[TopLevelKey.message] = mockedMessage
        return .ok(.json(responseJson))
    }
    
    private func messageCreationInThread(message: [String: Any]) -> HttpResponse {
        let parentId = message[MessagePayloadsCodingKeys.parentId.rawValue] as! String
        let showInChannel = message[MessagePayloadsCodingKeys.showReplyInChannel.rawValue] as! Bool
        let text = message[MessagePayloadsCodingKeys.text.rawValue] as! String
        let messageId = message[MessagePayloadsCodingKeys.id.rawValue] as! String
        var responseJson = TestData.toJson(.httpMessage)
        let responseMessage = responseJson[TopLevelKey.message] as! [String: Any]
        let timestamp: String = TestData.currentDate
        let user = setUpUser(
            responseMessage[MessagePayloadsCodingKeys.user.rawValue] as! [String: Any],
            userDetails: UserDetails.lukeSkywalker
        )
        let parrentMessage = findMessageById(parentId)
        
        // FIXME
        websocketMessage(
            parrentMessage[MessagePayloadsCodingKeys.text.rawValue] as! String,
            messageId: parentId,
            timestamp: parrentMessage[MessagePayloadsCodingKeys.createdAt.rawValue] as! String,
            eventType: .messageUpdated,
            user: user
        ) { message in
            message[MessagePayloadsCodingKeys.threadParticipants.rawValue] = [user]
            return message
        }
        
        websocketMessageInThread(
            text,
            parentId: parentId,
            messageId: messageId,
            timestamp: timestamp,
            eventType: .messageNew,
            user: user,
            showInChannel: showInChannel
        )
        
        var mockedMessage = mockMessageInThread(
            responseMessage,
            parentId: parentId,
            messageId: messageId,
            text: text,
            createdAt: timestamp,
            updatedAt: timestamp,
            showInChannel: showInChannel
        )
        mockedMessage[MessagePayloadsCodingKeys.user.rawValue] = user
        responseJson[TopLevelKey.message] = mockedMessage
        return .ok(.json(responseJson))
    }
    
    
    private func messageDeletion(request: HttpRequest) -> HttpResponse {
        let messageId = try! XCTUnwrap(request.params[":message_id"])
        var json = TestData.toJson(.httpMessage)
        let messageDetails = findMessageById(messageId)
        let timestamp: String = TestData.currentDate
        let user = setUpUser(
            messageDetails[MessagePayloadsCodingKeys.user.rawValue] as! [String: Any],
            userDetails: UserDetails.lukeSkywalker
        )
        var mockedMessage = mockDeletedMessage(messageDetails)
        mockedMessage[MessagePayloadsCodingKeys.user.rawValue] = user
        json[TopLevelKey.message] = mockedMessage
        
        websocketDelay {
            self.websocketMessage(
                messageId: messageId,
                timestamp: timestamp,
                eventType: .messageDeleted,
                user: user
            )
        }
        
        return .ok(.json(json))
    }
    
    private func mockMessageReplies(request: HttpRequest) -> HttpResponse {
        let messageId = try! XCTUnwrap(request.params[":message_id"])
        var json = TestData.toJson(.httpReplies)
        let messages = findMessagesByParrentId(messageId)
        json[TopLevelKey.messages] = messages
        return .ok(.json(json))
    }
}
