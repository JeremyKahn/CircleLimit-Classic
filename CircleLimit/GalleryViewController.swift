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
    
    var canSwitchPage: Bool = true {
        didSet {
            gallery.updateScrollEnabled()
        }
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
    func updateScrollEnabled() {
        scrollView.isScrollEnabled = galleryContext!.canSwitchPage && pages.count > 1
    }
    
    var defaultNumberOfPagesToMake = 5
    
    fileprivate var numberOfPagesLocation = filePath(fileName: "numberOfPages")
    
    fileprivate var pages: [CircleViewController] = []
    
    fileprivate var virgin = true
    
    var scrollView: UIScrollView {
        return view.subviews[0] as! UIScrollView
    }
    
    var galleryContext: GalleryContext?
    
    func newCircleViewController() -> CircleViewController {
        let vc = storyboard!.instantiateViewController(withIdentifier: "circleViewController") as! CircleViewController
        vc.galleryContext = galleryContext
        return vc
    }
    
    func newCircleViewController(withIndex index: Int) -> CircleViewController {
        let vc = newCircleViewController()
        vc.pageviewIndex = index
        vc.load()
        return vc
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.dataSource = self
        self.delegate   = self
        self.galleryContext = GalleryContext(gallery: self)
        
        let numberOfPagesToMake: Int
        if let savedNumber = loadStuff(location: numberOfPagesLocation, type: [Int].self)?[0] {
            numberOfPagesToMake = savedNumber
            virgin = false
        } else {
            numberOfPagesToMake = defaultNumberOfPagesToMake
        }
        
        for i in 0..<numberOfPagesToMake {
            pages.append(newCircleViewController(withIndex: i))
        }
        
        // Puts a simple example in two pages
        if virgin {
            pages[0].drawObjects = [Examples.getQuad334()]
            pages[2].drawObjects = [Examples.getQuad334()]
        }
        
        if let firstVC = pages.first
        {
            setViewControllers([firstVC], direction: .forward, animated: true, completion: nil)
        }
        
        scrollView.delaysContentTouches = true
        scrollView.canCancelContentTouches = false 
        
    }
    
    func giveEachPageItsIndex() {
        for i in 0..<pages.count {
            let cvc = pages[i]
            cvc.pageviewIndex = i
            cvc.save()
        }
        saveStuff([pages.count], location: numberOfPagesLocation) // Save the array because of the JSON bug
    }
    
    func deleteCurrentPage(_ currentPage: CircleViewController) {
        guard pages.count > 1 else {return}
        let currentIndex = pages.index(of: currentPage)!
        let newPage = dataSource!.pageViewController(self, viewControllerAfter: currentPage)
        if let newPage = newPage {
            setViewControllers([newPage], direction: .forward, animated: true, completion: nil)
        }
        pages.remove(at: currentIndex)
        giveEachPageItsIndex()
        updateScrollEnabled()
    }
    
    func cloneCurrentPage(_ currentPage: CircleViewController) {
        let newPage = newCircleViewController()
        let currentIndex = pages.index(of: currentPage)!
        // TODO: Move the cloning to CircleViewController
        newPage.drawObjects = currentPage.drawObjects.map() {$0.copy()}
        pages.insert(newPage, at: currentIndex + 1)
        giveEachPageItsIndex()
        updateScrollEnabled()
        setViewControllers([newPage], direction: .forward, animated: true, completion: nil)
    }
}

extension GalleryViewController: UIPageViewControllerDataSource
{
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        guard pages.count > 1 else {return viewController}
        
        guard let viewControllerIndex = pages.index(of: viewController as! CircleViewController) else { return nil }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0          else { return pages.last }
        
//        guard pages.count > previousIndex else { return nil        }
        
        return pages[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        guard pages.count > 1 else {
            return viewController
        }
        
        guard let viewControllerIndex = pages.index(of: viewController as! CircleViewController) else { return nil }
        
        let nextIndex = viewControllerIndex + 1
        
        guard nextIndex < pages.count else { return pages.first }
        
//        guard pages.count > nextIndex else { return nil         }
        
        return pages[nextIndex]
    }
}

extension GalleryViewController: UIPageViewControllerDelegate {

}

