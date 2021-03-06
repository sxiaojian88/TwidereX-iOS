//
//  SearchDetailTransitionController.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-10-28.
//  Copyright © 2020 Twidere. All rights reserved.
//

import UIKit

final class SearchDetailTransitionController: NSObject {
    
}

// MARK: - UINavigationControllerDelegate
extension SearchDetailTransitionController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push where fromVC is SearchViewController && toVC is SearchDetailViewController:
            return SearchToSearchDetailViewControllerAnimatedTransitioning(operation: operation)
        case .pop where fromVC is SearchDetailViewController && toVC is SearchViewController:
            return SearchToSearchDetailViewControllerAnimatedTransitioning(operation: operation)
        default:
            // fix edge dismiss gesture 
            toVC.navigationController?.interactivePopGestureRecognizer?.delegate = nil
            // assertionFailure("Wrong setup. Edge-drag gesture will be invalid. Set delegate to nil when using system push configuration")
            return nil
        }
    }
}
