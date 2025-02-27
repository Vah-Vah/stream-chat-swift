//
// Copyright © 2022 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// `ChatMessagePopupVC` is shown when user long-presses a message.
/// By default, it has a blurred background, reactions, and actions which are shown for a given message
/// and with which user can interact.
open class ChatMessagePopupVC: _ViewController, ComponentsProvider {
    /// `ContainerStackView` encapsulating underlying views `reactionsController`, `actionsController` and `messageContentView`.
    open private(set) lazy var messageContainerStackView = ContainerStackView()
        .withoutAutoresizingMaskConstraints

    /// `UIView` with `UIBlurEffect` that is shown as a background.
    open private(set) lazy var blurView: UIView = {
        let blur: UIBlurEffect
        if #available(iOS 13.0, *) {
            blur = UIBlurEffect(style: .systemUltraThinMaterial)
        } else {
            blur = UIBlurEffect(style: .regular)
        }
        return UIVisualEffectView(effect: blur)
            .withoutAutoresizingMaskConstraints
    }()
    
    /// Container view that holds `messageContentView`.
    open private(set) lazy var messageContentContainerView = UIView()
        .withoutAutoresizingMaskConstraints

    /// Insets for `messageContentView`'s bubble view.
    public var messageBubbleViewInsets: UIEdgeInsets = .zero

    /// `messageContentView` being displayed.
    public var messageContentView: ChatMessageContentView!

    /// Message data that is shown.
    public var message: ChatMessage { messageContentView.content! }
    
    /// Initial frame of a message.
    public var messageViewFrame: CGRect!

    /// `ChatMessageActionsVC` instance for showing actions.
    public var actionsController: ChatMessageActionsVC?

    /// `ChatMessageReactionsVC` instance for showing reactions.
    public var reactionsController: ChatMessageReactionsVC?

    /// `ChatMessageReactionAuthorsVC` instance for showing the authors of the reactions.
    public var reactionAuthorsController: ChatMessageReactionAuthorsVC?

    /// The width percentage of the actions view in relation with the popup's width.
    open var actionsViewWidthMultiplier: CGFloat {
        0.7
    }

    /// The height of the reactions author view. By default it depends on the number of total reactions.
    open var reactionAuthorsViewHeight: CGFloat {
        message.totalReactionsCount > 4 ? 320 : 180
    }

    /// The width percentage of the reactions author view in relation with the popup's width.
    /// By default it depends on the number of total reactions.
    open var reactionAuthorsViewWidthMultiplier: CGFloat {
        message.totalReactionsCount >= 4 ? 0.90 : 0.75
    }

    override open func setUp() {
        super.setUp()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOnView))
        tapRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(tapRecognizer)
    }

    override open func setUpAppearance() {
        super.setUpAppearance()
        view.backgroundColor = .clear
    }

    override open func setUpLayout() {
        guard messageViewFrame != nil else { return }
        
        view.embed(blurView)

        messageContainerStackView.axis = .vertical
        messageContainerStackView.spacing = 8
        view.addSubview(messageContainerStackView)

        var constraints: [NSLayoutConstraint] = [
            messageContainerStackView.leadingAnchor.pin(greaterThanOrEqualTo: view.leadingAnchor),
            messageContainerStackView.trailingAnchor.pin(lessThanOrEqualTo: view.trailingAnchor),
            messageContainerStackView.bottomAnchor.pin(lessThanOrEqualTo: view.bottomAnchor),
            messageContainerStackView.topAnchor.pin(greaterThanOrEqualTo: view.topAnchor)
        ]

        if let reactionsController = reactionsController {
            let reactionsContainerView = ContainerStackView()
            messageContainerStackView.addArrangedSubview(reactionsContainerView)
            reactionsContainerView.addArrangedSubview(.spacer(axis: .horizontal))
            
            reactionsController.view.translatesAutoresizingMaskIntoConstraints = false
            addChildViewController(reactionsController, targetView: reactionsContainerView)
            
            reactionsContainerView.addArrangedSubview(.spacer(axis: .horizontal))
            
            if message.isSentByCurrentUser {
                constraints += [
                    reactionsController.view.leadingAnchor
                        .pin(lessThanOrEqualTo: reactionsController.reactionsBubble.tailLeadingAnchor),
                    reactionsController.reactionsBubble.tailTrailingAnchor
                        .pin(equalTo: messageContentContainerView.leadingAnchor, constant: messageBubbleViewInsets.left)
                ]
            } else {
                constraints += [
                    reactionsController.reactionsBubble.tailLeadingAnchor
                        .pin(equalTo: messageContentContainerView.trailingAnchor, constant: -messageBubbleViewInsets.right)
                ]
            }
        }

        messageContainerStackView.addArrangedSubview(messageContentContainerView)
        constraints += [
            messageContentContainerView.widthAnchor.pin(equalToConstant: messageViewFrame.width),
            messageContentContainerView.heightAnchor.pin(equalToConstant: messageViewFrame.height)
        ]

        if let actionsController = actionsController {
            constraints.append(
                actionsController.view.widthAnchor.pin(equalTo: view.widthAnchor, multiplier: actionsViewWidthMultiplier)
            )

            let actionsContainerStackView = ContainerStackView()
            actionsContainerStackView.addArrangedSubview(.spacer(axis: .horizontal))
            messageContainerStackView.addArrangedSubview(actionsContainerStackView)

            actionsController.view.translatesAutoresizingMaskIntoConstraints = false
            addChildViewController(actionsController, targetView: actionsContainerStackView)

            if message.isSentByCurrentUser {
                constraints.append(
                    actionsController.view.trailingAnchor.pin(equalTo: messageContentContainerView.trailingAnchor)
                )
            } else {
                constraints.append(
                    actionsController.view.leadingAnchor.pin(
                        equalTo: messageContentContainerView.leadingAnchor,
                        constant: messageBubbleViewInsets.left
                    )
                )
            }
        }

        if let reactionAuthorsController = reactionAuthorsController {
            reactionAuthorsController.view.translatesAutoresizingMaskIntoConstraints = false
            addChildViewController(reactionAuthorsController, targetView: messageContainerStackView)

            constraints.append(
                reactionAuthorsController.view.heightAnchor.pin(
                    equalToConstant: reactionAuthorsViewHeight
                )
            )
            constraints.append(
                reactionAuthorsController.view.widthAnchor.pin(
                    equalTo: view.widthAnchor,
                    multiplier: reactionAuthorsViewWidthMultiplier
                )
            )

            if message.isSentByCurrentUser {
                constraints.append(
                    reactionAuthorsController.view.trailingAnchor.pin(
                        equalTo: messageContentContainerView.trailingAnchor
                    )
                )
            } else {
                constraints.append(
                    reactionAuthorsController.view.leadingAnchor.pin(
                        equalTo: messageContentContainerView.leadingAnchor,
                        constant: messageBubbleViewInsets.left
                    )
                )
            }
        }

        if message.isSentByCurrentUser {
            messageContainerStackView.alignment = .trailing
            constraints.append(
                messageContainerStackView.trailingAnchor.pin(
                    equalTo: view.leadingAnchor,
                    constant: messageViewFrame.maxX
                )
            )
        } else {
            messageContainerStackView.alignment = .leading
            constraints.append(
                messageContainerStackView.leadingAnchor.pin(
                    equalTo: view.leadingAnchor,
                    constant: messageViewFrame.minX
                )
            )
        }

        if messageViewFrame.minY <= 0 {
            constraints += [
                (reactionsController?.view ?? messageContentContainerView).topAnchor
                    .pin(equalTo: view.topAnchor)
                    .with(priority: .streamAlmostRequire)
            ]
        } else {
            reactionsController?.view.layoutIfNeeded()
            constraints += [
                messageContentContainerView.topAnchor.pin(
                    equalTo: view.topAnchor,
                    constant: messageViewFrame.minY
                )
                .with(priority: .streamLow)
            ]
        }

        NSLayoutConstraint.activate(constraints)
    }

    /// Triggered when `view` is tapped.
    @objc open func didTapOnView(_ gesture: UITapGestureRecognizer) {
        let actionsLocation = gesture.location(in: actionsController?.view)
        let reactionsLocation = gesture.location(in: reactionsController?.view)
        let isGestureInActionsView = actionsController?.view.frame.contains(actionsLocation) == true
        let isGestureInReactionsView = reactionsController?.view.frame.contains(reactionsLocation) == true

        if isGestureInActionsView || isGestureInReactionsView {
            return
        }

        dismiss(animated: true)
    }
}
