# UI and UX Implementation

## Design system

Build one, and use it everywhere.

- **Spacing scale**: 4, 8, 12, 16, 24, 32, 48. Pick a base unit and stick to it.
- **Type scale**: a fixed set of roles (display, title, body, caption) with defined sizes, weights, and line heights. Never an arbitrary font size.
- **Color tokens**: semantic names (`surface`, `onSurface`, `primary`, `error`, `divider`), not raw colors. This makes dark mode and theming a token change, not a hunt through the code.
- **Elevation and shape**: a defined set of corner radii and shadow/elevation levels.
- **Component library**: buttons, inputs, cards, sheets, tabs, lists, badges, toasts. Every screen uses these, not locally built variants.
- **Motion tokens**: durations and easing curves, defined once.

```text
semantic tokens -> light theme / dark theme -> components -> screens
```

Never reference a raw hex value in a screen. Theme differences then become a token problem, not an audit.

## Layout

- Use a layout system with consistent gutters and margins.
- Support the safe area: notches, gesture bars, status bars, rounded corners.
- Handle the keyboard: scroll the focused field into view, use the keyboard's "next" action to move between fields, and dismiss on submit.
- Support both orientations if the app allows it, or explicitly lock it and handle the rotation gracefully.
- Use safe areas and insets rather than hardcoded margins. Status bar height is not a constant.
- Constraint-based layout (constraints, flexbox, Compose constraints) adapts. Fixed absolute positions do not.

## Navigation

- Model navigation as a single state value, not a stack managed by hand across screens.
- Three patterns: stack (push/pop), tabs, and modal. Be consistent about which one a screen uses.
- Back must always work and must go somewhere sensible. The system back gesture is not optional.
- Deep links must land on the same screens as in-app navigation, with the same state.
- Preserve scroll position and form state when navigating back. Users notice when it resets.
- Do not use a hamburger drawer for a linear flow. Tabs for peer sections, stack for hierarchy, sheet for a focused task.

## Lists

- Virtualize anything longer than the screen. Never inflate every row.
- Stable keys: an ID, never the index.
- Support pull-to-refresh, infinite scroll, and an explicit "end of list" marker.
- Load states: skeleton rows that match the real layout, so nothing shifts on load.
- Handle a very fast scroll: keep the scroll position stable when data is prepended (offset correction).
- Row heights should be consistent or the list scrolls unpredictably.
- Swipe actions (delete, archive) must be undoable.

## Forms

- One field per concept, with a clear label above it. Placeholder text is a hint, not a label.
- Show the validation error under the field it belongs to, in text, not only a red border.
- Validate on blur, re-validate on change for a field already in error, and validate everything on submit.
- Disable the submit button only while the request is in flight. Do not disable it just because a field is empty; explain what is missing on submit.
- Preserve input on a failed submit.
- Handle the numeric keypad for numeric fields, the email keyboard for email, and the correct autofill hints and content types.
- Support autofill and password managers. Do not block paste.
- Never lose a form because of a rotation or a backgrounding event.

## Every data view needs four states

| State | Requirement |
|-------|-------------|
| Loading | Skeleton matching the final layout. No layout shift. |
| Empty | Explain why it is empty and what to do next. Offer the action. |
| Error | Friendly message, retry button, and a way to get help. |
| Content | The data, plus a pull-to-refresh |

- Never show a spinner and an error simultaneously.
- Never leave an infinite spinner after a failure.
- A blank screen is a bug.

## Feedback

- Immediate visual response to any tap, within one frame. If the action takes time, show a pending state on the control.
- Confirm destructive actions.
- Toast for transient confirmations, snackbar/banner for errors that need action, inline text for field errors.
- Progress indicators for anything over ~300 ms; below that, they feel like flicker.

## Accessibility

- Minimum touch target: 44x44 dp (iOS) / 48x48 dp (Android).
- Label every control. Icon-only buttons need an accessibility label.
- Group related elements and give the group a label.
- Support the platform accessibility APIs: `accessibilityLabel`, `accessibilityHint`, `accessibilityValue`, `contentDescription`, `traversalIndex`.
- Announce dynamic changes: a live region for search results, a save confirmation, a screen change.
- Support dynamic type / font scaling without clipping. Test at the largest size.
- Support keyboard navigation and visible focus on desktop and web.
- Contrast: 4.5:1 for text, 3:1 for large text and meaningful graphics.
- Do not rely on color alone. Pair color with an icon, a shape, or text.
- Respect the reduced-motion setting and disable non-essential animation.
- Respect the increased-contrast setting.
- Support VoiceOver and TalkBack end to end. Test with the screen reader actually running.

## Dark mode

- A separate token set, not an inversion. Semantic tokens map to different values per theme.
- Check every image and illustration in both themes. Transparency and shadows need rethinking.
- Test contrast in both themes.
- Follow the system setting by default, but let the user override.

## Localization and formatting

- Never concatenate translated strings. Use a string resource with placeholders and pluralization rules.
- Use locale-aware formatters for numbers, dates, times, and currency.
- Support right-to-left layouts: use start/end rather than left/right, and mirror directional icons.
- Allow text expansion of 30% without breaking the layout.
- Keep the language list realistic; do not ship a locale the app is not actually tested in.

## Empty, error, and onboarding

- Empty states are an opportunity. Explain the value, then offer the action.
- Error states tell the user what to do next, not just what failed.
- Onboarding: show value before asking for permissions. Ask for permissions in context, at the moment of need, with a reason.

## Performance in the UI

- Keep the main thread clear of IO, JSON parsing, and image decoding.
- Reuse views and recycle images. Downsample to the displayed size.
- Do not rebuild large view hierarchies on every state change. Isolate the state that changes.
- Keep list item views flat and shallow. A deeply nested hierarchy is expensive to measure and layout.
- Animate transforms and opacity. Animating layout properties forces a re-layout every frame.
- Avoid animating on the UI thread when a property animation or a shared element transition would do.

## Common mistakes

- Raw hex colors in screens.
- A spinner as the only loading state, and nothing for empty or error.
- No validation, or validation only on submit.
- A form that loses input on an error.
- Touch targets that are too small, especially icon-only buttons.
- Missing accessibility labels on icon buttons.
- Fixed heights that break with large fonts.
- Hardcoded margins that ignore the safe area.
- Localized strings built by concatenation.
- List rows without stable keys, so reordering scrambles the list.
