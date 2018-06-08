//
//  GalleryViewController.swift
//  CircleLimitClassic
//
//  Created by Kahn on 6/8/18.
//  Copyright © 2018 Jeremy Kahn. All rights reserved.
//

import UIKit

class GalleryViewController: UIPageViewController
{
    fileprivate var pages: [UIViewController] = []
    
    fileprivate func getViewController(withIdentifier identifier: String) -> UIViewController
    {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier)
    }
    
    var scrollView: UIScrollView {
        return view.subviews[0] as! UIScrollView
    }
    
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.dataSource = self
        self.delegate   = self
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        for _ in 1...5 {
            let vc = storyboard.instantiateViewController(withIdentifier:"circleViewController")
            pages.append(vc)
        }
        
        if let firstVC = pages.first
        {
            setViewControllers([firstVC], direction: .forward, animated: true, completion: nil)
        }
        
        scrollView.delaysContentTouches = true
        scrollView.canCancelContentTouches = false 
        
//        for gr in actualGestureRecognizers {
//            gr.name = "gallery"
//        }
//        setGRDelegate(delegate: pages[0] as! CircleViewController)
    }
    
    func cloneCurrentPage(_ currentPage: CircleViewController) {
        let newPage = getViewController(withIdentifier:"circleViewController") as! CircleViewController
        let currentIndex = pages.index(of: currentPage)!
        newPage.drawObjects = currentPage.drawObjects.map() {$0.copy()}
        pages.insert(newPage, at: currentIndex + 1)
    }
}

extension GalleryViewController: UIPageViewControllerDataSource
{
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        guard let viewControllerIndex = pages.index(of: viewController) else { return nil }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0          else { return pages.last }
        
        guard pages.count > previousIndex else { return nil        }
        
        return pages[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        guard let viewControllerIndex = pages.index(of: viewController) else { return nil }
        
        let nextIndex = viewControllerIndex + 1
        
        guard nextIndex < pages.count else { return pages.first }
        
        guard pages.count > nextIndex else { return nil         }
        
        return pages[nextIndex]
    }
}

extension GalleryViewController: UIPageViewControllerDelegate {

}

