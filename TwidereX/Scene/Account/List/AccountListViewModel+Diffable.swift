//
//  AccountListViewModel+Diffable.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-11-11.
//  Copyright © 2020 Twidere. All rights reserved.
//

import UIKit
import Combine
import CoreDataStack
import AlamofireImage

extension AccountListViewModel {
    
    func setupDiffableDataSource(
        for tableView: UITableView,
        dependency: NeedsDependency,
        accountListTableViewCellDelegate: AccountListTableViewCellDelegate,
        accountListViewControllerDelegate: AccountListViewControllerDelegate
    ) {
        diffableDataSource = UITableViewDiffableDataSource(tableView: tableView) { [weak dependency, weak accountListTableViewCellDelegate, weak accountListViewControllerDelegate] tableView, indexPath, item -> UITableViewCell? in
            guard let dependency = dependency else { return nil }
            guard let accountListViewControllerDelegate = accountListViewControllerDelegate else { return nil }
            switch item {
            case .twitterUser(let objectID):
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: AccountListTableViewCell.self), for: indexPath) as! AccountListTableViewCell
                let managedObjectContext = dependency.context.managedObjectContext
                managedObjectContext.performAndWait {
                    let twitterUser = managedObjectContext.object(with: objectID) as! TwitterUser
                    AccountListViewModel.configure(cell: cell, twitterUser: twitterUser, accountListViewControllerDelegate: accountListViewControllerDelegate)
                }
                cell.delegate = accountListTableViewCellDelegate
                return cell
            default:
                return nil
            }
        }
    }
    
    static func configure(cell: AccountListTableViewCell, twitterUser: TwitterUser, accountListViewControllerDelegate: AccountListViewControllerDelegate?) {
        // set avatar
        let avatarImageURL = twitterUser.avatarImageURL()
        let verified = twitterUser.verified
        UserDefaults.shared
            .observe(\.avatarStyle, options: [.initial, .new]) { defaults, _ in
                cell.userBriefInfoView.configure(withConfigurationInput: AvatarConfigurableViewConfiguration.Input(avatarImageURL: avatarImageURL, verified: verified))
            }
            .store(in: &cell.observations)
        
        cell.userBriefInfoView.lockImageView.isHidden = !twitterUser.protected
        
        // set name and username
        cell.userBriefInfoView.nameLabel.text = twitterUser.name
        cell.userBriefInfoView.usernameLabel.text = ""
        
        cell.userBriefInfoView.detailLabel.text = "@" + twitterUser.username
        
        if let accountListViewControllerDelegate = accountListViewControllerDelegate {
            if #available(iOS 14.0, *) {
                let menuItems = [
                    UIMenu(
                        title: L10n.Scene.ManageAccounts.deleteAccount,
                        options: .destructive,
                        children: [
                            UIAction(
                                title: L10n.Common.Controls.Actions.remove,
                                image: nil,
                                attributes: .destructive,
                                state: .off,
                                handler: { [weak accountListViewControllerDelegate] _ in
                                    accountListViewControllerDelegate?.signoutTwitterUser(id: twitterUser.id)
                                }
                            ),
                            UIAction(
                                title: L10n.Common.Controls.Actions.cancel,
                                attributes: [],
                                state: .off,
                                handler: { _ in
                                    // do nothing
                                }
                            )
                        ]
                    )
                ]
                cell.userBriefInfoView.menuButton.menu = UIMenu(title: "", children: menuItems)
                cell.userBriefInfoView.menuButton.showsMenuAsPrimaryAction = true
            } else {
                // delegate handle the button
            }
        }
    }

}
