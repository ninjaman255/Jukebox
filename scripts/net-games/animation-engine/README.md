# 📘 Animation System Documentation
## Overview
### This animation system provides a data-driven, extensible animation framework supporting:
- Value interpolation with easing
- Looping, ping-pong, and instant animations
- Discrete (step-based) value handling
- Multi-step animation sequences
- High-level, reusable animation presets

### The system is split into three layers:
Layer	        File	                            Responsibility
Enums	        animation-enums.lua	                Canonical animation constants
Engine	        animation-engine.lua	            Core animation runtime
Sequences	    animation-sequences.lua	            High-level animation helpers

# 📁 animation-enums.lua
**Purpose: Defines all shared string enums used throughout the animation system to prevent magic strings and ensure consistency.**

## Easing Functions
**AnimationEnums.easing_function_names**

**Name**	                **Description**
instant	                No interpolation; value changes immediately
linear	                Constant rate interpolation
ease_in	                Slow start
ease_out	            Slow end
ease_in_out	            Slow start & end
smoothstep	            Smooth polynomial interpolation
smootherstep	        Higher-order smoothstep
elastic_in	            Elastic overshoot at start
elastic_out	            Elastic overshoot at end
elastic_in_out	        Elastic both directions
bounce_in	            Bounce at start
bounce_out	            Bounce at end
square	                Quadratic curve
cubic	                Cubic curve

## Animation Types
**AnimationEnums.animation_types**

**purpose: classification and metadata.**

**Type**	                **Usage**
SUMMON	                    Entry animations
SET	                        Instant transitions
POSITION_CHANGE	            Movement
ATTACK	                    Combat effects
SLIDE	                    UI or entity sliding
BOB	                        Vertical oscillation
PULSE	                    Scaling pulses
SHAKE	                    Screen or object shake
FADE	                    Alpha transitions
TINT	                    Color changes
COLOR_PULSE	                Repeating color animations

## Animation Properties
**AnimationEnums.animation_properties**

**Property**	     |       **Meaning**
x, y	             |       Position
scale	             |       Uniform scale
scaleX, scaleY	     |       Non-uniform scale
rotation	         |       Rotation angle
alpha	             |       Transparency
r, g, b, a	         |       Color channels
Directions           |       AnimationEnums.directions

**Used by directional animations:** up, down, left, right, in, out

## Triggers
**AnimationEnums.triggers**

**Trigger**	                    **Fired When**
on_click	                    Input click
on_hover	                    Cursor hover
on_show	                        Object appears
on_hide	                        Object disappears
on_start	                    Animation begins
on_complete	                    Animation ends

# 📁 animation-engine.lua
**Purpose: The core runtime that:**
- Interpolates values over time
- Manages animation lifecycle
- Executes sequences and callbacks
- Integrates with the game tick loop

## 🔹 Core API
**AnimationEngine.animate(start, target, duration, options)**
Creates and starts an animation.

**Parameters:**
**Name**	                **Type**	        **Description**
start	                    table	Initial values
target	                    table	Target values
duration	                number	Seconds
options	                    table	Behavior config
Options                     Table

**Field**	                    **Type** **Description**
easing	                    Easing function name
easing_back	                Backward easing (ping-pong)
loop	                    Boolean
ping_pong	                Boolean
max_cycles	                Number
discrete	                table              { "key1", "key2" }
on_update(values, t, phase)	Per-frame callback
on_complete(values, interrupted)	Completion callback

Example
AnimationEngine.animate(
  { x = 0 },
  { x = 100 },
  0.5,
  {
    easing = "ease_out",
    on_update = function(v) sprite.x = v.x end
  }
)

Instant Animations

If easing = "instant":

Values apply immediately

on_update fires once

Animation completes same frame

AnimationEngine.stop_animation(id)

Stops an animation.

Triggers on_complete(..., true)

Returns true if stopped

🔹 Sequences
AnimationEngine.create_sequence(steps, options)

Creates a multi-step animation.

Step Types
1. animate
{
  type = "animate",
  duration = 0.3,
  start = { x = "current" },
  target = { x = "current+20" },
  easing = "ease_out"
}


Supported value references:

Keyword	Meaning
"current"	Last step value
"current+N"	Offset from last
"original"	Initial snapshot
2. delay
{ type = "delay", duration = 0.2 }

3. callback
{
  type = "callback",
  callback = function() print("Step reached") end
}

AnimationEngine.start_sequence(id)

Starts execution.

AnimationEngine.update_sequences(dt)

Advances delays and transitions.

AnimationEngine.stop_sequence(id)

Stops sequence and active animation.

🔹 Discrete-First Animations
AnimationEngine.animate_discrete_first(...)

Discrete values (e.g. sprite frame, state) update immediately, while continuous values animate.

Use Case

Frame index changes instantly

Position fades smoothly

🔹 Instant Helpers
AnimationEngine.set_to(object, values)

Immediately applies values using setters when available.

🔹 Utility
Function	Purpose
delay(seconds, fn)	Deferred callback
update_callbacks()	Internal scheduler
get_active_count()	Active animations
clear_all()	Hard reset
🔹 Engine Tick Hook
Net:on("tick", function (event)
  AnimationEngine.tick(event.delta_time)
end)


This ensures animations advance automatically.

📁 animation-sequences.lua
Purpose

Provides high-level, reusable animation behaviors built on top of the engine.

🔹 Common Animations
Movement
AnimationSequences.move_to(object, x, y, duration)

Scaling
AnimationSequences.scale_to(object, 1.2)

Rotation
AnimationSequences.rotate_to(object, 45)

Fade
AnimationSequences.fade_to(object, 128)

Tint
AnimationSequences.tint_to(object, 255, 0, 0)

🔹 Advanced Effects
Color Pulse
AnimationSequences.color_pulse(
  object,
  { r=255, g=0, b=0, a=255 },
  { r=0, g=0, b=255, a=200 },
  { loop = true, ping_pong = true }
)

Shake
AnimationSequences.shake(sprite, {
  intensity = 5,
  duration = 0.2
})


Includes:

Positional jitter

Rotational wobble

Intensity decay

Complex Summon

A cinematic, multi-step animation:

Bezier arc movement

Scale pulse

Optional rotation wobble

Bounce settle

AnimationSequences.complexSummon(
  sprite,
  0, 100, 0.5,
  100, 100, 1.0,
  { arc_height = 40, wobble_deg = 10 }
)

Menu Cursor
AnimationSequences.menuCursor(cursor)


Returns:

{ bob = animationId, pulse = animationId }

🔹 Utilities
Function	Description
reset(object)	Restores base values
stopAll()	Placeholder
isAnimating()	Placeholder
✅ Design Highlights

Fully data-driven

Deterministic lifecycle

Composable sequences

Game-loop safe

UI & gameplay ready