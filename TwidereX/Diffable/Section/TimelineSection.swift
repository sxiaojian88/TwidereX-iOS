//
//  TimelineSection.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-9-9.
//

import os.log
import UIKit
import Combine
import CoreData
import CoreDataStack

enum TimelineSection: Equatable, Hashable {
    case main
}

extension TimelineSection {
    static func tableViewDiffableDataSource(
        for tableView: UITableView,
        context: AppContext,
        managedObjectContext: NSManagedObjectContext,
        timestampUpdatePublisher: AnyPublisher<Date, Never>,
        timelinePostTableViewCellDelegate: TimelinePostTableViewCellDelegate,
        timelineMiddleLoaderTableViewCellDelegate: TimelineMiddleLoaderTableViewCellDelegate?
    ) -> UITableViewDiffableDataSource<TimelineSection, Item> {
        UITableViewDiffableDataSource(tableView: tableView) { tableView, indexPath, item -> UITableViewCell? in
            switch item {
            case .homeTimelineIndex(let objectID, let attribute):
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: TimelinePostTableViewCell.self), for: indexPath) as! TimelinePostTableViewCell

                // configure cell
                managedObjectContext.performAndWait {
                    let timelineIndex = managedObjectContext.object(with: objectID) as! TimelineIndex
                    TimelineSection.configure(cell: cell, readableLayoutFrame: tableView.readableContentGuide.layoutFrame, videoPlaybackService: context.videoPlaybackService, timelineIndex: timelineIndex)
                    TimelineSection.configure(cell: cell, overrideTraitCollection: context.overrideTraitCollection.value)
                    TimelineSection.configure(cell: cell, timelineIndex: timelineIndex, timestampUpdatePublisher: timestampUpdatePublisher)
                    TimelineSection.configure(cell: cell, attribute: attribute)
                }
                cell.delegate = timelinePostTableViewCellDelegate
                return cell
            case .mentionTimelineIndex(let objectID, let attribute):
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: TimelinePostTableViewCell.self), for: indexPath) as! TimelinePostTableViewCell
                
                // configure cell
                managedObjectContext.performAndWait {
                    let mentionTimelineIndex = managedObjectContext.object(with: objectID) as! MentionTimelineIndex
                    TimelineSection.configure(cell: cell, readableLayoutFrame: tableView.readableContentGuide.layoutFrame, videoPlaybackService: context.videoPlaybackService, mentionTimelineIndex: mentionTimelineIndex)
                    TimelineSection.configure(cell: cell, overrideTraitCollection: context.overrideTraitCollection.value)
                    TimelineSection.configure(cell: cell, mentionTimelineIndex: mentionTimelineIndex, timestampUpdatePublisher: timestampUpdatePublisher)
                    TimelineSection.configure(cell: cell, attribute: attribute)
                }
                cell.delegate = timelinePostTableViewCellDelegate
                return cell
            case .tweet(let objectID):
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: TimelinePostTableViewCell.self), for: indexPath) as! TimelinePostTableViewCell
                let activeTwitterAuthenticationBox = context.authenticationService.activeTwitterAuthenticationBox.value
                let requestTwitterUserID = activeTwitterAuthenticationBox?.twitterUserID ?? ""
                // configure cell
                managedObjectContext.performAndWait {
                    let tweet = managedObjectContext.object(with: objectID) as! Tweet
                    TimelineSection.configure(cell: cell, readableLayoutFrame: tableView.readableContentGuide.layoutFrame, videoPlaybackService: context.videoPlaybackService, tweet: tweet, requestUserID: requestTwitterUserID)
                    TimelineSection.configure(cell: cell, tweet: tweet, timestampUpdatePublisher: timestampUpdatePublisher)
                }
                cell.delegate = timelinePostTableViewCellDelegate
                return cell
            case .middleLoader(let upperTimelineIndexObjectID):
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: TimelineMiddleLoaderTableViewCell.self), for: indexPath) as! TimelineMiddleLoaderTableViewCell
                cell.delegate = timelineMiddleLoaderTableViewCellDelegate
                timelineMiddleLoaderTableViewCellDelegate?.configure(cell: cell, upperTimelineIndexObjectID: upperTimelineIndexObjectID)
                return cell
            case .bottomLoader:
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: TimelineBottomLoaderTableViewCell.self), for: indexPath) as! TimelineBottomLoaderTableViewCell
                cell.activityIndicatorView.startAnimating()
                return cell
            case .emptyStateHeader(let attribute):
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: TimelineHeaderTableViewCell.self), for: indexPath) as! TimelineHeaderTableViewCell
                TimelineHeaderView.configure(timelineHeaderView: cell.timelineHeaderView, attribute: attribute)
                return cell
            default:
                assertionFailure()
                return nil
            }
        }
    }
}

extension TimelineSection {
    
    static func configure(
        cell: TimelinePostTableViewCell,
        readableLayoutFrame: CGRect? = nil,
        videoPlaybackService: VideoPlaybackService,
        timelineIndex: TimelineIndex
    ) {
        if let tweet = timelineIndex.tweet {
            configure(
                cell: cell,
                readableLayoutFrame: readableLayoutFrame,
                videoPlaybackService: videoPlaybackService,
                tweet: tweet,
                requestUserID: timelineIndex.userID
            )
        }
    }
    
    static func configure(
        cell: TimelinePostTableViewCell,
        readableLayoutFrame: CGRect? = nil,
        videoPlaybackService: VideoPlaybackService,
        mentionTimelineIndex: MentionTimelineIndex
    ) {
        if let tweet = mentionTimelineIndex.tweet {
            configure(
                cell: cell,
                readableLayoutFrame: readableLayoutFrame,
                videoPlaybackService: videoPlaybackService,
                tweet: tweet,
                requestUserID: mentionTimelineIndex.userID
            )
        }
    }
    
    static func configure(
        cell: TimelinePostTableViewCell,
        readableLayoutFrame: CGRect?,
        videoPlaybackService: VideoPlaybackService,
        tweet: Tweet,
        requestUserID: String
    ) {
        // set retweet display
        cell.timelinePostViewTopLayoutConstraint.constant = tweet.retweet == nil ? TimelinePostTableViewCell.verticalMargin : TimelinePostTableViewCell.verticalMarginAlt
        cell.timelinePostView.retweetContainerStackView.isHidden = tweet.retweet == nil
        cell.timelinePostView.retweetInfoLabel.text = L10n.Common.Controls.Status.userRetweeted(tweet.author.name)
        
        // set avatar
        let avatarImageURL = (tweet.retweet?.author ?? tweet.author).avatarImageURL()
        let verified = (tweet.retweet?.author ?? tweet.author).verified
        UserDefaults.shared
            .observe(\.avatarStyle, options: [.initial, .new]) { defaults, _ in
                cell.timelinePostView.configure(avatarImageURL: avatarImageURL, verified: verified)
            }
            .store(in: &cell.observations)
        
        cell.timelinePostView.lockImageView.isHidden = !((tweet.retweet?.author ?? tweet.author).protected)
        
        // set name and username
        cell.timelinePostView.nameLabel.text = (tweet.retweet?.author ?? tweet.author).name
        cell.timelinePostView.usernameLabel.text = "@" + (tweet.retweet?.author ?? tweet.author).username
        
        // set date
        let createdAt = (tweet.retweet ?? tweet).createdAt
        cell.timelinePostView.dateLabel.text = createdAt.shortTimeAgoSinceNow
        
        // set text
        cell.timelinePostView.activeTextLabel.configure(with: (tweet.retweet ?? tweet).displayText)
        
        // set action toolbar title
        let isRetweeted = (tweet.retweet ?? tweet).retweetBy.flatMap({ $0.contains(where: { $0.id == requestUserID }) }) ?? false
        let retweetCountTitle: String = {
            let count = (tweet.retweet ?? tweet).metrics?.retweetCount.flatMap { Int(truncating: $0) }
            return TimelineSection.formattedNumberTitleForActionButton(count)
        }()
        cell.timelinePostView.actionToolbarContainer.retweetButton.setTitle(retweetCountTitle, for: .normal)
        cell.timelinePostView.actionToolbarContainer.retweetButton.isEnabled = !(tweet.retweet ?? tweet).author.protected
        cell.timelinePostView.actionToolbarContainer.isRetweetButtonHighligh = isRetweeted
        
        let isLike = (tweet.retweet ?? tweet).likeBy.flatMap({ $0.contains(where: { $0.id == requestUserID }) }) ?? false
        let favoriteCountTitle: String = {
            let count = (tweet.retweet ?? tweet).metrics?.likeCount.flatMap { Int(truncating: $0) }
            return TimelineSection.formattedNumberTitleForActionButton(count)
        }()
        cell.timelinePostView.actionToolbarContainer.likeButton.setTitle(favoriteCountTitle, for: .normal)
        cell.timelinePostView.actionToolbarContainer.isLikeButtonHighlight = isLike
        
        // set media display
        let media = Array((tweet.retweet ?? tweet).media ?? []).sorted { $0.index.compare($1.index) == .orderedAscending }
        
        // set image
        let mosiacImageViewModel = MosaicImageViewModel(twitterMedia: media)
        let imageViewMaxSize: CGSize = {
            let maxWidth: CGFloat = {
                // use timelinePostView width as container width
                // that width follows readable width and keep constant width after rotate
                let containerFrame = readableLayoutFrame ?? cell.timelinePostView.frame
                var containerWidth = containerFrame.width
                containerWidth -= 10
                containerWidth -= TimelinePostView.avatarImageViewSize.width
                return containerWidth
            }()
            let scale: CGFloat = {
                switch mosiacImageViewModel.metas.count {
                case 1:     return 1.3
                default:    return 0.7
                }
            }()
            return CGSize(width: maxWidth, height: maxWidth * scale)
        }()
        if mosiacImageViewModel.metas.count == 1 {
            let meta = mosiacImageViewModel.metas[0]
            let imageView = cell.timelinePostView.mosaicImageView.setupImageView(aspectRatio: meta.size, maxSize: imageViewMaxSize)
            imageView.af.setImage(
                withURL: meta.url,
                placeholderImage: UIImage.placeholder(color: .systemFill),
                imageTransition: .crossDissolve(0.2)
            )
        } else {
            let imageViews = cell.timelinePostView.mosaicImageView.setupImageViews(count: mosiacImageViewModel.metas.count, maxHeight: imageViewMaxSize.height)
            for (i, imageView) in imageViews.enumerated() {
                let meta = mosiacImageViewModel.metas[i]
                imageView.af.setImage(
                    withURL: meta.url,
                    placeholderImage: UIImage.placeholder(color: .systemFill),
                    imageTransition: .crossDissolve(0.2)
                )
            }
        }
        cell.timelinePostView.mosaicImageView.isHidden = mosiacImageViewModel.metas.isEmpty
        
        // set GIF & video
        let playerViewMaxSize: CGSize = {
            let maxWidth: CGFloat = {
                // use timelinePostView width as container width
                // that width follows readable width and keep constant width after rotate
                let containerFrame = readableLayoutFrame ?? cell.timelinePostView.frame
                var containerWidth = containerFrame.width
                containerWidth -= 10
                containerWidth -= TimelinePostView.avatarImageViewSize.width
                return containerWidth
            }()
            let scale: CGFloat = 1.3
            return CGSize(width: maxWidth, height: maxWidth * scale)
        }()
        if let media = media.first, let videoPlayerViewModel = videoPlaybackService.dequeueVideoPlayerViewModel(for: media) {
            let parent = cell.delegate?.parent()
            let mosaicPlayerView = cell.timelinePostView.mosaicPlayerView
            let playerViewController = mosaicPlayerView.setupPlayer(
                aspectRatio: videoPlayerViewModel.videoSize,
                maxSize: playerViewMaxSize,
                parent: parent
            )
            playerViewController.delegate = cell.delegate?.playerViewControllerDelegate
            playerViewController.player = videoPlayerViewModel.player
            playerViewController.showsPlaybackControls = videoPlayerViewModel.videoKind != .gif
            
            mosaicPlayerView.gifIndicatorBackgroundVisualEffectView.isHidden = videoPlayerViewModel.videoKind != .gif
            mosaicPlayerView.isHidden = false
        } else {
            cell.timelinePostView.mosaicPlayerView.playerViewController.player?.pause()
            cell.timelinePostView.mosaicPlayerView.playerViewController.player = nil
        }
        
        // set quote display
        let quote = tweet.retweet?.quote ?? tweet.quote
        if let quote = quote {
            // set avatar
            let avatarImageURL = quote.author.avatarImageURL()
            let verified = quote.author.verified
            UserDefaults.shared
                .observe(\.avatarStyle, options: [.initial, .new]) { defaults, _ in
                    cell.timelinePostView.quotePostView.configure(avatarImageURL: avatarImageURL, verified: verified)
                }
                .store(in: &cell.observations)
            
            // Note: cannot quote protected user
            cell.timelinePostView.quotePostView.lockImageView.isHidden = !quote.author.protected
            
            // set name and username
            cell.timelinePostView.quotePostView.nameLabel.text = quote.author.name
            cell.timelinePostView.quotePostView.usernameLabel.text = "@" + quote.author.username
            
            // set date
            let createdAt = quote.createdAt
            cell.timelinePostView.quotePostView.dateLabel.text = createdAt.shortTimeAgoSinceNow
            
            // set text
            cell.timelinePostView.quotePostView.activeTextLabel.configure(with: quote.displayText)
        }
        cell.timelinePostView.quotePostView.isHidden = quote == nil
        
        // set geo button
        if let place = tweet.place {
            cell.timelinePostView.geoButton.setTitle(place.fullname, for: .normal)
            cell.timelinePostView.geoContainerStackView.isHidden = false
        } else {
            cell.timelinePostView.geoContainerStackView.isHidden = true
        }
        
        // observe model change
        ManagedObjectObserver.observe(object: tweet.retweet ?? tweet)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // do nothing
            } receiveValue: { change in
                guard case let .update(object) = change.changeType,
                      let newTweet = object as? Tweet else { return }
                let targetTweet = newTweet.retweet ?? newTweet
                
                let isRetweeted = targetTweet.retweetBy.flatMap({ $0.contains(where: { $0.id == requestUserID }) }) ?? false
                let retweetCount = targetTweet.metrics?.retweetCount.flatMap { Int(truncating: $0) }
                let retweetCountTitle = TimelineSection.formattedNumberTitleForActionButton(retweetCount)
                cell.timelinePostView.actionToolbarContainer.retweetButton.setTitle(retweetCountTitle, for: .normal)
                cell.timelinePostView.actionToolbarContainer.isRetweetButtonHighligh = isRetweeted
                os_log("%{public}s[%{public}ld], %{public}s: retweet count label for tweet %s did update: %ld", ((#file as NSString).lastPathComponent), #line, #function, targetTweet.id, retweetCount ?? 0)
                
                let isLike = targetTweet.likeBy.flatMap({ $0.contains(where: { $0.id == requestUserID }) }) ?? false
                let favoriteCount = targetTweet.metrics?.likeCount.flatMap { Int(truncating: $0) }
                let favoriteCountTitle = TimelineSection.formattedNumberTitleForActionButton(favoriteCount)
                cell.timelinePostView.actionToolbarContainer.likeButton.setTitle(favoriteCountTitle, for: .normal)
                cell.timelinePostView.actionToolbarContainer.isLikeButtonHighlight = isLike
                os_log("%{public}s[%{public}ld], %{public}s: like count label for tweet %s did update: %ld", ((#file as NSString).lastPathComponent), #line, #function, targetTweet.id, favoriteCount ?? 0)
            }
            .store(in: &cell.disposeBag)
    }
    
    static func configure(
        cell: TimelinePostTableViewCell,
        overrideTraitCollection traitCollection: UITraitCollection?
    ) {
        cell.timelinePostView.retweetInfoLabel.font = .preferredFont(forTextStyle: .callout, compatibleWith: traitCollection)
        cell.timelinePostView.nameLabel.font = .preferredFont(forTextStyle: .headline, compatibleWith: traitCollection)
        cell.timelinePostView.usernameLabel.font = .preferredFont(forTextStyle: .subheadline, compatibleWith: traitCollection)
        cell.timelinePostView.dateLabel.font = .preferredFont(forTextStyle: .callout, compatibleWith: traitCollection)
        cell.timelinePostView.activeTextLabel.font = .preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
        cell.timelinePostView.geoButton.titleLabel?.font = .preferredFont(forTextStyle: .footnote, compatibleWith: traitCollection)
        
        cell.timelinePostView.quotePostView.nameLabel.font = .preferredFont(forTextStyle: .headline, compatibleWith: traitCollection)
        cell.timelinePostView.quotePostView.usernameLabel.font = .preferredFont(forTextStyle: .subheadline, compatibleWith: traitCollection)
        cell.timelinePostView.quotePostView.dateLabel.font = .preferredFont(forTextStyle: .callout, compatibleWith: traitCollection)
        cell.timelinePostView.quotePostView.activeTextLabel.font = .preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
    }
    
    static func configure(
        cell: TimelinePostTableViewCell,
        timelineIndex: TimelineIndex,
        timestampUpdatePublisher: AnyPublisher<Date, Never>
    ) {
        if let tweet = timelineIndex.tweet {
            configure(cell: cell, tweet: tweet, timestampUpdatePublisher: timestampUpdatePublisher)
        }
    }
    
    static func configure(
        cell: TimelinePostTableViewCell,
        mentionTimelineIndex: MentionTimelineIndex,
        timestampUpdatePublisher: AnyPublisher<Date, Never>
    ) {
        if let tweet = mentionTimelineIndex.tweet {
            configure(cell: cell, tweet: tweet, timestampUpdatePublisher: timestampUpdatePublisher)
        }
    }
    
    static func configure(
        cell: TimelinePostTableViewCell,
        tweet: Tweet,
        timestampUpdatePublisher: AnyPublisher<Date, Never>
    ) {
        let createdAt = (tweet.retweet ?? tweet).createdAt
        timestampUpdatePublisher
            .sink { _ in
                cell.timelinePostView.dateLabel.text = createdAt.shortTimeAgoSinceNow
            }
            .store(in: &cell.disposeBag)
        // quote date updater
        let quote = tweet.retweet?.quote ?? tweet.quote
        if let quote = quote {
            let createdAt = quote.createdAt
            timestampUpdatePublisher
                .sink { _ in
                    cell.timelinePostView.quotePostView.dateLabel.text = createdAt.shortTimeAgoSinceNow
                }
                .store(in: &cell.disposeBag)
        }
    }
    
    static func configure(
        cell: TimelinePostTableViewCell,
        attribute: Item.Attribute
    ) {
        // set separator line indent in non-conflict order
        switch attribute.separatorLineStyle {
        case .indent:
            cell.separatorLineExpandLeadingLayoutConstraint.isActive = false
            cell.separatorLineNormalLeadingLayoutConstraint.isActive = false
            cell.separatorLineExpandTrailingLayoutConstraint.isActive = false
            cell.separatorLineIndentLeadingLayoutConstraint.isActive = true
            cell.separatorLineNormalTrailingLayoutConstraint.isActive = true
        case .expand:
            cell.separatorLineNormalLeadingLayoutConstraint.isActive = false
            cell.separatorLineIndentLeadingLayoutConstraint.isActive = false
            cell.separatorLineNormalTrailingLayoutConstraint.isActive = false
            cell.separatorLineExpandLeadingLayoutConstraint.isActive = true
            cell.separatorLineExpandTrailingLayoutConstraint.isActive = true
        case .normal:
            cell.separatorLineExpandLeadingLayoutConstraint.isActive = false
            cell.separatorLineExpandTrailingLayoutConstraint.isActive = false
            cell.separatorLineIndentLeadingLayoutConstraint.isActive = false
            cell.separatorLineNormalLeadingLayoutConstraint.isActive = true
            cell.separatorLineNormalTrailingLayoutConstraint.isActive = true
        }
    }

}

extension TimelineSection {
    private static func formattedNumberTitleForActionButton(_ number: Int?) -> String {
        guard let number = number, number > 0 else { return "" }
        return String(number)
    }
}
