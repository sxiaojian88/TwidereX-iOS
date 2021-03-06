//
//  DisplayPreference.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-11-19.
//  Copyright © 2020 Twidere. All rights reserved.
//

import UIKit

extension UserDefaults {

    @objc dynamic var useTheSystemFontSize: Bool {
        get { return UserDefaults.shared[#function] ?? true }
        set { UserDefaults.shared[#function] = newValue }
    }
    
    static let contentSizeCategory: [UIContentSizeCategory] = [
        // .unspecified,
        .extraSmall,
        .small,
        .medium,
        .large,
        .extraLarge,
        .extraExtraLarge,
        .extraExtraExtraLarge,
    ]
    
    @objc dynamic var customContentSizeCatagory: UIContentSizeCategory {
        get {
            guard let index: Int = UserDefaults.shared[#function] else {
                return .medium
            }
            return UserDefaults.contentSizeCategory[index]
        }
        set {
            guard let index = UserDefaults.contentSizeCategory.firstIndex(of: newValue) else {
                assertionFailure()
                UserDefaults.shared[#function] = 0
                return
            }
            
            UserDefaults.shared[#function] = index
        }
    }
    
}

extension UserDefaults {
    
    @objc enum AvatarStyle: Int, CaseIterable {
        case circle
        case roundedSquare
        
        var text: String {
            switch self {
            case .circle:           return L10n.Scene.Settings.Display.Text.circle
            case .roundedSquare:    return L10n.Scene.Settings.Display.Text.roundedSquare
            }
        }
    }
    
    @objc dynamic var avatarStyle: AvatarStyle {
        get {
            guard let rawValue: Int = UserDefaults.shared[#function] else {
                return .circle
            }
            return AvatarStyle(rawValue: rawValue) ?? .circle
        }
        set {
            UserDefaults.shared[#function] = newValue.rawValue
        }
    }

}
