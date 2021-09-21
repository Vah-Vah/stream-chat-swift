//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import Foundation

/// - NOTE: Deprecations of the next major release.

public extension UserPresenceChangedEvent {
    @available(*, deprecated, message: "Use user.id")
    var userId: UserId { user.id }
}

public extension UserUpdatedEvent {
    @available(*, deprecated, message: "Use user.id")
    var userId: UserId { user.id }
}

public extension UserWatchingEvent {
    @available(*, deprecated, message: "Use user.id")
    var userId: UserId { user.id }
}

public extension UserBannedEvent {
    @available(*, deprecated, message: "Use user.id")
    var userId: UserId { user.id }
}

public extension UserUnbannedEvent {
    @available(*, deprecated, message: "Use user.id")
    var userId: UserId { user.id }
}

public extension ChannelDeletedEvent {
    @available(*, deprecated, message: "Use channel.deletedAt")
    var deletedAt: Date { channel.deletedAt ?? createdAt }
}

public extension TypingEvent {
    @available(*, deprecated, message: "Use user.id")
    var userId: UserId { user.id }
}
