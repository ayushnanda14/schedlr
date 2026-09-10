# Design System

## Design north star
Minimal, warm, intelligent, and quietly expressive.

The visual language should feel closer to a beautifully designed personal tool than a corporate dashboard or an AI marketing site.

## Brand qualities
- Calm
- Clean
- Light
- Precise
- Human
- Slightly playful in small details
- Never loud

## Color philosophy
Primary palette:
- White / warm near-white surfaces
- Very light neutral backgrounds
- Light greens and muted green tones
- Black / deep charcoal for primary text and structure

Accent palette:
Use a small set of bright contrasting colors for:
- tiny status indicators;
- pointers/carets;
- selected controls;
- important labels;
- progress markers;
- notification or attention cues;
- small action affordances.

Accents should be visually concentrated rather than used as large surfaces.

Do not use purple as a default accent. Avoid multi-color gradients that resemble generic AI products.

## Light theme direction
- Primary background: white or subtly warm white.
- Elevated surfaces: near-white with very slight contrast.
- Text: black/deep charcoal.
- Secondary text: cool/warm neutral gray with sufficient contrast.
- Green: primary identity color, generally light-to-medium saturation.
- Bright accents: sparingly used for emphasis.

## Dark theme direction
- Background: near-black/deep charcoal rather than pure black everywhere.
- Surfaces: slightly lifted charcoal tones.
- Primary text: soft white/off-white.
- Green: slightly brighter/lighter versions of the light-theme identity greens.
- Accents: remain bright but use them on small areas and maintain contrast.

## Color usage rules
- Backgrounds and large surfaces should remain quiet.
- Strong colors should be rare.
- A component should not need multiple saturated colors to explain itself.
- Status must not depend on color alone; pair color with text, iconography, shape, or placement.
- Do not use a different color for every category unless category recognition is a proven product need.

## Gradients
Gradients are allowed for:
- page backgrounds;
- subtle hero/summary surfaces;
- selected ambient highlights;
- small decorative transitions.

Rules:
- Prefer two closely related tones.
- Keep contrast low.
- Never make a gradient the main source of meaning.
- Avoid purple-blue-pink “AI” gradients.
- Avoid gradients on every card/button.

## Typography
Font: **Lato**.

Hierarchy should come primarily from:
- size;
- weight;
- spacing;
- placement;
- contrast.

Avoid using many font weights. Keep body text comfortable and readable.

Suggested hierarchy:
- Display: reserved for the main Today/date context or high-level summary.
- Heading: clear and compact.
- Body: highly readable.
- Secondary: restrained but accessible.
- Microcopy: short, purposeful, never tiny to the point of strain.

Do not use uppercase labels excessively.

## Spacing
Use a consistent spacing scale based around small increments (approximately 4px/8px rhythm).

Prefer whitespace over decorative separators.

Spacing should establish relationships:
- close spacing = related;
- medium spacing = separate groups;
- large spacing = new section/context.

## Shapes
- Rounded corners should be present but restrained.
- Avoid turning every element into a pill.
- Pills are best for compact statuses, filters, tags, and transient choices.
- Larger surfaces may use moderate corner radii.

## Borders and shadows
Use borders primarily to clarify structure or interaction.

Shadows should be:
- subtle;
- low-contrast;
- used sparingly for elevation rather than decoration.

Avoid stacked shadows and heavy floating-card aesthetics.

## Iconography
Icons should communicate actions or status, not fill visual space.

Prefer a coherent icon set with consistent stroke/fill treatment.

Icon-only controls need accessible labels/tooltips where appropriate.

## Motion
Motion should communicate state change, hierarchy, or continuity.

Prefer:
- short fades;
- subtle movement;
- gentle expansion/collapse;
- schedule transitions that help the user understand what moved.

Avoid:
- excessive bouncing;
- long animations;
- decorative constant motion.

Respect reduced-motion preferences.

## UI composition
Prefer:
- strong page-level hierarchy;
- one dominant primary action;
- compact secondary actions;
- mixed list/timeline layouts where they improve scanning;
- contextual actions next to the thing they affect.

Do not force all information into equal visual containers.

## Theme tokens
The implementation should define semantic tokens rather than hard-coded colors throughout components.

Example token families:
- `background`
- `surface`
- `surface-muted`
- `text-primary`
- `text-secondary`
- `border-subtle`
- `brand-green`
- `brand-green-soft`
- `accent-attention`
- `accent-positive`
- `accent-info`
- `danger`
- `focus-ring`

The exact values should live in the app's styling/token system rather than in feature components.
