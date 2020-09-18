//
//  HomeTimelineViewController.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-9-1.
//

import os.log
import UIKit
import Combine
import CoreDataStack
import TwitterAPI

final class HomeTimelineViewController: UIViewController, NeedsDependency {
    
    weak var context: AppContext! { willSet { precondition(!isViewLoaded) } }
    weak var coordinator: SceneCoordinator! { willSet { precondition(!isViewLoaded) } }
    
    var disposeBag = Set<AnyCancellable>()
    private(set) lazy var viewModel = HomeTimelineViewModel(context: context)
    
    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(TimelinePostTableViewCell.self, forCellReuseIdentifier: String(describing: TimelinePostTableViewCell.self))
        tableView.register(TimelineMiddleLoaderTableViewCell.self, forCellReuseIdentifier: String(describing: TimelineMiddleLoaderTableViewCell.self))
        tableView.register(TimelineBottomLoaderTableViewCell.self, forCellReuseIdentifier: String(describing: TimelineBottomLoaderTableViewCell.self))
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        return tableView
    }()
    
    let refreshControl = UIRefreshControl()
}

extension HomeTimelineViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Timeline"
        view.backgroundColor = .systemBackground
        
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(HomeTimelineViewController.refreshControlValueChanged(_:)), for: .valueChanged)
        
        #if DEBUG
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Drop", style: .plain, target: self, action: #selector(HomeTimelineViewController.dropBarButtonItemPressed(_:)))
        ]
        #endif
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.backgroundColor = .systemBackground
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor)
        ])
        
        viewModel.contentOffsetAdjustableTimelineViewControllerDelegate = self
        viewModel.tableView = tableView
        viewModel.setupDiffableDataSource(for: tableView)
        do {
            try viewModel.fetchedResultsController.performFetch()
        } catch {
            assertionFailure(error.localizedDescription)
        }
        tableView.delegate = self
        tableView.dataSource = viewModel.diffableDataSource
        
        context.authenticationService.twitterAuthentications
            .map { $0.first }
            .assign(to: \.value, on: viewModel.currentTwitterAuthentication)
            .store(in: &disposeBag)
        
        viewModel.isFetchingLatestTimeline
            .sink { [weak self] isFetching in
                guard let self = self else { return }
                if !isFetching {
                    self.refreshControl.endRefreshing()
                }
            }
            .store(in: &disposeBag)
    }
 
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { _ in
            // do nothing
        } completion: { _ in
            // fix AutoLayout cell height not update after rotate issue
            self.viewModel.cellFrameCache.removeAllObjects()
            self.tableView.reloadData()
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.reloadData()
    }
}

extension HomeTimelineViewController {
    
    @objc private func refreshControlValueChanged(_ sender: UIRefreshControl) {
        guard let twitterAuthentication = viewModel.currentTwitterAuthentication.value else {
            assertionFailure()
            return
        }
        let authorization = Twitter.API.OAuth.Authorization(
            consumerKey: twitterAuthentication.consumerKey,
            consumerSecret: twitterAuthentication.consumerSecret,
            accessToken: twitterAuthentication.accessToken,
            accessTokenSecret: twitterAuthentication.accessTokenSecret
        )
        
        guard !viewModel.isFetchingLatestTimeline.value else { return }
        viewModel.isFetchingLatestTimeline.value = true
        
        context.apiService.twitterHomeTimeline(authorization: authorization)
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                self.viewModel.isFetchingLatestTimeline.value = false
                
                switch completion {
                case .failure(let error):
                    // TODO: handle error
                    os_log("%{public}s[%{public}ld], %{public}s: fetch tweets failed. %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
                case .finished: break
                }
            } receiveValue: { tweets in
                // do nothing
            }
            .store(in: &disposeBag)
    }
    
    #if DEBUG
    @objc private func dropBarButtonItemPressed(_ sender: UIBarButtonItem) {
        let dropping = Array(viewModel.fetchedResultsController.fetchedObjects?.prefix(10) ?? [])
        viewModel.fetchedResultsController.managedObjectContext.performChanges {
            for object in dropping {
                object.tweet.flatMap { self.viewModel.fetchedResultsController.managedObjectContext.delete($0) }
                self.viewModel.fetchedResultsController.managedObjectContext.delete(object)
            }
        }
        .sink { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                assertionFailure(error.localizedDescription)
            }
        }
        .store(in: &disposeBag)
    }
    
    #endif
}

// MARK: - UITableViewDelegate
extension HomeTimelineViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let diffableDataSource = viewModel.diffableDataSource else { return 100 }
        guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return 100 }
        
        guard let frame = viewModel.cellFrameCache.object(forKey: NSNumber(value: item.hashValue))?.cgRectValue else {
            return 200
        }
        // os_log("%{public}s[%{public}ld], %{public}s: cache cell frame %s", ((#file as NSString).lastPathComponent), #line, #function, frame.debugDescription)

        return ceil(frame.height)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        os_log("%{public}s[%{public}ld], %{public}s: indexPath %s", ((#file as NSString).lastPathComponent), #line, #function, indexPath.debugDescription)
        
        if let cell = tableView.cellForRow(at: indexPath) as? TimelinePostTableViewCell {
            viewModel.focus(cell: cell, in: tableView, at: indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return }
        
        let key = item.hashValue
        let frame = cell.frame
        viewModel.cellFrameCache.setObject(NSValue(cgRect: frame), forKey: NSNumber(value: key))
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let diffableDataSource = viewModel.diffableDataSource else { return nil }
        guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return nil }
        
        switch item {
        case .homeTimelineIndex(let objectID, let attribute):
            let detailAction = UIContextualAction(style: .normal, title: "Detail", handler: { [weak self] (action, buttonView, completion) in
                defer { completion(true) }
                guard let self = self else { return }
                let managedObjectContext = self.viewModel.fetchedResultsController.managedObjectContext
                managedObjectContext.performAndWait {
                    guard let timelineIndex = managedObjectContext.object(with: objectID) as? TimelineIndex else { return }
                    guard let tweet = timelineIndex.tweet?.retweet ?? timelineIndex.tweet else { return }
    
                    let tweetPostViewModel = TweetPostViewModel(context: self.context, tweet: tweet)
                    self.coordinator.present(scene: .tweetPost(viewModel: tweetPostViewModel), from: self, transition: .showDetail)
                }
                completion(true)
            })
            detailAction.backgroundColor = .systemGreen
            return UISwipeActionsConfiguration(actions: [detailAction])
        default:
            return nil
        }
    }
    
}

extension HomeTimelineViewController: ContentOffsetAdjustableTimelineViewControllerDelegate {
    func navigationBar() -> UINavigationBar {
        return navigationController!.navigationBar
    }
}
