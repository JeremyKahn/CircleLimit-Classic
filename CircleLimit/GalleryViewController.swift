//
//  GalleryViewController.swift
//  CircleLimitClassic
//
//  Created by Kahn on 6/8/18.
//  Copyright © 2018 Jeremy Kahn. All rights reserved.
//

import UIKit

class GalleryContext {
    
    init(gallery: GalleryViewController) {
        self.gallery = gallery
    }
    
    var gallery: GalleryViewController
    
    var canSwitchPage: Bool {
        set(newValue) {
            gallery.scrollView.isScrollEnabled = newValue
        }
        get { return gallery.scrollView.isScrollEnabled }
    }
    
    func deletePage(currentPage: CircleViewController) {
        gallery.deleteCurrentPage(currentPage)
    }
    
    func clonePage(currentPage: CircleViewController) {
        gallery.cloneCurrentPage(currentPage)
    }
    
}

class GalleryViewController: UIPageViewController
{
    var numberOfPagesToMake = 5
    
    fileprivate var pages: [UIViewController] = []
    
    fileprivate func getViewController(withIdentifier identifier: String) -> UIViewController
    {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier)
    }
    
    var scrollView: UIScrollView {
        return view.subviews[0] as! UIScrollView
    }
    
    var galleryContext: GalleryContext?
    
    func newCircleViewController() -> CircleViewController {
        //        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let storyboard = self.storyboard!
        let vc = storyboard.instantiateViewController(withIdentifier:"circleViewController") as! CircleViewController
        vc.galleryContext = galleryContext
        return vc
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.dataSource = self
        self.delegate   = self
        self.galleryContext = GalleryContext(gallery: self)
        
        for _ in 0..<numberOfPagesToMake {
            pages.append(newCircleViewController())
        }
        giveEachPageItsIndex()
        
        if let firstVC = pages.first
        {
            setViewControllers([firstVC], direction: .forward, animated: true, completion: nil)
        }
        
        scrollView.delaysContentTouches = true
        scrollView.canCancelContentTouches = false 
        
    }
    
    func giveEachPageItsIndex() {
        for i in 0..<pages.count {
            let cvc = pages[i] as! CircleViewController
            cvc.pageviewIndex = i
        }
    }
    
    func deleteCurrentPage(_ currentPage: CircleViewController) {
        let currentIndex = pages.index(of: currentPage)!
        let newPage = dataSource!.pageViewController(self, viewControllerAfter: currentPage)
        if let newPage = newPage {
            setViewControllers([newPage], direction: .forward, animated: true, completion: nil)
        }
        pages.remove(at: currentIndex)
        giveEachPageItsIndex()
    }
    
    func cloneCurrentPage(_ currentPage: CircleViewController) {
        let newPage = newCircleViewController()
        let currentIndex = pages.index(of: currentPage)!
        newPage.drawObjects = currentPage.drawObjects.map() {$0.copy()}
        pages.insert(newPage, at: currentIndex + 1)
        giveEachPageItsIndex()
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

