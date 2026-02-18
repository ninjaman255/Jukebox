--[[
    TITLE: 
        ONB Stardust
    AUTHOR: 
        Maverick Peppers | Alias: James King | (https://github.com/TheMaverickProgrammer)
    ABOUT:
        Stardust is a highly customizable particle system and API for ONB.

        You can have many particle systems going at once.
        You can choose when to draw them at any time.
        You can also change a system in real-time for dynamic effects.
        See the README.md file that comes with this library.
    LICENSE:
        GNU GENERAL PUBLIC LICENSE
        Version 3, 29 June 2007

        Copyright (C) 2025 Maverick Peppers

        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program. If not, see <https://www.gnu.org/licenses/>.
--]]

local system_set = {}

local Presets = {
    random='random',
    linear=function(x) return x end,
    square=function(x) return x*x end,
    cubic=function(x) return x*x*x end,
}

local vec_one = function()
    return {
        x = 1,
        y = 1
    }
end

local vec_zero = function()
    return {
        x = 0,
        y = 0
    }
end

local ensure_val_or = function(c, val)
    if c == nil then
        c = val
    end

    return c
end

local ensure_vector_or = function(v, val)
    if v == nil then
        v = {}
    end

    if v.x == nil then
        v.x = val
    end

    if v.y == nil then
        v.y = val
    end

    return v
end

local ensure_config = function(c)
    if c == nil then
        c = {}
    end

    c.fco = ensure_vector_or(c.fco, vec_one())
    c.acc = ensure_vector_or(c.acc, vec_zero())
    c.vel = ensure_vector_or(c.vel, vec_zero())
    c.pos = ensure_vector_or(c.pos, vec_zero())
    c.scl = ensure_vector_or(c.scl, vec_one())
    c.cnt = ensure_val_or(c.cnt, 0)
    c.rot = ensure_val_or(c.rot, 0)
    c.ach = ensure_val_or(c.ach, 255)
    c.rch = ensure_val_or(c.rch, 255)
    c.gch = ensure_val_or(c.gch, 255)
    c.bch = ensure_val_or(c.bch, 255)
    c.del = ensure_val_or(c.del, 0)
    c.spn = ensure_val_or(c.spn, 1)

    return c
end

local resolve_mode = function(m)
    if type(m) == 'string' then
        return Presets[m]
    end

    return m
end

local system = function(opts)
    local t = {
        upp = {},
        low = {},
        liv = {},
        len = 0,
        del = 0,
        lim = 1,
        ani = {
            vel_x=Presets.random,
            acc_x=Presets.random,
            scl_x=Presets.random,
            vel_y=Presets.random,
            acc_y=Presets.random,
            scl_y=Presets.random,
            rot=Presets.random,
            ach=Presets.random,
            rch=Presets.random,
            gch=Presets.random,
            bch=Presets.random,
        }
    }

    local lerp_scalar = function(w, s1, s2)
        local s = s2 - s1
        local r = w * s
        return r + s1
    end

    local lerp_integer = function(w, s1, s2)
        return math.ceil(lerp_scalar(w, s1, s2))
    end

    local lerp_vec = function(w1, w2, v1, v2)
        local v = { x = v2.x - v1.x, y = v2.y - v1.y }
        local rx = w1*v.x
        local ry = w2*v.y
        return { x = rx + v1.x, y = ry + v1.y }
    end

    local rand_scalar = function(s1, s2)
        return lerp_scalar(math.random(), s1, s2)
    end

    local rand_vec = function(v1, v2)
        return lerp_vec(math.random(), math.random(), v1, v2)
    end

    local respawn = function(sys, p)
        p.max = sys:rand_cnt()
        p.cnt = p.max

        -- The property's init value is always picked from a range.
        p.pos = sys:rand_pos()
        p.fco = sys:rand_fco()

        -- The property's init value depends on their mode.
        p.acc = ensure_val_or(p.acc, vec_zero())
        p.vel = ensure_val_or(p.vel, vec_zero())
        p.scl = ensure_val_or(p.scl, vec_zero())
        p.rot = ensure_val_or(p.rot, 0)
        p.ach = ensure_val_or(p.ach, 255)
        p.rch = ensure_val_or(p.rch, 255)
        p.gch = ensure_val_or(p.gch, 255)
        p.bch = ensure_val_or(p.bch, 255)

        local acc = sys:rand_acc()
        local vel = sys:rand_vel()
        local scl = sys:rand_scl()
        local rot = sys:rand_rot()
        local ach = sys:rand_ach()
        local rch = sys:rand_rch()
        local gch = sys:rand_gch()
        local bch = sys:rand_bch()
        local start = sys.low

        if sys.ani.acc_x == Presets.random then
            p.acc.x = acc.x
        else
            p.acc.x = start.acc.x
        end

        if sys.ani.acc_y == Presets.random then
            p.acc.y = acc.y
        else
            p.acc.y = start.acc.y
        end

        if sys.ani.vel_x == Presets.random then
            p.vel.x = vel.x
        else
            p.vel.x = start.vel.x
        end

        if sys.ani.vel_y == Presets.random then
            p.vel.y = vel.y
        else
            p.vel.y = start.vel.y
        end

        if sys.ani.scl_x == Presets.random then
            p.scl.x = scl.x
        else
            p.scl.x = start.scl.x
        end

        if sys.ani.scl_y == Presets.random then
            p.scl.y = scl.y
        else
            p.scl.y = start.scl.y
        end

        if sys.ani.rot == Presets.random then
            p.rot = rot
        else
            p.rot = start.rot
        end

        if sys.ani.ach == Presets.random then
            p.ach = ach
        else
            p.ach = start.ach
        end

        if sys.ani.rch == Presets.random then
            p.rch = rch
        else
            p.rch = start.rch
        end

        if sys.ani.gch == Presets.random then
            p.gch = gch
        else
            p.gch = start.gch
        end

        if sys.ani.bch == Presets.random then
            p.bch = bch
        else
            p.bch = start.bch
        end
    end

    local tick_ani = function(sys, p)
        local w = 1.0 - (p.cnt / p.max)

        local acc_x = resolve_mode(sys.ani.acc_x)
        local acc_y = resolve_mode(sys.ani.acc_y)
        local vel_x = resolve_mode(sys.ani.vel_x)
        local vel_y = resolve_mode(sys.ani.vel_y)
        local scl_x = resolve_mode(sys.ani.scl_x)
        local scl_y = resolve_mode(sys.ani.scl_y)
        local rot = resolve_mode(sys.ani.rot)
        local ach = resolve_mode(sys.ani.ach)
        local rch = resolve_mode(sys.ani.rch)
        local gch = resolve_mode(sys.ani.gch)
        local bch = resolve_mode(sys.ani.bch)

        if acc_x ~= Presets.random then
            p.acc.x = lerp_scalar(acc_x(w), sys.low.acc.x, sys.upp.acc.x)
        end

        if acc_y ~= Presets.random then
            p.acc.y = lerp_scalar(acc_y(w), sys.low.acc.y, sys.upp.acc.y)
        end

        if vel_x ~= Presets.random then
            p.vel.x = lerp_scalar(vel_x(w), sys.low.vel.x, sys.upp.vel.x)
        end

        if vel_y ~= Presets.random then
            p.vel.y = lerp_scalar(vel_y(w), sys.low.vel.y, sys.upp.vel.y)
        end

        if scl_x ~= Presets.random then
            p.scl.x = lerp_scalar(scl_x(w), sys.low.scl.x, sys.upp.scl.x)
        end

        if scl_y ~= Presets.random then
            p.scl.y = lerp_scalar(scl_y(w), sys.low.scl.y, sys.upp.scl.y)
        end

        if rot ~= Presets.random then
            p.rot = lerp_scalar(rot(w), sys.low.rot, sys.upp.rot)
        end

        if ach ~= Presets.random then
            p.ach = lerp_integer(ach(w), sys.low.ach, sys.upp.ach)
            p.ach = math.min(255, math.max(p.ach, 0))
        end

        if rch ~= Presets.random then
            p.rch = lerp_integer(rch(w), sys.low.rch, sys.upp.rch)
            p.rch = math.min(255, math.max(p.rch, 0))
        end

        if gch ~= Presets.random then
            p.gch = lerp_integer(gch(w), sys.low.gch, sys.upp.gch)
            p.gch = math.min(255, math.max(p.gch, 0))
        end

        if bch ~= Presets.random then
            p.bch = lerp_integer(bch(w), sys.low.bch, sys.upp.bch)
            p.bch = math.min(255, math.max(p.bch, 0))
        end
    end

    t.config = function(self, opts)
        if opts == nil then
            opts = {}
        end

        opts.upper = ensure_config(opts.upper)
        opts.lower = ensure_config(opts.lower)
        opts.limit = ensure_val_or(opts.limit, 100)

        self.upp = opts.upper
        self.low = opts.lower
        self.lim = opts.limit

        self.len = 0
        self.del = self:rand_del()

        return self
    end

    t.spawn = function(self, a, b)
        b = ensure_val_or(b, a)
        self.upp.spn = math.max(a,b)
        self.low.spn = math.min(a,b)
        return self
    end

    t.frames = function(self, a, b)
        b = ensure_val_or(b, a)
        self.upp.cnt = math.max(a,b)
        self.low.cnt = math.min(a,b)
        return self
    end

    t.start_x = function(self, a, b)
        b = ensure_val_or(b, a)
        self.upp.pos.x = math.max(a,b)
        self.low.pos.x = math.min(a,b)
        return self
    end

    t.start_y = function(self, a, b)
        b = ensure_val_or(b, a)
        self.upp.pos.y = math.max(a,b)
        self.low.pos.y = math.min(a,b)
        return self
    end

    t.vel_x = function(self, a, b, mode)
        b = ensure_val_or(b, a)
        mode = ensure_val_or(mode, Presets.random)
        self.ani.vel_x = mode
        self.upp.vel.x = math.max(a,b)
        self.low.vel.x = math.min(a,b)
        return self
    end

    t.vel_y = function(self, a, b, mode)
        b = ensure_val_or(b, a)
        mode = ensure_val_or(mode, Presets.random)
        self.ani.vel_y = mode
        self.upp.vel.y = math.max(a,b)
        self.low.vel.y = math.min(a,b)
        return self
    end

    t.acc_x = function(self, a, b, mode)
        b = ensure_val_or(b, a)
        mode = ensure_val_or(mode, Presets.random)
        self.ani.acc_x = mode
        self.upp.acc.x = math.max(a,b)
        self.low.acc.x = math.min(a,b)
        return self
    end

    t.acc_y = function(self, a, b, mode)
        b = ensure_val_or(b, a)
        mode = ensure_val_or(mode, Presets.random)
        self.ani.acc_y = mode
        self.upp.acc.y = math.max(a,b)
        self.low.acc.y = math.min(a,b)
        return self
    end

    t.scl_x = function(self, a, b, mode)
        b = ensure_val_or(b, a)
        mode = ensure_val_or(mode, Presets.random)
        self.ani.scl_x = mode
        self.upp.scl.x = math.max(a,b)
        self.low.scl.x = math.min(a,b)
        return self
    end

    t.scl_y = function(self, a, b, mode)
        b = ensure_val_or(b, a)
        mode = ensure_val_or(mode, Presets.random)
        self.ani.scl_y = mode
        self.upp.scl.y = math.max(a,b)
        self.low.scl.y = math.min(a,b)
        return self
    end

    t.ach = function(self, a, b, mode)
        b = ensure_val_or(b, a)
        mode = ensure_val_or(mode, Presets.random)
        self.ani.ach = mode
        self.upp.ach = math.max(a,b)
        self.low.ach = math.min(a,b)
        return self
    end

    t.rch = function(self, a, b, mode)
        b = ensure_val_or(b, a)
        mode = ensure_val_or(mode, Presets.random)
        self.ani.rch = mode
        self.upp.rch = math.max(a,b)
        self.low.rch = math.min(a,b)
        return self
    end

    t.gch = function(self, a, b, mode)
        b = ensure_val_or(b, a)
        mode = ensure_val_or(mode, Presets.random)
        self.ani.gch = mode
        self.upp.gch = math.max(a,b)
        self.low.gch = math.min(a,b)
        return self
    end

    t.bch = function(self, a, b, mode)
        b = ensure_val_or(b, a)
        mode = ensure_val_or(mode, Presets.random)
        self.ani.bch = mode
        self.upp.bch = math.max(a,b)
        self.low.bch = math.min(a,b)
        return self
    end

    t.fco_x = function(self, a, b)
        b = ensure_val_or(b, a)
        self.upp.fco.x = math.max(a,b)
        self.low.fco.x = math.min(a,b)
        return self
    end

    t.fco_y = function(self, a, b)
        b = ensure_val_or(b, a)
        self.upp.fco.y = math.max(a,b)
        self.low.fco.y = math.min(a,b)
        return self
    end

    t.delay = function(self, a, b)
        b = ensure_val_or(b, a)
        self.upp.del = math.max(a,b)
        self.low.del = math.min(a,b)
        self.del = rand_scalar(a, b)
        return self
    end

    t.limit = function(self, limit)
        self.lim = limit
        return self
    end

    t.rand_fco = function(self)
        return rand_vec(self.low.fco, self.upp.fco)
    end

    t.rand_acc = function(self)
        return rand_vec(self.low.acc, self.upp.acc)
    end

    t.rand_vel = function(self)
        return rand_vec(self.low.vel, self.upp.vel)
    end

    t.rand_pos = function(self)
        return rand_vec(self.low.pos, self.upp.pos)
    end

    t.rand_scl = function(self)
        return rand_vec(self.low.scl, self.upp.scl)
    end

    t.rand_cnt = function(self)
        return rand_scalar(self.low.cnt, self.upp.cnt)
    end

    t.rand_rot = function(self)
        return rand_scalar(self.low.rot, self.upp.rot)

    end

    t.rand_ach = function(self)
        return rand_scalar(self.low.ach, self.upp.ach)
    end

    t.rand_rch = function(self)
        return rand_scalar(self.low.rch, self.upp.rch)
    end

    t.rand_gch = function(self)
        return rand_scalar(self.low.gch, self.upp.gch)
    end

    t.rand_bch = function(self)
        return rand_scalar(self.low.bch, self.upp.bch)
    end

    t.rand_spn = function(self)
        return rand_scalar(self.low.spn, self.upp.spn)
    end

    t.rand_del = function(self)
        return rand_scalar(self.low.del, self.upp.del)
    end

    t.tick = function(self)
        self.del = self.del - 1

        if self.del < 0 then
            self:gen(self:rand_spn())
            self.del = self:rand_del()
        end

        local next = {}
        for i=1, self.len do
            local p = self.liv[i]
            if p.cnt > 0 then
                tick_ani(self, p)
                p.vel.x = (p.vel.x + p.acc.x) * p.fco.x
                p.vel.y = (p.vel.y + p.acc.y) * p.fco.y
                p.pos.x = p.pos.x + p.vel.x
                p.pos.y = p.pos.y + p.vel.y
                table.insert(next, p)
                p.cnt = p.cnt - 1
            else
                self.len = self.len - 1
            end
        end
        -- assert: self.len == #next
        if self.len ~= #next then
            -- If this log appears, please report this as a bug!
            print('sys.len='..self.len..'but #next='..#next.."!")
        end

        self.liv = next
    end

    t.apply = function(self, force)
        force = ensure_vector_or(force, vec_zero())
        for i=1, self.len do
            local p = self.liv[i]
            p.acc.x = p.acc.x + force.x
            p.acc.y = p.acc.y + force.y
        end
        return self
    end

    t.build = function(self)
        return t:config({
            upper=self.upp,
            lower=self.low,
            count=self.len
        })
    end

    t.destroy = function(self)
        table.remove(system_set, self._idx)
    end

    t.gen = function(self, count)
        local prev = self.len
        if prev >= self.lim then return end

        count = math.min(math.abs(count), (self.lim - prev))
        count = math.max(count, 0)

        self.len = prev + count
        for i=count,1,-1 do
            if self.liv[prev+i] == nil then
                self.liv[prev+i] = {}
            end
            respawn(self, self.liv[prev+i])
        end

        return self
    end

    t.for_each = function(self, fn)
        for i,p in ipairs(self.liv) do
            fn(i, p, p.cnt > 0)
        end
    end

    t._idx = table.insert(system_set, t)

    return t:config(opts)
end

local DT = 0
Net:on("tick", function(event)
    DT = DT + event.delta_time
    for _, sys in pairs(system_set) do
        sys:tick()
    end
end)

return system