import SwiftUI
import UIKit

struct PageCurlContainer: UIViewControllerRepresentable {
    let pages: [AlbumPage]
    @Binding var currentIndex: Int
    let pickupState: ClipPickupState

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue]
        )
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator

        if let firstPage = context.coordinator.viewController(at: 0) {
            pvc.setViewControllers([firstPage], direction: .forward, animated: false)
        }
        return pvc
    }

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        guard !context.coordinator.isAnimating else { return }
        guard !pages.isEmpty else { return }
        let clampedIndex = min(currentIndex, pages.count - 1)
        if clampedIndex != context.coordinator.currentIndex {
            if let vc = context.coordinator.viewController(at: clampedIndex) {
                let direction: UIPageViewController.NavigationDirection = clampedIndex > context.coordinator.currentIndex ? .forward : .reverse
                context.coordinator.isAnimating = true
                uiViewController.setViewControllers([vc], direction: direction, animated: true) { _ in
                    context.coordinator.isAnimating = false
                    context.coordinator.currentIndex = clampedIndex
                }
            }
        }
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        let parent: PageCurlContainer
        var currentIndex = 0
        var isAnimating = false

        init(parent: PageCurlContainer) {
            self.parent = parent
        }

        func viewController(at index: Int) -> UIViewController? {
            guard index >= 0, index < parent.pages.count else { return nil }
            let page = parent.pages[index]
            let hostingVC = UIHostingController(rootView: AlbumPageView(page: page).environment(parent.pickupState))
            hostingVC.view.tag = index
            return hostingVC
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            let index = viewController.view.tag
            return self.viewController(at: index - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            let index = viewController.view.tag
            return self.viewController(at: index + 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            isAnimating = false
            if completed, let vc = pageViewController.viewControllers?.first {
                currentIndex = vc.view.tag
                parent.currentIndex = currentIndex
            }
        }
    }
}
