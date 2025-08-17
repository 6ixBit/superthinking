# superthinking

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

- Test With Google Auth:

run for redirect of Google auth: flutter run -d chrome --web-port 5173

## UI Design Guide

### Brand Colors

- Primary: `#3A86FF`
- Secondary: `#66D1C1`
- Success: `#34C759`
- Danger: `#FF3B30`
- Background: `#FFF7F0`
- Card: `#FFFFFF`

### Warm Orange Gradient Palette

Used in visual backgrounds and animations:

- `#FF994D`
- `#FFAD66`
- `#FFC180`
- `#FFD7A8`
- `#FFE7D1`

### Gradients

- Soft brand card gradient (profile card):
  - From: Primary (18% opacity)
  - To: Secondary (18% opacity)
  - Direction: Top-left → Bottom-right
- Attribute progress background (session detail):
  - Colors: Red/Amber/Green at 10% opacity with stops [0.0, 0.5, 1.0]

### Text Colors (usage)

- Body subdued: `black54`
- Strong body/title: `black87`
- Secondary UI: `black45`

### Shape and Radii

- 24: Feature cards (prominent surfaces)
- 18: Special elements (record screen tiles)
- 16: Cards, list items, containers
- 14: Buttons/inputs on profile-like surfaces
- 12: Pills/badges and small containers
- 10/9/8/4: Small controls and chips

### Shadows

- Brand card shadow: Primary @ 12% opacity, blur 24, spread 2, offset (0, 8)
- Generic card shadow: Black @ 4% opacity, blur 8, offset (0, 2)

### Theming

- Material 3 with `ColorScheme.fromSeed(seedColor: Primary)`
- Scaffold background uses Background color, cards use Card color

### Notes

- Storage and RLS enforce `<userId>/...` object paths; unrelated to UI but impacts asset URL shape in logs.
