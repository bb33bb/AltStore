//
//  AppScreenshotsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 9/18/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UIKit

import AltStoreCore
import Roxas

import Nuke

let defaultAspectRatio = CGSize(width: 9, height: 19.5)

class AppScreenshotCollectionViewCell: UICollectionViewCell
{
    let imageView: UIImageView
    
    var aspectRatio: CGSize = CGSize(width: 16, height: 9) {
        didSet {
            self.aspectRatioConstraint.isActive = false
            
            self.aspectRatioConstraint = self.imageView.widthAnchor.constraint(equalTo: self.imageView.heightAnchor, multiplier: self.aspectRatio.width / self.aspectRatio.height)
            self.aspectRatioConstraint.isActive = true
        }
    }
    
    var isRounded: Bool = false {
        didSet {
            if self.isRounded
            {
                var boundsWidth = self.imageView.bounds.width
                if boundsWidth == 0
                {
                    // self.imageView.bounds may be .zero at this point.
                    boundsWidth = self.bounds.width
                }
                
                let cornerRadius = (1.0 / 8.0) * boundsWidth
                self.imageView.layer.cornerRadius = cornerRadius
                
                self.setNeedsLayout()
            }
            else
            {
                self.imageView.layer.cornerRadius = 1
            }
        }
    }
    
    private var aspectRatioConstraint: NSLayoutConstraint
    
    override init(frame: CGRect)
    {
        self.imageView = UIImageView(frame: .zero)
        self.imageView.clipsToBounds = true
        self.imageView.layer.cornerCurve = .continuous
        
        self.imageView.layer.borderColor = UIColor.tertiaryLabel.cgColor
        
        self.aspectRatioConstraint = self.imageView.widthAnchor.constraint(equalTo: self.imageView.heightAnchor, multiplier: 9.0 / 16.0) // 16:9 by default
        
        super.init(frame: frame)
        
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.imageView)
        
//        self.contentView.backgroundColor = .purple
//        self.imageView.backgroundColor = .red
//        self.imageView.isHidden = true
        
        let widthConstraint = self.imageView.widthAnchor.constraint(equalTo: self.contentView.widthAnchor)
        widthConstraint.priority = UILayoutPriority(999)
        
        let heightConstraint = self.imageView.heightAnchor.constraint(equalTo: self.contentView.heightAnchor)
        heightConstraint.priority = UILayoutPriority(999)
        
        NSLayoutConstraint.activate([
            widthConstraint,
            heightConstraint,
            self.imageView.widthAnchor.constraint(lessThanOrEqualTo: self.contentView.widthAnchor),
            self.imageView.heightAnchor.constraint(lessThanOrEqualTo: self.contentView.heightAnchor),
            self.imageView.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor),
            self.imageView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateTraitsIfNeeded() 
    {
        super.updateTraitsIfNeeded()
        
        let displayScale = (self.traitCollection.displayScale == 0.0) ? 1.0 : self.traitCollection.displayScale
        self.imageView.layer.borderWidth = 1.0 / displayScale
    }
}

class AppScreenshotsViewController: UICollectionViewController
{
    let app: StoreApp
    
    private lazy var dataSource = self.makeDataSource()
    
    init?(app: StoreApp, coder: NSCoder)
    {
        self.app = app
        
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView.showsHorizontalScrollIndicator = false
        
        // Allow parent background color to show through.
        self.collectionView.backgroundColor = nil
        
        // Match the parent table view margins.
        self.collectionView.directionalLayoutMargins.top = 0
        self.collectionView.directionalLayoutMargins.bottom = 0
        self.collectionView.directionalLayoutMargins.leading = 20
        self.collectionView.directionalLayoutMargins.trailing = 20
        
        let collectionViewLayout = self.makeLayout()
        self.collectionView.collectionViewLayout = collectionViewLayout
        
        self.collectionView.register(AppScreenshotCollectionViewCell.self, forCellWithReuseIdentifier: RSTCellContentGenericCellIdentifier)
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
    }
}

private extension AppScreenshotsViewController
{
    func makeLayout() -> UICollectionViewCompositionalLayout
    {
        let layoutConfig = UICollectionViewCompositionalLayoutConfiguration()
        layoutConfig.contentInsetsReference = .none
        
        let layout = UICollectionViewCompositionalLayout(sectionProvider: { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            
            let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(168), heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            
            let groupSize = NSCollectionLayoutSize(widthDimension: .estimated(168), heightDimension: .absolute(400))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            let layoutSection = NSCollectionLayoutSection(group: group)
            layoutSection.interGroupSpacing = 10
            layoutSection.contentInsets.leading = 20
            layoutSection.contentInsets.trailing = 20
            layoutSection.orthogonalScrollingBehavior = .groupPaging
            
            return layoutSection
        }, configuration: layoutConfig)
        
        return layout
    }
    
    func makeDataSource() -> RSTArrayCollectionViewPrefetchingDataSource<AppScreenshot, UIImage>
    {
        let dataSource = RSTArrayCollectionViewPrefetchingDataSource<AppScreenshot, UIImage>(items: self.app.screenshots)
        dataSource.cellConfigurationHandler = { (cell, screenshot, indexPath) in
            let cell = cell as! AppScreenshotCollectionViewCell
            cell.imageView.image = nil
            cell.imageView.isIndicatingActivity = true
            
            if let aspectRatio = screenshot.size
            {
                cell.aspectRatio = aspectRatio
                cell.isRounded = false
            }
            else
            {
                cell.aspectRatio = defaultAspectRatio
                cell.isRounded = true
            }
        }
        dataSource.prefetchHandler = { (screenshot, indexPath, completionHandler) in
            let imageURL = screenshot.imageURL
            return RSTAsyncBlockOperation() { (operation) in
                let request = ImageRequest(url: imageURL, processors: [.screenshot])
                ImagePipeline.shared.loadImage(with: request, progress: nil) { result in
                    guard !operation.isCancelled else { return operation.finish() }
                    
                    switch result
                    {
                    case .success(let response): completionHandler(response.image, nil)
                    case .failure(let error): completionHandler(nil, error)
                    }
                }
            }
        }
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            let cell = cell as! AppScreenshotCollectionViewCell
            cell.imageView.isIndicatingActivity = false
            cell.imageView.image = image
            
            if let error = error
            {
                print("Error loading image:", error)
            }
        }
        
        return dataSource
    }
}

#Preview(traits: .portrait) {
    DatabaseManager.shared.startSynchronously()
    
   
    
    let storyboard = UIStoryboard(name: "Main", bundle: .main)
    
    let fetchRequest = StoreApp.fetchRequest()
    
    let storeApp = try! DatabaseManager.shared.viewContext.fetch(fetchRequest).first!
    
//    let appScreenshotsViewController = storyboard.instantiateViewController(identifier: "appScreenshotsViewController") { coder in
//        AppScreenshotsViewController(app: storeApp, coder: coder)
//    }
    
    let appViewConttroller = storyboard.instantiateViewController(withIdentifier: "appViewController") as! AppViewController
    appViewConttroller.app = storeApp
    
    let navigationController = UINavigationController(rootViewController: appViewConttroller)
    return navigationController
}