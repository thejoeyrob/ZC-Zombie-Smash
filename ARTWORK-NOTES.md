# Artwork added in 7.5

Created with the built-in image-generation tool; converted to WebP for the game.
Existing refined characters and weapon cutouts retain their source alpha.

- prop-barrel.webp: complete red worn fuel drum, steel bands, yellow flammable
  symbol, crisp comic shading, generous transparent margins, no scenery.
- console-toxic.webp: dark corroded metal, acid-green piping and toxic stains.
- console-splatter.webp: scarlet/ivory paint splashes over gunmetal.
- console-hazard.webp: worn yellow/black warning stripes and rugged steel.
- console-electro.webp: cobalt metal with violet/blue energized edges.
- console-circuit.webp: emerald circuitry and gold traces in anodized metal.

Skin prompt constraints: preserve the straight-on portrait console template,
keep top/side frame positions, extend the opening downward, leave a textured
blank lower deck, no baked buttons/text. Software supplies all controls and the
same fixed screen geometry for every skin.

- story-mantis.webp: the crowned emerald-coated villain in a ruined green
  laboratory, glowing staff, hypnotic monitors, entire main figure visible.
- story-army.webp: brainwashed comrades and zombies on a ruined British street.
- story-joey.webp: full-body tactical Joey holding the line with his rifle.

Comic prompt constraints: match the supplied character reference style, bold
ink and rich shading, 4:3 panel, safe framing, no baked words or visible organs.
Story text is accessible HTML, including the user's King of Proctology premise.


# Artwork added in 7.10

Built-in image generation, three separate edits using console-toxic.webp as the
structural reference. Originals are retained outside the runtime; final WebPs:
console-rustyard.webp, console-void.webp, console-warzone.webp (900×1600).
Existing nine skin files were resized by at most one source pixel to the same
900×1600 dimensions. No character, boss or weapon artwork was replaced.

Shared prompt: preserve the reference's straight-on portrait outer outline,
black screen opening, top rail, slim side rails, blank lower control deck and
metallic bevel. Change decorative material only. No baked controls, joystick,
buttons, text, logos or perspective. All four corners visible, edge-to-edge.
Crisp comic-realistic premium hardware with restrained edge lighting.

- Rustyard: oxidized copper, turquoise verdigris seams, gunmetal rails, warm
  copper hardware, teal illuminated aperture trace and worn copper lower deck.
- Void Reactor: graphite/violet anodized steel, amethyst edges, narrow luminous
  reactor channels, brushed black lower deck, silver hardware; restrained detail.
- Warzone: olive-drab ceramic-coated plates, forest camo stippling, muted brass
  hardware, amber strips, battlefield scratches and olive-carbon rails.

Runtime uses the eight decorative CSS slices from console-layout.js. This is
intentional: raster frame variation can never dictate gameplay dimensions again.
Gallery tiles use the same composition, rather than raw differently-sized holes.
