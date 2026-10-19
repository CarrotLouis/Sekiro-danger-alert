-- Pure range-entry logic. Native charge/target proofs must be supplied by a
-- separately reviewed reader. This module is not attached to the 1.0.0 entry.
local M={}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<1e8 end
local function entity_id(n)return type(n)=='number'and n>=1 and n<=4294967295 and n%1==0 end
local function cycle_id(v)
    return type(v)=='string'and #v>0 and #v<=160
        or type(v)=='number'and v==v and v>=0 and v<9007199254740992
end
function M.new(trigger)
    local self={states={},count=0}
    function self:reset()self.states={};self.count=0 end
    function self:finish(key)
        if self.states[key]then self.states[key]=nil;self.count=self.count-1 end
    end
    function self:observe(s)
        if type(s)~='table'or type(s.key)~='string'or #s.key==0 or #s.key>160 or not finite(s.time)then return 'invalid_input'end
        if not s.charging or s.alive==false then self:finish(s.key);return 'not_charging'end
        if not cycle_id(s.cycle)or not finite(s.distance)or s.distance<0 or not finite(s.range)
            or s.range<0 or s.range>15 or s.range%1~=0 then return 'invalid_input'end
        local inside=s.range>0 and s.distance<=s.range
        local old=self.states[s.key]
        if not old or old.cycle~=s.cycle then
            if not old and self.count>=128 then return 'state_limit'end
            if not old then self.count=self.count+1 end
            -- A first observation already inside is a baseline, unless the
            -- native reader proves this is the start of a fresh charge.
            old={cycle=s.cycle,inside=false,consumed=inside and not s.started,
                range=s.range,seen=s.time}
            self.states[s.key]=old
        elseif s.time<old.seen or s.time-old.seen>.35 or s.range~=old.range then
            -- A gap or an edited range cannot create a fresh crossing.
            old.uncertain=true
        end
        local crossing=inside and not old.inside
        old.inside=inside;old.seen=s.time;old.range=s.range
        if s.range==0 then old.uncertain=true;return 'range_disabled'end
        if old.uncertain then return 'continuity_unconfirmed'end
        if old.consumed then return 'entry_already_consumed'end
        if not crossing then return 'outside_or_no_entry'end
        -- Consume the first geometric crossing even when it targets somebody
        -- else: retargeting or leaving/re-entering this charge must not alert.
        old.consumed=true
        if s.target_verified~=true or not entity_id(s.target)or not entity_id(s.local_entity)then return 'target_unconfirmed'end
        if s.target~=s.local_entity then return 'other_target'end
        if s.enabled==false then return 'move_disabled'end
        trigger(s);return 'trigger'
    end
    return self
end
return M
