import UIKit

/// This class is a `UIViewController` that adds some convenience methods
/// when using child view controllers to render your UI. The convenience methods
/// invoke the approriate child view controller related methods in sequence and
/// adds the controllers view or custom view to view heirarcy inside the
/// content view of the `FamilyScrollView`.
open class FamilyViewController: UIViewController, FamilyFriendly {
  var observers = [NSKeyValueObservation]()
  var registry = [ViewController : View]()

  /// A custom implementation of a `UIScrollView` that handles continious scrolling
  /// when using scroll views inside of scroll view.
  public lazy var scrollView: FamilyScrollView = FamilyScrollView()

  deinit {
    childViewControllers.forEach { $0.removeFromParentViewController() }
    purgeRemovedViews()
  }

  /// Called after the controller's view is loaded into memory.
  open override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(scrollView)
    scrollView.frame = view.bounds
    scrollView.alwaysBounceVertical = true
    scrollView.clipsToBounds = true

    configureConstraints()
  }

  /// Notifies the view controller that its view is about to be added to a view hierarchy.
  ///
  /// - Parameter animated: If true, the view is being added to the window using an animation.
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if let tabBarController = self.tabBarController, tabBarController.tabBar.isTranslucent {
      scrollView.contentInset.bottom = tabBarController.tabBar.frame.size.height
      scrollView.scrollIndicatorInsets.bottom = scrollView.contentInset.bottom
    }
  }

  /// Called to notify the view controller that its view is about to layout its subviews.
  override open func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    scrollView.frame = view.bounds
    scrollView.contentView.frame = scrollView.bounds
  }

  /// Configure constraints for the scroll view.
  private func configureConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    if #available(iOS 11.0, tvOS 11.0, *) {
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
      scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
      scrollView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
      scrollView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    } else {
      if #available(iOS 9.0, *) {
        scrollView.topAnchor.constraint(equalTo: topLayoutGuide.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor).isActive = true
        scrollView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        scrollView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
      }
    }
  }

  /// Adds the specified view controller as a child of the current view controller.
  ///
  /// - Parameter childController: The view controller to be added as a child.
  override open func addChildViewController(_ childController: UIViewController) {
    childController.willMove(toParentViewController: self)
    super.addChildViewController(childController)

    switch childController {
    case let collectionViewController as UICollectionViewController:
      if let collectionView = collectionViewController.collectionView {
        scrollView.contentView.addSubview(collectionView)
      } else {
        assertionFailure("Unable to resolve collection view from controller.")
      }
    default:
      scrollView.contentView.addSubview(childController.view)
    }

    childController.didMove(toParentViewController: self)
    registry[childController] = childController.view
  }

  /// Adds the specified view controller as a child of the current view controller.
  ///
  /// - Parameters:
  ///   - childController: The view controller to be added as a child.
  ///   - height: The height that the child controllers should be constrained to.
  open func addChildViewController(_ childController: UIViewController, height: CGFloat) {
    childController.willMove(toParentViewController: self)
    super.addChildViewController(childController)
    scrollView.contentView.addSubview(childController.view)
    childController.didMove(toParentViewController: self)
    childController.view.translatesAutoresizingMaskIntoConstraints = true
    childController.view.autoresizingMask = []
    childController.view.frame.size.height = height
    registry[childController] = childController.view
  }

  /// Adds the specified view controller as a child of the current view controller.
  /// The closure is used to resolve another view for the view controller that should
  /// be added into the view heirarcy.
  ///
  /// - Parameters:
  ///   - childController: The view controller to be added as a child.
  ///   - closure: A closure used to resolve a view other than `.view` on controller used
  ///              to render the view controller.
  public func addChildViewController<T: UIViewController>(_ childController: T, view closure: (T) -> UIView) {
    childController.willMove(toParentViewController: self)
    super.addChildViewController(childController)
    let childView = closure(childController)
    childView.frame = view.bounds
    view.addSubview(childController.view)
    childController.view.alpha = 0
    scrollView.contentView.addSubview(childView)
    childController.didMove(toParentViewController: self)
    registry[childController] = childView

    let observer = childController.observe(\.parent, options: [.new, .old]) { [weak self] (_, value) in
      self?.purgeRemovedViews()
    }
    observers.append(observer)
  }

  /// Adds a collection of view controllers as children of the current view controller.
  ///
  /// - Parameter childControllers: The view controllers to be added as children.
  public func addChildViewControllers(_ childControllers: UIViewController ...) {
    addChildViewControllers(childControllers)
  }

  /// Adds a collection of view controllers as children of the current view controller.
  ///
  /// - Parameter childControllers: The view controllers to be added as children.
  public func addChildViewControllers(_ childControllers: [UIViewController]) {
    for childController in childControllers {
      addChildViewController(childController)
    }
  }

  public func addView(_ subview: View) {
    subview.frame = view.bounds
    scrollView.contentView.addSubview(subview)
    scrollView.frame = view.bounds
  }

  /// Remove stray views from view hierarcy.
  func purgeRemovedViews() {
    for (controller, view) in registry where controller.parent == nil {
      view.removeFromSuperview()
      registry.removeValue(forKey: controller)
    }
  }
}
