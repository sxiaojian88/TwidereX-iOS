//
//  MentionTimelineViewModel+LoadOldestState.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-11-3.
//  Copyright © 2020 Twidere. All rights reserved.
//

import os.log
import Foundation
import GameplayKit

extension MentionTimelineViewModel {
    class LoadOldestState: GKState {
        weak var viewModel: MentionTimelineViewModel?
        
        init(viewModel: MentionTimelineViewModel) {
            self.viewModel = viewModel
        }
        
        override func didEnter(from previousState: GKState?) {
            os_log("%{public}s[%{public}ld], %{public}s: enter %s, previous: %s", ((#file as NSString).lastPathComponent), #line, #function, self.debugDescription, previousState.debugDescription)
            viewModel?.loadOldestStateMachinePublisher.send(self)
        }
    }
}

extension MentionTimelineViewModel.LoadOldestState {
    class Initial: MentionTimelineViewModel.LoadOldestState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            guard let viewModel = viewModel else { return false }
            guard !(viewModel.fetchedResultsController.fetchedObjects ?? []).isEmpty else { return false }
            return stateClass == Loading.self
        }
    }
    
    class Loading: MentionTimelineViewModel.LoadOldestState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            return stateClass == Fail.self || stateClass == Idle.self || stateClass == NoMore.self
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            guard let viewModel = viewModel, let stateMachine = stateMachine else { return }
            guard let twitterAuthenticationBox = viewModel.context.authenticationService.activeTwitterAuthenticationBox.value else {
                stateMachine.enter(Fail.self)
                return
            }
            
            guard let last = viewModel.fetchedResultsController.fetchedObjects?.last,
                  let tweet = last.tweet else {
                stateMachine.enter(Idle.self)
                return
            }
            
            // TODO: only set large count when using Wi-Fi
            let maxID = tweet.id
            viewModel.context.apiService.twitterMentionTimeline(count: 200, maxID: maxID, twitterAuthenticationBox: twitterAuthenticationBox)
                .delay(for: .seconds(1), scheduler: DispatchQueue.main)
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    switch completion {
                    case .failure(let error):
                        // TODO: handle error
                        os_log("%{public}s[%{public}ld], %{public}s: fetch tweets failed. %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
                    case .finished:
                        // handle isFetchingLatestTimeline in fetch controller delegate
                        break
                    }
                } receiveValue: { response in
                    let tweets = response.value
                    // enter no more state when no new tweets
                    if tweets.isEmpty || (tweets.count == 1 && tweets[0].idStr == maxID) {
                        stateMachine.enter(NoMore.self)
                    } else {
                        stateMachine.enter(Idle.self)
                    }
                }
                .store(in: &viewModel.disposeBag)
        }
    }
    
    class Fail: MentionTimelineViewModel.LoadOldestState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            return stateClass == Loading.self || stateClass == Idle.self
        }
    }
    
    class Idle: MentionTimelineViewModel.LoadOldestState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            return stateClass == Loading.self
        }
    }
    
    class NoMore: MentionTimelineViewModel.LoadOldestState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            // reset state if needs
            return stateClass == Idle.self
        }
        
        override func didEnter(from previousState: GKState?) {
            guard let viewModel = viewModel else { return }
            guard let diffableDataSource = viewModel.diffableDataSource else {
                assertionFailure()
                return
            }
            var snapshot = diffableDataSource.snapshot()
            snapshot.deleteItems([.bottomLoader])
            diffableDataSource.apply(snapshot)
        }
    }
}
