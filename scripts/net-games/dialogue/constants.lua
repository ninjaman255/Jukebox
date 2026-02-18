-- scripts/net-games/dialogue/constants.lua

local C = {}

C.AdvanceMode = {
  INPUT = "input",  -- BN style: wait for confirm
  TIMER = "timer",  -- legacy/auto: delay then advance
}

C.PageAdvance = {
  WAIT_FOR_CONFIRM = "wait_for_confirm",
  AUTO_ADVANCE = "auto_advance",
  AUTO_ADVANCE_OR_CONFIRM = "auto_advance_or_confirm",
}

C.InputMode = {
  DIALOGUE_OWNS_INPUT = "dialogue_owns_input",
  OVERLAY_ONLY = "overlay_only",
}

return C
