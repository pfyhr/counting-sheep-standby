# 🐑 Counting Sheep

A nightstand animation for iPhone — sheep jump over a fence as you drift off to sleep.

**[→ Open it](https://pfyhr.github.io/counting-sheep-standby/)**

---

```
        *    .  *       .        *    .       *
   .         *      .       *              .
                  ·                 *
        *                .                   *

                            )
                   /\_____/|       🌙
  ________________/ o   o  |________________________
  |                \_____/                          |
  |                  |||                            |
  |      🐑 ~~~>    |||||    ~~~> 🐑               |
  |__________________|||||__________________________|
```

## Features

- Physics-based parabolic jump arc (real projectile motion equations)
- Random jump height each sheep
- 5% chance of a backflip
- Sheep counter ticks up at the exact moment each sheep clears the fence
- Live clock and date
- Tap to dim for nightstand comfort
- Screen wake lock (keeps display on while open)
- Installable as a PWA — works fullscreen with no browser chrome

## Install on iPhone

1. Open **[pfyhr.github.io/counting-sheep-standby](https://pfyhr.github.io/counting-sheep-standby/)** in Safari
2. Tap the Share button → **Add to Home Screen**
3. Prop your phone up while charging

## How it works

The jump uses two independent CSS animations on nested elements so X and Y can have different easing curves:

- **Horizontal** — `linear` (constant velocity)
- **Vertical** — `cubic-bezier(0, 0.67, 0.33, 1)` rising, `cubic-bezier(0.67, 0, 1, 0.33)` falling

The bezier values are derived by degree-elevating the quadratic Bézier that represents constant-gravity projectile motion, giving an exact parabola rather than an approximation.

Per-cycle randomness (height, backflip) is driven by the [Web Animations API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Animations_API) so new keyframes are generated in JS each loop.
