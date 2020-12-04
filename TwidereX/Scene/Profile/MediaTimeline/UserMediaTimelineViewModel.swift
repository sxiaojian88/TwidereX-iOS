//
//  UserMediaTimelineViewModel.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-11-4.
//  Copyright © 2020 Twidere. All rights reserved.
//

import os.log
import UIKit
import Combine
import CoreData
import CoreDataStack
import GameplayKit
import TwitterAPI

final class UserMediaTimelineViewModel: NSObject {
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let context: AppContext
    let fetchedResultsController: NSFetchedResultsController<Tweet>
    let userID: CurrentValueSubject<String?, Never>
    
    // output
    private(set) lazy var stateMachine: GKStateMachine = {
        let stateMachine = GKStateMachine(states: [
            State.Initial(viewModel: self),
            State.Reloading(viewModel: self),
            State.Idle(viewModel: self),
            State.Fail(viewModel: self),
            State.LoadingMore(viewModel: self),
            State.NoMore(viewModel: self),
        ])
        stateMachine.enter(State.Initial.self)
        return stateMachine
    }()
    lazy var stateMachinePublisher = CurrentValueSubject<State, Never>(State.Initial(viewModel: self))
    var diffableDataSource: UICollectionViewDiffableDataSource<MediaSection, Item>!
    let tweetIDs = CurrentValueSubject<[Twitter.Entity.Tweet.ID], Never>([])
    let items = CurrentValueSubject<[Item], Never>([])
    
    init(context: AppContext, userID: String?) {
        self.context = context
        self.fetchedResultsController = {
            let fetchRequest = Tweet.sortedFetchRequest
            fetchRequest.predicate = Tweet.predicate(idStrs: [])
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.fetchBatchSize = 20
            let controller = NSFetchedResultsController(
                fetchRequest: fetchRequest,
                managedObjectContext: context.managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            
            return controller
        }()
        self.userID = CurrentValueSubject(userID)
        super.init()
        
        self.fetchedResultsController.delegate = self
        
        Publishers.CombineLatest(
            items.eraseToAnyPublisher(),
            stateMachinePublisher.eraseToAnyPublisher()
        )
        .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] items, state in
            guard let self = self else { return }
            os_log("%{public}s[%{public}ld], %{public}s: state did change", ((#file as NSString).lastPathComponent), #line, #function)

            var snapshot = NSDiffableDataSourceSnapshot<MediaSection, Item>()
            snapshot.appendSections([.main])
            snapshot.appendItems(items, toSection: .main)
            switch self.stateMachine.currentState {
            case is State.Fail:
                // TODO:
                break
            case is State.Initial, is State.NoMore:
                break
            case is State.Idle, is State.Reloading, is State.LoadingMore:
                snapshot.appendSections([.loader])
                snapshot.appendItems([.bottomLoader], toSection: .loader)
            default:
                assertionFailure()
            }

            self.diffableDataSource?.apply(snapshot, animatingDifferences: true)
        }
        .store(in: &disposeBag)

        tweetIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ids in
                guard let self = self else { return }
                self.fetchedResultsController.fetchRequest.predicate = Tweet.predicate(idStrs: ids)
                do {
                    try self.fetchedResultsController.performFetch()
                } catch {
                    assertionFailure(error.localizedDescription)
                }
            }
            .store(in: &disposeBag)
    }
    
}

extension UserMediaTimelineViewModel {
    
    enum UserTimelineError: Swift.Error {
        case invalidAuthorization
        case invalidUserID
        case invalidAnchorToLoadMore
    }
    
    func fetchLatest() -> AnyPublisher<Twitter.Response.Content<[Twitter.Entity.Tweet]>, Error> {
        guard let twitterAuthenticationBox = context.authenticationService.activeTwitterAuthenticationBox.value else {
            return Fail(error: UserTimelineError.invalidAuthorization).eraseToAnyPublisher()
        }
        guard let userID = self.userID.value, !userID.isEmpty else {
            return Fail(error: UserTimelineError.invalidUserID).eraseToAnyPublisher()
        }
        
        return context.apiService.twitterUserTimeline(count: 200, userID: userID, excludeReplies: true, twitterAuthenticationBox: twitterAuthenticationBox)
    }
    
    func loadMore() -> AnyPublisher<Twitter.Response.Content<[Twitter.Entity.Tweet]>, Error> {
        guard let twitterAuthenticationBox = context.authenticationService.activeTwitterAuthenticationBox.value else {
            return Fail(error: UserTimelineError.invalidAuthorization).eraseToAnyPublisher()
        }
        guard let userID = self.userID.value, !userID.isEmpty else {
            return Fail(error: UserTimelineError.invalidUserID).eraseToAnyPublisher()
        }
        guard let maxID = tweetIDs.value.last else {
            return Fail(error: UserTimelineError.invalidAnchorToLoadMore).eraseToAnyPublisher()
        }
        
        return context.apiService.twitterUserTimeline(count: 200, userID: userID, maxID: maxID, excludeReplies: true, twitterAuthenticationBox: twitterAuthenticationBox)
    }
    
}
