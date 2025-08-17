# UI Design Guide

## Brand Palette

- Primary: `#3A86FF`
- Secondary: `#66D1C1`
- Success: `#34C759`
- Danger: `#FF3B30`
- Background: `#FFF7F0`
- Card: `#FFFFFF`

## Warm Orange Gradient Palette

Used in visual backgrounds/animations (record screen aurora):

- `#FF994D`
- `#FFAD66`
- `#FFC180`
- `#FFD7A8`
- `#FFE7D1`

## Gradients

- Soft brand card gradient (profile card)
  - From: Primary at 18% opacity
  - To: Secondary at 18% opacity
  - Direction: Top-left → Bottom-right
- Attribute progress background (session detail)
  - Colors: Red/Amber/Green at 10% opacity
  - Stops: `[0.0, 0.5, 1.0]`

## Neutrals and Text Usage

- Strong body/title: `black87`
- Secondary body: `black54`
- Tertiary/secondary UI: `black45`
- Subtle dividers/overlays: `black12`, `black04`
- Surface: `white`
- Greys used:
  - `grey.shade200` (light surfaces)
  - `grey.shade600` (icons/text in secondary context)

## Utility Colors Referenced

- Red (errors, destructive actions), including `Colors.red`, `Colors.red.shade400`
- Green (positive state), including `Colors.green`, `Colors.green.shade700`
- Amber (neutral warning/accent), `Colors.amber`
- Blue (accents), `Colors.blue`, `Colors.blueAccent`
- Orange (accents), `Colors.orange`, `Colors.orange.shade600`
- Purple/Teal occasional accents, `Colors.purple`, `Colors.teal.shade600`

## Shape and Radii

- 24: Feature cards / prominent surfaces
- 18: Special elements (e.g., record screen tiles)
- 16: Cards, list items, containers
- 14: Buttons/controls on profile-like surfaces
- 12: Pills/badges and compact containers
- 10 / 9 / 8 / 4: Small controls, chips, tags

## Shadows

- Brand card shadow (on gradient surfaces)
  - Color: Primary @ 12% opacity
  - Blur: 24, Spread: 2, Offset: (0, 8)
- Generic card shadow (lists/cards)
  - Color: Black @ 4% opacity
  - Blur: 8, Offset: (0, 2)

## Theming

- Material 3, `ColorScheme.fromSeed(seedColor: Primary)`
- Scaffold background: Background color
- Card surfaces: Card color

## File References (for maintainers)

- Theme: `lib/theme/app_colors.dart`, `lib/theme/app_theme.dart`
- Warm orange palette: `lib/screens/record_session_screen.dart` (Aurora painter)
- Soft brand gradient + brand shadow: `lib/screens/profile_screen.dart` (dominant thinking style card)
- Attribute gradient: `lib/screens/session_detail_screen.dart` (progress container)
- Generic card shadow: `lib/screens/sessions_screen.dart` (list card)

## Usage Guidelines

- Use Primary for CTAs, selection states, and key accents.
- Reserve Secondary for complementary accents and gradients.
- Use the warm orange palette for ambient/expressive visuals, not text.
- Prefer `black87` for primary text, `black54` for secondary, `black45` for tertiary.
- Keep container radii consistent with the scale above; default to 16 for cards.
- Apply subtle shadows sparingly to elevate interactive surfaces.
