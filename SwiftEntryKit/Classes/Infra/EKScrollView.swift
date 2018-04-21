//
//  EKScrollView.swift
//  SwiftEntryKit
//
//  Created by Daniel Huri on 4/19/18.
//  Copyright (c) 2018 huri000@gmail.com. All rights reserved.
//

import UIKit

protocol EntryScrollViewDelegate: class {
    func changeToActive(withAttributes attributes: EKAttributes)
    func changeToInactive(withAttributes attributes: EKAttributes)
}

class EKScrollView: UIScrollView {
    
    private weak var entryDelegate: EntryScrollViewDelegate!
    
    // MARK: Props
    private var outDispatchWorkItem: DispatchWorkItem!
    
    private var outConstraint: NSLayoutConstraint!
    private var inConstraint: NSLayoutConstraint!
    
    private var attributes: EKAttributes!
    
    // MARK: Lifecyce
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(withEntryDelegate entryDelegate: EntryScrollViewDelegate) {
        self.entryDelegate = entryDelegate
        super.init(frame: .zero)
        setupAttributes()
    }
    
    // MARK: Setup
    func setup(with contentView: UIView, attributes: EKAttributes) {
        
        self.attributes = attributes
        
        // Layout the content view inside the scroll view
        addSubview(contentView)
        contentView.layoutToSuperview(.left, .right, .top, .bottom)
        contentView.layoutToSuperview(.width, .height)
        
        let safeAreaInsets = EKWindowProvider.safeAreaInset
        
        // Determine the layout entrance type according to the entry type
        let messageBottomInSuperview: NSLayoutAttribute
        let messageTopInSuperview: NSLayoutAttribute
        var inOffset: CGFloat = 0
        var outOffset: CGFloat = 0
        
        // Define a spacer to catch top / bottom offsets
        var spacerView: UIView!
        if safeAreaInsets.top > 0 || safeAreaInsets.bottom > 0 {
            spacerView = UIView()
            addSubview(spacerView)
            spacerView.set(.height, of: safeAreaInsets.top)
            spacerView.layoutToSuperview(.width, .centerX)
        }
        
        switch attributes.location {
        case .top:
            messageBottomInSuperview = .top
            messageTopInSuperview = .bottom
            
            inOffset = safeAreaInsets.top
            switch attributes.shape {
            case .floating(info: let info):
                inOffset += info.verticalOffset
            default:
                break
            }
            outOffset = -safeAreaInsets.top
            
            spacerView?.layout(.bottom, to: .top, of: self)

        case .bottom:
            messageBottomInSuperview = .bottom
            messageTopInSuperview = .top
            
            inOffset = -safeAreaInsets.bottom
            switch attributes.shape {
            case .floating(info: let info):
                inOffset -= info.verticalOffset
            default:
                break
            }
            
            spacerView?.layout(.top, to: .bottom, of: self)
        }
        
        // Layout the scroll view itself according to the entry type
        outConstraint = layout(messageTopInSuperview, to: messageBottomInSuperview, of: superview!, offset: outOffset, priority: .must)
        inConstraint = layout(to: messageBottomInSuperview, of: superview!, offset: inOffset, priority: .defaultLow)
        layoutToSuperview(axis: .horizontally)
        
        animateIn()
        
        setupTapGestureRecognizer()
    }

    private func setupAttributes() {
        clipsToBounds = false
        alwaysBounceVertical = true
        bounces = true
        showsVerticalScrollIndicator = false
    }
    
    private func setupTapGestureRecognizer() {
        guard attributes.contentInteraction.isResponsive else {
            return
        }
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognized))
        tapGestureRecognizer.numberOfTapsRequired = 1
        addGestureRecognizer(tapGestureRecognizer)
    }
    
    // MARK: State Change / Animations
    private func changeToActiveState() {
        inConstraint.priority = .must
        outConstraint.priority = .defaultLow
        superview?.layoutIfNeeded()
    }
    
    private func changeToInactiveState() {
        inConstraint.priority = .defaultLow
        outConstraint.priority = .must
        superview?.layoutIfNeeded()
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
        if EKAttributes.count > 0 {
            EKAttributes.count -= 1
        }
        if EKAttributes.isEmpty {
            EKWindowProvider.shared.state = .main
        }
    }
    
    func animateOut(rollOut: Bool) {
        outDispatchWorkItem?.cancel()
        if let rollOutAnimation = attributes.rollOutAdditionalAnimation, rollOut {
            UIView.animate(withDuration: rollOutAnimation.duration, delay: 0, options: [.curveEaseOut], animations: {
                for type in rollOutAnimation.types {
                    switch type {
                    case .scale(scale: let scale):
                        self.transform = CGAffineTransform(scaleX: scale, y: scale)
                    case .fade:
                        self.alpha = 0
                    case .translation:
                        break
                    }
                }
            }, completion: nil)
        }
        
        entryDelegate?.changeToInactive(withAttributes: attributes)

        UIView.animate(withDuration: attributes.exitAnimation.duration, delay: 0.1, options: [.beginFromCurrentState], animations: {
            self.changeToInactiveState()
        }, completion: { finished in
            self.removeFromSuperview()
        })
    }
    
    private func animateIn() {
        
        // Increment entry count
        EKAttributes.count += 1
    
        // Change to active state
        superview?.layoutIfNeeded()
        UIView.animate(withDuration: attributes.entranceAnimation.duration, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: {
            self.changeToActiveState()
        }, completion: nil)
    
        entryDelegate?.changeToActive(withAttributes: attributes)

        // Change to inactive state
        outDispatchWorkItem = DispatchWorkItem { [weak self] in
            self?.animateOut(rollOut: false)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + attributes.entranceAnimation.duration + attributes.visibleDuration, execute: outDispatchWorkItem)
    }
    
    // MARK: Tap Gesture Handler
    @objc func tapGestureRecognized() {
        switch attributes.contentInteraction.defaultAction {
        case .dismissEntry:
            animateOut(rollOut: true)
            fallthrough
        default:
            attributes.contentInteraction.customActions.forEach { $0() }
        }
    }
}