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
- Warm near-neutral page backgrounds
- Black / near-black / deep charcoal for structure and dark-mode pages

Accent:
- One saturated vermillion (`#B8451F` light, `#E0522E` dark)
- Use it for the selected control in a group, the current/next indicator, toggles, and small action affordances
- Inactive siblings use text-secondary, not a washed accent
- Do not fill cards, navigation bars, or large buttons with vermillion
- The selected tab may use a small `accent-tint` wash; nothing else should

Accents should be visually concentrated rather than used as large surfaces.

Do not use purple or sage-green as a default identity color. Avoid multi-color gradients that resemble generic AI products.

## Light theme direction
- Primary background: warm near-white (`#F6F4F1`).
- Elevated surfaces: white.
- Text: warm charcoal (`#292724`).
- Secondary text: warm gray (`#96938C`) with sufficient contrast.
- Vermillion: the only saturated identity color; keep it small.
- Bright accents: sparingly used for emphasis.

## Dark theme direction
- Background: near-black (`#0D0D0E`), not lifted sage grey.
- Surfaces: slightly lifted (`#161617`) so cards separate from the page.
- Primary text: warm off-white (`#E5E4E1`).
- Secondary text: muted warm gray (`#7A7873`).
- Vermillion: slightly brighter (`#E0522E`) for contrast on near-black.
- Accents: remain bright but use them on small areas and maintain contrast.

## Color usage rules
- Backgrounds and large surfaces should remain quiet.
- Strong colors should be rare.
- A component should not need multiple saturated colors to explain itself.
- Status must not depend on color alone; pair color with text, iconography, shape, or placement.
- Do not use a different color for every category unless category recognition is a proven product need.

## Gradients
Page backgrounds are flat near-neutrals. Gradients are allowed only for:
- a very quiet hero wash if a single surface needs lift;
- small decorative transitions.

Rules:
- Prefer two closely related near-neutral tones.
- Keep contrast low.
- Never make a gradient the main source of meaning.
- Avoid purple-blue-pink “AI” gradients and sage-green identity washes.
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
- `background` / `page`
- `surface`
- `surface-muted`
- `text-primary`
- `text-secondary`
- `border-subtle`
- `brand` / `accent` (vermillion)
- `brand-soft` / `accent-tint`
- `accent-attention`
- `danger`
- `focus-ring`

The exact values should live in the app's styling/token system rather than in feature components.
