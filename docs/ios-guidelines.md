## Platform

This is a native iPhone application.

Prefer:
- SwiftUI-native components
- platform-standard interaction patterns
- NavigationStack
- sheets
- confirmation dialogs
- context menus where appropriate
- swipe actions where appropriate
- system typography where appropriate
- Dynamic Type
- VoiceOver accessibility
- haptic feedback where it improves interaction

Avoid:
- copying web UI patterns directly into the app
- desktop-style sidebars unless appropriate
- tiny touch targets
- unnecessary custom controls
- excessive modal flows
- hamburger menus when native navigation works better

## Touch targets

Interactive elements should generally provide
a comfortable touch target of approximately 44×44 points
or larger.

## Interaction

Prefer:
- swipe actions for quick secondary actions
- long press/context menus for advanced actions
- sheets for focused creation/editing flows
- inline editing when it reduces friction
- clear destructive-action confirmation

## Motion

Use subtle animation to communicate:
- state changes
- insertion/removal
- schedule changes
- completion
- navigation

Avoid decorative animation.
