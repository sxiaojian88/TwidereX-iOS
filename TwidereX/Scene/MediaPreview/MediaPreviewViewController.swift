//
//  MediaPreviewViewController.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-11-5.
//  Copyright © 2020 Twidere. All rights reserved.
//

import os.log
import UIKit
import Combine
import CoreData
import CoreDataStack
import AlamofireImage
import Kingfisher
import Pageboy

protocol MediaPreviewViewControllerDelegate: class {
    func mediaPreviewViewController(_ viewController: MediaPreviewViewController, longPressGestureRecognizerTriggered longPressGestureRecognizer: UILongPressGestureRecognizer)
}

final class MediaPreviewViewController: UIViewController, NeedsDependency {

    weak var context: AppContext! { willSet { precondition(!isViewLoaded) } }
    weak var coordinator: SceneCoordinator! { willSet { precondition(!isViewLoaded) } }

    var disposeBag = Set<AnyCancellable>()
    var viewModel: MediaPreviewViewModel!
    weak var delegate: MediaPreviewViewControllerDelegate?
    
    // TODO: adapt Reduce Transparency preference
    let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    
    let pagingViewConttroller = MediaPreviewPagingViewController()
        
    let mediaInfoDescriptionView = MediaInfoDescriptionView()
    
    let closeButtonBackground: UIVisualEffectView = {
        let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        backgroundView.alpha = 0.9
        backgroundView.layer.masksToBounds = true
        backgroundView.layer.cornerRadius = 8
        backgroundView.layer.cornerCurve = .continuous
        return backgroundView
    }()
    
    let closeButtonBackgroundVisualEffectView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: UIBlurEffect(style: .systemUltraThinMaterial)))
    
    let closeButton: UIButton = {
        let button = HitTestExpandedButton(type: .custom)
        button.imageView?.tintColor = .label
        button.setImage(Asset.Editing.xmarkRound.image.withRenderingMode(.alwaysTemplate), for: .normal)
        return button
    }()
    
    let pageControlBackgroundVisualEffectView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: UIBlurEffect(style: .systemMaterial), style: .label))
    
    let pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        return pageControl
    }()
    
    deinit {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s:", ((#file as NSString).lastPathComponent), #line, #function)
    }
    
}

extension MediaPreviewViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        overrideUserInterfaceStyle = .dark
                
        visualEffectView.frame = view.bounds
        view.addSubview(visualEffectView)
        
        pagingViewConttroller.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(pagingViewConttroller)
        visualEffectView.contentView.addSubview(pagingViewConttroller.view)
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: pagingViewConttroller.view.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: pagingViewConttroller.view.bottomAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: pagingViewConttroller.view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: pagingViewConttroller.view.trailingAnchor),
        ])
        pagingViewConttroller.didMove(toParent: self)
        
        mediaInfoDescriptionView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.contentView.addSubview(mediaInfoDescriptionView)
        NSLayoutConstraint.activate([
            visualEffectView.bottomAnchor.constraint(equalTo: mediaInfoDescriptionView.bottomAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: mediaInfoDescriptionView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: mediaInfoDescriptionView.trailingAnchor),
        ])

        closeButtonBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButtonBackground)
        NSLayoutConstraint.activate([
            closeButtonBackground.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 12),
            closeButtonBackground.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor)
        ])
        closeButtonBackgroundVisualEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        closeButtonBackground.contentView.addSubview(closeButtonBackgroundVisualEffectView)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButtonBackgroundVisualEffectView.contentView.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: closeButtonBackgroundVisualEffectView.topAnchor, constant: 4),
            closeButton.leadingAnchor.constraint(equalTo: closeButtonBackgroundVisualEffectView.leadingAnchor, constant: 4),
            closeButtonBackgroundVisualEffectView.trailingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 4),
            closeButtonBackgroundVisualEffectView.bottomAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 4),
        ])
        
        pageControlBackgroundVisualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.contentView.addSubview(pageControlBackgroundVisualEffectView)
        NSLayoutConstraint.activate([
            pageControlBackgroundVisualEffectView.centerXAnchor.constraint(equalTo: mediaInfoDescriptionView.centerXAnchor),
            mediaInfoDescriptionView.topAnchor.constraint(equalTo: pageControlBackgroundVisualEffectView.bottomAnchor, constant: 8),
        ])
        
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControlBackgroundVisualEffectView.contentView.addSubview(pageControl)
        NSLayoutConstraint.activate([
            pageControl.topAnchor.constraint(equalTo: pageControlBackgroundVisualEffectView.topAnchor),
            pageControl.leadingAnchor.constraint(equalTo: pageControlBackgroundVisualEffectView.leadingAnchor),
            pageControl.trailingAnchor.constraint(equalTo: pageControlBackgroundVisualEffectView.trailingAnchor),
            pageControl.bottomAnchor.constraint(equalTo: pageControlBackgroundVisualEffectView.bottomAnchor),
        ])
        
        mediaInfoDescriptionView.delegate = self
        
        Publishers.CombineLatest3(
            viewModel.avatarImageURL.eraseToAnyPublisher(),
            viewModel.isVerified.eraseToAnyPublisher(),
            viewModel.avatarStyle.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
            .sink { [weak self] avatarImageURL, isVerified, _ in
                guard let self = self else { return }
                self.mediaInfoDescriptionView.configure(withConfigurationInput: AvatarConfigurableViewConfiguration.Input(avatarImageURL: avatarImageURL, verified: isVerified))
            }
            .store(in: &disposeBag)
        viewModel.name
            .receive(on: DispatchQueue.main)
            .assign(to: \.text, on: mediaInfoDescriptionView.nameLabel)
            .store(in: &disposeBag)
        viewModel.content
            .receive(on: DispatchQueue.main)
            .sink { [weak self] content in
                guard let self = self else { return }
                self.mediaInfoDescriptionView.activeLabel.text = content
            }
            .store(in: &disposeBag)
        
        closeButton.addTarget(self, action: #selector(MediaPreviewViewController.closeButtonPressed(_:)), for: .touchUpInside)
        
        viewModel.mediaPreviewImageViewControllerDelegate = self
        
        pagingViewConttroller.interPageSpacing = 10
        pagingViewConttroller.delegate = self
        pagingViewConttroller.dataSource = viewModel
        
        switch viewModel.rootItem {
        case .tweet(let meta):
            pageControl.numberOfPages = viewModel.viewControllers.count
            if case let .tweet(meta) = viewModel.rootItem {
                pageControl.currentPage = meta.initialIndex
            }
            pageControl.isHidden = viewModel.viewControllers.count == 1
            mediaInfoDescriptionView.actionToolbarContainer.delegate = self
            let managedObjectContext = self.context.managedObjectContext
            managedObjectContext.perform {
                let tweet = managedObjectContext.object(with: meta.tweetObjectID) as! Tweet
                let targetTweet = tweet.retweet ?? tweet
                let activeTwitterAuthenticationBox = self.context.authenticationService.activeTwitterAuthenticationBox.value
                let requestTwitterUserID = activeTwitterAuthenticationBox?.twitterUserID ?? ""
                MediaPreviewViewController.configure(actionToolbarContainer: self.mediaInfoDescriptionView.actionToolbarContainer, tweet: targetTweet, requestTwitterUserID: requestTwitterUserID)
                
                // observe model change
                ManagedObjectObserver.observe(object: tweet.retweet ?? tweet)
                    .receive(on: DispatchQueue.main)
                    .sink { _ in
                        // do nothing
                    } receiveValue: { [weak self] change in
                        guard let self = self else { return }
                        guard case let .update(object) = change.changeType,
                              let newTweet = object as? Tweet else { return }
                        let targetTweet = newTweet.retweet ?? newTweet
                        let activeTwitterAuthenticationBox = self.context.authenticationService.activeTwitterAuthenticationBox.value
                        let requestTwitterUserID = activeTwitterAuthenticationBox?.twitterUserID ?? ""
                        
                        MediaPreviewViewController.configure(actionToolbarContainer: self.mediaInfoDescriptionView.actionToolbarContainer, tweet: targetTweet, requestTwitterUserID: requestTwitterUserID)
                    }
                    .store(in: &self.disposeBag)
            }
        case .local(let meta):
            pageControl.isHidden = true
            mediaInfoDescriptionView.isHidden = true
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        visualEffectView.frame = view.bounds
    }
    
}

extension MediaPreviewViewController {
    private static func configure(actionToolbarContainer: ActionToolbarContainer, tweet: Tweet, requestTwitterUserID: TwitterUser.ID) {
        let isRetweeted = tweet.retweetBy.flatMap({ $0.contains(where: { $0.id == requestTwitterUserID }) }) ?? false
        actionToolbarContainer.isRetweetButtonHighligh = isRetweeted
        
        let isLike = tweet.likeBy.flatMap({ $0.contains(where: { $0.id == requestTwitterUserID }) }) ?? false
        actionToolbarContainer.isLikeButtonHighlight = isLike
    }
}

extension MediaPreviewViewController {
    
    @objc private func closeButtonPressed(_ sender: UIButton) {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
        dismiss(animated: true, completion: nil)
    }
    
}

// MARK: - PageboyViewControllerDelegate
extension MediaPreviewViewController: PageboyViewControllerDelegate {
    func pageboyViewController(
        _ pageboyViewController: PageboyViewController,
        willScrollToPageAt index: PageboyViewController.PageIndex,
        direction: PageboyViewController.NavigationDirection,
        animated: Bool
    ) {
        // do nothing
    }
    
    func pageboyViewController(
        _ pageboyViewController: PageboyViewController,
        didScrollTo position: CGPoint,
        direction: PageboyViewController.NavigationDirection,
        animated: Bool
    ) {
        // do nothing
    }
    
    func pageboyViewController(
        _ pageboyViewController: PageboyViewController,
        didScrollToPageAt index: PageboyViewController.PageIndex,
        direction: PageboyViewController.NavigationDirection,
        animated: Bool
    ) {
        // update page control
        pageControl.currentPage = index
    }
    
    func pageboyViewController(
        _ pageboyViewController: PageboyViewController,
        didReloadWith currentViewController: UIViewController,
        currentPageIndex: PageboyViewController.PageIndex
    ) {
        // do nothing
    }

}

// MARK: - ActionToolbarContainerDelegate
extension MediaPreviewViewController: ActionToolbarContainerDelegate {
    func actionToolbarContainer(_ actionToolbarContainer: ActionToolbarContainer, menuButtonDidPressed sender: UIButton) {
        let currentIndex = pagingViewConttroller.currentIndex
        tweet()
            .sink { [weak self] tweet in
                guard let tweet = tweet else { return }
                guard let self = self else { return }
                var applicationActivities: [UIActivity] = [
                    SafariActivity(sceneCoordinator: self.coordinator)
                ]
                let media = Array(tweet.media ?? Set()).sorted(by: { $0.index.compare($1.index) == .orderedAscending })
                if let currentIndex = currentIndex, currentIndex < media.count,
                   let urlString = media[currentIndex].url, let url = URL(string: urlString) {
                    applicationActivities.append(SavePhotoActivity(context: self.context, url: url))
                }
                
                let activityViewController = UIActivityViewController(
                    activityItems: tweet.activityItems,
                    applicationActivities: applicationActivities
                )
                activityViewController.popoverPresentationController?.sourceView = sender
                self.present(activityViewController, animated: true, completion: nil)
            }
            .store(in: &disposeBag)
    }
}

// MARK: - MediaPreviewingViewController
extension MediaPreviewViewController: MediaPreviewingViewController {
    
    func isInteractiveDismissable() -> Bool {
        if let mediaPreviewImageViewController = pagingViewConttroller.currentViewController as? MediaPreviewImageViewController {
            let previewImageView = mediaPreviewImageViewController.previewImageView
            // TODO: allow zooming pan dismiss
            guard previewImageView.zoomScale == previewImageView.minimumZoomScale else {
                return false
            }
            
            let safeAreaInsets = previewImageView.safeAreaInsets
            let statusBarFrameHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
            return previewImageView.contentOffset.y <= -(safeAreaInsets.top - statusBarFrameHeight)
        }
        
        return false
    }
    
}

// MARK: - MediaPreviewImageViewControllerDelegate
extension MediaPreviewViewController: MediaPreviewImageViewControllerDelegate {
    
    func mediaPreviewImageViewController(_ viewController: MediaPreviewImageViewController, tapGestureRecognizerDidTrigger tapGestureRecognizer: UITapGestureRecognizer) {
        
    }
    
    func mediaPreviewImageViewController(_ viewController: MediaPreviewImageViewController, longPressGestureRecognizerDidTrigger longPressGestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.mediaPreviewViewController(self, longPressGestureRecognizerTriggered: longPressGestureRecognizer)
    }
    
}

// MARK: - MediaInfoDescriptionViewDelegate
extension MediaPreviewViewController: MediaInfoDescriptionViewDelegate { }
