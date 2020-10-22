//
//  APIService+CoreData+V2+TwitterUser.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-10-19.
//  Copyright © 2020 Twidere. All rights reserved.
//

import Foundation
import CoreData
import CoreDataStack
import CommonOSLog
import TwitterAPI

extension APIService.CoreData.V2 {
    
    static func createOrMergeTwitterUser(
        into managedObjectContext: NSManagedObjectContext,
        for requestTwitterUser: TwitterUser?,
        user: Twitter.Entity.V2.User,
        networkDate: Date,
        log: OSLog
    ) -> (user: TwitterUser, isCreated: Bool) {
        let processEntityTaskSignpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "update database - process entity: createOrMergeTwitterUser", signpostID: processEntityTaskSignpostID, "process twitter user %{public}s", user.id)
        defer {
            os_signpost(.end, log: log, name: "update database - process entity: createOrMergeTwitterUser", signpostID: processEntityTaskSignpostID, "process twitter user %{public}s", user.id)
        }
        
        // fetch old twitter user
        let oldTwitterUser: TwitterUser? = {
            let request = TwitterUser.sortedFetchRequest
            request.predicate = TwitterUser.predicate(idStr: user.id)
            request.returnsObjectsAsFaults = false
            do {
                return try managedObjectContext.fetch(request).first
            } catch {
                assertionFailure(error.localizedDescription)
                return nil
            }
        }()
        
        if let oldTwitterUser = oldTwitterUser {
            // merge old twitter usre
            APIService.CoreData.V2.mergeTwitterUser(for: requestTwitterUser, old: oldTwitterUser, entity: user, networkDate: networkDate)
            os_signpost(.event, log: log, name: "update database - process entity: createOrMergeTwitterUser", signpostID: processEntityTaskSignpostID, "find old twitter user %{public}s: name %s", user.id, oldTwitterUser.name)
            return (oldTwitterUser, false)
        } else {
            let publicMetrics = user.publicMetrics
            let metricsProperty = TwitterUserMetrics.Property(followersCount: publicMetrics?.followersCount, followingCount: publicMetrics?.followingCount, listedCount: publicMetrics?.listedCount, tweetCount: publicMetrics?.tweetCount)
            let metrics = TwitterUserMetrics.insert(into: managedObjectContext, property: metricsProperty)
            
            let twitterUserProperty = TwitterUser.Property(entity: user, networkDate: networkDate)
            let twitterUser = TwitterUser.insert(
                into: managedObjectContext,
                property: twitterUserProperty,
                metrics: metrics,
                following: nil,
                followRequestSent: nil
            )
            os_signpost(.event, log: log, name: "update database - process entity: createOrMergeTwitterUser", signpostID: processEntityTaskSignpostID, "did insert new twitter user %{public}s: name %s", twitterUser.identifier.uuidString, twitterUserProperty.name)
            return (twitterUser, true)
        }
    }
    
    static func mergeTwitterUser(for requestTwitterUser: TwitterUser?, old user: TwitterUser, entity: Twitter.Entity.V2.User, networkDate: Date) {
        guard networkDate > user.updatedAt else { return }
        // only fulfill API supported fields
        user.update(name: entity.name)
        user.update(username: entity.username)
        entity.description.flatMap { user.update(bioDescription: $0) }
        entity.url.flatMap { user.update(url: $0) }
        entity.location.flatMap { user.update(location: $0) }
        entity.protected.flatMap { user.update(protected: $0) }
        entity.profileImageURL.flatMap { user.update(profileImageURL: $0) }
        
        user.setupMetricsIfNeeds()
        entity.publicMetrics.flatMap { user.metrics?.update(followingCount: $0.followingCount) }
        entity.publicMetrics.flatMap { user.metrics?.update(followersCount: $0.followersCount) }
        entity.publicMetrics.flatMap { user.metrics?.update(listedCount: $0.listedCount) }
        entity.publicMetrics.flatMap { user.metrics?.update(tweetCount: $0.tweetCount) }

        // relationship with requestTwitterUser
        // TODO: merge more fileds

        user.didUpdate(at: networkDate)
    }
    
}