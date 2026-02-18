# ONB Stardust
- [ONB Stardust](#onb-stardust)
  - [About](#about)
    - [Changelog](#changelog)
      - [1.0.1](#101)
      - [1.0.0](#100)
  - [Installing](#installing)
  - [Example](#example)
    - [Drawing](#drawing)
  - [Particle API](#particle-api)
  - [Particle System API](#particle-system-api)
    - [`sys.spawn(self, a, b)`](#sysspawnself-a-b)
    - [`sys.frames(self, a, b)`](#sysframesself-a-b)
    - [`sys.start_x(self, a, b)`](#sysstart_xself-a-b)
    - [`sys.start_y(self, a, b)`](#sysstart_yself-a-b)
    - [`sys.vel_x(self, a, b, mode)`](#sysvel_xself-a-b-mode)
    - [`sys.vel_y(self, a, b, mode)`](#sysvel_yself-a-b-mode)
    - [`sys.acc_x(self, a, b, mode)`](#sysacc_xself-a-b-mode)
    - [`sys.acc_y(self, a, b, mode)`](#sysacc_yself-a-b-mode)
    - [`sys.scl_x(self, a, b, mode)`](#sysscl_xself-a-b-mode)
    - [`sys.scl_y(self, a, b, mode)`](#sysscl_yself-a-b-mode)
    - [`sys.ach(self, a, b, mode)`](#sysachself-a-b-mode)
    - [`sys.rch(self, a, b, mode)`](#sysrchself-a-b-mode)
    - [`sys.gch(self, a, b, mode)`](#sysgchself-a-b-mode)
    - [`sys.bch(self, a, b, mode)`](#sysbchself-a-b-mode)
    - [`sys.fco_x(self, a, b)`](#sysfco_xself-a-b)
    - [`sys.fco_y(self, a, b)`](#sysfco_yself-a-b)
    - [`sys.delay(self, a, b)`](#sysdelayself-a-b)
    - [`sys.limit(self, limit)`](#syslimitself-limit)
    - [`sys.apply(self, force)`](#sysapplyself-force)
    - [`sys.gen(self, count)`](#sysgenself-count)
    - [`sys.for_each(self, fn)`](#sysfor_eachself-fn)
  - [Modes](#modes)
    - [Random](#random)
    - [Ease-In Presets](#ease-in-presets)
    - [Custom](#custom)
## About
Written by James King (https://github.com/TheMaverickProgrammer)

ONB Startdust is highly customizable particle system and API for ONB.

You can ...
- have many particle systems going at once.
- choose when to draw particles.
- change any system in real-time for dynamic effects.

### Changelog
#### 1.0.1
- Added red, green, and blue channel property to stardust.
- Fixed bad default values for some vector animation properties.

#### 1.0.0
- Initial release

## Installing
To Install this library, drop the folder with its contents under your server's
`/scripts/libs/` path and require it as shown below.

```lua
local stardust = require("scripts/stardust/lib")
```

`stardust` is a constructor. This constructor will add a new particle system to a private list and then return a reference to the newly created system.
This private list tracks all created particle systems and will update each system on every server tick for you.

## Example
Here's an example on how to make slow moving stars.

```lua
local stars =
    stardust()
    :frames(300)
    :start_x(100, 580)
    :start_y(0, 480)
    :vel_x(-0.1)
    :vel_y(0.1)
    :acc_x(-0.001, -0.01)
    :acc_y(0.001, 0.001)
    :delay(3)
    :spawn(2)
    :limit(1200)
    :build()
```

This example encompasses every detail we need for any particle system.
All except for one function on the particle system returns the system
as a reference so that more configuration can be chained in a sequence.

However, the `build()` function does not return the particle system.
It should be last in the construction chain.

### Drawing
Draw by passing in a callback function to `sys.for_each`.
Here is the definition of `for_each`:

```lua
sys.for_each = function(self, fn)
    for i,p in ipairs(self.liv) do
        fn(i, p, p.cnt > 0)
    end
end
```

The signature for the callback function `fn` is `function(index, particle, is_alive)`.

The `index` is the integer index in the system.
The `particle` is the object to draw.
The `is_alive` parameter is a boolean to inform if the particle is dead and should be cleared.

Let's see an example on using it with ONB servers.

```lua
Net:on("tick", function(event)
    DT = DT + event.delta_time
    for player_id, _ in pairs(players) do
        stars:for_each(
            function(index, value, is_alive)
                local data = { sx=0, sy=0 }

                if is_alive then
                    data = {
                        x=value.pos.x,
                        y=value.pos.y,
                        ox=32,
                        oy=32,
                        sx=value.scl.x,
                        sy=value.scl.y,
                        a=value.ach
                    }
                end

                data.id = index

                Net.player_draw_sprite(player_id, 'foo', data)
            end
        )
    end
end
```

We make use of `is_alive` to conditionally send the `data` containing zero'd scale x-y pairs.
Effectively, this clears the particles from the client as they cannot be seen.

Otherwise, we use the particle data to draw our particle sprite named `"foo"`.

## Particle API
The particles `p` in a particle system are objects and therefore lua tables `{}`.

They have the following properties:
- `p.max` - the life time of the particle.
- `p.cnt` - the remaining life time of the particle (counter).
- `p.pos` - the 2D vector position.
- `p.fco` - the 2D vector **f**riction\* **co**efficient. (default: `(1,1)`).
- `p.acc` - the 2D vector acceleration of the particle.
- `p.vel` - the 2D vector velocity of the particle.
- `p.scl` - the 2D vector scale of the particle for sprites.
- `p.rot` - the rotation in degrees.
- `p.ach` - the integer **a**lpha color **ch**annel of the particle (opacity).
- `p.rch` - the integer **r**ed color **ch**annel of the particle.
- `p.gch` - the integer **g**reen color **ch**annel of the particle.
- `p.bch` - the integer **b**lue color **ch**annel of the particle.

> A friction value of zero in any of the two vector components will halt the particle completely. 
> A value of one behaves as if there is no friction at all.

## Particle System API
The systems `sys` in the API are objects and therefore lua tables `{}`.

The API for each property setter is similar.
They take on the signature `function(self, a, b)` where `[a, b]` is an optional range of values. 
If only one value is provided, then the range becomes `[a, a]` or just `a`.

Some properties can be animated over time using "ease-in" math functions.
Those setters in the API will have an additional parameter `mode`.

### `sys.spawn(self, a, b)`
How many particles to spawn when the spawn condition is met.
### `sys.frames(self, a, b)` 
How many frames for a particle to live.
### `sys.start_x(self, a, b)`
Where to spawn a particle on the screen horizontally.
### `sys.start_y(self, a, b)` 
Where to spawn a particle on the screen vertically.
### `sys.vel_x(self, a, b, mode)`
The x velocity of a particle.
### `sys.vel_y(self, a, b, mode)`
The y velocity of a particle.
### `sys.acc_x(self, a, b, mode)`
The x acceleration of a particle.
### `sys.acc_y(self, a, b, mode)`
The y acceleration of a particle.
### `sys.scl_x(self, a, b, mode)`
The x scale of a particle.
### `sys.scl_y(self, a, b, mode)`
The y scale of a particle.
### `sys.ach(self, a, b, mode)`
The **a**lpha color **ch**annel of a particle's sprite (opacity).
### `sys.rch(self, a, b, mode)`
The **r**ed color **ch**annel of a particle's sprite.
### `sys.gch(self, a, b, mode)`
The **g**reen color **ch**annel of a particle's sprite.
### `sys.bch(self, a, b, mode)`
The **b**lue color **ch**annel of a particle's sprite.
### `sys.fco_x(self, a, b)`
The x **f**riction **co**efficient of a particle's velocity.
### `sys.fco_y(self, a, b)`
The y **f**riction **co**efficient of a particle's velocity.
### `sys.delay(self, a, b)`
The number of ticks between the spawn condition.
When the system's count-down reaches zero from this initial value,
then the spawn condition is met.
### `sys.limit(self, limit)`
The server budget for particles for this particle system, `sys`.
Effectively, the "max" allowed particles for this system.
### `sys.apply(self, force)`
Apply a 2D vector `force` onto every particle.
This operation adds the `force` vector to the particle's current `acc` value.
### `sys.gen(self, count)`
This is invoked automatically when the spawn condition is satisfied.
However, it can be invoked manually as well.
### `sys.for_each(self, fn)`
The callback function `fn` must have the following signature:

```lua
function(index, particle, is_alive) ... end
```

Every particle in the system will be applied to this callback.
This callback is used primarily to send draw-sprite commands but can be used in other ways.

## Modes
In some particle system setter functions are the field `mode`.
This is an optional field. By default the value is `"random"`.

Other possible values are:
- `"linear"`
- `"square"`
- `"cubic"`
- custom
  
### Random
Random setters will choose a random scalar or vector value in the `[a, b]` range provided as the particle's initial value.
This tends to be the only value and makes for very stiff particle effects.

### Ease-In Presets
There are other functions provided which change the behavior of the particles in the system. Instead of randomly selecting an initial value from a range, every particle begins with their inital value set to the minimal number in your provided `[a, b]` range of values. As the particle decays and its life approaches zero, the particle's properties will approach their respective `b` maximum value; if one was provided.

```lua
linear=function(x) return x end,
square=function(x) return x*x end,
cubic=function(x) return x*x*x end,
```

### Custom
To provide a custom ease-in, simply provide a function instead of a string preset. 
The function should be defined like so:

```lua
function (x)
    local y = ...
    -- do some stuff
    return y 
end
```

Where `x` is the floating-point representation of the particle lifetime as values `[0.0, 1.0]`.

For example, lets say a particle has a `max` lifetime of `300` frames. 
But it was only on frame `100`.
Then `x` will be calculated as
- `x = 1.0 - (cnt/max)` 
- which is to say `x = 1.0 - (100/300)` 
- or `x = 1.0 - 0.33` 
- and finally `0.66`.

Therefore in this example `x=0.66` which is more than half (50%) of this particle's lifetime.

The return value of this ease-in function should also be in the same range `[0.0, 1.0]`.

This suggest you write some conversion of `x` to a custom progression system and return the new value as `y`.