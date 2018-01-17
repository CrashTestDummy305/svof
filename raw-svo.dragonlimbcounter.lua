-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

svo.dl_version = "1.0"

svo.dl_list = {}
local limbs = {"head", "torso", "rightarm", "leftarm", "rightleg", "leftleg"}
local hittable = {}
svo.dl_prep_at = 3
svo.dl_break_at = 4

enableTrigger("svo Dragon limbcounter")
enableAlias("svo Dragon limbcounter")

-- Their blah, blah, blah are also prepped.
local function get_other_prepped(t, limbhit)
  local s = {}
  for i = 1, #limbs do
    if limbs[i] ~= limbhit and t[limbs[i]] == svo.dl_prep_at then s[#s+1] = limbs[i] end
  end

  if #s == 0 then return ""
  else return string.format(" Their %s %s also prepped.", svo.concatand(s), (#s == 1 and "is" or "are")) end
end

function svo.dl_ignore()
  if not next(hittable) then return end
  table.remove(select(2, next(hittable)))
end


function svo.sk.dl_checklimbcounter()
  -- make the announces work with a singleprompt
  local echof = svo.itf
  moveCursor(0, getLineNumber())

  -- we'll only ever have one name here so far
  local who, t = next(hittable)
  local where
  for i = 1, #t do
    local dmg
    where, dmg = next(t[i])
    svo.dl_list[who][where] = svo.dl_list[who][where] + dmg
    raiseEvent("svo limbcounter hit", who, where)
  end

  if not where then
    echof("Failed to connect.%s", get_other_prepped(svo.dl_list[who], ""))
  else
    if svo.dl_list[who][where] >= svo.dl_break_at then
      echof("%s's %s broke.%s", who, where, get_other_prepped(svo.dl_list[who], where))
      svo.dl_list[who][where] = 0
    elseif svo.dl_list[who][where] >= svo.dl_prep_at then
      echof("%s's %s is prepped.%s", who, where, get_other_prepped(svo.dl_list[who], where))
    else
      echof("%s's %s is now at %s/%s.%s", who, where, svo.dl_list[who][where], svo.dl_break_at, get_other_prepped(svo.dl_list[who], where))
    end
  end

  hittable = {}
  disableTrigger("svodl Don't register")
  svo.signals.before_prompt_processing:disconnect(svo.sk.dl_checklimbcounter)
end

function svo.dl_hit(who, where)
  svo.dl_list[who] = svo.dl_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0}
  where = where:gsub(" ", "")
  svo.lasthit = who

  hittable[who] = hittable[who] or {}
  hittable[who][#hittable[who] + 1] = {[where] = 1}
  svo.signals.before_prompt_processing:connect(svo.sk.dl_checklimbcounter)
  enableTrigger("svodl Don't register")
end

function svo.dl_reset(whom)
  if not svo.defc.dragonform then return end

  if whom then whom = string.title(whom) end

  local t = {
    h = "head",
    t = "torso",
    rl = "rightleg",
    ll = "leftleg",
    ra = "rightarm",
    la = "leftarm",
  }

  if whom == "All" then
    svo.dl_list = {}
    svo.echof("Reset everyone's limb status.")
  elseif not whom and svo.lasthit then
    svo.dl_list[svo.lasthit] = {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, dl_break_at = svo.dl_break_at}
    svo.echof("Reset %s's limb status.", svo.lasthit)
  elseif t[whom:lower()] then
    if not svo.lasthit or not svo.dl_list[svo.lasthit] then
      svo.echof("Not keeping track of anyone yet to reset their limb.")
    else
      svo.dl_list[svo.lasthit][t[whom:lower()]] = 0
      svo.echof("Reset %s %s's status.", svo.lasthit, t[whom:lower()])
    end
  elseif whom then
    if svo.dl_list[whom] then
      svo.dl_list[whom] = nil
      svo.echof("Reset %s's limb status.", whom)
    else
      svo.echof("Weren't keeping track of %s anyway.", whom)
    end
  else
    svo.echof("Not keeping track of anyone to reset them anyway.")
  end
  raiseEvent("svo limbcounter reset")
end

function svo.dl_show()
  if not svo.defc.dragonform then return end

  if not next(svo.dl_list) then svo.echof("dragon limbcounter: Not keeping track of anyone yet."); return end

  setFgColor(unpack(svo.getDefaultColorNums))
  for person, limbt in pairs(svo.dl_list) do
    echo("---"..person.." ") fg("a_darkgrey")
    echoLink("(reset)", 'svo.dl_reset"'..person..'"', "Reset limb status for "..person, true)
    setFgColor(unpack(svo.getDefaultColorNums))
    echo(string.format(" -- prep at %s -- break at %s --", svo.dl_prep_at, svo.dl_break_at))
    echo(string.rep("-", (52-#person-#tostring(svo.dl_prep_at)-#tostring(svo.dl_break_at))))
    echo"\n|"
    for i = 1, #limbs do
      if limbt[limbs[i]] >= svo.dl_break_at - 1 then fg("green") end
      echo(string.format("%14s", (limbt[limbs[i]] >= svo.dl_break_at - 1 and limbs[i].." prep" or limbs[i].. " "..limbt[limbs[i]])))
      if limbt[limbs[i]] >= svo.dl_break_at - 1 then setFgColor(unpack(svo.getDefaultColorNums)) end
      echo"|"
    end
    echo"\n"
  end
  echo(string.rep("-", 91))
end

svo.echof("Loaded svo Dragon limbcounter, version %s.", tostring(svo.dl_version))
