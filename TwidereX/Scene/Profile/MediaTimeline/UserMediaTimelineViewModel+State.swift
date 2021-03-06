//
//  UserMediaTimelineViewModel+State.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-11-4.
//  Copyright © 2020 Twidere. All rights reserved.
//

import os.log
import Foundation
import GameplayKit
import TwitterAPI

extension UserMediaTimelineViewModel {
    class State: GKState {
        weak var viewModel: UserMediaTimelineViewModel?
        
        init(viewModel: UserMediaTimelineViewModel) {
            self.viewModel = viewModel
        }
        
        override func didEnter(from previousState: GKState?) {
            os_log("%{public}s[%{public}ld], %{public}s: enter %s, previous: %s", ((#file as NSString).lastPathComponent), #line, #function, self.debugDescription, previousState.debugDescription)
            viewModel?.stateMachinePublisher.send(self)
        }
    }
}

extension UserMediaTimelineViewModel.State {
    class Initial: UserMediaTimelineViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            guard let viewModel = viewModel else { return false }
            switch stateClass {
            case is Reloading.Type:
                return viewModel.userID.value != nil
            case is Suspended.Type:
                return true
            default:
                return false
            }
        }
    }
    
    class Reloading: UserMediaTimelineViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Fail.Type:
                return true
            case is Idle.Type:
                return true
            case is NoMore.Type:
                return true
            case is NotAuthorized.Type, is Blocked.Type:
                return true
            case is Suspended.Type:
                return true
            default:
                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            guard let viewModel = viewModel, let stateMachine = stateMachine else { return }
            
            viewModel.tweetIDs.value = []
            viewModel.items.value = []
            
            let userID = viewModel.userID.value
            viewModel.fetchLatest()
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    switch completion {
                    case .failure(let error):
                        os_log("%{public}s[%{public}ld], %{public}s: fetch user timeline latest response error: %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
                        if NotAuthorized.canEnter(for: error) {
                            stateMachine.enter(NotAuthorized.self)
                        } else if Blocked.canEnter(for: error) {
                            stateMachine.enter(Blocked.self)
                        } else {
                            stateMachine.enter(Fail.self)
                        }
                    case .finished:
                        break
                    }
                } receiveValue: { response in
                    guard viewModel.userID.value == userID else { return }
                    let pagingTweetIDs = response.value
                        .map { $0.idStr }
                    let tweetIDs = response.value
                        .filter { ($0.retweetedStatus ?? $0).user.idStr == userID }
                        .map { $0.idStr }
                    
                    if pagingTweetIDs.isEmpty {
                        stateMachine.enter(NoMore.self)
                    } else {
                        stateMachine.enter(Idle.self)
                    }
                    
                    viewModel.pagingTweetIDs.value = pagingTweetIDs
                    viewModel.tweetIDs.value = tweetIDs
                }
                .store(in: &viewModel.disposeBag)
        }
    }
    
    class Fail: UserMediaTimelineViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Reloading.Type, is LoadingMore.Type:
                return true
            case is Suspended.Type:
                return true
            default:
                return false
            }
        }
    }
    
    class Idle: UserMediaTimelineViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Reloading.Type, is LoadingMore.Type:
                return true
            case is Suspended.Type:
                return true
            default:
                return false
            }
        }
    }
    
    class LoadingMore: UserMediaTimelineViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Fail.Type:
                return true
            case is Idle.Type:
                return true
            case is NoMore.Type:
                return true
            case is NotAuthorized.Type, is Blocked.Type:
                return true
            case is Suspended.Type:
                return true
            default:
                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            guard let viewModel = viewModel, let stateMachine = stateMachine else { return }
            
            let userID = viewModel.userID.value
            viewModel.loadMore()
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    switch completion {
                    case .failure(let error):
                        stateMachine.enter(Fail.self)
                        os_log("%{public}s[%{public}ld], %{public}s: load more fail: %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
                    case .finished:
                        break
                    }
                } receiveValue: { response in
                    guard viewModel.userID.value == userID else { return }
                    
                    var pagingTweetIDs = viewModel.pagingTweetIDs.value
                    var tweetIDs = viewModel.tweetIDs.value
                    
                    var hasNewMedia = false
                    for tweet in response.value {
                        let tweetID = tweet.idStr
                        
                        if !pagingTweetIDs.contains(tweetID) {
                            pagingTweetIDs.append(tweetID)
                        }
                        
                        // skip retweet
                        guard tweet.retweetedStatus == nil else {
                            continue
                        }
                        
                        
                        // skip no media (now require photo)
                        guard let media = tweet.extendedEntities?.media,
                              media.contains(where: { $0.type == "photo" }) else {
                            continue
                        }
                        hasNewMedia = true
                        
                        if !tweetIDs.contains(tweetID) {
                            tweetIDs.append(tweetID)
                        }
                    }
                    
                    if !hasNewMedia {
                        stateMachine.enter(NoMore.self)
                    } else {
                        stateMachine.enter(Idle.self)
                    }
                    
                    viewModel.pagingTweetIDs.value = pagingTweetIDs
                    viewModel.tweetIDs.value = tweetIDs
                }
                .store(in: &viewModel.disposeBag)
        }
    }
    
    class NotAuthorized: UserMediaTimelineViewModel.State {
        static func canEnter(for error: Error) -> Bool {
            if let responseError = error as? Twitter.API.Error.ResponseError,
               let twitterAPIError = responseError.twitterAPIError,
               case .notAuthorizedToSeeThisStatus = twitterAPIError {
                return true
            }
            
            return false
        }
        
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Reloading.Type:
                return true
            case is Suspended.Type:
                return true
            default:
                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            guard let viewModel = viewModel else { return }
            
            // trigger items update
            viewModel.pagingTweetIDs.value = []
            viewModel.tweetIDs.value = []
        }
    }
    
    class Blocked: UserMediaTimelineViewModel.State {
        static func canEnter(for error: Error) -> Bool {
            if let responseError = error as? Twitter.API.Error.ResponseError,
               let twitterAPIError = responseError.twitterAPIError,
               case .blockedFromViewingThisUserProfile = twitterAPIError {
                return true
            }
            
            return false
        }
        
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Reloading.Type:
                return true
            case is Suspended.Type:
                return true
            default:
                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            guard let viewModel = viewModel else { return }
            
            // trigger items update
            viewModel.pagingTweetIDs.value = []
            viewModel.tweetIDs.value = []
        }
    }
    
    class Suspended: UserMediaTimelineViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            return false
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            guard let viewModel = viewModel else { return }
            
            // trigger items update
            viewModel.pagingTweetIDs.value = []
            viewModel.tweetIDs.value = []
            viewModel.items.value = []
        }
    }
    
    class NoMore: UserMediaTimelineViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Reloading.Type:
                return true
            case is NotAuthorized.Type, is Blocked.Type:
                return true
            case is Suspended.Type:
                return true
            default:
                return false
            }
        }
    }
    
}
