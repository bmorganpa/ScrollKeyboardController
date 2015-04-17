# ScrollKeyboardController [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

A framework for handling the showing/hiding of the keyboard on iOS. Easily allows you to scroll to your UITextFields and UITextViews so that they are not covered by the keyboard.

## Instructions

1. Put your UITextFields and UITextViews inside a scroll view.
2. Add an SKCKeyboardController object to your storyboard or xib.
3. Wire up the scroll view to the "scrollView" property on SKCKeyboardController.
4. Then wire up the "Editing Did Begin" for each UITextField to "firstResponderDidChange" on SKCKeyboardController.
5. For UITextViews, you should set your SKCKeyboardController object as the UITextView's delegate.