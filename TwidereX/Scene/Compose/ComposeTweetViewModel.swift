//
//  ComposeTweetViewModel.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-10-22.
//  Copyright © 2020 Twidere. All rights reserved.
//

import Foundation
import Combine
import CoreDataStack
import AlamofireImage
import twitter_text


final class ComposeTweetViewModel {
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let context: AppContext
    let twitterTextParser = TwitterTextParser.defaultParser()
    let currentTwitterAuthentication = CurrentValueSubject<TwitterAuthentication?, Never>(nil)
    let composeContent = CurrentValueSubject<String, Never>("")

    // output
    var diffableDataSource: UITableViewDiffableDataSource<ComposeTweetSection, ComposeTweetItem>?
    let avatarImageURL = CurrentValueSubject<URL?, Never>(nil)
    let isAvatarLockHidden = CurrentValueSubject<Bool, Never>(true)
    let twitterTextparseResults = CurrentValueSubject<TwitterTextParseResults, Never>(.init())
    
    init(context: AppContext) {
        self.context = context
        
        composeContent
            .map { text in self.twitterTextParser.parseTweet(text) }
            .assign(to: \.value, on: twitterTextparseResults)
            .store(in: &disposeBag)
        
        twitterTextparseResults.print().sink { _ in }.store(in: &disposeBag)
    }
    
}

extension ComposeTweetViewModel {
    
    func setupDiffableDataSource(for tableView: UITableView) {
        diffableDataSource = UITableViewDiffableDataSource<ComposeTweetSection, ComposeTweetItem>(tableView: tableView) { [weak self] tableView, indexPath, item -> UITableViewCell? in
            guard let self = self else { return nil }
            
            switch item {
            case .reply(let objectID):
                fatalError("TODO:")
                
            case .input:
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ComposeTweetContentTableViewCell.self), for: indexPath) as! ComposeTweetContentTableViewCell
                
                // set avatar
                self.avatarImageURL
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] url in
                        guard let self = self else { return }
                        let placeholderImage = UIImage
                            .placeholder(size: TimelinePostView.avatarImageViewSize, color: .systemFill)
                            .af.imageRoundedIntoCircle()
                        guard let url = url else {
                            cell.avatarImageView.image = UIImage.placeholder(color: .systemFill)
                            return
                        }
                        let filter = ScaledToSizeCircleFilter(size: ComposeTweetViewController.avatarImageViewSize)
                        cell.avatarImageView.af.setImage(
                            withURL: url,
                            placeholderImage: placeholderImage,
                            filter: filter,
                            imageTransition: .crossDissolve(0.2)
                        )
                    }
                    .store(in: &cell.disposeBag)
                self.isAvatarLockHidden.receive(on: DispatchQueue.main).assign(to: \.isHidden, on: cell.lockImageView).store(in: &cell.disposeBag)
                
                // self size input cell
                cell.composeText
                    .receive(on: DispatchQueue.main)
                    .sink { text in
                        tableView.beginUpdates()
                        tableView.endUpdates()
                    }
                    .store(in: &cell.disposeBag)
                cell.composeText.assign(to: \.value, on: self.composeContent).store(in: &cell.disposeBag)
                
                return cell
            case .quote(let objectID):
                fatalError("TODO:")
            }
        }
        
        var snapshot = NSDiffableDataSourceSnapshot<ComposeTweetSection, ComposeTweetItem>()
        snapshot.appendSections([.repliedTo, .input, .quoted])
        snapshot.appendItems([.input], toSection: .input)
        diffableDataSource?.apply(snapshot, animatingDifferences: false)
    }
     
    func composeTweetContentTableViewCell(of tableView: UITableView) -> ComposeTweetContentTableViewCell? {
        guard let diffableDataSource = diffableDataSource,
              let indexPath = diffableDataSource.indexPath(for: .input) else { return nil }
        
        let cell = tableView.cellForRow(at: indexPath) as? ComposeTweetContentTableViewCell
        return cell
    }
    
}