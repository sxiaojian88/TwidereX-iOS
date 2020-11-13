//
//  MediaSection.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-11-4.
//  Copyright © 2020 Twidere. All rights reserved.
//

import UIKit
import CoreData
import CoreDataStack

enum MediaSection: Int {
    case main
    case loader
}

extension MediaSection {
    static func collectionViewDiffableDataSource(
        collectionView: UICollectionView,
        managedObjectContext: NSManagedObjectContext,
        searchMediaCollectionViewCellDelegate: SearchMediaCollectionViewCellDelegate?
    ) -> UICollectionViewDiffableDataSource<MediaSection, Item> {
        UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item -> UICollectionViewCell? in
            switch item {
            case .photoTweet(let objectID, let attribute):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: SearchMediaCollectionViewCell.self), for: indexPath) as! SearchMediaCollectionViewCell
                managedObjectContext.performAndWait {
                    let tweet = managedObjectContext.object(with: objectID) as! Tweet
                    let media = Array(tweet.media ?? Set()).sorted(by: { $0.index.compare($1.index) == .orderedAscending })
                    if media.isEmpty {
                         assertionFailure()
                    } else {
                        var snapshot = NSDiffableDataSourceSnapshot<SearchMediaCollectionViewCell.Section, SearchMediaCollectionViewCell.Item>()
                        snapshot.appendSections([.main])
                        let items = media.compactMap { element -> SearchMediaCollectionViewCell.Item? in
                            guard element.type == "photo" else { return nil }
                            guard let url = element.photoURL(sizeKind: .small)?.0 else { return nil }
                            return SearchMediaCollectionViewCell.Item.preview(url: url)
                        }
                        snapshot.appendItems(items, toSection: .main)
                        cell.diffableDataSource.apply(snapshot, animatingDifferences: false)
                        cell.multiplePhotosIndicatorBackgroundVisualEffectView.isHidden = items.count <= 1
                    }
                }
                // TODO: use attribute control preview position
                cell.delegate = searchMediaCollectionViewCellDelegate
                return cell
            case .bottomLoader:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: ActivityIndicatorCollectionViewCell.self), for: indexPath) as! ActivityIndicatorCollectionViewCell
                cell.activityIndicatorView.startAnimating()
                return cell
            default:
                assertionFailure()
                return nil
            }
        }
    }
}
