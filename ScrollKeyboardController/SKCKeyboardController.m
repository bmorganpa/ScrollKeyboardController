#import "SKCKeyboardController.h"

@interface UIView (FirstResponder)

- (UIView *)findFirstResponder;

@end

@interface SKCKeyboardState : NSObject

@property (nonatomic, assign, readonly) UIKeyboardType keyboardType;
@property (nonatomic, assign, readonly) UITextAutocorrectionType autocorrectionType;
@property (nonatomic, assign, readonly) CGFloat keyboardHeight;

- (instancetype)initWithKeyboardType:(UIKeyboardType)keyboardType autocorrectType:(UITextAutocorrectionType)autocorrectionType keyboardHeight:(CGFloat)keyboardHeight;

@end

@interface SKCScrollViewState : NSObject

@property (nonatomic, assign, readonly) UIEdgeInsets contentInset;
@property (nonatomic, assign, readonly) UIEdgeInsets scrollIndicatorInsets;

- (instancetype)initWithContentInset:(UIEdgeInsets)contentInset scrollIndicatorInsets:(UIEdgeInsets)scrollIndicatorInsets;

@end

@interface SKCKeyboardController ()

@property (nonatomic, strong) SKCKeyboardState *keyboardState;
@property (nonatomic, strong) SKCScrollViewState *originalScrollViewState;
@property (nonatomic, assign, readonly, getter = isKeyboardShowing) BOOL keyboardShowing;

@end

@implementation SKCKeyboardController {
    id _keyboardWillShowObserver;
    id _keyboardWillHideObserver;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_keyboardWillShowObserver], _keyboardWillShowObserver = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:_keyboardWillHideObserver], _keyboardWillHideObserver = nil;
}

- (id)init
{
    if (nil != (self = [super init])) {
        
        __weak SKCKeyboardController *_weakSelf = self;
        _keyboardWillShowObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:UIKeyboardWillShowNotification
            object:nil
            queue:nil
            usingBlock:^(NSNotification *notification) {
                SKCKeyboardController *_strongSelf = _weakSelf;
                
                CGRect keyboardFrame = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
                
                UIScrollView *scrollView = _strongSelf.scrollView;
                UIView *firstResponder = [scrollView findFirstResponder];
                CGRect convertedKeyboardFrame = [scrollView convertRect:keyboardFrame fromView:nil];
                CGFloat keyboardHeightDiff = convertedKeyboardFrame.size.height - _strongSelf.keyboardState.keyboardHeight;
                
                if (!_strongSelf.originalScrollViewState) {
                    [_strongSelf setOriginalScrollViewState:
                        [[SKCScrollViewState alloc]
                            initWithContentInset:scrollView.contentInset
                            scrollIndicatorInsets:scrollView.scrollIndicatorInsets
                        ]
                    ];
                }
                
                [_strongSelf setKeyboardState:
                    [[SKCKeyboardState alloc]
                        initWithKeyboardType:[(id<UITextInputTraits>)firstResponder keyboardType]
                        autocorrectType:[(id<UITextInputTraits>)firstResponder autocorrectionType]
                        keyboardHeight:convertedKeyboardFrame.size.height
                    ]
                ];
                
                CGPoint scrollViewContentOffset = _strongSelf.scrollView.contentOffset;
                if (firstResponder) {
                    scrollViewContentOffset = [_strongSelf contentOffsetToCenterView:firstResponder];
                }
                
                UIEdgeInsets scrollViewContentInset = scrollView.contentInset;
                UIEdgeInsets scrollViewScrollIndicatorInsets = scrollView.scrollIndicatorInsets;
                scrollViewContentInset.bottom += keyboardHeightDiff;
                scrollViewScrollIndicatorInsets.bottom += keyboardHeightDiff;
                
                CGFloat animationDuration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
                if (animationDuration < 0.001) {
                    animationDuration = 0.25;
                }
                [UIView animateWithDuration:animationDuration animations:^{
                    [scrollView setContentOffset:scrollViewContentOffset];
                    [scrollView setContentInset:scrollViewContentInset];
                    [scrollView setScrollIndicatorInsets:scrollViewScrollIndicatorInsets];
                }];
            }
        ];
        
        _keyboardWillHideObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:UIKeyboardWillHideNotification
            object:nil
            queue:nil
            usingBlock:^(NSNotification *notification) {
                SKCKeyboardController *_strongSelf = _weakSelf;
                SKCScrollViewState *previousScrollViewState = _strongSelf.originalScrollViewState;
                if (previousScrollViewState) {
                    [_strongSelf setOriginalScrollViewState:nil];
                    
                    UIScrollView *scrollView = _strongSelf.scrollView;
                    [UIView animateWithDuration:[[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue] animations:^{
                        [scrollView setContentInset:previousScrollViewState.contentInset];
                        [scrollView setScrollIndicatorInsets:previousScrollViewState.scrollIndicatorInsets];
                    }];
                }
                [_strongSelf setKeyboardState:nil];
            }
        ];
    }
    return self;
}

- (IBAction)firstResponderDidChange:(id)sender
{
    [self _updateContentOffset:sender];
}

- (IBAction)dismissKeyboard:(id)sender
{
    [self.scrollView endEditing:YES];
}

#pragma mark - Properties

- (BOOL)isKeyboardShowing
{
    return nil != self.keyboardState;
}

- (BOOL)isKeyboardOfSameType:(UIView *)view
{
    return [view conformsToProtocol:@protocol(UITextInputTraits)]
        && (self.keyboardState.keyboardType == [(id<UITextInputTraits>)view keyboardType])
        && (self.keyboardState.autocorrectionType == [(id<UITextInputTraits>)view autocorrectionType]);
}

- (void)setScrollView:(UIScrollView *)scrollView
{
    if (_scrollView != scrollView) {
        _scrollView = scrollView;
        
        if (_scrollView) {
            UIGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard:)];
            [_scrollView addGestureRecognizer:tapGestureRecognizer];
        }
    }
}

#pragma mark - UITextViewDelegate Methods

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [self _updateContentOffset:textView];
}

- (void)_updateContentOffset:(UIView *)view
{
    if (self.isKeyboardShowing && [self isKeyboardOfSameType:view]) {
        [self.scrollView setContentOffset:[self contentOffsetToCenterView:view] animated:YES];
    }
}

- (CGPoint)contentOffsetToCenterView:(UIView *)view
{
    CGFloat scrollViewCenter = floorf(0.5 * (self.scrollView.frame.size.height - self.keyboardState.keyboardHeight));
    CGFloat textViewCenter = [self.scrollView convertPoint:view.center fromView:view.superview].y;
    return CGPointMake(self.scrollView.contentOffset.x, textViewCenter - scrollViewCenter);
}

@end

@implementation UIView (FirstResponder)

- (UIView *)findFirstResponder
{
    if (self.isFirstResponder) {
        return self;
    }
    for (UIView *subView in self.subviews) {
        UIView *responder = [subView findFirstResponder];
        if (responder) {
            return responder;
        }
    }
    return nil;
}

@end

@implementation SKCKeyboardState

- (instancetype)initWithKeyboardType:(UIKeyboardType)keyboardType autocorrectType:(UITextAutocorrectionType)autocorrectionType keyboardHeight:(CGFloat)keyboardHeight
{
    if (nil != (self = [super init])) {
        _keyboardType = keyboardType;
        _autocorrectionType = autocorrectionType;
        _keyboardHeight = keyboardHeight;
    }
    return self;
}

@end

@implementation SKCScrollViewState

- (instancetype)initWithContentInset:(UIEdgeInsets)contentInset scrollIndicatorInsets:(UIEdgeInsets)scrollIndicatorInsets
{
    if (nil != (self = [super init])) {
        _contentInset = contentInset;
        _scrollIndicatorInsets = scrollIndicatorInsets;
    }
    return self;
}

@end
