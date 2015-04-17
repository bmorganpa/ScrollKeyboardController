#import "SKCKeyboardController.h"

@interface UIView (FirstResponder)

- (UIView *)findFirstResponder;

@end

@interface SKCKeyboardControllerState : NSObject

@property (nonatomic, assign, readonly) UIKeyboardType keyboardType;
@property (nonatomic, assign, readonly) CGFloat keyboardHeight;
@property (nonatomic, assign, readonly) UIEdgeInsets contentInset;
@property (nonatomic, assign, readonly) UIEdgeInsets scrollIndicatorInsets;

- (instancetype)initWithKeyboardType:(UIKeyboardType)keyboardType keyboardHeight:(CGFloat)keyboardHeight contentInset:(UIEdgeInsets)contentInset scrollIndicatorInsets:(UIEdgeInsets)scrollIndicatorInsets;

@end

@interface SKCKeyboardController ()

@property (nonatomic, strong) SKCKeyboardControllerState *originalState;
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
                CGFloat keyboardHeightDiff = convertedKeyboardFrame.size.height - _strongSelf.originalState.keyboardHeight;
                
                [_strongSelf setOriginalState:
                    [[SKCKeyboardControllerState alloc]
                        initWithKeyboardType:[(id<UITextInputTraits>)firstResponder keyboardType]
                        keyboardHeight:convertedKeyboardFrame.size.height
                        contentInset:scrollView.contentInset
                        scrollIndicatorInsets:scrollView.scrollIndicatorInsets]
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
                SKCKeyboardControllerState *previousState = _strongSelf.originalState;
                if (previousState) {
                    [_strongSelf setOriginalState:nil];
                    
                    UIScrollView *scrollView = _strongSelf.scrollView;
                    [UIView animateWithDuration:[[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue] animations:^{
                        [scrollView setContentInset:previousState.contentInset];
                        [scrollView setScrollIndicatorInsets:previousState.scrollIndicatorInsets];
                    }];
                }
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
    return nil != self.originalState;
}

- (BOOL)isKeyboardOfSameType:(UIView *)view
{
    return [view conformsToProtocol:@protocol(UITextInputTraits)]
        && (self.originalState.keyboardType == [(id<UITextInputTraits>)view keyboardType]);
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
    CGFloat scrollViewCenter = floorf(0.5 * (self.scrollView.frame.size.height - self.originalState.keyboardHeight));
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

@implementation SKCKeyboardControllerState

- (instancetype)initWithKeyboardType:(UIKeyboardType)keyboardType keyboardHeight:(CGFloat)keyboardHeight contentInset:(UIEdgeInsets)contentInset scrollIndicatorInsets:(UIEdgeInsets)scrollIndicatorInsets
{
    if (nil != (self = [super init])) {
        _keyboardType = keyboardType;
        _keyboardHeight = keyboardHeight;
        _contentInset = contentInset;
        _scrollIndicatorInsets = scrollIndicatorInsets;
    }
    return self;
}

@end