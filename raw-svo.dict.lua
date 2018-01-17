-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

--[[
spriority: global async priority. In use when curing in sync mode.
aspriority: inter-balance sync priority. In use when curing in async mode.
isadvisable: determines if it is possible to cure this aff. some things that
  block bals might not block a single aff
]]

local sys, affs, defdefup, defkeepup, signals = svo.sys, svo.affs, svo.defdefup, svo.defkeepup, svo.signals
local deepcopy, conf, sk, me, defs, defc = svo.deepcopy, svo.conf, svo.sk, svo.me, svo.defs, svo.defc
local defences, stats, empty, cnrl, rift = svo.defences, svo.stats, svo.empty, svo.cnrl, svo.rift
local bals, pipes = svo.bals, svo.pipes

-- these lists are checked by curing functions in the skeleton
svo.dict_balanceful = {}
svo.dict_balanceless = {}
svo.dict_balanceful_def = {}
svo.dict_balanceless_def = {}
svo.dict_herb = {}
svo.dict_misc = {}
svo.dict_misc_def = {}
svo.dict_purgative = {}
svo.dict_salve_def = {}
svo.dict_smoke_def = {}

svo.codepaste = {}
local codepaste = svo.codepaste

local tekura_ability_isadvisable = function (new_stance)
  return (
    (
      (
        sys.deffing
        and defdefup[defs.mode][new_stance]
        and not defc[new_stance]
      )
      or (
        conf.keepup
        and defkeepup[defs.mode][new_stance]
        and not defc[new_stance]
      )
    )
    and me.path == "tekura"
    and not codepaste.balanceful_defs_codepaste()
    and not defc.riding
  ) or false
end

local shikudo_ability_isadvisable = function (new_form)
  return (
    (
      (
        sys.deffing
        and defdefup[defs.mode][new_form]
        and not defc[new_form]
      )
      or (
        conf.keepup
        and defkeepup[defs.mode][new_form]
        and not defc[new_form]
      )
    )
    and me.path == "shikudo"
    and not codepaste.balanceful_defs_codepaste()
    and not defc.riding
  ) or false
end

local tekura_stance_oncompleted = function (new_stance)
  local stances = {
    "horse",
    "eagle",
    "cat",
    "bear",
    "rat",
    "scorpion",
    "dragon"
  }

  for _, stance in ipairs(stances) do
    defences.lost(stance)
  end

  defences.got(new_stance)
end

local shikudo_form_oncompleted = function (new_form)
  local shikudo_forms = {
    "tykonos",
    "willow",
    "rain",
    "oak",
    "gaital",
    "maelstrom"
  }

  for _, form in ipairs(shikudo_forms) do
    defences.lost(form)
  end

  defences.got(new_form)
end

-- used to check if we're writhing from something already
--impale stacks below other writhes
codepaste.writhe = function()
  return (
    not svo.doingaction("curingtransfixed") and not svo.doingaction("transfixed") and
    not svo.doingaction("curingimpale") and not svo.doingaction("impale") and
    not svo.doingaction("curingbound") and not svo.doingaction("bound") and
    not svo.doingaction("curingwebbed") and not svo.doingaction("webbed") and
    not svo.doingaction("curingroped") and not svo.doingaction("roped") and
    not svo.doingaction("curinghoisted") and not svo.doingaction("hoisted") and
    not svo.doingaction("dragonflex"))
end

-- gives a warning if we're having too many reaves
codepaste.checkreavekill = function()
  -- count up all humours, if three - warn of nearly, if four - warn of reaveability
  local c = 0
  if affs.cholerichumour then c = c + 1 end
  if affs.melancholichumour then c = c + 1 end
  if affs.phlegmatichumour then c = c + 1 end
  if affs.sanguinehumour then c = c + 1 end

  if c == 4 then
    sk.warn "reavable"
  elseif c == 3 then
    sk.warn "nearlyreavable"
  elseif c == 2 then
    sk.warn "somewhatreavable"
  end
end

codepaste.checkdismemberkill = function()
  if not svo.enabledclasses.sentinel then return end

  if affs.bound and affs.impale then
    sk.warn "dismemberable"
  end
end

codepaste.badaeon = function()
  -- if we're in a poor aeon situation, warn to gtfo
  if not affs.aeon then return end

  local c = 0
  if affs.asthma then c = c + 1 end
  if affs.stupidity then c = c + 1 end
  if affs.voided then c = c + 1 end
  if affs.asthma and affs.anorexia then c = c + 1 end

  if c >= 1 then sk.warn "badaeon" end
end

codepaste.addrestobreakleg = function(aff, oldhp, tekura)
  local leg = aff:find("right") and "right" or "left"

  if not conf.aillusion or ((not oldhp or oldhp > stats.currenthealth) or svo.paragraph_length >= 3 or
    (affs.recklessness and getStopWatchTime(affs[aff].sw) >= conf.ai_restoreckless))
    -- accept it when it was a tremolo hit that set us up for a break as well
    or (sk.tremoloside and sk.tremoloside[leg])
  then

    -- clear sk.tremoloside for the leg, so tremolo later on can know when it /didn't/ break a leg
    if sk.tremoloside and sk.tremoloside[leg] then
      sk.tremoloside[leg] = nil
    end

    if not tekura then
      svo.addaffdict(svo.dict[aff])
    else
      if not sk.delaying_break then
        -- from the first hit, it's approximately getNetworkLatency() time until the second -
        -- add the conf.tekura_delay to allow for variation in ping
        sk.delaying_break = tempTimer(getNetworkLatency() + conf.tekura_delay, function()
          sk.delaying_break = nil

          for _, tekuraaff in ipairs(sk.tekura_mangles) do
            svo.addaffdict(svo.dict[tekuraaff])
          end
          sk.tekura_mangles = nil
          svo.make_gnomes_work()
        end)
      end

      sk.tekura_mangles = sk.tekura_mangles or {}
      sk.tekura_mangles[#sk.tekura_mangles+1] = aff
    end
  end
end

codepaste.addrestobreakarm = function(aff, oldhp, tekura)
  if not conf.aillusion or ((not oldhp or oldhp > stats.currenthealth) or svo.paragraph_length >= 3 or
    (affs.recklessness and getStopWatchTime(affs[aff].sw) >= conf.ai_restoreckless)) then

    if not tekura then
      svo.addaffdict(svo.dict[aff])
      signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      signals.canoutr:emit()

    else
      if not sk.delaying_break then
         -- from the first hit, it's approximately getNetworkLatency() time until the second - add the conf.tekura_delay
         -- to allow for variation in ping
        sk.delaying_break = tempTimer(getNetworkLatency() + conf.tekura_delay, function()
          sk.delaying_break = nil

          for _, tekuraaff in ipairs(sk.tekura_mangles) do
            svo.addaffdict(svo.dict[tekuraaff])
          end
          sk.tekura_mangles = nil

          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          signals.canoutr:emit()

          svo.make_gnomes_work()
        end)
      end

      sk.tekura_mangles = sk.tekura_mangles or {}
      sk.tekura_mangles[#sk.tekura_mangles+1] = aff
    end

  end
end

codepaste.remove_focusable = function ()
  if not affs.unknownmental then return end
  affs.unknownmental.p.count = affs.unknownmental.p.count - 1
  if affs.unknownmental.p.count <= 0 then
    svo.rmaff("unknownmental")
    svo.dict.unknownmental.count = 0
  else
    svo.updateaffcount(svo.dict.unknownmental)
  end
end

-- keep argument is used when the aff is still on you
codepaste.remove_stackableaff = function (aff, keep)
  if not affs[aff] then return end
  svo.dict[aff].count = svo.dict[aff].count - 1

  if keep and svo.dict[aff].count <= 0 then svo.dict[aff].count = 1 end

  if svo.dict[aff].count <= 0 then
    svo.rmaff(aff)
    svo.dict[aff].count = 0
  else
    svo.updateaffcount(svo.dict[aff])
  end
end

-- -> boolean
-- returns true if we're using some non-standard cure - tree, restore, class skill...
codepaste.nonstdcure = function()
  if svo.haveskillset('venom') then
    return svo.doingaction"shrugging"
  end
  if svo.haveskillset('healing') then
    return svo.doingaction"usehealing"
  end

  return (svo.doingaction"touchtree" or svo.doingaction"restore")
end

if svo.haveskillset('metamorphosis') then
  codepaste.nonmorphdefs = function ()
    for _, def in ipairs{"flame", "lyre", "nightsight", "rest", "resistance", "stealth", "temperance", "elusiveness"} do
      if ((sys.deffing and defdefup[defs.mode][def]) or (not sys.deffing and conf.keepup and defkeepup[defs.mode][def])) and not defc[def] then return false end
    end

    -- local def = "vitality"
    -- if ((sys.deffing and defdefup[defs.mode][def]) or (conf.keepup and defkeepup[defs.mode][def])) and not svo.doingaction"cantvitality" then return false end
    return true
  end
end

codepaste.smoke_elm_pipe = function()
  if pipes.elm.id == 0 then sk.warn "noelmid" end
  if not (pipes.elm.lit or pipes.elm.arty) then
    sk.forcelight_elm = true
  end

  return (not (pipes.elm.id == 0) and
    (pipes.elm.lit or pipes.elm.arty) and
    not (pipes.elm.puffs == 0))
end

codepaste.smoke_valerian_pipe = function()
  if pipes.valerian.id == 0 then sk.warn "novalerianid" end
  if not (pipes.valerian.lit or pipes.valerian.arty) then
    sk.forcelight_valerian = true
  end

  return (not (pipes.valerian.id == 0) and
    (pipes.valerian.lit or pipes.valerian.arty) and
    not (pipes.valerian.puffs == 0))
end

codepaste.smoke_skullcap_pipe = function()
  if pipes.skullcap.id == 0 then sk.warn "noskullcapid" end
  if not (pipes.skullcap.lit or pipes.skullcap.arty) then
    sk.forcelight_skullcap = true
  end

  return (not (pipes.skullcap.id == 0) and
    (pipes.skullcap.lit or pipes.skullcap.arty) and
    not (pipes.skullcap.puffs == 0))
end

codepaste.balanceful_defs_codepaste = function()
  for k,_ in pairs(svo.dict_balanceful_def) do
    if svo.doingaction(k) then return true end
  end
end

-- adds the unknownany aff or increases the count by 1 or specified amount
codepaste.addunknownany = function(amount)
  local count = svo.dict.unknownany.count
  svo.addaffdict(svo.dict.unknownany)

  svo.dict.unknownany.count = (count or 0) + (amount or 1)
  svo.updateaffcount(svo.dict.unknownany)
end

sk.burns = {"ablaze", "severeburn", "extremeburn", "charredburn", "meltingburn"}
-- removes all burning afflictions except for the optional specified one
codepaste.remove_burns = function(skipaff)
  local burns = deepcopy(sk.burns)
  if skipaff then
    table.remove(burns, table.index_of(burns, skipaff))
  end

  svo.rmaff(burns)
end

sk.next_burn = function()
  for i,v in ipairs(sk.burns) do
    if affs[v] then return sk.burns[i+1] or sk.burns[#sk.burns] end
  end
end

sk.current_burn = function()
  for _,v in ipairs(sk.burns) do
    if affs[v] then return v end
  end
end

sk.previous_burn = function(howfar)
  for i,v in ipairs(sk.burns) do
    if affs[v] then return sk.burns[i-(howfar and howfar or 1)] or nil end
  end
end

codepaste.serversideahealthmanaprio = function()
  local healhealth_prio = svo.prio.getnumber("healhealth", "sip")
  local healmana_prio   = svo.prio.getnumber("healmana"  , "sip")

  -- swap using curing system commands as appropriate
  -- setup special balance in cache mentioning which is first, so it is remembered
  sk.priochangecache.special = sk.priochangecache.special or { healthormana = ""}

  if healhealth_prio > healmana_prio and sk.priochangecache.special.healthormana ~= "health" then
    svo.sendcuring("priority health")
    sk.priochangecache.special.healthormana = "health"
  elseif healmana_prio > healhealth_prio and sk.priochangecache.special.healthormana ~= "mana" then
    svo.sendcuring("priority mana")
    sk.priochangecache.special.healthormana = "mana"
  end
end

--[[ dict is to NEVER be iterated over fully by prompt checks; so isadvisable functions can
      typically expect not to check for the common things because pre-
      filtering is done.
  ]]

svo.dict = {
  -- (string) what serverside calls this by - names can be different as they were revealed years after Svof was made
  gamename = nil,
  onservereignore = nil, -- (function) a function which'll return true if this needs to be ignored serverside
  healhealth = {
    description = "heals health with health/vitality or moss/potash",
    sip = {
      name = false, --"healhealth_sip",
      balance = false, --"sip",
      action_name = false, --"healhealth"
      aspriority = 0,
      spriority = 0,

      -- managed outside priority lists
      irregular = true,

      isadvisable = function ()
        -- should healhealth be prioritised above health affs, don't apply if above healthaffsabove% and have an aff
        local function shouldntsip()
          local crackedribs    = svo.prio.getnumber("crackedribs", "sip")
          local healhealth     = svo.prio.getnumber("healhealth", "sip")
          local skullfractures = svo.prio.getnumber("skullfractures", "sip")
          local torntendons    = svo.prio.getnumber("torntendons", "sip")
          local wristfractures = svo.prio.getnumber("wristfractures", "sip")

          if stats.hp >= conf.healthaffsabove and ((healhealth > crackedribs and affs.crackedribs) or
            (healhealth > skullfractures and affs.skullfractures) or (healhealth > torntendons and affs.torntendons) or
             (healhealth > wristfractures and affs.wristfractures)) then
            return true
          end

          return false
        end

if not svo.haveskillset('kaido') then
        return ((stats.currenthealth < sys.siphealth or (sk.gettingfullstats and stats.currenthealth < stats.maxhealth))
         and not svo.actions.healhealth_sip and not shouldntsip())
else
        return ((stats.currenthealth < sys.siphealth or (sk.gettingfullstats and stats.currenthealth < stats.maxhealth))
         and not svo.actions.healhealth_sip  and not shouldntsip() and
          (defc.dragonform or -- sip health if we're in dragonform, can't use Kaido
            not svo.can_usemana() or -- or we don't have enough mana (should be an option). The downside of this is that we
            -- won't get mana back via sipping, only moss, the time to being able to transmute will approach slower than
            -- straight sipping mana
            (affs.prone and not conf.transsipprone) or -- or we're prone and sipping while prone is off (better for
            --bashing, not so for PK)
            (conf.transmute ~= "replaceall" and conf.transmute ~= "replacehealth" and not svo.doingaction"transmute")
            -- or we're not in a replacehealth/replaceall mode, so we can still sip
          )
        )
end
      end,

      oncompleted = function ()
        svo.lostbal_sip()
      end,

      noeffect = function()
        svo.lostbal_sip()
      end,

      onprioswitch = function()
        codepaste.serversideahealthmanaprio()
      end,

      sipcure = {"health", "vitality"},

      onstart = function ()
        svo.sip(svo.dict.healhealth.sip)
      end
    },
    moss = {
      aspriority = 0,
      spriority = 0,
      -- managed outside priority lists
      irregular = true,

      isadvisable = function ()
if not svo.haveskillset('kaido') then
        return ((stats.currenthealth < sys.mosshealth) and (not svo.doingaction("healhealth") or (stats.currenthealth < (sys.mosshealth-600)))) or false
else
        return ((stats.currenthealth < sys.mosshealth) and (not svo.doingaction("healhealth") or (stats.currenthealth < (sys.mosshealth-600))) and (defc.dragonform or not svo.can_usemana() or affs.prone or (conf.transmute ~= "replaceall" and not svo.doingaction"transmute"))) or false
end
      end,

      oncompleted = function ()
        svo.lostbal_moss()
      end,

      noeffect = function()
        svo.lostbal_moss()
      end,

      eatcure = {"irid", "potash"},
      actions = {"eat moss", "eat irid", "eat potash"},
      onstart = function ()
        svo.eat(svo.dict.healhealth.moss)
      end
    },
  },
  healmana = {
    description = "heals mana with mana/mentality or moss/potash",
    sip = {
      aspriority = 0,
      spriority = 0,
      -- managed outside priority lists
      irregular = true,

      isadvisable = function ()
        return ((stats.currentmana < sys.sipmana or (sk.gettingfullstats and stats.currentmana < stats.maxmana)) and not svo.doingaction("healmana")) or false
      end,

      oncompleted = function ()
        svo.lostbal_sip()
      end,

      noeffect = function()
        svo.lostbal_sip()
      end,

      onprioswitch = function()
        codepaste.serversideahealthmanaprio()
      end,

      sipcure = {"mana", "mentality"},

      onstart = function ()
        svo.sip(svo.dict.healmana.sip)
      end
    },
    moss = {
      aspriority = 0,
      spriority = 0,
      -- managed outside priority lists
      irregular = true,

      isadvisable = function ()
        return ((stats.currentmana < sys.mossmana) and (not svo.doingaction("healmana") or (stats.currentmana < (sys.mossmana-600)))) or false
      end,

      oncompleted = function ()
        svo.lostbal_moss()
      end,

      noeffect = function()
        svo.lostbal_moss()
      end,

      eatcure = {"irid", "potash"},
      actions = {"eat moss", "eat irid", "eat potash"},
      onstart = function ()
        svo.eat(svo.dict.healmana.moss)
      end
    },
  },
  skullfractures = {
    count = 0,
    sip = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.skullfractures and stats.hp >= conf.healthaffsabove) or false
      end,

      oncompleted = function ()
        svo.lostbal_sip()
        -- two counts are cured if you're above 5
        local howmany = svo.dict.skullfractures.count
        codepaste.remove_stackableaff("skullfractures", true)
        if howmany > 5 then
          codepaste.remove_stackableaff("skullfractures", true)
        end
      end,

      cured = function()
        svo.lostbal_sip()
        svo.rmaff("skullfractures")
        svo.dict.skullfractures.count = 0
      end,

      fizzled = function ()
        svo.lostbal_sip()
        empty.apply_health_head()
      end,

      noeffect = function ()
        svo.lostbal_sip()
      end,

      -- in case an unrecognised message is shown, don't error
      empty = function()
      end,

      actions = {"apply health to head"},
      onstart = function ()
        send("apply health to head", conf.commandecho)
      end
    },
    aff = {
      oncompleted = function (number)
        -- double kngiht affs from precision strikes
        if sk.doubleknightaff then number = (number or 0) + 1 end

        local count = svo.dict.skullfractures.count
        svo.addaffdict(svo.dict.skullfractures)

        svo.dict.skullfractures.count = (count or 0) + (number or 1)
        if svo.dict.skullfractures.count > 7 then
          svo.dict.skullfractures.count = 7
        end
        svo.updateaffcount(svo.dict.skullfractures)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("skullfractures")
        svo.dict.skullfractures.count = 0
      end,

      general_cure = function(amount, dontkeep)
        -- two counts are cured if you're above 5
        local howmany = svo.dict.skullfractures.count
        for _ = 1, (amount or 1) do
          codepaste.remove_stackableaff("skullfractures", not dontkeep)
        end
        if howmany > 5 then
          codepaste.remove_stackableaff("skullfractures", not dontkeep)
        end
      end,

      general_cured = function(_)
        svo.rmaff("skullfractures")
        svo.dict.skullfractures.count = 0
      end,
    }
  },
  crackedribs = {
    count = 0,
    sip = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.crackedribs and stats.hp >= conf.healthaffsabove) or false
      end,

      oncompleted = function ()
        svo.lostbal_sip()
        -- two counts are cured if you're above 5
        local howmany = svo.dict.crackedribs.count
        codepaste.remove_stackableaff("crackedribs", true)
        if howmany > 5 then
          codepaste.remove_stackableaff("crackedribs", true)
        end
      end,

      cured = function()
        svo.lostbal_sip()
        svo.rmaff("crackedribs")
        svo.dict.crackedribs.count = 0
      end,

      fizzled = function ()
        svo.lostbal_sip()
        empty.apply_health_torso()
      end,

      noeffect = function ()
        svo.lostbal_sip()
      end,

      -- in case an unrecognised message is shown, don't error
      empty = function()
      end,

      actions = {"apply health to torso"},
      onstart = function ()
        send("apply health to torso", conf.commandecho)
      end
    },
    aff = {
      oncompleted = function (number)
        -- double kngiht affs from precision strikes
        if sk.doubleknightaff then number = (number or 0) + 1 end

        local count = svo.dict.crackedribs.count
        svo.addaffdict(svo.dict.crackedribs)

        svo.dict.crackedribs.count = (count or 0) + (number or 1)
        if svo.dict.crackedribs.count > 7 then
          svo.dict.crackedribs.count = 7
        end
        svo.updateaffcount(svo.dict.crackedribs)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("crackedribs")
        svo.dict.crackedribs.count = 0
      end,

      general_cure = function(amount, dontkeep)
        -- two counts are cured if you're above 5
        local howmany = svo.dict.crackedribs.count
        for _ = 1, (amount or 1) do
          codepaste.remove_stackableaff("crackedribs", not dontkeep)
        end
        if howmany > 5 then
          codepaste.remove_stackableaff("crackedribs", not dontkeep)
        end
      end,

      general_cured = function()
        svo.rmaff("crackedribs")
        svo.dict.crackedribs.count = 0
      end,
    }
  },
  wristfractures = {
    count = 0,
    sip = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.wristfractures and stats.hp >= conf.healthaffsabove) or false
      end,

      oncompleted = function ()
        svo.lostbal_sip()
        -- two counts are cured if you're above 5
        local howmany = svo.dict.wristfractures.count
        codepaste.remove_stackableaff("wristfractures", true)
        if howmany > 5 then
          codepaste.remove_stackableaff("wristfractures", true)
        end
      end,

      cured = function()
        svo.lostbal_sip()
        svo.rmaff("wristfractures")
        svo.dict.wristfractures.count = 0
      end,

      fizzled = function ()
        svo.lostbal_sip()
        empty.apply_health_arms()
      end,

      noeffect = function ()
        svo.lostbal_sip()
      end,

      -- in case an unrecognised message is shown, don't error
      empty = function()
      end,

      actions = {"apply health to arms"},
      onstart = function ()
        send("apply health to arms", conf.commandecho)
      end
    },
    aff = {
      oncompleted = function (number)
        -- double kngiht affs from precision strikes
        if sk.doubleknightaff then number = (number or 0) + 1 end

        local count = svo.dict.wristfractures.count
        svo.addaffdict(svo.dict.wristfractures)

        svo.dict.wristfractures.count = (count or 0) + (number or 1)
        if svo.dict.wristfractures.count > 7 then
          svo.dict.wristfractures.count = 7
        end
        svo.updateaffcount(svo.dict.wristfractures)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("wristfractures")
        svo.dict.wristfractures.count = 0
      end,

      general_cure = function(amount, dontkeep)
        -- two counts are cured if you're above 5
        local howmany = svo.dict.wristfractures.count
        for _ = 1, (amount or 1) do
          codepaste.remove_stackableaff("wristfractures", not dontkeep)
        end
        if howmany > 5 then
          codepaste.remove_stackableaff("wristfractures", not dontkeep)
        end
      end,

      general_cured = function()
        svo.rmaff("wristfractures")
        svo.dict.wristfractures.count = 0
      end,
    }
  },
  torntendons = {
    count = 0,
    sip = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.torntendons and stats.hp >= conf.healthaffsabove) or false
      end,

      oncompleted = function ()
        svo.lostbal_sip()
                -- two counts are cured if you're above 5
        local howmany = svo.dict.torntendons.count
        codepaste.remove_stackableaff("torntendons", true)
        if howmany > 5 then
          codepaste.remove_stackableaff("torntendons", true)
        end
      end,

      cured = function()
        svo.lostbal_sip()
        svo.rmaff("torntendons")
        svo.dict.torntendons.count = 0
      end,

      fizzled = function ()
        svo.lostbal_sip()
        empty.apply_health_legs()
      end,

      noeffect = function ()
        svo.lostbal_sip()
      end,

      -- in case an unrecognised message is shown, don't error
      empty = function()
      end,

      actions = {"apply health to legs"},
      onstart = function ()
        send("apply health to legs", conf.commandecho)
      end
    },
    aff = {
      oncompleted = function (number)
        -- double kngiht affs from precision strikes
        if sk.doubleknightaff then number = (number or 0) + 1 end

        local count = svo.dict.torntendons.count
        svo.addaffdict(svo.dict.torntendons)

        svo.dict.torntendons.count = (count or 0) + (number or 1)
        if svo.dict.torntendons.count > 7 then
          svo.dict.torntendons.count = 7
        end
        svo.updateaffcount(svo.dict.torntendons)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("torntendons")
        svo.dict.torntendons.count = 0
      end,

      general_cure = function(amount, dontkeep)
        -- two counts are cured if you're above 5
        local howmany = svo.dict.torntendons.count
        for _ = 1, (amount or 1) do
          codepaste.remove_stackableaff("torntendons", not dontkeep)
        end
        if howmany > 5 then
          codepaste.remove_stackableaff("torntendons", not dontkeep)
        end
      end,

      general_cured = function()
        svo.rmaff("torntendons")
        svo.dict.torntendons.count = 0
      end,
    }
  },
  cholerichumour = {
    gamename = "temperedcholeric",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.cholerichumour) or false
      end,

      -- this is called when you still have some left
      oncompleted = function ()
        svo.lostbal_herb()
        codepaste.remove_stackableaff("cholerichumour", true)
      end,

      empty = function()
        empty.eat_ginger()
        svo.lostbal_herb()
      end,

      cured = function()
        svo.lostbal_herb()
        svo.rmaff("cholerichumour")
        svo.dict.cholerichumour.count = 0
      end,

      noeffect = function()
        svo.lostbal_herb()
      end,

      -- does damage based on humour count
      inundated = function()
        svo.rmaff("cholerichumour")
        svo.dict.cholerichumour.count = 0
      end,

      eatcure = {"ginger", "antimony"},

      onstart = function ()
        svo.eat(svo.dict.cholerichumour.herb)
      end
    },
    aff = {
      oncompleted = function (number)
        local count = svo.dict.cholerichumour.count
        svo.addaffdict(svo.dict.cholerichumour)

        svo.dict.cholerichumour.count = (count or 0) + (number or 1)
        if svo.dict.cholerichumour.count > 8 then
          svo.dict.cholerichumour.count = 8
        end
        svo.updateaffcount(svo.dict.cholerichumour)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("cholerichumour")
        svo.dict.cholerichumour.count = 0
      end
    }
  },
  melancholichumour = {
    gamename = "temperedmelancholic",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.melancholichumour) or false
      end,

      -- this is called when you still have some left
      oncompleted = function ()
        svo.lostbal_herb()
        codepaste.remove_stackableaff("melancholichumour", true)
      end,

      empty = function()
        empty.eat_ginger()
        svo.lostbal_herb()
      end,

      cured = function()
        svo.lostbal_herb()
        svo.rmaff("melancholichumour")
        svo.dict.melancholichumour.count = 0
      end,

      noeffect = function()
        svo.lostbal_herb()
      end,

      -- does mana damage based on humour count
      inundated = function()
        svo.rmaff("melancholichumour")
        svo.dict.melancholichumour.count = 0
      end,

      eatcure = {"ginger", "antimony"},

      onstart = function ()
        svo.eat(svo.dict.melancholichumour.herb)
      end
    },
    aff = {
      oncompleted = function (number)
        local count = svo.dict.melancholichumour.count
        svo.addaffdict(svo.dict.melancholichumour)

        svo.dict.melancholichumour.count = (count or 0) + (number or 1)
        if svo.dict.melancholichumour.count > 8 then
          svo.dict.melancholichumour.count = 8
        end
        svo.updateaffcount(svo.dict.melancholichumour)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("melancholichumour")
        svo.dict.melancholichumour.count = 0
      end
    }
  },
  phlegmatichumour = {
    gamename = "temperedphlegmatic",
    count = 0,
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.phlegmatichumour) or false
      end,

      -- this is called when you still have some left
      oncompleted = function ()
        svo.lostbal_herb()
        codepaste.remove_stackableaff("phlegmatichumour", true)
      end,

      empty = function()
        empty.eat_ginger()
        svo.lostbal_herb()
      end,

      cured = function()
        svo.lostbal_herb()
        svo.rmaff("phlegmatichumour")
        svo.dict.phlegmatichumour.count = 0
      end,

      noeffect = function()
        svo.lostbal_herb()
      end,

      -- gives various afflictions, amount of which depends on your humour level
      --[[
        1-2: 1 affliction
        3-6: 2 afflictions
        7-9: 3 afflictions
        10: 4 afflictions

        Above information is roughly accurate.
        Gives between one and four afflictions from the following: lethargy, slickness, anorexia, weariness.
        Afflictions not hidden by gmcp, so removed from the inundated function.
      ]]
      inundated = function()
        svo.rmaff("phlegmatichumour")
        svo.dict.phlegmatichumour.count = 0
      end,

      eatcure = {"ginger", "antimony"},

      onstart = function ()
        svo.eat(svo.dict.phlegmatichumour.herb)
      end
    },
    aff = {
      oncompleted = function (number)
        local count = svo.dict.phlegmatichumour.count
        svo.addaffdict(svo.dict.phlegmatichumour)

        svo.dict.phlegmatichumour.count = (count or 0) + (number or 1)
        if svo.dict.phlegmatichumour.count > 8 then
          svo.dict.phlegmatichumour.count = 8
        end
        svo.updateaffcount(svo.dict.phlegmatichumour)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("phlegmatichumour")
        svo.dict.phlegmatichumour.count = 0
      end
    }
  },
  sanguinehumour = {
    gamename = "temperedsanguine",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.sanguinehumour) or false
      end,

      -- this is called when you still have some left
      oncompleted = function ()
        svo.lostbal_herb()
        codepaste.remove_stackableaff("sanguinehumour", true)
      end,

      empty = function()
        empty.eat_ginger()
        svo.lostbal_herb()
      end,

      cured = function()
        svo.lostbal_herb()
        svo.rmaff("sanguinehumour")
        svo.dict.sanguinehumour.count = 0
      end,

      noeffect = function()
        svo.lostbal_herb()
      end,

      -- gives bleeding depending on your sanguine humour level, from 250 for first to 2500 for last
      inundated = function()
        local min = 250
        -- local max = 2500
        if not affs.sanguinehumour then return end

        local bledfor = svo.dict.sanguinehumour.count * min

        svo.addaffdict(svo.dict.bleeding)
        svo.dict.bleeding.count = bledfor
        svo.updateaffcount(svo.dict.bleeding)

        svo.rmaff("sanguinehumour")
        svo.dict.sanguinehumour.count = 0
      end,

      eatcure = {"ginger", "antimony"},

      onstart = function ()
        svo.eat(svo.dict.sanguinehumour.herb)
      end
    },
    aff = {
      oncompleted = function (number)
        local count = svo.dict.sanguinehumour.count
        svo.addaffdict(svo.dict.sanguinehumour)

        svo.dict.sanguinehumour.count = (count or 0) + (number or 1)
        if svo.dict.sanguinehumour.count > 8 then
          svo.dict.sanguinehumour.count = 8
        end
        svo.updateaffcount(svo.dict.sanguinehumour)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("sanguinehumour")
        svo.dict.sanguinehumour.count = 0
      end
    }
  },
  waterbubble = {
    gamename = "airpocket",
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return not defc.waterbubble and ((sys.deffing and defdefup[defs.mode].waterbubble) or (conf.keepup and defkeepup[defs.mode].waterbubble)) and not affs.anorexia and me.is_underwater
      end,

      eatcure = {"pear", "calcite"},

      onstart = function ()
        svo.eat(svo.dict.waterbubble.herb)
      end,

      oncompleted = function ()
        defences.got("waterbubble")
      end,

      empty = function()
      end
    }
  },
  pacifism = {
    gamename = "pacified",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.pacifism and
          not svo.doingaction("pacifism") and (not svo.haveskillset('chivalry') or not svo.dict.rage.misc.isadvisable())) or false
      end,

      oncompleted = function ()
        svo.rmaff("pacifism")
        svo.lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        svo.eat(svo.dict.pacifism.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.pacifism and
          not svo.doingaction("pacifism") and (not svo.haveskillset('chivalry') or not svo.dict.rage.misc.isadvisable())) or false
      end,

      oncompleted = function ()
        svo.rmaff("pacifism")
        svo.lostbal_focus()
      end,

      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.pacifism)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("pacifism")
        codepaste.remove_focusable()
      end,
    }
  },
  peace = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.peace and (not svo.haveskillset('chivalry') or not svo.dict.rage.misc.isadvisable())) or false
      end,

      oncompleted = function ()
        svo.rmaff("peace")
        svo.lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        svo.eat(svo.dict.peace.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.peace)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("peace")
      end,
    }
  },
  inlove = {
    gamename = "lovers",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.inlove and (not svo.haveskillset('chivalry') or not svo.dict.rage.misc.isadvisable())) or false
      end,

      oncompleted = function ()
        svo.rmaff("inlove")
        svo.lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        svo.eat(svo.dict.inlove.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.inlove)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("inlove")
      end,
    }
  },
  dissonance = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.dissonance and not svo.usingbal("focus")) or false
      end,

      oncompleted = function ()
        svo.rmaff("dissonance")
        svo.lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        svo.eat(svo.dict.dissonance.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.dissonance)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("dissonance")
      end,
    }
  },
  dizziness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.dizziness and
          not svo.doingaction("dizziness") and not svo.usingbal("focus")) or false
      end,

      oncompleted = function ()
        svo.rmaff("dizziness")
        svo.lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        svo.eat(svo.dict.dizziness.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.dizziness and
          not svo.doingaction("dizziness")) or false
      end,

      oncompleted = function ()
        svo.rmaff("dizziness")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.dizziness)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("dizziness")
        codepaste.remove_focusable()
      end,
    }
  },
  shyness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.shyness and
          not svo.doingaction("shyness") and not svo.usingbal("focus")) or false
      end,

      oncompleted = function ()
        svo.rmaff("shyness")
        svo.lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        svo.eat(svo.dict.shyness.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.shyness and
          not svo.doingaction("shyness")) or false
      end,

      oncompleted = function ()
        svo.rmaff("shyness")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.shyness)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("shyness")
        codepaste.remove_focusable()
      end,
    }
  },
  epilepsy = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.epilepsy and
          not svo.doingaction("epilepsy") and not svo.usingbal("focus")) or false
      end,

      oncompleted = function ()
        svo.rmaff("epilepsy")
        svo.lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        svo.eat(svo.dict.epilepsy.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.epilepsy and
          not svo.doingaction("epilepsy")) or false
      end,

      oncompleted = function ()
        svo.rmaff("epilepsy")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.epilepsy)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("epilepsy")
        codepaste.remove_focusable()
      end,
    }
  },
  impatience = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        -- curing impatience before hypochondria will make it get re-applied
        return (affs.impatience and not affs.madness and not svo.usingbal("focus")  and not affs.hypochondria) or false
      end,

      oncompleted = function ()
        svo.rmaff("impatience")
        svo.lostbal_herb()

        -- if serverside cures impatience before we can even validate it, cancel it
        svo.affsp.impatience = nil
        svo.killaction(svo.dict.checkimpatience.misc)
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        svo.eat(svo.dict.impatience.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.impatience)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("impatience")
      end,
    }
  },
  stupidity = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.stupidity and
          not svo.doingaction("stupidity") and not svo.usingbal("focus")) or false
      end,

      oncompleted = function ()
        svo.rmaff("stupidity")
        svo.lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        svo.eat(svo.dict.stupidity.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.stupidity and
          not svo.doingaction("stupidity") and not affs.madness) or false
      end,

      oncompleted = function ()
        svo.rmaff("stupidity")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.stupidity)
        sk.stupidity_count = 0
        codepaste.badaeon()
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("stupidity")
        codepaste.remove_focusable()
      end,
    }
  },
  masochism = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.masochism and not affs.madness and
          not svo.doingaction("masochism")) or false
      end,

      oncompleted = function ()
        svo.rmaff("masochism")
        svo.lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        svo.eat(svo.dict.masochism.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.masochism and not affs.madness and
          not svo.doingaction("masochism")) or false
      end,

      oncompleted = function ()
        svo.rmaff("masochism")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.masochism)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("masochism")
        codepaste.remove_focusable()
      end,
    }
  },
  recklessness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.recklessness and not affs.madness and
          not svo.doingaction("recklessness")) or false
      end,

      oncompleted = function ()
        svo.rmaff("recklessness")
        svo.lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        svo.eat(svo.dict.recklessness.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.recklessness and not affs.madness and
          not svo.doingaction("recklessness")) or false
      end,

      oncompleted = function ()
        svo.rmaff("recklessness")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function (data)
        if data and data.attacktype and data.attacktype == "domination" and (data.atline+1 == getLastLineNumber("main")
          or (data.atline+1 == getLastLineNumber("main") and
            svo.find_until_last_paragraph("The gremlin races between your legs, throwing you off-balance.", "exact"))) then
          svo.addaffdict(svo.dict.recklessness)
        elseif not conf.aillusion or
          (stats.maxhealth == stats.currenthealth and stats.maxmana == stats.currentmana) then
          svo.addaffdict(svo.dict.recklessness)
        end
      end,

      -- used for addaff to skip all checks
      forced = function ()
        svo.addaffdict(svo.dict.recklessness)
      end
    },
    gone = {
      oncompleted = function()
        svo.rmaff("recklessness")
        codepaste.remove_focusable()
      end,
    },
    onremoved = function ()
      svo.check_generics()
      if not affs.blackout then
        svo.killaction(svo.dict.nomana.waitingfor)
      end
      signals.before_prompt_processing:block(svo.valid.check_recklessness)
    end,
    onadded = function()
      signals.before_prompt_processing:unblock(svo.valid.check_recklessness)
    end,
  },
  justice = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.justice and (not svo.haveskillset('chivalry') or not svo.dict.rage.misc.isadvisable())) or false
      end,

      oncompleted = function ()
        svo.rmaff("justice")
        svo.lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        svo.eat(svo.dict.justice.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.justice)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("justice")
      end,
    }
  },
  generosity = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.generosity and
          not svo.doingaction("generosity") and (not svo.haveskillset('chivalry') or not svo.dict.rage.misc.isadvisable())) or false
      end,

      oncompleted = function ()
        svo.rmaff("generosity")
        svo.lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        svo.eat(svo.dict.generosity.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.generosity and
          not svo.doingaction("generosity") and (not svo.haveskillset('chivalry') or not svo.dict.rage.misc.isadvisable())) or false
      end,

      oncompleted = function ()
        svo.rmaff("generosity")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.generosity)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("generosity")
        codepaste.remove_focusable()
      end,
    }
  },
  weakness = {
    gamename = "weariness",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.weakness and
          not svo.doingaction("weakness")) or false
      end,

      oncompleted = function ()
        svo.rmaff("weakness")
        svo.lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        svo.eat(svo.dict.weakness.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.weakness)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("weakness")
        codepaste.remove_focusable()
      end,
    }
  },
  vertigo = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.vertigo and not affs.madness and
          not svo.doingaction("vertigo")) or false
      end,

      oncompleted = function ()
        svo.rmaff("vertigo")
        svo.lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        svo.eat(svo.dict.vertigo.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.vertigo and not affs.madness and
          not svo.doingaction("vertigo")) or false
      end,

      oncompleted = function ()
        svo.rmaff("vertigo")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.vertigo)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("vertigo")
        codepaste.remove_focusable()
      end,
    }
  },
  loneliness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.loneliness and not affs.madness and not svo.doingaction("loneliness")) or false
      end,

      oncompleted = function ()
        svo.rmaff("loneliness")
        svo.lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        svo.eat(svo.dict.loneliness.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.loneliness and not affs.madness and not svo.doingaction("loneliness")) or false
      end,

      oncompleted = function ()
        svo.rmaff("loneliness")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.loneliness)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("loneliness")
        codepaste.remove_focusable()
      end,
    }
  },
  dementia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.dementia and not affs.madness and not svo.doingaction("dementia")) or false
      end,

      oncompleted = function ()
        svo.rmaff("dementia")
        svo.lostbal_herb()
      end,

      eatcure = {"ash", "stannum"},
      onstart = function ()
        svo.eat(svo.dict.dementia.herb)
      end,

      empty = function()
        empty.eat_ash()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.dementia and not affs.madness and not svo.doingaction("dementia")) or false
      end,

      oncompleted = function ()
        svo.rmaff("dementia")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.dementia)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("dementia")
      end,
    }
  },
  paranoia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.paranoia and not affs.madness and not svo.doingaction("paranoia")) or false
      end,

      oncompleted = function ()
        svo.rmaff("paranoia")
        svo.lostbal_herb()
      end,

      eatcure = {"ash", "stannum"},
      onstart = function ()
        svo.eat(svo.dict.paranoia.herb)
      end,

      empty = function()
        empty.eat_ash()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.paranoia and not affs.madness and not svo.doingaction("paranoia")) or false
      end,

      oncompleted = function ()
        svo.rmaff("paranoia")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.paranoia)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("paranoia")
      end,
    }
  },
  hypersomnia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hypersomnia and not affs.madness) or false
      end,

      oncompleted = function ()
        svo.rmaff("hypersomnia")
        svo.lostbal_herb()
      end,

      eatcure = {"ash", "stannum"},
      onstart = function ()
        svo.eat(svo.dict.hypersomnia.herb)
      end,

      empty = function()
        empty.eat_ash()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.hypersomnia)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("hypersomnia")
      end,
    }
  },
  hallucinations = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hallucinations and not affs.madness and not svo.doingaction("hallucinations")) or false
      end,

      oncompleted = function ()
        svo.rmaff("hallucinations")
        svo.lostbal_herb()
      end,

      eatcure = {"ash", "stannum"},
      onstart = function ()
        svo.eat(svo.dict.hallucinations.herb)
      end,

      empty = function()
        empty.eat_ash()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hallucinations and not affs.madness and not svo.doingaction("hallucinations")) or false
      end,

      oncompleted = function ()
        svo.rmaff("hallucinations")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.hallucinations)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("hallucinations")
      end,
    }
  },
  confusion = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.confusion and
          not svo.doingaction("confusion") and not affs.madness) or false
      end,

      oncompleted = function ()
        svo.rmaff("confusion")
        svo.lostbal_herb()
      end,

      eatcure = {"ash", "stannum"},
      onstart = function ()
        svo.eat(svo.dict.confusion.herb)
      end,

      empty = function()
        empty.eat_ash()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.confusion and
          not svo.doingaction("confusion") and not affs.madness) or false
      end,

      oncompleted = function ()
        svo.rmaff("confusion")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.confusion)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("confusion")
        codepaste.remove_focusable()
      end,
    }
  },
  agoraphobia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.agoraphobia and
          not svo.doingaction("agoraphobia")) or false
      end,

      oncompleted = function ()
        svo.rmaff("agoraphobia")
        svo.lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        svo.eat(svo.dict.agoraphobia.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.agoraphobia and
          not svo.doingaction("agoraphobia")) or false
      end,

      oncompleted = function ()
        svo.rmaff("agoraphobia")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.agoraphobia)
        codepaste.remove_focusable()
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("agoraphobia")
      end,
    }
  },
  claustrophobia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.claustrophobia and
          not svo.doingaction("claustrophobia")) or false
      end,

      oncompleted = function ()
        svo.rmaff("claustrophobia")
        svo.lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        svo.eat(svo.dict.claustrophobia.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.claustrophobia and
          not svo.doingaction("claustrophobia")) or false
      end,

      oncompleted = function ()
        svo.rmaff("claustrophobia")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.claustrophobia)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("claustrophobia")
        codepaste.remove_focusable()
      end,
    }
  },
  paralysis = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.paralysis) or false
      end,

      oncompleted = function ()
        svo.rmaff("paralysis")
        svo.lostbal_herb()
        svo.killaction(svo.dict.checkparalysis.misc)
      end,

      eatcure = {"bloodroot", "magnesium"},
      onstart = function ()
        svo.eat(svo.dict.paralysis.herb)
      end,

      empty = function()
        empty.eat_bloodroot()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.paralysis)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("paralysis")
      end,
    },
    onremoved = function () svo.affsp.paralysis = nil svo.donext() end
  },
  asthma = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.asthma) or false
      end,

      oncompleted = function ()
        svo.rmaff("asthma")
        svo.lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        svo.eat(svo.dict.asthma.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.asthma)
        local r = svo.findbybal("smoke")
        if r then
          svo.killaction(svo.dict[r.action_name].smoke)
        end

        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        codepaste.badaeon()
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("asthma")
      end,
    }
  },
  clumsiness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.clumsiness) or false
      end,

      oncompleted = function ()
        svo.rmaff("clumsiness")
        svo.lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        svo.eat(svo.dict.clumsiness.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.clumsiness)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("clumsiness")
      end,
    }
  },
  sensitivity = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.sensitivity) or false
      end,

      oncompleted = function ()
        svo.rmaff("sensitivity")
        svo.lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        svo.eat(svo.dict.sensitivity.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.sensitivity)
      end,

      -- used by AI to check if we're deaf when we got sensi
      checkdeaf = function()
        -- if deafness was stripped, then prompt flags would have removed it at this point and defc.deaf wouldn't be set
        -- also check back to see if deafness went instead, like from bloodleech:
        -- A bloodleech leaps at you, clamping with teeth onto exposed flesh and secreting some foul toxin into your bloodstream. You stumble as you are afflicted with sensitivity.$Your hearing is suddenly restored.
        -- or dragoncurse: A sudden sense of panic overtakes you as the draconic curse manifests, afflicting you with sensitivity.$Your hearing is suddenly restored.
        -- however, don't go off on dstab: Bob pricks you twice in rapid succession with her dirk.$Your hearing is suddenly restored.$A prickly, stinging sensation spreads through your body.
        if svo.find_until_last_paragraph("Your hearing is suddenly restored.", "exact") and not svo.find_until_last_paragraph("A prickly, stinging sensation spreads through your body.", "exact") then return end

        if not conf.aillusion or (not defc.deaf and not affs.deafaff) then
          svo.addaffdict(svo.dict.sensitivity)
        end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("sensitivity")
      end,
    }
  },
  healthleech = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.healthleech) or false
      end,

      oncompleted = function ()
        svo.rmaff("healthleech")
        svo.lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        svo.eat(svo.dict.healthleech.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.healthleech)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("healthleech")
      end,
    }
  },
  relapsing = {
    -- if it's an aff that can be checked, remove it's action and add an appropriate checkaff. Then if the checkaff succeeds, add the relapsing too.
    saw_with_checkable = false,
    gamename = "scytherus",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.relapsing) or false
      end,

      oncompleted = function ()
        svo.rmaff("relapsing")
        svo.lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        svo.eat(svo.dict.relapsing.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    --[[
      relapsing:  ai off, accept everything
                  ai on, accept everything only if we do have relapsing, or it's a checkable symptom -> undeaf/unblind, blind/deaf, camus, else -> ignore

      implementation: generic affs get called to aff.oncompleted, otherwise specialities deal with aff.<func>
    ]]
    aff = {
      -- this goes off when there is no AI or we got a generic affliction that doesn't mean much
      oncompleted = function ()
        -- don't mess with anything special if we have it confirmed
        if affs.relapsing then return end

        if not conf.aillusion or svo.lifevision.l.diag_physical then
          svo.addaffdict(svo.dict.relapsing)
          svo.dict.relapsing.saw_with_checkable = nil
        else
          if svo.actions.checkparalysis_aff then
            svo.dict.relapsing.saw_with_checkable = "paralysis"
          elseif not svo.pl.tablex.find_if(svo.actions:keys(), function (key) return string.find(key, "check", 1, true) end) then
            -- don't process the rest of the affs it gives if it's not checkable and we don't have relapsing already
            sk.stopprocessing = true
          end
        end
        svo.dict.relapsing.aff.hitvitality = nil
      end,

      forced = function ()
        svo.addaffdict(svo.dict.relapsing)
      end,

      camus = function (oldhp)
        if not conf.aillusion or
          ((not affs.recklessness and stats.currenthealth < oldhp) -- health went down without recklessness
           or (svo.dict.relapsing.aff.hitvitality and ((100/stats.maxhealth)* stats.currenthealth) <= 60)) then -- or we're above due to vitality
          svo.addaffdict(svo.dict.relapsing)
          svo.dict.relapsing.aff.hitvitality = nil
          svo.dict.relapsing.saw_with_checkable = nil
        end
      end,

      sumac = function (oldhp)
        if not conf.aillusion or
          ((not affs.recklessness and stats.currenthealth < oldhp) -- health went down without recklessness
           or (svo.dict.relapsing.aff.hitvitality and ((100/stats.maxhealth)* stats.currenthealth) <= 60)) then -- or we're above due to vitality
          svo.addaffdict(svo.dict.relapsing)
          svo.dict.relapsing.aff.hitvitality = nil
          svo.dict.relapsing.saw_with_checkable = nil
        end
      end,

      oleander = function (hadblind)
        if not conf.aillusion or (not hadblind and (defc.blind or affs.blindaff)) then
          svo.addaffdict(svo.dict.relapsing)
          svo.dict.relapsing.saw_with_checkable = nil
        end
      end,

      colocasia = function (hadblindordeaf)
        if not conf.aillusion or (not hadblindordeaf and (defc.blind or affs.blindaff or defc.deaf or affs.deafaff)) then
          svo.addaffdict(svo.dict.relapsing)
          svo.dict.relapsing.saw_with_checkable = nil
        end
      end,

      oculus = function (hadblind)
        if not conf.aillusion or (hadblind and not (defc.blind or affs.blindaff)) then
          svo.addaffdict(svo.dict.relapsing)
          svo.dict.relapsing.saw_with_checkable = nil
        end
      end,

      prefarar = function (haddeaf)
        if not conf.aillusion or (haddeaf and not (defc.deaf or affs.deafaff)) then
          svo.addaffdict(svo.dict.relapsing)
          svo.dict.relapsing.saw_with_checkable = nil
        end
      end,

      asthma = function ()
        if not conf.aillusion or svo.lifevision.l.diag_physical then
          svo.addaffdict(svo.dict.relapsing)
          svo.dict.relapsing.saw_with_checkable = nil
        else
          if svo.actions.checkasthma_aff then
            svo.dict.relapsing.saw_with_checkable = "asthma"
          elseif not svo.pl.tablex.find_if(svo.actions:keys(), function (key) return string.find(key, "check", 1, true) end) then
            -- don't process the rest of the affs it gives.
            sk.stopprocessing = true
          end
        end
        svo.dict.relapsing.aff.hitvitality = nil
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("relapsing")
        svo.dict.relapsing.saw_with_checkable = nil
      end,
    }
  },
  darkshade = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.darkshade) or false
      end,

      oncompleted = function ()
        svo.rmaff("darkshade")
        svo.lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        svo.eat(svo.dict.darkshade.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        if not conf.aillusion or (not oldhp or stats.currenthealth < oldhp) then
          svo.addaffdict(svo.dict.darkshade)
        end
      end,

      forced = function ()
        svo.addaffdict(svo.dict.darkshade)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("darkshade")
      end,
    }
  },
  lethargy = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        -- curing lethargy before hypochondria or torntendons will make it get re-applied
        return (affs.lethargy and not affs.madness and not affs.hypochondria) or false
      end,

      oncompleted = function ()
        svo.rmaff("lethargy")
        svo.lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        svo.eat(svo.dict.lethargy.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.lethargy)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("lethargy")
      end,
    }
  },
  illness = {
    gamename = "nausea",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        -- curing illness before hypochondria will make it get re-applied
        return (affs.illness and not affs.madness and not affs.hypochondria) or false
      end,

      oncompleted = function ()
        svo.rmaff("illness")
        svo.lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        svo.eat(svo.dict.illness.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    aff = {
      oncompleted = function ()
        if not svo.find_until_last_paragraph("Your enhanced constitution allows you to shrug off the nausea.", "exact") then
          svo.addaffdict(svo.dict.illness)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("illness")
      end,
    }
  },
  addiction = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        -- curing addiction before hypochondria or skullfractures will make it get re-applied
        return (affs.addiction and not affs.madness and not affs.hypochondria) or false
      end,

      oncompleted = function ()
        svo.rmaff("addiction")
        svo.lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        svo.eat(svo.dict.addiction.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.addiction)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("addiction")
      end,
    },
    onremoved = function ()
      rift.checkprecache()
    end
  },
  haemophilia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.haemophilia) or false
      end,

      oncompleted = function ()
        svo.rmaff("haemophilia")
        svo.lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        svo.eat(svo.dict.haemophilia.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.haemophilia)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("haemophilia")
      end,
    }
  },
  hypochondria = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hypochondria) or false
      end,

      oncompleted = function ()
        svo.rmaff("hypochondria")
        svo.lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        svo.eat(svo.dict.hypochondria.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.hypochondria)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("hypochondria")
      end,
    }
  },

-- smoke cures
  aeon = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.aeon and codepaste.smoke_elm_pipe()) or false
      end,

      oncompleted = function ()
        svo.rmaff("aeon")
        svo.lostbal_smoke()
        sk.elm_smokepuff()
      end,

      smokecure = {"elm", "cinnabar"},
      onstart = function ()
        send("smoke " .. pipes.elm.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_elm()
        svo.lostbal_smoke()
        sk.elm_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.aeon)
        svo.affsp.aeon = nil
        defences.lost("speed")
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        sk.checkaeony()
        signals.aeony:emit()
        codepaste.badaeon()
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("aeon")
      end,
    },
    onremoved = function ()
      svo.affsp.aeon = nil
      sk.retardation_count = 0
      sk.checkaeony()
      signals.aeony:emit()
    end
  },
  hellsight = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hellsight and not affs.inquisition and codepaste.smoke_valerian_pipe()) or false
      end,

      oncompleted = function ()
        svo.rmaff("hellsight")
        svo.lostbal_smoke()
        sk.valerian_smokepuff()
      end,

      smokecure = {"valerian", "realgar"},
      onstart = function ()
        send("smoke " .. pipes.valerian.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_valerian()
        svo.lostbal_smoke()
        sk.valerian_smokepuff()
      end,

      inquisition = function ()
        svo.addaffdict(svo.dict.inquisition)
        sk.valerian_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.hellsight)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("hellsight")
      end,
    }
  },
  deadening = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.deadening and codepaste.smoke_elm_pipe()) or false
      end,

      oncompleted = function ()
        svo.rmaff("deadening")
        svo.lostbal_smoke()
        sk.elm_smokepuff()
      end,

      smokecure = {"elm", "cinnabar"},
      onstart = function ()
        send("smoke " .. pipes.elm.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_elm()
        svo.lostbal_smoke()
        sk.elm_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.deadening)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("deadening")
      end,
    }
  },
  madness = {
    gamename = "whisperingmadness",
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.madness and codepaste.smoke_elm_pipe() and not affs.hecate) or false
      end,

      oncompleted = function ()
        svo.rmaff("madness")
        svo.lostbal_smoke()
        sk.elm_smokepuff()
      end,

      smokecure = {"elm", "cinnabar"},
      onstart = function ()
        send("smoke " .. pipes.elm.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_elm()
        svo.lostbal_smoke()
        sk.elm_smokepuff()
      end,

      hecate = function()
        sk.elm_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.madness)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("madness")
      end,
    }
  },
  -- valerian cures
  slickness = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.slickness and codepaste.smoke_valerian_pipe() and not svo.doingaction"slickness") or false
      end,

      oncompleted = function ()
        svo.rmaff("slickness")
        svo.lostbal_smoke()
        sk.valerian_smokepuff()
      end,

      smokecure = {"valerian", "realgar"},
      onstart = function ()
        send("smoke " .. pipes.valerian.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_valerian()
        svo.lostbal_smoke()
        sk.valerian_smokepuff()
      end
    },
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.slickness and not affs.anorexia and not svo.doingaction"slickness" and not affs.stain) or false -- anorexia is redundant, but just in for now
      end,

      oncompleted = function ()
        svo.rmaff("slickness")
        svo.lostbal_herb()
      end,

      eatcure = {"bloodroot", "magnesium"},
      onstart = function ()
        svo.eat(svo.dict.slickness.herb)
      end,

      empty = function()
        empty.eat_bloodroot()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.slickness)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("slickness")
      end,
    }
  },
  disloyalty = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.disloyalty and codepaste.smoke_valerian_pipe()) or false
      end,

      oncompleted = function ()
        svo.rmaff("disloyalty")
        svo.lostbal_smoke()
        sk.valerian_smokepuff()
      end,

      smokecure = {"valerian", "realgar"},
      onstart = function ()
        send("smoke " .. pipes.valerian.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_valerian()
        svo.lostbal_smoke()
        sk.valerian_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.disloyalty)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("disloyalty")
      end,
    }
  },
  manaleech = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.manaleech and codepaste.smoke_valerian_pipe()) or false
      end,

      oncompleted = function ()
        svo.rmaff("manaleech")
        svo.lostbal_smoke()
        sk.valerian_smokepuff()
      end,

      smokecure = {"valerian", "realgar"},
      onstart = function ()
        send("smoke " .. pipes.valerian.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_valerian()
        svo.lostbal_smoke()
        sk.valerian_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.manaleech)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("manaleech")
      end,
    }
  },


  -- restoration cures
  heartseed = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.heartseed and not affs.mildtrauma) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingheartseed.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to torso", "apply restoration", "apply reconstructive to torso", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.heartseed.salve, " to torso")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.heartseed.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.heartseed)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("heartseed")
      end,
    }
  },
  curingheartseed = {
    spriority = 0,
    waitingfor = {
      customwait = 6, -- 4 to cure

      oncompleted = function ()
        svo.rmaff("heartseed")
      end,

      ontimeout = function ()
        svo.rmaff("heartseed")
      end,

      noeffect = function ()
        svo.rmaff("heartseed")
      end,

      onstart = function ()
    -- add blocking of the cure coming too early if it'll become necessary.
      end,
    }
  },
  hypothermia = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hypothermia and not affs.mildtrauma) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curinghypothermia.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to torso", "apply restoration", "apply reconstructive to torso", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.hypothermia.salve, " to torso")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.hypothermia.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.hypothermia)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("hypothermia")
      end,
    }
  },
  curinghypothermia = {
    spriority = 0,
    waitingfor = {
      customwait = 6, -- 4 to cure

      oncompleted = function ()
        svo.rmaff("hypothermia")
      end,

      ontimeout = function ()
        svo.rmaff("hypothermia")
      end,

      noeffect = function ()
        svo.rmaff("hypothermia")
      end,

      onstart = function ()
        -- add blocking of the cure coming too early if it'll become necessary.
      end,
    }
  },

  mutilatedrightleg = {
    gamename = "mangledrightleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mutilatedrightleg) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingmutilatedrightleg.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to legs", "apply restoration", "apply reconstructive to legs", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.mutilatedrightleg.salve, " to legs")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.mutilatedrightleg.salve.oncompleted()
      end,

      -- in blackout, this goes through quietly
      ontimeout = function()
        if affs.blackout then
          svo.dict.mutilatedrightleg.salve.oncompleted()
        end
      end,
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakleg("mutilatedrightleg", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakleg("mutilatedrightleg", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("mutilatedrightleg")
      end,
    }
  },
  curingmutilatedrightleg = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("mutilatedrightleg")
        svo.addaffdict(svo.dict.mangledrightleg)

        local result = svo.checkany(svo.dict.curingmutilatedleftleg.waitingfor, svo.dict.curingmangledrightleg.waitingfor, svo.dict.curingmangledleftleg.waitingfor, svo.dict.curingparestolegs.waitingfor)

        if result then
          svo.killaction(svo.dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mutilatedrightleg then
          svo.rmaff("mutilatedrightleg")
          svo.addaffdict(svo.dict.mangledrightleg)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        svo.rmaff("mutilatedrightleg")
        svo.addaffdict(svo.dict.mangledrightleg)
      end,

      noeffect = function ()
        svo.rmaff("mutilatedrightleg")
      end
    }
  },
  parestolegs = {
    salve = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      customwaitf = function()
        return not affs.blackout and 0 or 4 -- can't see applies in blackout
      end,

      isadvisable = function ()
        return (affs.parestolegs) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingparestolegs.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to legs", "apply restoration", "apply reconstructive to legs", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.parestolegs.salve, " to legs")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.parestolegs.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.parestolegs)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("parestolegs")
      end,
    }
  },
  curingparestolegs = {
    waitingfor = {
      customwait = 4,

      oncompleted = function ()
        svo.rmaff("parestolegs")

        local result = svo.checkany(svo.dict.curingmutilatedrightleg.waitingfor, svo.dict.curingmutilatedleftleg.waitingfor, svo.dict.curingmangledrightleg.waitingfor, svo.dict.curingmangledleftleg.waitingfor)

        if result then
          svo.killaction(svo.dict[result.action_name].waitingfor)
        end
      end,

      onstart = function ()
      end,

      ontimeout = function ()
        svo.rmaff("parestolegs")
      end,

      noeffect = function ()
        svo.rmaff("parestolegs")
      end
    }
  },
  mangledrightleg = {
    gamename = "damagedrightleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mangledrightleg and not (affs.mutilatedrightleg or affs.mutilatedleftleg)) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingmangledrightleg.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to legs", "apply restoration", "apply reconstructive to legs", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.mangledrightleg.salve, " to legs")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.mangledrightleg.salve.oncompleted()
      end,

      -- in blackout, this goes through quietly
      ontimeout = function()
        if affs.blackout then
          svo.dict.mangledrightleg.salve.oncompleted()
        end
      end,
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakleg("mangledrightleg", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakleg("mangledrightleg", oldhp, true)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("mangledrightleg")
      end,
    }
  },
  curingmangledrightleg = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("parestolegs")
        svo.rmaff("mangledrightleg")
        svo.addaffdict(svo.dict.crippledrightleg)

        local result = svo.checkany(svo.dict.curingmutilatedrightleg.waitingfor, svo.dict.curingmutilatedleftleg.waitingfor, svo.dict.curingmangledleftleg.waitingfor, svo.dict.curingparestolegs.waitingfor)

        if result then
          svo.killaction(svo.dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mangledrightleg then
          svo.rmaff("mangledrightleg")
          svo.addaffdict(svo.dict.crippledrightleg)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        svo.rmaff("mangledrightleg")
        svo.addaffdict(svo.dict.crippledrightleg)
      end,

      noeffect = function ()
        svo.rmaff("mangledrightleg")
      end
    }
  },
  crippledrightleg = {
    gamename = "brokenrightleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.crippledrightleg and not (affs.mutilatedrightleg or affs.mangledrightleg or affs.parestolegs)) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("crippledrightleg")

        if affs.unknowncrippledlimb then
          svo.dict.unknowncrippledlimb.count = svo.dict.unknowncrippledlimb.count - 1
          if svo.dict.unknowncrippledlimb.count <= 0 then svo.rmaff"unknowncrippledlimb" else svo.updateaffcount(svo.dict.unknowncrippledlimb) end
        end

        if not affs.unknowncrippledleg then return end
        svo.dict.unknowncrippledleg.count = svo.dict.unknowncrippledleg.count - 1
        if svo.dict.unknowncrippledleg.count <= 0 then svo.rmaff"unknowncrippledleg" else svo.updateaffcount(svo.dict.unknowncrippledleg) end
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to legs", "apply mending", "apply renewal to legs", "apply renewal"},
      onstart = function ()
        svo.apply(svo.dict.crippledrightleg.salve, " to legs")
      end,

      fizzled = function ()
        svo.lostbal_salve()
        svo.addaffdict(svo.dict.mangledrightleg)
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.noeffect_mending_legs()
      end,

      -- sometimes restoration can lag out and hit when this goes - ignore
      empty = function() end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.crippledrightleg)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("crippledrightleg")
      end,
    }
  },
  mutilatedleftleg = {
    gamename = "mangledleftleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mutilatedleftleg) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingmutilatedleftleg.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to legs", "apply restoration", "apply reconstructive to legs", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.mutilatedleftleg.salve, " to legs")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.mutilatedleftleg.salve.oncompleted()
      end,

      -- in blackout, this goes through quietly
      ontimeout = function()
        if affs.blackout then
          svo.dict.mutilatedleftleg.salve.oncompleted()
        end
      end,
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakleg("mutilatedleftleg", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakleg("mutilatedleftleg", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("mutilatedleftleg")
      end,
    }
  },
  curingmutilatedleftleg = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("mutilatedleftleg")
        svo.addaffdict(svo.dict.mangledleftleg)

        local result = svo.checkany(svo.dict.curingmutilatedrightleg.waitingfor, svo.dict.curingmangledrightleg.waitingfor, svo.dict.curingmangledleftleg.waitingfor, svo.dict.curingparestolegs.waitingfor)

        if result then
          svo.killaction(svo.dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mutilatedleftleg then
          svo.rmaff("mutilatedleftleg")
          svo.addaffdict(svo.dict.mangledleftleg)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        svo.rmaff("mutilatedleftleg")
        svo.addaffdict(svo.dict.mangledleftleg)
      end,

      noeffect = function ()
        svo.rmaff("mutilatedleftleg")
      end
    }
  },
  mangledleftleg = {
    gamename = "damagedleftleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mangledleftleg and not (affs.mutilatedrightleg or affs.mutilatedleftleg)) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingmangledleftleg.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to legs", "apply restoration", "apply reconstructive to legs", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.mangledleftleg.salve, " to legs")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.mangledleftleg.salve.oncompleted()
      end,

      -- in blackout, this goes through quietly
      ontimeout = function()
        if affs.blackout then
          svo.dict.mangledleftleg.salve.oncompleted()
        end
      end,
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakleg("mangledleftleg", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakleg("mangledleftleg", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("mangledleftleg")
      end,
    }
  },
  curingmangledleftleg = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("parestolegs")
        svo.rmaff("mangledleftleg")
        svo.addaffdict(svo.dict.crippledleftleg)

        local result = svo.checkany(svo.dict.curingmutilatedrightleg.waitingfor, svo.dict.curingmutilatedleftleg.waitingfor, svo.dict.curingmangledrightleg.waitingfor, svo.dict.curingparestolegs.waitingfor)

        if result then
          svo.killaction(svo.dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mangledleftleg then
          svo.rmaff("mangledleftleg")
          svo.addaffdict(svo.dict.crippledleftleg)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        svo.rmaff("mangledleftleg")
        svo.addaffdict(svo.dict.crippledleftleg)
      end,

      noeffect = function ()
        svo.rmaff("mangledleftleg")
      end
    }
  },
  crippledleftleg = {
    gamename = "brokenleftleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.crippledleftleg and not (affs.mutilatedleftleg or affs.mangledleftleg or affs.parestolegs)) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("crippledleftleg")

        if affs.unknowncrippledlimb then
          svo.dict.unknowncrippledlimb.count = svo.dict.unknowncrippledlimb.count - 1
          if svo.dict.unknowncrippledlimb.count <= 0 then svo.rmaff"unknowncrippledlimb" else svo.updateaffcount(svo.dict.unknowncrippledlimb) end
        end

        if not affs.unknowncrippledleg then return end
        svo.dict.unknowncrippledleg.count = svo.dict.unknowncrippledleg.count - 1
        if svo.dict.unknowncrippledleg.count <= 0 then svo.rmaff"unknowncrippledleg" else svo.updateaffcount(svo.dict.unknowncrippledleg) end
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to legs", "apply mending", "apply renewal to legs", "apply renewal"},
      onstart = function ()
        svo.apply(svo.dict.crippledleftleg.salve, " to legs")
      end,

      fizzled = function ()
        svo.lostbal_salve()
        svo.addaffdict(svo.dict.mangledleftleg)
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.noeffect_mending_legs()
      end,

      -- sometimes restoration can lag out and hit when this goes - ignore
      empty = function() end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.crippledleftleg)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("crippledleftleg")
      end,
    }
  },
  parestoarms = {
    salve = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      customwaitf = function()
        return not affs.blackout and 0 or 4 -- can't see applies in blackout
      end,

      isadvisable = function ()
        return (affs.parestoarms) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingparestoarms.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to arms", "apply restoration", "apply reconstructive to arms", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.parestoarms.salve, " to arms")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.parestoarms.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.parestoarms)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("parestoarms")
      end,
    }
  },
  curingparestoarms = {
    waitingfor = {
      customwait = 4,

      oncompleted = function ()
        svo.rmaff("parestoarms")

        local result = svo.checkany(svo.dict.curingmutilatedrightarm.waitingfor, svo.dict.curingmutilatedleftarm.waitingfor, svo.dict.curingmangledrightarm.waitingfor, svo.dict.curingmangledleftarm.waitingfor)

        if result then
          svo.killaction(svo.dict[result.action_name].waitingfor)
        end
      end,

      onstart = function ()
      end,

      ontimeout = function ()
        svo.rmaff("parestoarms")
      end,

      noeffect = function ()
        svo.rmaff("parestoarms")
      end
    }
  },
  mutilatedleftarm = {
    gamename = "mangledleftarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mutilatedleftarm) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingmutilatedleftarm.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to arms", "apply restoration", "apply reconstructive to arms", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.mutilatedleftarm.salve, " to arms")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.mutilatedleftarm.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakarm("mutilatedleftarm", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakarm("mutilatedleftarm", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("mutilatedleftarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingmutilatedleftarm = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("mutilatedleftarm")
        svo.addaffdict(svo.dict.mangledleftarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        local result = svo.checkany(svo.dict.curingmutilatedrightarm.waitingfor, svo.dict.curingmangledrightarm.waitingfor, svo.dict.curingmangledleftarm.waitingfor, svo.dict.curingparestoarms.waitingfor)

        if result then
          svo.killaction(svo.dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mutilatedleftarm then
          svo.rmaff("mutilatedleftarm")
          svo.addaffdict(svo.dict.mangledleftarm)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        svo.rmaff("mutilatedleftarm")
        svo.addaffdict(svo.dict.mangledleftarm)
      end,

      noeffect = function ()
        svo.rmaff("mutilatedleftarm")
      end
    }
  },
  mangledleftarm = {
    gamename = "damagedleftarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mangledleftarm and not (affs.mutilatedrightarm or affs.mutilatedleftarm)) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingmangledleftarm.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to arms", "apply restoration", "apply reconstructive to arms", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.mangledleftarm.salve, " to arms")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.mangledleftarm.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakarm("mangledleftarm", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakarm("mangledleftarm", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("mangledleftarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingmangledleftarm = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("parestoarms")
        svo.rmaff("mangledleftarm")
        svo.addaffdict(svo.dict.crippledleftarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        local result = svo.checkany(svo.dict.curingmutilatedrightarm.waitingfor, svo.dict.curingmutilatedleftarm.waitingfor, svo.dict.curingmangledrightarm.waitingfor, svo.dict.curingparestoarms.waitingfor)

        if result then
          svo.killaction(svo.dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mangledleftarm then
          svo.rmaff("mangledleftarm")
          svo.addaffdict(svo.dict.crippledleftarm)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        svo.rmaff("mangledleftarm")
        svo.addaffdict(svo.dict.crippledleftarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,

      noeffect = function ()
        svo.rmaff("mangledleftarm")
      end
    }
  },
  crippledleftarm = {
    gamename = "brokenleftarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.crippledleftarm and not (affs.mutilatedleftarm or affs.mangledleftarm or affs.parestoarms)) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("crippledleftarm")

        if affs.unknowncrippledlimb then
          svo.dict.unknowncrippledlimb.count = svo.dict.unknowncrippledlimb.count - 1
          if svo.dict.unknowncrippledlimb.count <= 0 then svo.rmaff"unknowncrippledlimb" else svo.updateaffcount(svo.dict.unknowncrippledlimb) end
        end

        if not affs.unknowncrippledarm then return end
        svo.dict.unknowncrippledarm.count = svo.dict.unknowncrippledarm.count - 1
        if svo.dict.unknowncrippledarm.count <= 0 then svo.rmaff"unknowncrippledarm" else svo.updateaffcount(svo.dict.unknowncrippledarm) end
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to arms", "apply mending", "apply renewal to arms", "apply renewal"},
      onstart = function ()
        svo.apply(svo.dict.crippledleftarm.salve, " to arms")
      end,

      fizzled = function ()
        svo.lostbal_salve()
        svo.addaffdict(svo.dict.mangledleftarm)
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.noeffect_mending_arms()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.crippledleftarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("crippledleftarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  mutilatedrightarm = {
    gamename = "mangledrightarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mutilatedrightarm) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingmutilatedrightarm.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to arms", "apply restoration", "apply reconstructive to arms", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.mutilatedrightarm.salve, " to arms")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.mutilatedrightarm.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakarm("mutilatedrightarm", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakarm("mutilatedrightarm", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("mutilatedrightarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingmutilatedrightarm = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("mutilatedrightarm")
        svo.addaffdict(svo.dict.mangledrightarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        local result = svo.checkany(svo.dict.curingmutilatedleftarm.waitingfor, svo.dict.curingmangledrightarm.waitingfor, svo.dict.curingmangledleftarm.waitingfor, svo.dict.curingparestoarms.waitingfor)

        if result then
          svo.killaction(svo.dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mutilatedrightarm then
          svo.rmaff("mutilatedrightarm")
          svo.addaffdict(svo.dict.mangledrightarm)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        svo.rmaff("mutilatedleftarm")
        svo.addaffdict(svo.dict.mangledleftarm)
      end,

      noeffect = function ()
        svo.rmaff("mutilatedrightarm")
      end
    }
  },
  mangledrightarm = {
    gamename = "damagedrightarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mangledrightarm and not (affs.mutilatedrightarm or affs.mutilatedleftarm)) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingmangledrightarm.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to arms", "apply restoration", "apply reconstructive to arms", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.mangledrightarm.salve, " to arms")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.mangledrightarm.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakarm("mangledrightarm", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakarm("mangledrightarm", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("mangledrightarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingmangledrightarm = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("mangledrightarm")
        svo.rmaff("parestoarms")
        svo.addaffdict(svo.dict.crippledrightarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        local result = svo.checkany(svo.dict.curingmutilatedrightarm.waitingfor, svo.dict.curingmutilatedleftarm.waitingfor, svo.dict.curingmangledleftarm.waitingfor, svo.dict.curingparestoarms.waitingfor)

        if result then
          svo.killaction(svo.dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mangledrightarm then
          svo.rmaff("mangledrightarm")
          svo.addaffdict(svo.dict.crippledrightarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        svo.rmaff("mangledleftarm")
        svo.addaffdict(svo.dict.crippledleftarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,

      noeffect = function ()
        svo.rmaff("mangledrightarm")
      end
    }
  },
  crippledrightarm = {
    gamename = "brokenrightarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.crippledrightarm and not (affs.mutilatedrightarm or affs.mangledrightarm or affs.parestoarms)) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("crippledrightarm")

        if affs.unknowncrippledlimb then
          svo.dict.unknowncrippledlimb.count = svo.dict.unknowncrippledlimb.count - 1
          if svo.dict.unknowncrippledlimb.count <= 0 then svo.rmaff"unknowncrippledlimb" else svo.updateaffcount(svo.dict.unknowncrippledlimb) end
        end

        if not affs.unknowncrippledarm then return end
        svo.dict.unknowncrippledarm.count = svo.dict.unknowncrippledarm.count - 1
        if svo.dict.unknowncrippledarm.count <= 0 then svo.rmaff"unknowncrippledarm" else svo.updateaffcount(svo.dict.unknowncrippledarm) end
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to arms", "apply mending", "apply renewal to arms", "apply renewal"},
      onstart = function ()
        svo.apply(svo.dict.crippledrightarm.salve, " to arms")
      end,

      fizzled = function ()
        svo.lostbal_salve()
        svo.addaffdict(svo.dict.mangledrightarm)
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.noeffect_mending_arms()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.crippledrightarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("crippledrightarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  laceratedthroat = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.laceratedthroat) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curinglaceratedthroat.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to head", "apply restoration", "apply reconstructive to head", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.laceratedthroat.salve, " to head")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.laceratedthroat.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.laceratedthroat)
      end,

      -- separated, so we can use it normally if necessary - another class might get it
      sylvanhit = function (oldhp)
        if not conf.aillusion or (not affs.recklessness and stats.currenthealth < oldhp) then
          svo.addaffdict(svo.dict.laceratedthroat)
        end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("laceratedthroat")
      end,
    }
  },
  curinglaceratedthroat = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("laceratedthroat")
        svo.addaffdict(svo.dict.slashedthroat)
      end,

      onstart = function ()
      end,

      noeffect = function()
        svo.rmaff("laceratedthroat")
        svo.addaffdict(svo.dict.slashedthroat)
      end
    }
  },
  slashedthroat = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.slashedthroat) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("slashedthroat")
      end,

      noeffect = function ()
        empty.apply_epidermal_head()
      end,

      empty = function ()
        empty.apply_epidermal_head()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to head", "apply epidermal", "apply sensory to head", "apply sensory"},
      onstart = function ()
        svo.apply(svo.dict.slashedthroat.salve, " to head")
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.slashedthroat)
      end,

      -- separated, so we can use it normally if necessary - another class might get it
      sylvanhit = function (oldhp)
        if not conf.aillusion or (not affs.recklessness and stats.currenthealth < oldhp) then
          svo.addaffdict(svo.dict.slashedthroat)
        end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("slashedthroat")
      end,
    }
  },
  serioustrauma = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.serioustrauma) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingserioustrauma.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to torso", "apply restoration", "apply reconstructive to torso", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.serioustrauma.salve, " to torso")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.serioustrauma.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        if not conf.aillusion or not oldhp or oldhp > stats.currenthealth or svo.paragraph_length >= 3 then
          if affs.mildtrauma then svo.rmaff("mildtrauma") end
          svo.addaffdict(svo.dict.serioustrauma)
        end
      end,

      forced = function ()
        if affs.mildtrauma then svo.rmaff("mildtrauma") end
        svo.addaffdict(svo.dict.serioustrauma)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("serioustrauma")
      end,
    }
  },
  curingserioustrauma = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("serioustrauma")
        svo.addaffdict(svo.dict.mildtrauma)
      end,

      ontimeout = function ()
        if affs.serioustrauma then
          svo.rmaff("serioustrauma")
          svo.addaffdict(svo.dict.mildtrauma)
        end
      end,

      onstart = function ()
      end,

      noeffect = function ()
        svo.rmaff("serioustrauma")
        svo.rmaff("mildtrauma")
      end
    }
  },
  mildtrauma = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mildtrauma) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingmildtrauma.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to torso", "apply restoration", "apply reconstructive to torso", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.mildtrauma.salve, " to torso")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.mildtrauma.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        if not conf.aillusion or not oldhp or oldhp > stats.currenthealth or svo.paragraph_length >= 3 then
          svo.addaffdict(svo.dict.mildtrauma)
        end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("mildtrauma")
      end,
    }
  },
  curingmildtrauma = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("mildtrauma")
      end,

      ontimeout = function ()
        svo.rmaff("mildtrauma")
      end,

      onstart = function ()
      end,

      noeffect = function ()
        svo.rmaff("mildtrauma")
      end
    }
  },
  seriousconcussion = {
    gamename = "mangledhead",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.seriousconcussion) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingseriousconcussion.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to head", "apply restoration", "apply reconstructive to head", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.seriousconcussion.salve, " to head")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.seriousconcussion.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        if not conf.aillusion or not oldhp or oldhp > stats.currenthealth or svo.paragraph_length >= 3 then
          if affs.mildconcussion then svo.rmaff("mildconcussion") end
          svo.addaffdict(svo.dict.seriousconcussion)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        end
      end,

      forced = function ()
        if affs.mildconcussion then svo.rmaff("mildconcussion") end
        svo.addaffdict(svo.dict.seriousconcussion)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("seriousconcussion")
      end,
    },
    onadded = function()
      if affs.prone and affs.seriousconcussion then
        sk.warn "pulpable"
      end
    end
  },
  curingseriousconcussion = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("seriousconcussion")
        svo.addaffdict(svo.dict.mildconcussion)
      end,

      ontimeout = function ()
        if affs.seriousconcussion then
          svo.rmaff("seriousconcussion")
          svo.addaffdict(svo.dict.mildconcussion)
        end
      end,

      onstart = function ()
      end,

      noeffect = function ()
        svo.rmaff("seriousconcussion")
        svo.rmaff("mildconcussion")
      end
    }
  },
  mildconcussion = {
    gamename = "damagedhead",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mildconcussion) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()

        svo.doaction(svo.dict.curingmildconcussion.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to head", "apply restoration", "apply reconstructive to head", "apply reconstructive"},
      onstart = function ()
        svo.apply(svo.dict.mildconcussion.salve, " to head")
      end,

      -- we get no msg from an application of this
      empty = function ()
        svo.dict.mildconcussion.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        if not conf.aillusion or not oldhp or oldhp > stats.currenthealth or svo.paragraph_length >= 3 then
          svo.addaffdict(svo.dict.mildconcussion)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        end
      end,

      forced = function ()
        svo.addaffdict(svo.dict.mildconcussion)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("mildconcussion")
      end,
    }
  },
  curingmildconcussion = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("mildconcussion")
      end,

      ontimeout = function ()
        svo.rmaff("mildconcussion")
      end,

      onstart = function ()
      end,

      noeffect = function ()
        svo.rmaff("mildconcussion")
      end
    }
  },


-- salve cures
  anorexia = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.anorexia and not svo.doingaction"anorexia") or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("anorexia")
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.apply_epidermal_body()
      end,

      empty = function ()
        empty.apply_epidermal_body()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to body", "apply epidermal", "apply sensory to body", "apply sensory"},
      onstart = function ()
        svo.apply(svo.dict.anorexia.salve, " to body")
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.anorexia and
          not svo.doingaction("anorexia")) or false
      end,

      oncompleted = function ()
        svo.rmaff("anorexia")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.anorexia)
        codepaste.badaeon()
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("anorexia")
        codepaste.remove_focusable()
      end,
    }
  },
  ablaze = {
    gamename = "burning",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.ablaze) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("ablaze")
      end,

      all = function()
        svo.lostbal_salve()
        codepaste.remove_burns()
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal"},
      onstart = function ()
        svo.apply(svo.dict.ablaze.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        codepaste.remove_burns("ablaze")
        svo.addaffdict(svo.dict.ablaze)
      end,
    },
    gone = {
      oncompleted = function ()
        local currentburn = sk.current_burn()
        svo.rmaff(currentburn)
      end,

      -- used in blackout and passive curing where multiple levels could be cured at once
      generic_reducelevel = function(amount)
        -- if no amount is specified, find the current level and take it down a notch
        if not amount then
          local reduceto, currentburn = sk.previous_burn(), sk.current_burn()

          svo.rmaff(currentburn)
          svo.addaffdict(svo.dict[reduceto])
        else -- amount is specified
          local reduceto, currentburn = sk.previous_burn(amount), sk.current_burn()
          svo.rmaff(currentburn)

          if not reduceto then reduceto = "ablaze" end
          svo.addaffdict(svo.dict[reduceto])
        end
      end
    }
  },
  severeburn = {
    salve = {
      aspriority = 0,
      spriority = 0,
      irregular = true,

      isadvisable = function ()
        return (affs.severeburn) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("severeburn")
        svo.addaffdict(svo.dict.ablaze)
      end,

      all = function()
        svo.lostbal_salve()
        codepaste.remove_burns()
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal"},
      onstart = function ()
        svo.apply(svo.dict.severeburn.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        codepaste.remove_burns("severeburn")
        svo.addaffdict(svo.dict.severeburn)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("severeburn")
      end,
    }
  },
  extremeburn = {
    salve = {
      aspriority = 0,
      spriority = 0,
      irregular = true,

      isadvisable = function ()
        return (affs.extremeburn) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("extremeburn")
        svo.addaffdict(svo.dict.severeburn)
      end,

      all = function()
        svo.lostbal_salve()
        codepaste.remove_burns()
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal"},
      onstart = function ()
        svo.apply(svo.dict.extremeburn.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        codepaste.remove_burns("extremeburn")
        svo.addaffdict(svo.dict.extremeburn)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("extremeburn")
      end,
    }
  },
  charredburn = {
    salve = {
      aspriority = 0,
      spriority = 0,
      irregular = true,

      isadvisable = function ()
        return (affs.charredburn) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("charredburn")
        svo.addaffdict(svo.dict.extremeburn)
      end,

      all = function()
        svo.lostbal_salve()
        codepaste.remove_burns()
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal"},
      onstart = function ()
        svo.apply(svo.dict.charredburn.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        codepaste.remove_burns("charredburn")
        svo.addaffdict(svo.dict.charredburn)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("charredburn")
      end,
    }
  },
  meltingburn = {
    salve = {
      aspriority = 0,
      spriority = 0,
      irregular = true,

      isadvisable = function ()
        return (affs.meltingburn) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("meltingburn")
        svo.addaffdict(svo.dict.charredburn)
      end,

      all = function()
        svo.lostbal_salve()
        codepaste.remove_burns()
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal"},
      onstart = function ()
        svo.apply(svo.dict.meltingburn.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        codepaste.remove_burns("meltingburn")
        svo.addaffdict(svo.dict.meltingburn)

        sk.warn "golemdestroyable"
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("meltingburn")
      end,
    }
  },
  selarnia = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.selarnia) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("selarnia")
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal", "apply mending to torso", "apply renewal to torso"},
      onstart = function ()
        svo.apply(svo.dict.selarnia.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.selarnia)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("selarnia")
      end,
    }
  },
  itching = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.itching) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("itching")
      end,

      noeffect = function ()
        empty.apply_epidermal_body()
      end,

      empty = function ()
        empty.apply_epidermal_body()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to body", "apply epidermal", "apply sensory to body", "apply sensory"},
      onstart = function ()
        svo.apply(svo.dict.itching.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.itching)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("itching")
      end,
    }
  },
  stuttering = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.stuttering) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("stuttering")
      end,

      noeffect = function ()
        empty.apply_epidermal_head()
      end,

      empty = function ()
        empty.apply_epidermal_head()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to head", "apply epidermal", "apply sensory to head", "apply sensory"},
      onstart = function ()
        svo.apply(svo.dict.stuttering.salve, " to head")
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.stuttering)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("stuttering")
      end,
    }
  },
  scalded = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.scalded and not defc.blind and not affs.blindaff) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("scalded")
      end,

      noeffect = function ()
        empty.apply_epidermal_head()
      end,

      empty = function ()
        empty.apply_epidermal_head()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to head", "apply epidermal", "apply sensory to head", "apply sensory"},
      onstart = function ()
        svo.apply(svo.dict.scalded.salve, " to head")
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.scalded)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("scalded")
      end,
    }
  },
  numbedleftarm = {
    waitingfor = {
      customwait = 15, -- lasts 15s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        svo.rmaff("numbedleftarm")
        svo.make_gnomes_work()
      end,

      oncompleted = function ()
        svo.rmaff("numbedleftarm")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.numbedleftarm)
        if not svo.actions.numbedleftarm_waitingfor then svo.doaction(svo.dict.numbedleftarm.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("numbedleftarm")
        svo.killaction(svo.dict.numbedleftarm.waitingfor)
      end,
    }
  },
  numbedrightarm = {
    waitingfor = {
      customwait = 8, -- lasts 8s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        svo.rmaff("numbedrightarm")
        svo.make_gnomes_work()
      end,

      oncompleted = function ()
        svo.rmaff("numbedrightarm")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.numbedrightarm)
        if not svo.actions.numbedrightarm_waitingfor then svo.doaction(svo.dict.numbedrightarm.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("numbedrightarm")
        svo.killaction(svo.dict.numbedrightarm.waitingfor)
      end,
    }
  },
  blindaff = {
    gamename = "blind",
    onservereignore = function()
      return not svo.dict.blind.onservereignore()
    end,
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.blindaff or (defc.blind and not ((sys.deffing and defdefup[defs.mode].blind) or
          (conf.keepup and defkeepup[defs.mode].blind))) or affs.scalded) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("blindaff")
        defences.lost("blind")

        local restoreaff, restoredef
        if affs.deafaff then restoreaff = true end
        if defc.deaf then restoredef = true end

        empty.apply_epidermal_head()

        if restoreaff then svo.addaffdict(svo.dict.deafaff) end
        if restoredef then defences.got("deaf") end
      end,

      noeffect = function ()
        empty.apply_epidermal_head()
      end,

      empty = function ()
        empty.apply_epidermal_head()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to head", "apply epidermal", "apply sensory to head", "apply sensory"},
      onstart = function ()
        svo.apply(svo.dict.blindaff.salve, " to head")
      end
    },
    aff = {
      oncompleted = function ()
        if (defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind) or
          (svo.me.class == "Apostate" or defc.mindseye) then
          defences.got("blind")
        else
          svo.addaffdict(svo.dict.blindaff)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("blindaff")
        defences.lost("blind")
      end,
    }
  },
  deafaff = {
    gamename = "deaf",
    onservereignore = function()
      return not svo.dict.deaf.onservereignore()
    end,
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.deafaff or defc.deaf and not ((sys.deffing and defdefup[defs.mode].deaf) or
          (conf.keepup and defkeepup[defs.mode].deaf))) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("deafaff")
        defences.lost("deaf")
      end,

      noeffect = function ()
        empty.apply_epidermal_head()
      end,

      empty = function ()
        empty.apply_epidermal_head()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to head", "apply epidermal", "apply sensory to head", "apply sensory"},
      onstart = function ()
        svo.apply(svo.dict.deafaff.salve, " to head")
      end
    },
    aff = {
      oncompleted = function ()
        if (defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf) or defc.mindseye then
          defences.got("deaf")
        else
          svo.addaffdict(svo.dict.deafaff)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("deafaff")
        defences.lost("deaf")
      end,
    }
  },

  shivering = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.shivering and not affs.frozen and not affs.hypothermia) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("shivering")
      end,

      noeffect = function()
        svo.lostbal_salve()
      end,

      gotcaloricdef = function (hypothermia)
        if not hypothermia then svo.rmaff({"frozen", "shivering"}) end
        svo.dict.caloric.salve.oncompleted ()
      end,

      applycure = {"caloric", "exothermic"},
      actions = {"apply caloric to body", "apply caloric", "apply exothermic to body", "apply exothermic"},
      onstart = function ()
        svo.apply(svo.dict.shivering.salve, " to body")
      end,

      empty = function ()
        svo.lostbal_salve()
        svo.rmaff("shivering")
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.shivering)
        defences.lost("caloric")
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("shivering")
      end,
    }
  },
  frozen = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.frozen and not affs.hypothermia) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("frozen")
        svo.addaffdict(svo.dict.shivering)
      end,

      noeffect = function()
        svo.lostbal_salve()
      end,

      gotcaloricdef = function (hypothermia)
        if not hypothermia then svo.rmaff({"frozen", "shivering"}) end
        svo.dict.caloric.salve.oncompleted ()
      end,

      applycure = {"caloric", "exothermic"},
      actions = {"apply caloric to body", "apply caloric", "apply exothermic to body", "apply exothermic"},
      onstart = function ()
        svo.apply(svo.dict.frozen.salve, " to body")
      end,

      empty = function ()
        svo.lostbal_salve()
        svo.rmaff("frozen")
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.frozen)
        defences.lost("caloric")
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("frozen")
      end
    }
  },

-- purgatives
  voyria = {
    purgative = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.voyria) or false
      end,

      oncompleted = function ()
        svo.lostbal_purgative()
        svo.rmaff("voyria")
      end,

      sipcure = {"immunity", "antigen"},
      onstart = function ()
        svo.sip(svo.dict.voyria.purgative)
      end,

      noeffect = function()
        svo.rmaff("voyria")
        svo.lostbal_purgative()
      end,

      empty = function ()
        svo.lostbal_purgative()
        empty.sip_immunity()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.voyria)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("voyria")
      end
    }
  },


-- misc
  lovers = {
    map = {},
    tempmap = {},
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      dontbatch = true,

      isadvisable = function ()
        return (affs.lovers and not svo.doingaction("lovers")) or false
      end,

      oncompleted = function (whom)
        svo.dict.lovers.map[whom] = nil
        if not next(svo.dict.lovers.map) then
          svo.rmaff("lovers")
        end
      end,

      onclear = function ()
        svo.dict.lovers.tempmap = {}
      end,

      nobody = function ()
        if svo.dict.lovers.rejecting then
          svo.dict.lovers.map[svo.dict.lovers.rejecting] = nil
          svo.dict.lovers.rejecting = nil
        end

        if not next(svo.dict.lovers.map) then
          svo.rmaff("lovers")
        end
      end,

      onstart = function ()
        svo.dict.lovers.rejecting = next(svo.dict.lovers.map)
        if not svo.dict.lovers.rejecting then -- if we added it via some manual way w/o a name, this failsafe will catch & remove it
          svo.rmaff("lovers")
          return
        end

        send("reject " .. svo.dict.lovers.rejecting, conf.commandecho)
      end
    },
    aff = {
      oncompleted = function (whom)
        if not svo.dict.lovers.tempmap and not whom then return end

        svo.addaffdict(svo.dict.lovers)
        for _, name in ipairs(svo.dict.lovers.tempmap) do
          svo.dict.lovers.map[name] = true
        end
        svo.dict.lovers.tempmap = {}

        if whom then
          svo.dict.lovers[whom] = true
        end

        svo.affl.lovers = {names = svo.dict.lovers.map}
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("lovers")
        svo.dict.lovers.map = {}
      end,
    }
  },
  fear = {
    misc = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.fear and not svo.doingaction("fear")) or false
      end,

      oncompleted = function ()
        svo.rmaff("fear")
      end,

      action = "compose",
      onstart = function ()
        send("compose", conf.commandecho)
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return false
        --[[return (affs.fear and
          not svo.doingaction("fear")) or false]]
      end,

      oncompleted = function ()
        svo.rmaff("fear")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.fear)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("fear")
        codepaste.remove_focusable()
      end
    }
  },
  sleep = {
    misc = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.sleep and
          not svo.doingaction("curingsleep") and not svo.doingaction("sleep")) or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.curingsleep.waitingfor)
      end,

      actions = {"wake", "wake up"},
      onstart = function ()
        send("wake up", conf.commandecho)
      end,

      -- ???
      empty = function ()
      end
    },
    aff = {
      oncompleted = function ()
        if not affs.sleep then svo.addaffdict(svo.dict.sleep) defences.lost("insomnia") end
      end,

      symptom = function()
        if not affs.sleep then svo.addaffdict(svo.dict.sleep) defences.lost("insomnia") end
        svo.addaffdict(svo.dict.prone)

        -- reset non-wait things we were doing, because they got cancelled by the stun
        if affs.sleep or svo.actions.sleep_aff then
          for _,v in svo.actions:iter() do
            if v.p.balance ~= "waitingfor" and v.p.balance ~= "aff" and v.p.name ~= "sleep_misc" then
              svo.killaction(svo.dict[v.p.action_name][v.p.balance])
            end
          end
        end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("sleep")
      end,
    }
  },
  curingsleep = {
    spriority = 0,
    waitingfor = {
      customwait = 999,

      oncompleted = function ()
        svo.rmaff("sleep")

        -- reset sleep so we try waking up again after being awoken and slept at once (like in a dsl or a delph snipe)
        if svo.actions.sleep_misc then
          svo.killaction(svo.dict.sleep.misc)
        end
      end,

      onstart = function () end
    }
  },
  bleeding = {
    count = 0,
    -- affs.bleeding.spammingbleed is used to throttle bleed spamming so it doesn't get out of control
    misc = {
      aspriority = 0,
      spriority = 0,
      -- managed outside priorities
      uncurable = true,

      isadvisable = function ()
        if affs.bleeding and not svo.doingaction("bleeding") and not affs.bleeding.spammingbleed and not affs.haemophilia and not affs.sleep and svo.can_usemana() and conf.clot then
          if (not affs.corrupted and svo.dict.bleeding.count >= conf.bleedamount) then
            return true
          elseif (affs.corrupted and svo.dict.bleeding.count >= conf.manableedamount) then
            if stats.currenthealth >= sys.corruptedhealthmin then
              return true
            else
              sk.warn "cantclotmana"
              return false
            end
          end
        else return false end
      end,

      -- by default, oncompleted means a clot went through okay
      oncompleted = function ()
        svo.dict.bleeding.saw_haemophilia = nil
      end,

      -- oncured in this case means that we actually cured it; don't have any more bleeding
      oncured = function ()
        if affs.bleeding and affs.bleeding.spammingbleed then killTimer(affs.bleeding.spammingbleed); affs.bleeding.spammingbleed = nil end
        svo.rmaff("bleeding")
        svo.dict.bleeding.count = 0
        svo.dict.bleeding.saw_haemophilia = nil
      end,

      nomana = function ()
        if not svo.actions.nomana_waitingfor and stats.currentmana ~= 0 then
          svo.echof("Seems we're out of mana.")
          svo.doaction(svo.dict.nomana.waitingfor)
        end

        svo.dict.bleeding.saw_haemophilia = nil
        if affs.bleeding and affs.bleeding.spammingbleed then killTimer(affs.bleeding.spammingbleed); affs.bleeding.spammingbleed = nil end
      end,

      haemophilia = function()
        if svo.dict.bleeding.saw_haemophilia then
          svo.addaffdict(svo.dict.haemophilia)
          svo.echof("Seems like we do have haemophilia for real.")
        else
          svo.dict.bleeding.saw_haemophilia = true
        end
        if affs.bleeding and affs.bleeding.spammingbleed then killTimer(affs.bleeding.spammingbleed); affs.bleeding.spammingbleed = nil end
      end,

      action = "clot",
      onstart = function ()
        local show = conf.commandecho and not conf.gagclot
        send("clot", show)

        -- don't optimize with corruption for now (but do if need need be)
        if not sys.sync and ((not affs.corrupted and svo.stats.mp >= 70 and (svo.dict.bleeding.count and svo.dict.bleeding.count >= 200))
            or (affs.corrupted and stats.currenthealth+500 >= sys.corruptedhealthmin)) then
          send("clot", show)
          send("clot", show)

          -- after sending a bunch of clots, wait a bit before doing it again
          if affs.bleeding then
            if affs.bleeding.spammingbleed then killTimer(affs.bleeding.spammingbleed); affs.bleeding.spammingbleed = nil end
            affs.bleeding.spammingbleed = tempTimer(svo.getping(), function () affs.bleeding.spammingbleed = nil; svo.make_gnomes_work() end)
          end
        end
      end
    },
    aff = {
      oncompleted = function (amount)
        svo.addaffdict(svo.dict.bleeding)
        -- TODO: affs.count vs svo.dict.count?
        affs.bleeding.p.count = amount or (affs.bleeding.p.count + 200)
        svo.updateaffcount(svo.dict.bleeding)

        -- remove bleeding if we've had it for a while and didn't clot it up
        if sk.smallbleedremove then killTimer(sk.smallbleedremove) end
        sk.smallbleedremove = tempTimer(conf.smallbleedremove or 8, function()
          sk.smallbleedremove = nil
          if not affs.bleeding then return end

          if svo.dict.bleeding.count <= conf.bleedamount or svo.dict.bleeding.count <= conf.manableedamount then
            svo.rmaff("bleeding")
          end
        end)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("bleeding")
      end,
    },
    onremoved = function()
      svo.dict.bleeding.count = 0
      if sk.smallbleedremove then
        killTimer(sk.smallbleedremove)
        sk.smallbleedremove = nil
      end
    end
  },
  touchtree = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        if not next(affs) or not bals.tree or svo.doingaction("touchtree") or affs.sleep or not conf.tree or affs.stun
         or affs.unconsciousness or affs.numbedrightarm or affs.numbedleftarm or affs.paralysis or affs.webbed
          or affs.bound or affs.transfixed or affs.roped or affs.impale or ((affs.crippledleftarm or affs.mangledleftarm
           or affs.mutilatedleftarm) and (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm))
            or codepaste.nonstdcure() then return false end

        for name, func in pairs(svo.tree) do
          if not me.disabledtreefunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function (aff)
        -- small heuristic - shivering can be upgraded to frozen
        if aff == "shivering" and not affs.shivering and affs.frozen then
          svo.rmaff("frozen")
        -- handle levels of burns

        elseif aff == "all burns" then
          codepaste.remove_burns()

        elseif aff == "burn" then
          local previousburn, currentburn = sk.previous_burn(), sk.current_burn()

          if not currentburn then
            codepaste.remove_burns()
          else
            svo.rmaff(currentburn)
            svo.addaffdict(svo.dict[previousburn])
          end

        elseif aff == "skullfractures" then
          -- two counts are cured if you're above 5
          local howmany = svo.dict.skullfractures.count
          codepaste.remove_stackableaff("skullfractures", true)
          if howmany > 5 then
            codepaste.remove_stackableaff("skullfractures", true)
          end

        elseif aff == "skullfractures cured" then
          svo.rmaff("skullfractures")
          svo.dict.skullfractures.count = 0

        elseif aff == "crackedribs" then
          -- two counts are cured if you're above 5
          local howmany = svo.dict.crackedribs.count
          codepaste.remove_stackableaff("crackedribs", true)
          if howmany > 5 then
            codepaste.remove_stackableaff("crackedribs", true)
          end

        elseif aff == "crackedribs cured" then
          svo.rmaff("crackedribs")
          svo.dict.crackedribs.count = 0

        elseif aff == "wristfractures" then
          -- two counts are cured if you're above 5
          local howmany = svo.dict.wristfractures.count
          codepaste.remove_stackableaff("wristfractures", true)
          if howmany > 5 then
            codepaste.remove_stackableaff("wristfractures", true)
          end

        elseif aff == "wristfractures cured" then
          svo.rmaff("wristfractures")
          svo.dict.wristfractures.count = 0

        elseif aff == "torntendons" then
          -- two counts are cured if you're above 5
          local howmany = svo.dict.torntendons.count
          codepaste.remove_stackableaff("torntendons", true)
          if howmany > 5 then
            codepaste.remove_stackableaff("torntendons", true)
          end

        elseif aff == "torntendons cured" then
          svo.rmaff("torntendons")
          svo.dict.torntendons.count = 0

        else
          svo.rmaff(aff)
        end

        svo.lostbal_tree()
      end,

      action = "touch tree",
      onstart = function ()
        send("touch tree", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_tree()
        empty.tree()
      end,

      offbal = function ()
        svo.lostbal_tree()
      end
    }
  },
  restore = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      uncurable = true,

      isadvisable = function ()
        if not next(affs) or not conf.restore or svo.usingbal("salve") or codepaste.balanceful_codepaste() or
          codepaste.nonstdcure() then return false end

        for name, func in pairs(svo.restore) do
          if not me.disabledrestorefunc[name] then
            local s,m = pcall(func[1])
            if s and m then svo.debugf("restore: %s strat went off", name) return true end
          end
        end
      end,

      oncompleted = function (number)
        if number then
          -- empty
          if number+1 == getLineNumber() then
            svo.dict.unknowncrippledlimb.count = 0
            svo.dict.unknowncrippledarm.count = 0
            svo.dict.unknowncrippledleg.count = 0
            svo.rmaff({"crippledleftarm", "crippledleftleg", "crippledrightarm", "crippledrightleg", "unknowncrippledarm", "unknowncrippledleg", "unknowncrippledlimb"})
          end
        end
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,

      action = "restore",
      onstart = function ()
        send("restore", conf.commandecho)
      end
    }
  },
  dragonheal = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      uncurable = true,

      isadvisable = function ()
        if not next(affs) or not defc.dragonform or not conf.dragonheal or not bals.dragonheal or codepaste.balanceful_codepaste() or codepaste.nonstdcure() or (affs.recklessness and affs.weakness) then return false end

        for name, func in pairs(svo.dragonheal) do
          if not me.disableddragonhealfunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function (number)
        if number then
          -- empty
          if number+1 == getLineNumber() then
            empty.dragonheal()
          end
        end

        svo.lostbal_dragonheal()
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,

      nobalance = function ()
        svo.lostbal_dragonheal()
      end,

      action = "dragonheal",
      onstart = function ()
        send("dragonheal", conf.commandecho)
      end
    }
  },
  defcheck = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (bals.balance and bals.equilibrium and me.manualdefcheck and not svo.doingaction("defcheck")) or false
      end,

      oncompleted = function ()
        me.manualdefcheck = false
        svo.process_defs()
      end,

      ontimeout = function ()
        me.manualdefcheck = false
      end,

      action = "def",
      onstart = function ()
        send("def", conf.commandecho)
      end
    },
  },
  diag = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return ((sys.manualdiag or (affs.unknownmental and affs.unknownmental.p.count >= conf.unknownfocus) or (affs.unknownany and affs.unknownany.p.count >= conf.unknownany)) and bals.balance and bals.equilibrium and not svo.doingaction("diag")) or false
      end,

      oncompleted = function ()
        sys.manualdiag = false
        sk.diag_list = {}
        svo.rmaff("unknownmental")
        svo.rmaff("unknownany")
        svo.dict.unknownmental.count = 0
        svo.dict.unknownany.count = 0
        svo.dict.bleeding.saw_haemophilia = nil
        svo.dict.relapsing.saw_with_checkable = nil

        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,

      actions = {"diag", "diagnose", "diag me", "diagnose me"},
      onstart = function ()
        send("diag", conf.commandecho)
      end
    },
  },
  block = {
    gamename = "blocking",
    physical = {
      blockingdir = "",
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        if defc.block and ((conf.keepup and not defkeepup[defs.mode].block and not sys.deffing) or (sys.deffing and not defdefup[defs.mode].block)) and not svo.doingaction"block" then return true end

        return (
          ((sys.deffing and defdefup[defs.mode].block) or (conf.keepup and defkeepup[defs.mode].block and not sys.deffing))
          and (not defc.block or svo.dict.block.physical.blockingdir ~= conf.blockingdir)
          and not svo.doingaction"block"
          and (not sys.enabledgmcp or (gmcp.Room and gmcp.Room.Info.exits[conf.blockingdir]))
          and not codepaste.balanceful_codepaste()
          and not affs.prone
          and (not svo.haveskillset('metamorphosis') or (defc.riding or defc.elephant or defc.dragonform or defc.hydra))
          and (not svo.haveskillset('subterfuge') or not defc.phase)
        ) or false
      end,

      oncompleted = function (dir)
        if dir then
          svo.dict.block.physical.blockingdir = sk.anytoshort(dir)
        else --workaround for looping
          svo.dict.block.physical.blockingdir = conf.blockingdir
        end
        defences.got("block")
      end,

      -- in case of failing to block, register that the action has been completed
      failed = function()
      end,

      onstart = function ()
        if (not defc.block or svo.dict.block.physical.blockingdir ~= conf.blockingdir) then
          send("block "..tostring(conf.blockingdir), conf.commandecho)
        else
          send("unblock", conf.commandecho)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        defences.lost("block")
        svo.dict.block.physical.blockingdir = ""

        if svo.actions.block_physical then
          svo.killaction(svo.dict.block.physical)
        end
      end
    }
  },
  doparry = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (not sys.sp_satisfied and not sys.blockparry and not affs.paralysis
          and not svo.doingaction"doparry" and ((svo.haveskillset('tekura') and conf.guarding) or conf.parry) and not codepaste.balanceful_codepaste()
          -- blademasters can parry with their sword sheathed, and monks don't need to wield anything
          and ((svo.haveskillset('tekura') or svo.me.class == "Blademaster") or ((not sys.enabledgmcp or defc.dragonform) or (next(me.wielded) and sk.have_parryable())))
          and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function (limb)
        local t = svo.sps.parry_currently
        for currentlimb, _ in pairs(t) do t[currentlimb] = false end
        t[limb] = true
        svo.check_sp_satisfied()
      end,

      onstart = function ()
        if svo.sps.something_to_parry() then
          for name, limb in pairs(svo.sp_config.parry_shouldbe) do
            if limb and limb ~= svo.sps.parry_currently[name] then
if not svo.haveskillset('tekura') then
              send(string.format("%sparry %s", (not defc.dragonform and "" or "claw"), name), conf.commandecho)
else
              send(string.format("%s %s", (not defc.dragonform and "guard" or "clawparry"), name), conf.commandecho)
end
              return
            end
          end
        elseif type(svo.sp_config.parry) == "string" and svo.sp_config.parry == "manual" then
          -- check if we need to unparry in manual
          for limb, status in pairs(svo.sps.parry_currently) do
            if status ~= svo.sp_config.parry_shouldbe[limb] then
if not svo.haveskillset('tekura') then
             send(string.format("%sparry nothing", (not defc.dragonform and "" or "claw")), conf.commandecho)
else
             send(string.format("%s nothing", (not defc.dragonform and "guard" or "clawparry")), conf.commandecho)
end
             return
            end
          end

          -- got here? nothing to do...
          svo.sys.sp_satisfied = true
        elseif svo.sp_config.priority[1] and not svo.sps.parry_currently[svo.sp_config.priority[1]] then
if not svo.haveskillset('tekura') then
          send(string.format("%sparry %s", (not defc.dragonform and "" or "claw"), svo.sp_config.priority[1]), conf.commandecho)
else
          send(string.format("%s %s", (not defc.dragonform and "guard" or "clawparry"), svo.sp_config.priority[1]), conf.commandecho)
end
        else -- got here? nothing to do...
          svo.sys.sp_satisfied = true end
      end,

      none = function ()
        for limb, _ in pairs(svo.sps.parry_currently) do
          svo.sps.parry_currently[limb] = false
        end

        svo.check_sp_satisfied()
      end
    }
  },
  doprecache = {
    misc = {
      aspriority = 0,
      spriority = 0,
      -- not a curable in-game affliction? mark it so priority doesn't get set
      uncurable = true,

      isadvisable = function ()
        return (rift.doprecache and not sys.blockoutr and not svo.findbybal"herb" and not svo.doingaction"doprecache" and sys.canoutr) or false
      end,

      oncompleted = function ()
        -- check if we still need to precache, and if not, clear rift.doprecache
        rift.checkprecache()

        if rift.doprecache then
          -- allow other outrs to catch up, then re-check again
          if sys.blockoutr then killTimer(sys.blockoutr); sys.blockoutr = nil end
          sys.blockoutr = tempTimer(sys.wait + svo.syncdelay(), function () sys.blockoutr = nil
            svo.debugf("sys.blockoutr expired") svo.make_gnomes_work()
            end)
          svo.debugf("sys.blockoutr setup: ", debug.traceback())
        end
      end,

      ontimeout = function ()
        rift.checkprecache()
      end,

      onstart = function ()
        for herb, _ in pairs(rift.precache) do
          if rift.precache[herb] ~= 0 and rift.riftcontents[herb] ~= 0 and (rift.invcontents[herb] < rift.precache[herb]) then
            send(string.format("outr %s%s", (affs.addiction and "" or (rift.precache[herb] - rift.invcontents[herb].." ")), herb), conf.commandecho)
            if sys.sync then return end
          end
        end
      end
    }
  },
  prone = {
    misc = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.prone and (not affs.paralysis or svo.doingaction"paralysis")
          and (svo.haveskillset('weaponmastery') and (sk.didfootingattack or (bals.balance and bals.equilibrium and bals.leftarm and bals.rightarm)) or (bals.balance and bals.equilibrium and bals.leftarm and bals.rightarm))
          and not svo.doingaction("prone") and not affs.sleep
          and not affs.impale
          and not affs.transfixed
          and not affs.webbed and not affs.bound and not affs.roped
          and not affs.crippledleftleg and not affs.crippledrightleg
          and not affs.mangledleftleg and not affs.mangledrightleg
          and not affs.mutilatedleftleg and not affs.mutilatedrightleg) or false
      end,

      oncompleted = function ()
        svo.rmaff("prone")
      end,

      onstart = function ()
if svo.haveskillset('weaponmastery') then
        if sk.didfootingattack and conf.recoverfooting then
          send("recover footing", conf.commandecho)
          if affs.blackout then send("recover footing", conf.commandecho) end
        else
          send("stand", conf.commandecho)
          if affs.blackout then send("stand", conf.commandecho) end
        end
else
        send("stand", conf.commandecho)
        if affs.blackout then send("stand", conf.commandecho) end
end
      end
    },
    aff = {
      oncompleted = function ()
        if not affs.prone then svo.addaffdict(svo.dict.prone) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("prone")
      end
    },
    onremoved = function () svo.donext() end,
    onadded = function()
      if affs.prone and affs.seriousconcussion then
        sk.warn "pulpable"
      end
    end
  },
  disrupt = {
    gamename = "disrupted",
    misc = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.disrupt and not svo.doingaction("disrupt")
          and not affs.confusion and not affs.sleep) or false
      end,

      oncompleted = function ()
        svo.rmaff("disrupt")
      end,

      oncured = function ()
        svo.rmaff("disrupt")
      end,

      action = "concentrate",
      onstart = function ()
        send("concentrate", conf.commandecho)
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.disrupt)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("disrupt")
      end
    }
  },
  lightpipes = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return ((not pipes.valerian.arty and not pipes.valerian.lit and pipes.valerian.puffs > 0 and not (pipes.valerian.id == 0)
          or (not pipes.elm.arty and not pipes.elm.lit and pipes.elm.puffs > 0 and not (pipes.elm.id == 0))
          or (not pipes.skullcap.arty and not pipes.skullcap.lit and pipes.skullcap.puffs > 0 and not (pipes.skullcap.id == 0))
          or (not pipes.elm.arty2 and not pipes.elm.lit2 and pipes.elm.puffs2 > 0 and not (pipes.elm.id2 == 0))
          or (not pipes.valerian.arty2 and not pipes.valerian.lit2 and pipes.valerian.puffs2 > 0 and not (pipes.valerian.id2 == 0))
          or (not pipes.skullcap.arty2 and not pipes.skullcap.lit2 and pipes.skullcap.puffs2 > 0 and not (pipes.skullcap.id2 == 0))
          )
        and (conf.relight or sk.forcelight_valerian or sk.forcelight_skullcap or sk.forcelight_elm)
        and not (svo.doingaction("lightskullcap") or svo.doingaction("lightelm") or svo.doingaction("lightvalerian") or svo.doingaction("lightpipes"))) or false
      end,

      oncompleted = function ()
        pipes.valerian.lit = true
        pipes.valerian.lit2 = true
        sk.forcelight_valerian = false
        pipes.elm.lit = true
        pipes.elm.lit2 = true
        sk.forcelight_elm = false
        pipes.skullcap.lit = true
        pipes.skullcap.lit2 = true
        sk.forcelight_skullcap = false

        svo.lastlit("valerian")
      end,

      actions = {"light pipes"},
      onstart = function ()
        if conf.gagrelight then
          send("light pipes", false)
        else
          send("light pipes", conf.commandecho) end
      end
    }
  },
  fillskullcap = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      herb = "skullcap",
      uncurable = true,
      fillingid = 0,

      mainpipeout = function()
        return (pipes.skullcap.puffs <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.skullcap.id == 0)
      end,

      secondarypipeout = function()
        return (pipes.skullcap.puffs2 <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.skullcap.id2 == 0)
      end,

      isadvisable = function ()
        return ((svo.dict.fillskullcap.physical.mainpipeout() or svo.dict.fillskullcap.physical.secondarypipeout()) and not svo.doingaction("fillskullcap") and not svo.doingaction("fillelm") and not svo.doingaction("fillvalerian") and not svo.will_take_balance() and not (affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm or affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm or affs.paralysis or affs.transfixed)) or false
      end,

      oncompleted = function ()
        if svo.dict.fillskullcap.fillingid == pipes.skullcap.id then
          pipes.skullcap.puffs = pipes.skullcap.maxpuffs or 10
          pipes.skullcap.lit = false
          rift.invcontents.skullcap = rift.invcontents.skullcap - 1
          if rift.invcontents.skullcap < 0 then rift.invcontents.skullcap = 0 end
        else
          pipes.skullcap.puffs2 = pipes.skullcap.maxpuffs2 or 10
          pipes.skullcap.lit2 = false
          rift.invcontents.skullcap = rift.invcontents.skullcap - 1
          if rift.invcontents.skullcap < 0 then rift.invcontents.skullcap = 0 end
        end
      end,

      onstart = function ()
        if svo.dict.fillskullcap.physical.mainpipeout() then
          svo.fillpipe("skullcap", pipes.skullcap.id)
          svo.dict.fillskullcap.fillingid = pipes.skullcap.id
        else
          svo.fillpipe("skullcap", pipes.skullcap.id2)
          svo.dict.fillskullcap.fillingid = pipes.skullcap.id2
        end
      end
    }
  },
  fillelm = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      herb = "elm",
      uncurable = true,
      fillingid = 0,

      mainpipeout = function()
        return (pipes.elm.puffs <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.elm.id == 0)
      end,

      secondarypipeout = function()
        return (pipes.elm.puffs2 <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.elm.id2 == 0)
      end,

      isadvisable = function ()
        return ((svo.dict.fillelm.physical.mainpipeout() or svo.dict.fillelm.physical.secondarypipeout()) and not svo.doingaction("fillskullcap") and not svo.doingaction("fillelm") and not svo.doingaction("fillvalerian") and not svo.will_take_balance()  and not (affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm or affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm or affs.paralysis or affs.transfixed)) or false
      end,

      oncompleted = function ()
        if svo.dict.fillelm.fillingid == pipes.elm.id then
          pipes.elm.puffs = pipes.elm.maxpuffs or 10
          pipes.elm.lit = false
          rift.invcontents.elm = rift.invcontents.elm - 1
          if rift.invcontents.elm < 0 then rift.invcontents.elm = 0 end
        else
          pipes.elm.puffs2 = pipes.elm.maxpuffs2 or 10
          pipes.elm.lit2 = false
          rift.invcontents.elm = rift.invcontents.elm - 1
          if rift.invcontents.elm < 0 then rift.invcontents.elm = 0 end
        end
      end,

      onstart = function ()
        if svo.dict.fillelm.physical.mainpipeout() then
          svo.fillpipe("elm", pipes.elm.id)
          svo.dict.fillelm.fillingid = pipes.elm.id
        else
          svo.fillpipe("elm", pipes.elm.id2)
          svo.dict.fillelm.fillingid = pipes.elm.id2
        end
      end
    }
  },
  fillvalerian = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      herb = "valerian",
      uncurable = true,
      fillingid = 0,

      mainpipeout = function()
        return (pipes.valerian.puffs <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.valerian.id == 0)
      end,

      secondarypipeout = function()
        return (pipes.valerian.puffs2 <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.valerian.id2 == 0)
      end,

      isadvisable = function ()
        if (svo.dict.fillvalerian.physical.mainpipeout() or svo.dict.fillvalerian.physical.secondarypipeout()) and not svo.doingaction("fillskullcap") and not svo.doingaction("fillelm") and not svo.doingaction("fillvalerian") and not svo.will_take_balance() then

          if (affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm or affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm or affs.paralysis or affs.transfixed) then
            sk.warn "emptyvalerianpipenorefill"
            return false
          else
            return true
          end
        end
      end,

      oncompleted = function ()
        if svo.dict.fillvalerian.fillingid == pipes.valerian.id then
          pipes.valerian.puffs = pipes.valerian.maxpuffs or 10
          pipes.valerian.lit = false
          rift.invcontents.valerian = rift.invcontents.valerian - 1
          if rift.invcontents.valerian < 0 then rift.invcontents.valerian = 0 end
        else
          pipes.valerian.puffs2 = pipes.valerian.maxpuffs2 or 10
          pipes.valerian.lit2 = false
          rift.invcontents.valerian = rift.invcontents.valerian - 1
          if rift.invcontents.valerian < 0 then rift.invcontents.valerian = 0 end
        end
      end,

      onstart = function ()
        if svo.dict.fillvalerian.physical.mainpipeout() then
          svo.fillpipe("valerian", pipes.valerian.id)
          svo.dict.fillvalerian.fillingid = pipes.valerian.id
        else
          svo.fillpipe("valerian", pipes.valerian.id2)
          svo.dict.fillvalerian.fillingid = pipes.valerian.id2
        end
      end
    }
  },
  rewield = {
    rewieldables = false,
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (conf.autorewield and svo.dict.rewield.rewieldables and not svo.doingaction"rewield" and not affs.impale and not affs.webbed and not affs.transfixed and not affs.roped and not affs.transfixed and sys.canoutr and not affs.mutilatedleftarm and not affs.mutilatedrightarm and not affs.mangledrightarm and not affs.mangledleftarm and not affs.crippledrightarm and not affs.crippledleftarm) or false
      end,

      oncompleted = function (id)
        if not svo.dict.rewield.rewieldables then return end

        for count, item in ipairs(svo.dict.rewield.rewieldables) do
          if item.id == id then
            table.remove(svo.dict.rewield.rewieldables, count)
            break
          end
        end

        if #svo.dict.rewield.rewieldables == 0 then
          svo.dict.rewield.rewieldables = false
        end
      end,

      failed = function ()
        svo.dict.rewield.rewieldables = false
      end,

      clear = function ()
        svo.dict.rewield.rewieldables = false
      end,

      onstart = function ()
        for _, t in pairs(svo.dict.rewield.rewieldables) do
          send("wield "..t.id, conf.commandecho)
          if sys.sync then return end
        end
      end
    }
  },
  blackout = {
    waitingfor = {
      customwait = 60,

      onstart = function ()
      end,

      oncompleted = function ()
        svo.rmaff("blackout")
      end,

      ontimeout = function ()
        svo.rmaff("blackout")
      end
    },
    aff = {
      oncompleted = function ()
        if affs.blackout then return end

        svo.addaffdict(svo.dict.blackout)
        svo.check_generics()

        tempTimer(4.5, function() if affs.blackout then svo.addaffdict(svo.dict.disrupt) svo.make_gnomes_work() end end)

        -- prevent leprosy in blackout
        if svo.enabledskills.necromancy then
          svo.echof("Fighting a Necromancer - going to assume crippled limbs every now and then.")
          tempTimer(3, function() if affs.blackout then svo.addaffdict(svo.dict.unknowncrippledlimb) svo.make_gnomes_work() end end)
          tempTimer(5, function() if affs.blackout then svo.addaffdict(svo.dict.unknowncrippledlimb) svo.make_gnomes_work() end end)
        end

        if svo.enabledskills.curses then
          svo.echof("Fighting a Shaman - going to check for asthma/anorexia.")
          tempTimer(3, function() if affs.blackout then svo.affsp.anorexia = true; svo.affsp.asthma = true; svo.make_gnomes_work() end end)
          tempTimer(5, function() if affs.blackout then svo.affsp.anorexia = true; svo.affsp.asthma = true; svo.make_gnomes_work() end end)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("blackout")
      end,
    },
    onremoved = function ()
      svo.check_generics()
      if sk.sylvan_eclipse then
        sys.manualdiag = true
      end

      if not affs.recklessness then
        svo.killaction(svo.dict.nomana.waitingfor)
      end

      if svo.dict.blackout.check_lust then
        svo.echof("Checking allies for potential lust...")
        send("allies", conf.commandecho)
        svo.dict.blackout.check_lust = nil
      end

      tempTimer(0.5, function()
        if not bals.equilibrium and not conf.serverside then svo.addaffdict(svo.dict.disrupt) end

        if stats.currenthealth == 0 and conf.assumestats ~= 0 then
          svo.reset.affs()
          svo.reset.general()
          svo.reset.defs()
          conf.paused = true
          echo"\n"svo.echof("We died.")
          raiseEvent("svo config changed", "paused")
        end
      end)

      -- if we came out with full health and mana out of blackout, assume we've got recklessness meanwhile. don't do it in serverside curing though, because that doesn't assume the same
      if (not svo.dict.blackout.addedon or svo.dict.blackout.addedon ~= os.time()) and stats.currenthealth == stats.maxhealth and stats.currentmana == stats.maxmana then
        svo.addaffdict(svo.dict.recklessness)
        svo.echof("suspicious full stats out of blackout - going to assume reckless.")
        if conf.serverside then
          svo.sendcuring("predict recklessness")
        end
      end
    end,
    onadded = function()
      svo.dict.blackout.addedon = os.time()
    end
  },
  unknownany = {
    count = 0,
    reckhp = false, reckmana = false,
    waitingfor = {
      customwait = 999,

      onstart = function ()
      end,

      empty = function ()
      end
    },
    aff = {
      oncompleted = function (number)

        if ((svo.dict.unknownany.reckhp and stats.currenthealth == stats.maxhealth) or
          (svo.dict.unknownany.reckmana and stats.currentmana == stats.maxmana)) then
            svo.addaffdict(svo.dict.recklessness)

            if conf.serverside then
              svo.sendcuring("predict recklessness")
            end

            if number and number > 1 then
              -- take one off because one affliction is recklessness
              codepaste.addunknownany(number-1)
            end
        else
          codepaste.addunknownany(number)
        end

        svo.dict.unknownany.reckhp = false; svo.dict.unknownany.reckmana = false
      end,

      wrack = function()
        -- if 3, then it was not hidden, ignore - affliction triggers will watch the aff
        if svo.paragraph_length >= 3 then return end

        if ((svo.dict.unknownany.reckhp and stats.currenthealth == stats.maxhealth) or
          (svo.dict.unknownany.reckmana and stats.currentmana == stats.maxmana)) then
            svo.addaffdict(svo.dict.recklessness)

            if conf.serverside then
              svo.sendcuring("predict recklessness")
            end
        else
          codepaste.addunknownany()
        end

        svo.dict.unknownany.reckhp = false; svo.dict.unknownany.reckmana = false
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("unknownany")
        svo.dict.unknownany.count = 0
      end,

      -- to be used when you lost one unknown (for example, you saw a symptom for something else)
      lost_level = function()
        if not affs.unknownany then return end
        affs.unknownany.p.count = affs.unknownany.p.count - 1
        if affs.unknownany.p.count <= 0 then
          svo.rmaff("unknownany")
          svo.dict.unknownany.count = 0
        else
          svo.updateaffcount(svo.dict.unknownany)
        end
      end
    }
  },
  unknownmental = {
    count = 0,
    reckhp = false, reckmana = false,
    focus = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affs.unknownmental) or false
      end,

      oncompleted = function ()
        -- special: gets called on each focus mind cure, but we most of
        -- the time don't have an unknown aff
        if not affs.unknownmental then return end
        affs.unknownmental.p.count = affs.unknownmental.p.count - 1
        if affs.unknownmental.p.count <= 0 then
          svo.rmaff("unknownmental")
          svo.dict.unknownmental.count = 0
        else
          svo.updateaffcount(svo.dict.unknownmental)
        end

        svo.lostbal_focus()
      end,

      onstart = function ()
        send("focus mind", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        svo.rmaff("unknownmental")
      end
    },
    aff = {
      oncompleted = function (number)
        if ((svo.dict.unknownmental.reckhp and stats.currenthealth == stats.maxhealth) or
          (svo.dict.unknownmental.reckmana and stats.currentmana == stats.maxmana)) then
            svo.addaffdict(svo.dict.recklessness)

            if conf.serverside then
              svo.sendcuring("predict recklessness")
            end

            if number and number > 1 then
              local count = svo.dict.unknownany.count
              svo.addaffdict(svo.dict.unknownany)
              -- take one off because one affliction is recklessness
              affs.unknownany.p.count = (count or 0) + (number - 1)
              svo.updateaffcount(svo.dict.unknownany)
            end
        else
          local count = svo.dict.unknownmental.count
          svo.addaffdict(svo.dict.unknownmental)

          svo.dict.unknownmental.count = (count or 0) + (number or 1)
          svo.updateaffcount(svo.dict.unknownmental)
        end

        svo.dict.unknownmental.reckhp = false; svo.dict.unknownmental.reckmana = false
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("unknownmental")
        svo.dict.unknownmental.count = 0
      end,

      -- to be used when you lost one focusable (for example, you saw a symptom for something else)
      lost_level = function()
        if not affs.unknownmental then return end
        affs.unknownmental.p.count = affs.unknownmental.p.count - 1
        if affs.unknownmental.p.count <= 0 then
          svo.rmaff("unknownmental")
          svo.dict.unknownmental.count = 0
        else
          svo.updateaffcount(svo.dict.unknownmental)
        end
      end
    }
  },
  unknowncrippledlimb = {
    count = 0,
    salve = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affs.unknowncrippledlimb and not (affs.mutilatedrightarm or affs.mutilatedleftarm or affs.mangledleftarm or affs.mangledrightarm or affs.parestoarms) and not (affs.mutilatedrightleg or affs.mutilatedleftleg or affs.mangledleftleg or affs.mangledrightleg or affs.parestolegs)) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("unknowncrippledlimb")
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending", "apply renewal"},
      onstart = function ()
        svo.apply(svo.dict.unknowncrippledlimb.salve)
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.apply_mending()
      end,

      fizzled = function ()
        svo.lostbal_salve()
        -- if it fizzled, then it means we've got a resto break on arms or legs
        -- applying resto without targetting a limb doesn't work, so try mending on both, see what happens
        svo.rmaff("unknowncrippledlimb")
        svo.addaffdict(svo.dict.unknowncrippledarm)
        svo.addaffdict(svo.dict.unknowncrippledleg)
        tempTimer(0, function() svo.show_info("some limb broken?", "It would seem an arm or a leg of yours is broken (the salve fizzled), not just crippled - going to work out which is it and fix it") end)
      end,
    },
    aff = {
      oncompleted = function (amount)
        svo.dict.unknowncrippledlimb.count = svo.dict.unknowncrippledlimb.count + (amount or 1)
        if svo.dict.unknowncrippledlimb.count > 4 then svo.dict.unknowncrippledlimb.count = 4 end
        svo.addaffdict(svo.dict.unknowncrippledlimb)
        svo.updateaffcount(svo.dict.unknowncrippledlimb)
      end
    },
    gone = {
      oncompleted = function ()
        svo.dict.unknowncrippledlimb.count = 0
        svo.rmaff("unknowncrippledlimb")
      end,
    },
    onremoved = function ()
      if svo.dict.unknowncrippledlimb.count <= 0 then return end

      svo.dict.unknowncrippledlimb.count = svo.dict.unknowncrippledlimb.count - 1
      if svo.dict.unknowncrippledlimb.count <= 0 then return end
      svo.addaffdict(svo.dict.unknowncrippledlimb)
      svo.updateaffcount(svo.dict.unknowncrippledlimb)
    end,
  },
  unknowncrippledarm = {
    count = 0,
    salve = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affs.unknowncrippledarm and not (affs.mutilatedrightarm or affs.mutilatedleftarm or affs.mangledleftarm or affs.mangledrightarm or affs.parestoarms)) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("unknowncrippledarm")
      end,

      actions = {"apply mending to arms", "apply mending", "apply renewal to arms", "apply renewal"},
      applycure = {"mending", "renewal"},
      onstart = function ()
        svo.apply(svo.dict.unknowncrippledarm.salve, " to arms")
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.noeffect_mending_arms()
      end,

      fizzled = function (limb)
        svo.lostbal_salve()
        if limb and svo.dict["mangled"..limb] then svo.addaffdict(svo.dict["mangled"..limb]) end
      end,
    },
    aff = {
      oncompleted = function (amount)
        svo.dict.unknowncrippledarm.count = svo.dict.unknowncrippledarm.count + (amount or 1)
        if svo.dict.unknowncrippledarm.count > 2 then svo.dict.unknowncrippledarm.count = 2 end
        svo.addaffdict(svo.dict.unknowncrippledarm)
        svo.updateaffcount(svo.dict.unknowncrippledarm)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.dict.unknowncrippledarm.count = 0
        svo.rmaff("unknowncrippledarm")
      end,
    },
    onremoved = function ()
      if svo.dict.unknowncrippledarm.count <= 0 then return end

      svo.dict.unknowncrippledarm.count = svo.dict.unknowncrippledarm.count - 1
      if svo.dict.unknowncrippledarm.count <= 0 then return end
      svo.addaffdict(svo.dict.unknowncrippledarm)
      svo.updateaffcount(svo.dict.unknowncrippledarm)
    end,
  },
  unknowncrippledleg = {
    count = 0,
    salve = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affs.unknowncrippledleg and not (affs.mutilatedrightleg or affs.mutilatedleftleg or affs.mangledleftleg or affs.mangledrightleg or affs.parestolegs)) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        svo.rmaff("unknowncrippledleg")
      end,

      actions = {"apply mending to legs", "apply mending", "apply renewal to legs", "apply renewal"},
      applycure = {"mending", "renewal"},
      onstart = function ()
        svo.apply(svo.dict.unknowncrippledleg.salve, " to legs")
      end,

      noeffect = function ()
        svo.lostbal_salve()
        empty.noeffect_mending_legs()
      end,

      fizzled = function (limb)
        svo.lostbal_salve()
        if limb and svo.dict["mangled"..limb] then svo.addaffdict(svo.dict["mangled"..limb]) end
      end,
    },
    aff = {
      oncompleted = function (amount)
        svo.dict.unknowncrippledleg.count = svo.dict.unknowncrippledleg.count + (amount or 1)
        if svo.dict.unknowncrippledleg.count > 2 then svo.dict.unknowncrippledleg.count = 2 end
        svo.addaffdict(svo.dict.unknowncrippledleg)
        svo.updateaffcount(svo.dict.unknowncrippledleg)
      end
    },
    gone = {
      oncompleted = function ()
        svo.dict.unknowncrippledleg.count = 0
        svo.rmaff("unknowncrippledleg")
      end,
    },
    onremoved = function ()
      if svo.dict.unknowncrippledleg.count <= 0 then return end

      svo.dict.unknowncrippledleg.count = svo.dict.unknowncrippledleg.count - 1
      if svo.dict.unknowncrippledleg.count <= 0 then return end
      svo.addaffdict(svo.dict.unknowncrippledleg)
      svo.updateaffcount(svo.dict.unknowncrippledleg)
    end,
  },
  unknowncure = {
    count = 0,
    waitingfor = {
      customwait = 999,

      onstart = function ()
      end,

      empty = function ()
      end
    },
    aff = {
      oncompleted = function (number)
        local count = svo.dict.unknowncure.count
        svo.addaffdict(svo.dict.unknowncure)

        svo.dict.unknowncure.count = (count or 0) + (number or 1)
        svo.updateaffcount(svo.dict.unknowncure)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("unknowncure")
        svo.dict.unknowncure.count = 0
      end
    }
  },


-- writhes
  bound = {
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,

      isadvisable = function ()
        return (affs.bound and codepaste.writhe()) or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.curingbound.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        send("writhe", conf.commandecho)
      end,

      helpless = function ()
        empty.writhe()
      end,

      impale = function ()
        svo.doaction(svo.dict.curingimpale.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.bound)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("bound")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingbound = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("bound")
      end,

      onstart = function ()
      end
    }
  },
  webbed = {
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,

      isadvisable = function ()
        return (affs.webbed and codepaste.writhe() and not (bals.balance and bals.rightarm and bals.leftarm and svo.dict.dragonflex.misc.isadvisable()) and (not svo.haveskillset('voicecraft') or (not conf.dwinnu or not svo.dict.dwinnu.misc.isadvisable()))) or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.curingwebbed.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        if math.random(1, 30) == 1 then
          send("writhe wiggle wiggle", conf.commandecho)
        else
          send("writhe", conf.commandecho)
        end
      end,

      helpless = function ()
        empty.writhe()
      end,

      impale = function ()
        svo.doaction(svo.dict.curingimpale.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        affs.webbed = nil
        svo.addaffdict(svo.dict.webbed)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("webbed")
      end,
    },
    onremoved = function () signals.canoutr:emit() svo.donext() end
  },
  curingwebbed = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("webbed")
      end,

      onstart = function ()
      end
    }
  },
  roped = {
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,

      isadvisable = function ()
        return (affs.roped and codepaste.writhe() and not (bals.balance and bals.rightarm and bals.leftarm and svo.dict.dragonflex.misc.isadvisable()) and (not svo.haveskillset('voicecraft') or (not conf.dwinnu or not svo.dict.dwinnu.misc.isadvisable()))) or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.curingroped.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        send("writhe", conf.commandecho)
      end,

      helpless = function ()
        empty.writhe()
      end,

      impale = function ()
        svo.doaction(svo.dict.curingimpale.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.roped)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("roped")
      end,
    },
    onremoved = function () signals.canoutr:emit() svo.donext() end
  },
  curingroped = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("roped")
      end,

      onstart = function ()
      end
    }
  },
  hoisted = {
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,
      uncurable = true,

      isadvisable = function ()
        return (affs.hoisted and codepaste.writhe() and bals.balance and bals.rightarm and bals.leftarm) or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.curinghoisted.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        send("writhe", conf.commandecho)
      end,

      helpless = function ()
        empty.writhe()
      end,

      impale = function ()
        svo.doaction(svo.dict.curingimpale.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.hoisted)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("hoisted")
      end,
    }
  },
  curinghoisted = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("hoisted")
      end,

      onstart = function ()
      end
    }
  },
  transfixed = {
    gamename = "transfixation",
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,

      isadvisable = function ()
        return (affs.transfixed and codepaste.writhe()) or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.curingtransfixed.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        send("writhe", conf.commandecho)
      end,

      helpless = function ()
        empty.writhe()
      end,

      impale = function ()
        svo.doaction(svo.dict.curingimpale.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        if not conf.aillusion or ((not affs.blindaff and not defc.blind) or svo.lifevision.l.blindaff_aff or svo.lifevision.l.blind_herb or svo.lifevision.l.blind_misc) then
          svo.affsp.transfixed = nil
          svo.addaffdict(svo.dict.transfixed)
        end

        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("transfixed")
      end,
    },
    onremoved = function () signals.canoutr:emit() svo.donext() end
  },
  curingtransfixed = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("transfixed")
      end,

      onstart = function ()
      end
    }
  },
  impale = {
    gamename = "impaled",
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,


      isadvisable = function ()
        return (affs.impale and not svo.doingaction("curingimpale") and not svo.doingaction("impale") and bals.balance and bals.rightarm and bals.leftarm) or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.curingimpale.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        send("writhe", conf.commandecho)
      end,

      helpless = function ()
        empty.writhe()
      end,

      dragged = function()
        svo.rmaff("impale")
      end,
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.impale)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("impale")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingimpale = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        svo.rmaff("impale")
      end,

      withdrew = function ()
        svo.rmaff("impale")
      end,

      dragged = function()
        svo.rmaff("impale")
      end,

      onstart = function ()
      end
    }
  },
  dragonflex = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (conf.dragonflex and ((affs.webbed and not svo.ignore.webbed) or (affs.roped and not svo.ignore.roped)) and codepaste.writhe() and not affs.paralysis and defc.dragonform and bals.balance and not svo.doingaction"impale") or false
      end,

      oncompleted = function ()
        svo.rmaff{"webbed", "roped"}
      end,

      action = "dragonflex",
      onstart = function ()
        send("dragonflex", conf.commandecho)
      end
    },
  },

  -- anti-illusion checks, grouped by symptom similarity
  checkslows = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (next(svo.affsp) and (svo.affsp.retardation or svo.affsp.aeon or svo.affsp.truename)) or false
      end,

      oncompleted = function () end,

      sluggish = function ()
        if svo.affsp.retardation then
          svo.affsp.retardation = nil
          svo.addaffdict(svo.dict.retardation)
          signals.newroom:unblock(sk.check_retardation)
        elseif svo.affsp.aeon then
          svo.affsp.aeon = nil

          svo.addaffdict(svo.dict.aeon)
          defences.lost("speed")
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        elseif svo.affsp.truename then
          svo.affsp.truename = nil

          svo.addaffdict(svo.dict.aeon)
          defences.lost("speed")
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        end

        sk.checkaeony()
        signals.aeony:emit()
        codepaste.badaeon()
      end,

      onclear = function ()
        if svo.affsp.retardation then
          svo.affsp.retardation = nil
        elseif svo.affsp.aeon then
          svo.affsp.aeon = nil
        elseif svo.affsp.truename then
          svo.affsp.truename = nil
        end
      end,

      onstart = function ()
        send("say", false)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function (which)
      if svo.paragraph_length > 2 or svo.ignore.checkslows then
          if which == "truename" then which = "aeon" end

          svo.addaffdict(svo.dict[which])
          svo.killaction(svo.dict.checkslows.misc)

          if which == "aeon" then defences.lost("speed") end
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)

          sk.checkaeony()
          signals.aeony:emit()
          codepaste.badaeon()

          if which == 'retardation' then
            signals.newroom:unblock(sk.check_retardation)
          end
        else
          svo.affsp[which] = true
        end
      end,

      truename = function()
        svo.affsp.truename = true
      end,
    },
  },

  checkanorexia = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (svo.affsp.anorexia) or false
      end,

      oncompleted = function () end,

      blehfood = function ()
        svo.addaffdict(svo.dict.anorexia)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        svo.affsp.anorexia = nil
      end,

      onclear = function ()
        svo.affsp.anorexia = nil
      end,

      onstart = function ()
        send("eat something", false)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function ()
        if svo.paragraph_length > 2 then
          svo.addaffdict(svo.dict.anorexia)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          svo.killaction(svo.dict.checkanorexia.misc)
        else
          svo.affsp.anorexia = true
        end

        -- register it as a possible hypochondria symptom
        if svo.paragraph_length == 1 then
          sk.hypochondria_symptom()
        end
      end
    },
  },

  checkparalysis = {
    description = "anti-illusion check for paralysis",
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return false -- hardcoded to be off, as there's no known solution currently that works
        --return (svo.affsp.paralysis and not affs.sleep and (not conf.waitparalysisai or (bals.balance and bals.equilibrium)) and not affs.roped) or false
      end,

      oncompleted = function () end,

      paralysed = function ()
        svo.addaffdict(svo.dict.paralysis)

        if svo.dict.relapsing.saw_with_checkable == "paralysis" then
          svo.dict.relapsing.saw_with_checkable = nil
          svo.addaffdict(svo.dict.relapsing)
        end

        if type(svo.affsp.paralysis) == "string" then
          svo.addaffdict(svo.dict[svo.affsp.paralysis])
        end
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        svo.affsp.paralysis = nil
      end,

      onclear = function ()
        svo.affsp.paralysis = nil
      end,

      onstart = function ()
        send("fling paralysis", false)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function (withaff) -- ie, "darkshade" - add the additional aff if we have paralysis
        -- disabled, as fling no longer works and illusions are not so prevalent
        if true then
        -- if svo.paragraph_length > 2 or (not (bals.balance and bals.equilibrium) and not conf.waitparalysisai) then -- if it's not an illusion for sure, or if we have waitparalysisai off and don't have both balance/eq, accept it as paralysis right now
          svo.addaffdict(svo.dict.paralysis)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          svo.killaction(svo.dict.checkparalysis.misc)
          if withaff then svo.addaffdict(svo.dict[withaff]) end
        -- else -- else, it gets added to be checked later if we have waitparalysisai on and don't have balance or eq
        --   svo.affsp.paralysis = withaff or true
        end
      end
    },
  },

  checkimpatience = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (svo.affsp.impatience and not affs.sleep and bals.focus and conf.focus) or false
      end,

      oncompleted = function () end,

      impatient = function ()
        if not affs.impatience then
          svo.addaffdict(svo.dict.impatience)
          svo.echof("Looks like the impatience is real.")
        end

        svo.affsp.impatience = nil
      end,

      -- if serverside cures impatience before we can even validate it, cancel it
      oncancel = function ()
        svo.affsp.impatience = nil
        svo.killaction(svo.dict.checkimpatience.misc)
      end,

      onclear = function ()
        if svo.affsp.impatience then
          svo.lostbal_focus()
          if svo.affsp.impatience ~= "quiet" then
            svo.echof("The impatience earlier was actually an illusion, ignoring it.")
          end
          svo.affsp.impatience = nil
        end
      end,

      onstart = function ()
        send("focus", false)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function (option)
        if svo.paragraph_length > 2 then
          svo.addaffdict(svo.dict.impatience)
          svo.killaction(svo.dict.checkimpatience.misc)
        else
          svo.affsp.impatience = option and option or true
        end
      end
    },
  },

  checkasthma = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (svo.affsp.asthma and conf.breath and bals.balance and bals.equilibrium) or false
      end,

      oncompleted = function () end,

      weakbreath = function ()
        svo.addaffdict(svo.dict.asthma)
        local r = svo.findbybal("smoke")
        if r then
          svo.killaction(svo.dict[r.action_name].smoke)
        end

        if svo.dict.relapsing.saw_with_checkable == "asthma" then
          svo.dict.relapsing.saw_with_checkable = nil
          svo.addaffdict(svo.dict.relapsing)
        end

        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        svo.affsp.asthma = nil
        codepaste.badaeon()
      end,

      onclear = function ()
        svo.affsp.asthma = nil
      end,

      onstart = function ()
        send("hold breath", conf.commandecho)
      end
    },
    smoke = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (svo.affsp.asthma and not svo.dict.checkasthma.misc.isadvisable() and codepaste.smoke_valerian_pipe()) or false
      end,

      oncompleted = function ()
        svo.lostbal_smoke()
      end,

      badlungs = function ()
        svo.addaffdict(svo.dict.asthma)
        local r = svo.findbybal("smoke")
        if r then
          svo.killaction(svo.dict[r.action_name].smoke)
        end

        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        svo.affsp.asthma = nil
      end,

      -- mucous can hit when we aren't even afflicted, so it's moot. Have to wait for it to clear up
      mucous = function()
      end,

      onclear = function ()
        svo.affsp.asthma = nil
        svo.lostbal_smoke()
      end,

      empty = function()
        svo.affsp.asthma = nil
        svo.lostbal_smoke()
      end,

      smokecure = {"valerian", "realgar"},
      onstart = function ()
        send("smoke " .. pipes.valerian.id, conf.commandecho)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function (oldhp)
      if svo.paragraph_length > 2 or (oldhp and stats.currenthealth < oldhp) or (svo.paragraph_length == 2 and svo.find_until_last_paragraph("aura of weapons rebounding disappears", "substring")) then
          svo.addaffdict(svo.dict.asthma)
          local r = svo.findbybal("smoke")
          if r then
            svo.killaction(svo.dict[r.action_name].smoke)
          end

          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          svo.killaction(svo.dict.checkasthma.misc)

          -- if we were checking and we got a verified aff, kill verification
          if svo.actions.checkasthma_smoke then
            svo.killaction(svo.dict.checkasthma.smoke)
          end
        else
          svo.affsp.asthma = true
        end
      end
    },
  },

  checkhypersomnia = {
    description = "anti-illusion check for hypersomnia",
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (svo.affsp.hypersomnia and not affs.sleep) or false
      end,

      oncompleted = function () end,

      hypersomnia = function ()
        svo.addaffdict(svo.dict.hypersomnia)

        svo.affsp.hypersomnia = nil
      end,

      onclear = function ()
        svo.affsp.hypersomnia = nil
      end,

      onstart = function ()
        send("insomnia", conf.commandecho)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function ()
        -- can't check hypersomnia with insomina up - it'll give the insomnia
        -- def line
        if svo.paragraph_length > 2 or defc.insomnia then
          svo.addaffdict(svo.dict.hypersomnia)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          svo.killaction(svo.dict.checkhypersomnia.misc)
        else
          svo.affsp.hypersomnia = true
        end
      end
    },
  },

  checkstun = {
    templifevision = false, -- stores the lifevision actions that will be wiped until confirmed
    tempactions = false, -- stores the actions queue items that will be wiped until confirmed
    time = 0,
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (svo.affsp.stun) or false
      end,

      oncompleted = function (data)
        -- 'fromstun' is given to us if we just had started checking for stun with checkstun_misc, and stun wore off before we could finish - for this rare scenario, we complete checkstun
        if data ~= "fromstun" then svo.dict.stun.aff.oncompleted(svo.dict.checkstun.time) end
        svo.dict.checkstun.time = 0
        svo.affsp.stun = nil
        tempTimer(0, function ()
          if not svo.dict.checkstun.templifevision then return end

          svo.lifevision.l = deepcopy(svo.dict.checkstun.templifevision)
          svo.dict.checkstun.templifevision = nil

          if svo.lifevision.l.checkstun_aff then
            svo.lifevision.l:set("checkstun_aff", nil)
          end

          for k,v in svo.dict.checkstun.tempactions:iter() do
            if svo.actions[k] then
              svo.debugf("%s already exists, overwriting it", k)
            else
              svo.debugf("re-added %s", k)
            end

            svo.actions[k] = v
          end

          svo.dict.checkstun.tempactions = nil
          svo.send_in_the_gnomes()
        end)
      end,

      onclear = function ()
        svo.affsp.stun = nil
        svo.dict.checkstun.templifevision = nil
        svo.dict.checkstun.tempactions = nil
      end,

      onstart = function ()
        send("eat something", false)
      end
    },
    aff = {
      -- this is an affliction for svo's purposes, but not in the game. Although it would be best if the 'aff' balance was replaced with something else
      notagameaff = true,
      oncompleted = function (num)
      if svo.paragraph_length > 2 then
          svo.dict.stun.aff.oncompleted()
          svo.killaction(svo.dict.checkstun.misc)
        elseif not affs.sleep and not conf.paused then -- let autodetection take care of after we wake up. otherwise, a well timed stun & stun symptom on awake can trick us. if paused, let it through as well, because we don't want to kill affs
          svo.affsp.stun = true
          svo.dict.checkstun.time = num
          svo.dict.checkstun.templifevision = deepcopy(svo.lifevision.l)
          svo.dict.checkstun.tempactions = deepcopy(svo.actions)
          sk.stopprocessing = true
        end
      end
    },
  },

  checkwrithes = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (next(svo.affsp) and ((svo.affsp.impale and not affs.transfixed and not affs.webbed and not affs.roped) or (svo.affsp.webbed and not affs.transfixed and not affs.roped) or svo.affsp.transfixed)) or false
      end,

      oncompleted = function () end,

      webbily = function ()
        svo.affsp.webbed = nil
        svo.addaffdict(svo.dict.webbed)
        signals.canoutr:emit()
      end,

      impaly = function ()
        svo.affsp.impale = nil
        svo.addaffdict(svo.dict.impale)
        signals.canoutr:emit()
      end,

      transfixily = function ()
        svo.affsp.transfixed = nil
        svo.addaffdict(svo.dict.transfixed)
        signals.canoutr:emit()
      end,

      onclear = function ()
        svo.affsp.impale = nil
        svo.affsp.webbed = nil
        svo.affsp.transfixed = nil
      end,

      onstart = function ()
        send("outr", false)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function (which)
        if svo.paragraph_length > 2 then
          svo.addaffdict(svo.dict[which])
          svo.killaction(svo.dict.checkwrithes.misc)
        else
          svo.affsp[which] = true
        end
      end,

      impale = function (oldhp)
        if (oldhp and stats.currenthealth < oldhp) then
          svo.addaffdict(svo.dict.impale)
          signals.canoutr:emit()
        else
          svo.affsp.impale = true
        end
      end
    }
  },
  amnesia = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affs.amnesia) or false
      end,

      oncompleted = function ()
      end,

      onstart = function ()
        send("touch stuff", conf.commandecho)
        svo.rmaff("amnesia")
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.amnesia)

        -- cancel what we were doing, do it again
        if sys.sync then
          local result
          for balance,actions in pairs(svo.bals_in_use) do
            if balance ~= "waitingfor" and balance ~= "gone" and balance ~= "aff" and next(actions) then result = select(2, next(actions)) break end
          end
          if result then
            svo.killaction(svo.dict[result.action_name][result.balance])
          end

          svo.conf.send_bypass = true
          send("touch stuff", conf.commandecho)
          svo.conf.send_bypass = false
        end
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("amnesia")
      end,
    }
  },

  -- uncurable
  stun = {
    waitingfor = {
      customwait = 1,

      isadvisable = function ()
        return false
      end,

      ontimeout = function ()
        svo.rmaff("stun")

        if svo.dict.checkstun.templifevision then
          svo.debugf("stun timed out = restoring checkstun lifevisions")
          svo.dict.checkstun.misc.oncompleted("fromstun")
          svo.make_gnomes_work()
        end

      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("stun")

        if svo.dict.checkstun.templifevision then
          svo.debugf("stun finished = restoring checkstun lifevisions")
          svo.dict.checkstun.misc.oncompleted("fromstun")
        end
      end
    },
    aff = {
      oncompleted = function (num)
        if affs.stun then return end

        svo.dict.stun.waitingfor.customwait = (num and num ~= 0) and num or 1
        svo.addaffdict(svo.dict.stun)
        svo.doaction(svo.dict.stun.waitingfor)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("stun")
        svo.killaction(svo.dict.stun.waitingfor)
      end,
    },
    onremoved = function () svo.donext() end
  },
  unconsciousness = {
    waitingfor = {
      customwait = 7,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        svo.rmaff("unconsciousness")
        svo.make_gnomes_work()
      end,

      oncompleted = function ()
        svo.rmaff("unconsciousness")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.unconsciousness)
        if not svo.actions.unconsciousness_waitingfor then svo.doaction(svo.dict.unconsciousness.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("unconsciousness")
        svo.killaction(svo.dict.unconsciousness.waitingfor)
      end,
    },
    onremoved = function () svo.donext() end
  },
  swellskin = { -- eating any herb cures it
    waitingfor = {
      customwait = 999,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("swellskin")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.swellskin)
        if not svo.actions.swellskin_waitingfor then svo.doaction(svo.dict.swellskin.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("swellskin")
        svo.killaction(svo.dict.swellskin.waitingfor)
      end,
    }
  },
  pinshot = {
    waitingfor = {
      customwait = 20, -- lasts 18s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        svo.rmaff("pinshot")
        svo.make_gnomes_work()
      end,

      oncompleted = function ()
        svo.rmaff("pinshot")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.pinshot)
        if not svo.actions.pinshot_waitingfor then svo.doaction(svo.dict.pinshot.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("pinshot")
        svo.killaction(svo.dict.pinshot.waitingfor)
      end,
    }
  },
  dehydrated = {
    waitingfor = {
      customwait = 45, -- lasts 45s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        svo.rmaff("dehydrated")
        svo.make_gnomes_work()
      end,

      oncompleted = function ()
        svo.rmaff("dehydrated")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.dehydrated)
        if not svo.actions.dehydrated_waitingfor then svo.doaction(svo.dict.dehydrated.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("dehydrated")
        svo.killaction(svo.dict.dehydrated.waitingfor)
      end,
    }
  },
  timeflux = {
    waitingfor = {
      customwait = 50, -- lasts 50s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        svo.rmaff("timeflux")
        svo.make_gnomes_work()
      end,

      oncompleted = function ()
        svo.rmaff("timeflux")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.timeflux)
        if not svo.actions.timeflux_waitingfor then svo.doaction(svo.dict.timeflux.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("timeflux")
        svo.killaction(svo.dict.timeflux.waitingfor)
      end,
    }
  },
  inquisition = {
    waitingfor = {
      customwait = 30, -- ??

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("inquisition")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.inquisition)
        if not svo.actions.inquisition_waitingfor then svo.doaction(svo.dict.inquisition.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("inquisition")
        svo.killaction(svo.dict.inquisition.waitingfor)
      end,
    }
  },
  lullaby = {
    waitingfor = {
      customwait = 45, -- takes 45s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("lullaby")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.lullaby)
        if not svo.actions.lullaby_waitingfor then svo.doaction(svo.dict.lullaby.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("lullaby")
        svo.killaction(svo.dict.lullaby.waitingfor)
      end,
    }
  },
  corrupted = {
    waitingfor = {
      customwait = 999, -- time increases

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("corrupted")
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.corrupted)
        if not svo.actions.corrupted_waitingfor then svo.doaction(svo.dict.corrupted.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("corrupted")
        svo.killaction(svo.dict.corrupted.waitingfor)
      end,
    }
  },
  mucous = {
    waitingfor = {
      customwait = 6,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("mucous")
      end,

      ontimeout = function()
        svo.rmaff("mucous")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.mucous)
        if not svo.actions.mucous_waitingfor then svo.doaction(svo.dict.mucous.waitingfor) end

        local r = svo.findbybal("smoke")
        if r then
          svo.killaction(svo.dict[r.action_name].smoke)
        end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("mucous")
        svo.killaction(svo.dict.mucous.waitingfor)
      end,
    }
  },
  phlogistication = {
    waitingfor = {
      customwait = 999, -- time increases

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("phlogistication")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.phlogistication)
        if not svo.actions.phlogistication_waitingfor then svo.doaction(svo.dict.phlogistication.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("phlogistication")
        svo.killaction(svo.dict.phlogistication.waitingfor)
      end,
    }
  },
  vitrification = {
    waitingfor = {
      customwait = 999,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("vitrification")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.vitrification)
        if not svo.actions.vitrification_waitingfor then svo.doaction(svo.dict.vitrification.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("vitrification")
        svo.killaction(svo.dict.vitrification.waitingfor)
      end,
    }
  },

  icing = {
    waitingfor = {
      customwait = 30, -- ??

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("icing")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.icing)
        if not svo.actions.icing_waitingfor then svo.doaction(svo.dict.icing.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("icing")
        svo.killaction(svo.dict.icing.waitingfor)
      end,
    }
  },
  burning = {
    waitingfor = {
      customwait = 30, -- ??

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("burning")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.burning)
        if not svo.actions.burning_waitingfor then svo.doaction(svo.dict.burning.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("burning")
        svo.killaction(svo.dict.burning.waitingfor)
      end,
    }
  },
  voided = {
    waitingfor = {
      customwait = 20, -- lasts 20s tops, 15s in some stances. out-times multiple pommelstrikes

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("voided")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.voided)
        codepaste.badaeon()
        if not svo.actions.voided_waitingfor then svo.doaction(svo.dict.voided.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("voided")
        svo.killaction(svo.dict.voided.waitingfor)
      end,
    }
  },
  hamstring = {
    waitingfor = {
      customwait = 10,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        if affs.hamstring then
          svo.rmaff("hamstring")
          svo.echof("Hamstring should have worn off by now, removing it.")
        end
      end,

      oncompleted = function ()
        svo.rmaff("hamstring")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.hamstring)
        if not svo.actions.hamstring_waitingfor then svo.doaction(svo.dict.hamstring.waitingfor) end
      end,

      renew = function ()
        svo.addaffdict(svo.dict.hamstring)

        -- hamstrings timer gets renewed on hit
        if svo.actions.hamstring_waitingfor then
          svo.killaction(svo.dict.hamstring.waitingfor)
        end
        svo.doaction(svo.dict.hamstring.waitingfor)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("hamstring")
        svo.killaction(svo.dict.hamstring.waitingfor)
      end,
    }
  },
  galed = {
    waitingfor = {
      customwait = 10,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("galed")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.galed)
        if not svo.actions.galed_waitingfor then svo.doaction(svo.dict.galed.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("galed")
        svo.killaction(svo.dict.galed.waitingfor)
      end,
    }
  },
  rixil = {
    -- will double the cooldown period of the next focus ability.
    waitingfor = {
      customwait = 999,

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("rixil")
        svo.killaction(svo.dict.rixil.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.rixil)
        if svo.actions.rixil_waitingfor then svo.killaction(svo.dict.rixil.waitingfor) end
        svo.doaction(svo.dict.rixil.waitingfor)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("rixil")
        svo.killaction(svo.dict.rixil.waitingfor)
      end,
    }
  },
  hecate = {
    waitingfor = {
      customwait = 22, -- seems to last at least 18s per log

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
        svo.rmaff("hecate")
        svo.killaction(svo.dict.hecate.waitingfor)
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("hecate")
        svo.killaction(svo.dict.hecate.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.hecate)
        if svo.actions.hecate_waitingfor then svo.killaction(svo.dict.hecate.waitingfor) end
        svo.doaction(svo.dict.hecate.waitingfor)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("hecate")
        svo.killaction(svo.dict.hecate.waitingfor)
      end,
    }
  },
  palpatar = {
    waitingfor = {
      customwait = 999,

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("palpatar")
        svo.killaction(svo.dict.palpatar.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.palpatar)
        if svo.actions.palpatar_waitingfor then svo.killaction(svo.dict.palpatar.waitingfor) end
        svo.doaction(svo.dict.palpatar.waitingfor)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("palpatar")
        svo.killaction(svo.dict.palpatar.waitingfor)
      end,
    }
  },
  -- extends tree balance by 10s now
  ninkharsag = {
    waitingfor = {
      customwait = 60, -- it lasts a minute

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
        svo.rmaff("ninkharsag")
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("ninkharsag")
        svo.killaction(svo.dict.ninkharsag.waitingfor)
      end,

    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.ninkharsag)
        if svo.actions.ninkharsag_waitingfor then svo.killaction(svo.dict.ninkharsag.waitingfor) end
        svo.doaction(svo.dict.ninkharsag.waitingfor)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("ninkharsag")
        svo.killaction(svo.dict.ninkharsag.waitingfor)
      end,

      -- anti-illusion-checked aff hiding. in 'gone' because 'aff' resets the timer with checkaction, waitingfor has some other effect
      hiddencures = function (amount)
        local curableaffs = svo.gettreeableaffs()

        -- if we saw more ninkharsag lines than affs we've got, we can remove the affs safely
        if amount >= #curableaffs then
          svo.rmaff(curableaffs)
        else
          -- otherwise add an unknown aff - so we eventually diagnose to see what is our actual aff status like.
          -- this does mess with the aff counts, but it is better than not diagnosing ever.
          codepaste.addunknownany()
        end
      end
    }
  },
  cadmus = {
    -- focusing will give one of: lethargy, clumsiness, haemophilia, healthleech, sensitivity, darkshade
    waitingfor = {
      customwait = 999,

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("cadmus")
        svo.killaction(svo.dict.cadmus.waitingfor)
      end
    },
    aff = {
      -- oldmaxhp is an argument
      oncompleted = function (_)
        svo.addaffdict(svo.dict.cadmus)
        if svo.actions.cadmus_waitingfor then svo.killaction(svo.dict.cadmus.waitingfor) end
        svo.doaction(svo.dict.cadmus.waitingfor)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("cadmus")
        svo.killaction(svo.dict.cadmus.waitingfor)
      end,
    }
  },
  spiritdisrupt = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.spiritdisrupt and not affs.madness and
          not svo.doingaction("spiritdisrupt")) or false
      end,

      oncompleted = function ()
        svo.rmaff("spiritdisrupt")
        svo.lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        svo.eat(svo.dict.spiritdisrupt.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.spiritdisrupt)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("spiritdisrupt")
        codepaste.remove_focusable()
      end,
    }
  },
  airdisrupt = {
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.airdisrupt and not affs.spiritdisrupt) or false
      end,

      oncompleted = function ()
        svo.rmaff("airdisrupt")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.airdisrupt and not svo.doingaction("airdisrupt")) or false
      end,

      oncompleted = function ()
        svo.rmaff("airdisrupt")
        svo.lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        svo.eat(svo.dict.airdisrupt.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.airdisrupt)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("airdisrupt")
        codepaste.remove_focusable()
      end,
    }
  },
  earthdisrupt = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.earthdisrupt and not svo.doingaction("earthdisrupt")) or false
      end,

      oncompleted = function ()
        svo.rmaff("earthdisrupt")
        svo.lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        svo.eat(svo.dict.earthdisrupt.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.earthdisrupt)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("earthdisrupt")
        codepaste.remove_focusable()
      end,
    }
  },
  waterdisrupt = {
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.waterdisrupt and not affs.spiritdisrupt) or false
      end,

      oncompleted = function ()
        svo.rmaff("waterdisrupt")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.waterdisrupt and not svo.doingaction("waterdisrupt")) or false
      end,

      oncompleted = function ()
        svo.rmaff("waterdisrupt")
        svo.lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        svo.eat(svo.dict.waterdisrupt.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.waterdisrupt)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("waterdisrupt")
        codepaste.remove_focusable()
      end,
    }
  },
  firedisrupt = {
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.firedisrupt and not affs.spiritdisrupt) or false
      end,

      oncompleted = function ()
        svo.rmaff("firedisrupt")
        svo.lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        svo.lostbal_focus()

        empty.focus()
      end
    },
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.firedisrupt and not svo.doingaction("firedisrupt")) or false
      end,

      oncompleted = function ()
        svo.rmaff("firedisrupt")
        svo.lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        svo.eat(svo.dict.firedisrupt.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.firedisrupt)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("firedisrupt")
        codepaste.remove_focusable()
      end,
    }
  },
  stain = {
    waitingfor = {
      customwait = 60*2+20, -- lasts 2min, but varies, so let's go with 140s

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
        svo.rmaff("stain")
        svo.echof("Taking a guess, I think stain expired by now.")
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("stain")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function (oldmaxhp)
        -- oldmaxhp doesn't come from diag, it is optional
        if (not conf.aillusion) or (oldmaxhp and (stats.maxhealth < oldmaxhp)) then
          svo.addaffdict(svo.dict.stain)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          codepaste.badaeon()
          if svo.actions.stain_waitingfor then svo.killaction(svo.dict.stain.waitingfor) end
          svo.doaction(svo.dict.stain.waitingfor)
        end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("stain")
        svo.killaction(svo.dict.stain.waitingfor)
      end,
    }
  },
  depression = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return affs.depression or false
      end,

      oncompleted = function ()
        svo.rmaff("depression")
        svo.lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        svo.eat(svo.dict.depression.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.depression)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("depression")
      end,
    }
  },
  parasite = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return affs.parasite or false
      end,

      oncompleted = function ()
        svo.rmaff("parasite")
        svo.lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        svo.eat(svo.dict.parasite.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.parasite)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("parasite")
      end,
    }
  },
  retribution = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return affs.retribution or false
      end,

      oncompleted = function ()
        svo.rmaff("retribution")
        svo.lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        svo.eat(svo.dict.retribution.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.retribution)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("retribution")
      end,
    }
  },
  shadowmadness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return affs.shadowmadness or false
      end,

      oncompleted = function ()
        svo.rmaff("shadowmadness")
        svo.lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        svo.eat(svo.dict.shadowmadness.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.shadowmadness)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("shadowmadness")
      end,
    }
  },
  timeloop = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return affs.timeloop or false
      end,

      oncompleted = function ()
        svo.rmaff("timeloop")
        svo.lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        svo.eat(svo.dict.timeloop.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.timeloop)
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("timeloop")
      end,
    }
  },
  degenerate = {
    waitingfor = {
      customwait = 0, -- seems to last 6 seconds per degenerate affliction when boosted, set below

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("degenerate")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        local timeout = 0
        for _, aff in ipairs(empty.degenerateaffs) do
          timeout = timeout + (affs[aff] and 7 or 0)
        end
        svo.dict.degenerate.waitingfor.customwait = timeout
        svo.addaffdict(svo.dict.degenerate)
        if not svo.actions.degenerate_waitingfor then svo.doaction(svo.dict.degenerate.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("degenerate")
        svo.killaction(svo.dict.degenerate.waitingfor)
      end,
    }
  },
  deteriorate = {
    waitingfor = {
      customwait = 0, -- seems to last 6 seconds per deteriorate affliction when boosted, set below

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("deteriorate")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        local timeout = 0
        for _, aff in ipairs(empty.deteriorateaffs) do
          timeout = timeout + (affs[aff] and 7 or 0)
        end
        svo.dict.deteriorate.waitingfor.customwait = timeout
        svo.addaffdict(svo.dict.deteriorate)
        if not svo.actions.deteriorate_waitingfor then svo.doaction(svo.dict.deteriorate.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("deteriorate")
        svo.killaction(svo.dict.deteriorate.waitingfor)
      end,
    }
  },
  hatred = {
    waitingfor = {
      customwait = 15,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("hatred")
        svo.make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.hatred)
        if not svo.actions.hatred_waitingfor then svo.doaction(svo.dict.hatred.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("hatred")
        svo.killaction(svo.dict.hatred.waitingfor)
      end,
    }
  },
  paradox = {
    count = 0,
    blocked_herb = "",
    boosted = {
      oncompleted = function ()
        svo.dict.paradox.aff.count = 10
        svo.updateaffcount(svo.dict.paradox)
      end
    },
    weakened = {
      oncompleted = function ()
        codepaste.remove_stackableaff("paradox", true)
      end
    },
    aff = {
      oncompleted = function (herb)
        svo.dict.paradox.count = 5
        svo.dict.paradox.blocked_herb = herb
        svo.addaffdict(svo.dict.paradox)
        svo.affl["paradox"].herb = herb
        svo.updateaffcount(svo.dict.paradox)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("paradox")
        svo.dict.paradox.count = 0
        svo.dict.paradox.blocked_herb = ""
      end,
    }
  },
  retardation = {
    waitingfor = {
      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        svo.rmaff("retardation")
      end
    },
    aff = {
      oncompleted = function ()
        if not affs.retardation then
          svo.addaffdict(svo.dict.retardation)
          sk.checkaeony()
          signals.aeony:emit()
          signals.newroom:unblock(sk.check_retardation)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("retardation")
      end,
    },
    onremoved = function ()
      svo.affsp.retardation = nil
      sk.checkaeony()
      signals.aeony:emit()
      signals.newroom:block(sk.check_retardation)
    end,
    onadded = function()
      signals.newroom:unblock(sk.check_retardation)
    end
  },
  nomana = {
    waitingfor = {
      customwait = 30,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,
      ontimeout = function ()
        echo"\n"svo.echof("Hm, maybe we have enough mana for mana skills now...")
        svo.killaction(svo.dict.nomana.waitingfor)
        svo.make_gnomes_work()
      end
    }
  },

  -- random actions that should be protected by AI
  givewarning = {
    happened = {
      oncompleted = function (tbl)
        if tbl and tbl.initialmsg then
          echo"\n\n"
          svo.echof("Careful: %s", tbl.initialmsg)
          echo"\n"
        end

        if tbl and tbl.prefixwarning then
          local duration = tbl.duration or 4
          local startin = tbl.startin or 0
          cnrl.warning = tbl.prefixwarning or ""

          -- timer for starting
          if not conf.warningtype then return end

          tempTimer(startin, function ()

            if cnrl.warnids[tbl.prefixwarning] then killTrigger(cnrl.warnids[tbl.prefixwarning]) end

              cnrl.warnids[tbl.prefixwarning] = tempRegexTrigger('^', [[
                if ((svo.conf.warningtype == "prompt" and isPrompt()) or svo.conf.warningtype == "all" or svo.conf.warningtype == "right") and getCurrentLine() ~= "" and not svo.gagline then
                  svo.prefixwarning()
                end
              ]])
            end)

          -- timer for ending
          tempTimer(startin+duration, function () killTrigger(cnrl.warnids[tbl.prefixwarning]) end)
        end
      end
    }
  },
  stolebalance = {
    happened = {
      oncompleted = function (balance)
        svo["lostbal_"..balance]()
      end
    }
  },
  gotbalance = {
    happened = {
      tempmap = {},
      oncompleted = function ()
        for _, balance in ipairs(svo.dict.gotbalance.happened.tempmap) do
          if not bals[balance] then
            bals[balance] = true

            raiseEvent("svo got balance", balance)

            svo.endbalancewatch(balance)

            -- this concern should be separated into its own
            if balance == "tree" then
              killTimer(sys.treetimer)
            end
          end
        end
        svo.dict.gotbalance.happened.tempmap = {}
      end,

      oncancel = function ()
        svo.dict.gotbalance.happened.tempmap = {}
      end
    }
  },
  gothit = {
    happened = {
      tempmap = {},
      oncompleted = function ()
        for name, class in pairs(svo.dict.gothit.happened.tempmap) do
          if name == '?' then
            raiseEvent("svo got hit by", class)
          else
            raiseEvent("svo got hit by", class, name)
          end
        end
        svo.dict.gothit.happened.tempmap = {}
      end,

      oncancel = function ()
        svo.dict.gothit.happened.tempmap = {}
      end
    }
  },

-- general defences
  rebounding = {
    blocked = false, -- we need to block off in blackout, because otherwise we waste sips
    smoke = {
      aspriority = 137,
      spriority = 261,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].rebounding and not defc.rebounding) or (conf.keepup and defkeepup[defs.mode].rebounding and not defc.rebounding)) and codepaste.smoke_skullcap_pipe() and not svo.doingaction("waitingonrebounding") and not svo.dict.rebounding.blocked) or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.waitingonrebounding.waitingfor)
        sk.skullcap_smokepuff()
        svo.lostbal_smoke()
      end,

      alreadygot = function ()
        defences.got("rebounding")
        sk.skullcap_smokepuff()
        svo.lostbal_smoke()
      end,

      ontimeout = function ()
        if not affs.blackout then return end

        svo.dict.rebounding.blocked = true
        tempTimer(3, function () svo.dict.rebounding.blocked = false; svo.make_gnomes_work() end)
      end,

      smokecure = {"skullcap", "malachite"},
      onstart = function ()
        send("smoke " .. pipes.skullcap.id, conf.commandecho)
      end,

      empty = function ()
        svo.dict.rebounding.smoke.oncompleted()
      end
    }
  },
  waitingonrebounding = {
    spriority = 0,
    waitingfor = {
      customwait = 9,

      onstart = function () raiseEvent("svo rebounding start") end,

      oncompleted = function ()
        defences.got("rebounding")
      end,

      deathtarot = function () -- nothing happens! It just doesn't come up :/
      end,

      -- expend torso cancels rebounding coming up
      expend = function()
        if svo.actions.waitingonrebounding_waitingfor then
          svo.killaction(svo.dict.waitingonrebounding.waitingfor)
        end
      end,
    }
  },
  frost = {
    purgative = {
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return ((sys.deffing and defdefup[defs.mode].frost and not defc.frost) or (conf.keepup and defkeepup[defs.mode].frost and not defc.frost)) or false
      end,

      oncompleted = function ()
        defences.got("frost")
        if svo.haveskillset('metamorphosis') then
          defences.got("temperance")
        end
      end,

      sipcure = {"frost", "endothermia"},

      onstart = function ()
        svo.sip(svo.dict.frost.purgative)
      end,

      empty = function ()
        defences.got("frost")
      end,

      noeffect = function()
        defences.got("frost")
      end
    },
    gone = {
      oncompleted = function ()
        if svo.haveskillset('metamorphosis') then
          defences.lost("temperance")
        end
      end
    }
  },
  venom = {
    gamename = "poisonresist",
    purgative = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return ((sys.deffing and defdefup[defs.mode].venom and not defc.venom) or (conf.keepup and defkeepup[defs.mode].venom and not defc.venom)) or false
      end,

      oncompleted = function ()
        defences.got("venom")
      end,

      noeffect = function()
        defences.got("venom")
      end,

      sipcure = {"venom", "toxin"},

      onstart = function ()
        svo.sip(svo.dict.venom.purgative)
      end,

      empty = function ()
        defences.got("venom")
      end
    }
  },
  levitation = {
    gamename = "levitating",
    purgative = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return ((sys.deffing and defdefup[defs.mode].levitation and not defc.levitation) or (conf.keepup and defkeepup[defs.mode].levitation and not defc.levitation)) or false
      end,

      oncompleted = function ()
        defences.got("levitation")
      end,

      noeffect = function()
        defences.got("levitation")
      end,

      sipcure = {"levitation", "hovering"},

      onstart = function ()
        svo.sip(svo.dict.levitation.purgative)
      end,

      empty = function ()
        defences.got("levitation")
      end
    }
  },
  speed = {
    blocked = false, -- we need to block off in blackout, because otherwise we waste sips
    purgative = {
      aspriority = 8,
      spriority = 265,
      def = true,

      isadvisable = function ()
        return (not defc.speed and ((sys.deffing and defdefup[defs.mode].speed) or (conf.keepup and defkeepup[defs.mode].speed)) and not svo.doingaction("curingspeed") and not svo.doingaction("speed") and not svo.dict.speed.blocked and not me.manualdefcheck) or false
      end,

      oncompleted = function (def)
        if def then defences.got("speed")
        else
          if affs.palpatar then
            svo.dict.curingspeed.waitingfor.customwait = 10
          else
            svo.dict.curingspeed.waitingfor.customwait = 7
          end

          svo.doaction(svo.dict.curingspeed.waitingfor)
        end
      end,

      ontimeout = function ()
        if not affs.blackout then return end

        svo.dict.speed.blocked = true
        tempTimer(3, function () svo.dict.speed.blocked = false; svo.make_gnomes_work() end)
      end,

      noeffect = function()
        defences.got("speed")
      end,

      sipcure = {"speed", "haste"},

      onstart = function ()
        svo.sip(svo.dict.speed.purgative)
      end,

      empty = function ()
        svo.dict.speed.purgative.oncompleted ()
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("speed")
      end
    }
  },
  curingspeed = {
    spriority = 0,
    waitingfor = {
      customwait = 7,

      oncompleted = function ()
        defences.got("speed")
      end,

      ontimeout = function ()
        if defc.speed then return end

        if (sys.deffing and defdefup[defs.mode].speed) or (conf.keepup and defkeepup[defs.mode].speed) then
          svo.echof("Warning - speed didn't come up in 7s, checking 'def'.")
          me.manualdefcheck = true
        end
      end,

      onstart = function () end
    }
  },
  sileris = {
    gamename = "fangbarrier",
    applying = "",
    misc = {
      aspriority = 8,
      spriority = 265,
      def = true,

      isadvisable = function ()
        return (not defc.sileris and ((sys.deffing and defdefup[defs.mode].sileris) or (conf.keepup and defkeepup[defs.mode].sileris)) and not svo.doingaction("waitingforsileris") and not svo.doingaction("sileris") and not affs.paralysis and not affs.slickness and not me.manualdefcheck) or false
      end,

      oncompleted = function (def)
        if def and not defc.sileris then defences.got("sileris")
        else svo.doaction(svo.dict.waitingforsileris.waitingfor) end
      end,

      slick = function()
        svo.addaffdict(svo.dict.slickness)
      end,

      ontimeout = function ()
        if not affs.blackout then return end

        svo.dict.sileris.blocked = true
        tempTimer(3, function () svo.dict.sileris.blocked = false; svo.make_gnomes_work() end)
      end,

      -- special case for 'missing herb' trig
      eatcure = {"sileris", "quicksilver"},
      applycure = {"sileris", "quicksilver"},
      actions = {"apply sileris", "apply quicksilver"},
      onstart = function ()
        local use = "sileris"

        if conf.curemethod and conf.curemethod ~= "conconly" and (

          conf.curemethod == "transonly" or

          (conf.curemethod == "preferconc" and
            -- we don't have in inventory, but do have alchemy in inventory, use alchemy
             (not (rift.invcontents.sileris > 0) and (rift.invcontents.quicksilver > 0)) or
              -- or if we don't have the conc cure in rift either, use alchemy
             (not (rift.riftcontents.sileris > 0))) or

          (conf.curemethod == "prefertrans" and
            (rift.invcontents.quicksilver > 0
              or (not (rift.invcontents.sileris > 0) and (rift.riftcontents.quicksilver > 0)))) or

          -- prefercustom, and we either prefer alchy and have it, or prefer conc and don't have it
          (conf.curemethod == "prefercustom" and (
            (me.curelist[use] == use and rift.riftcontents[use] <= 0)
              or
            (me.curelist[use] == "quicksilver" and rift.riftcontents["quicksilver"] > 0)
          ))

          ) then
            use = "quicksilver"
        end

        sys.last_used["sileris_misc"] = use

        svo.dict.sileris.applying = use
        if rift.invcontents[use] > 0 then
          send("outr "..use, conf.commandecho)
          send("apply "..use, conf.commandecho)
        else
          send("outr "..use, conf.commandecho)
          send("apply "..use, conf.commandecho)
        end
      end,

      empty = function ()
        svo.dict.sileris.misc.oncompleted()
      end
    },
    gone = {
      oncompleted = function (line_spotted_on)
        if not conf.aillusion or not line_spotted_on or (line_spotted_on+1 == getLastLineNumber("main")) then
          defences.lost("sileris")
        end
      end,

      camusbite = function (oldhp)
        if not conf.aillusion or (not affs.recklessness and stats.currenthealth < oldhp) then
          defences.lost("sileris")
        end
      end,

      sumacbite = function (oldhp)
        if not conf.aillusion or (not affs.recklessness and stats.currenthealth < oldhp) then
          defences.lost("sileris")
        end
      end,
    }
  },
  waitingforsileris = {
    spriority = 0,
    waitingfor = {
      customwait = 8,

      oncompleted = function ()
        defences.got("sileris")
      end,

      ontimeout = function ()
        if defc.sileris then return end

        if (sys.deffing and defdefup[defs.mode].sileris) or (conf.keepup and defkeepup[defs.mode].sileris) then
          svo.echof("Warning - sileris isn't back yet, we might've been tricked. Going to see if we get bitten.")
          local oldsileris = defc.sileris
          defc.sileris = "unsure"
          if oldsileris ~= defc.sileris then raiseEvent("svo got def", "sileris") end
        end
      end,

      onstart = function () end
    }
  },
  deathsight = {
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.deathsight and (not conf.deathsight or not svo.can_usemana()) and ((sys.deffing and defdefup[defs.mode].deathsight) or (conf.keepup and defkeepup[defs.mode].deathsight)) and not svo.doingaction("deathsight")) or false
      end,

      oncompleted = function ()
        defences.got("deathsight")
      end,

      eatcure = {"skullcap", "azurite"},
      onstart = function ()
        svo.eat(svo.dict.deathsight.herb)
      end,

      empty = function()
        defences.got("deathsight")
      end
    },
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return (not defc.deathsight and conf.deathsight and svo.can_usemana() and not svo.doingaction("deathsight") and ((sys.deffing and defdefup[defs.mode].deathsight) or (conf.keepup and defkeepup[defs.mode].deathsight)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("deathsight")
      end,

      action = "deathsight",
      onstart = function ()
        send("deathsight", conf.commandecho)
      end
    },
  },
  thirdeye = {
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].thirdeye and not defc.thirdeye) or (conf.keepup and defkeepup[defs.mode].thirdeye and not defc.thirdeye)) and not svo.doingaction("thirdeye") and not (conf.thirdeye and svo.can_usemana())) or false
      end,

      oncompleted = function ()
        defences.got("thirdeye")
      end,

      eatcure = {"echinacea", "dolomite"},
      onstart = function ()
        svo.eat(svo.dict.thirdeye.herb)
      end,

      empty = function()
        defences.got("thirdeye")
      end
    },
    misc = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (conf.thirdeye and svo.can_usemana() and not svo.doingaction("thirdeye") and ((sys.deffing and defdefup[defs.mode].thirdeye and not defc.thirdeye) or (conf.keepup and defkeepup[defs.mode].thirdeye and not defc.thirdeye))) or false
      end,

      -- by default, oncompleted means a clot went through okay
      oncompleted = function ()
        defences.got("thirdeye")
      end,

      action = "thirdeye",
      onstart = function ()
        send("thirdeye", conf.commandecho)
      end
    },
  },
  insomnia = {
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].insomnia and not defc.insomnia) or (conf.keepup and defkeepup[defs.mode].insomnia and not defc.insomnia)) and not svo.doingaction("insomnia") and not (conf.insomnia and svo.can_usemana()) and not affs.hypersomnia) or false
      end,

      oncompleted = function ()
        defences.got("insomnia")
      end,

      eatcure = {"cohosh", "gypsum"},
      onstart = function ()
        svo.eat(svo.dict.insomnia.herb)
      end,

      empty = function()
        defences.got("insomnia")
      end,

      hypersomnia = function ()
        svo.addaffdict(svo.dict.hypersomnia)
      end
    },
    misc = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (conf.insomnia and svo.can_usemana() and not svo.doingaction("insomnia") and ((sys.deffing and defdefup[defs.mode].insomnia and not defc.insomnia) or (conf.keepup and defkeepup[defs.mode].insomnia and not defc.insomnia)) and not affs.hypersomnia) or false
      end,

      oncompleted = function ()
        defences.got("insomnia")
      end,

      hypersomnia = function ()
        svo.addaffdict(svo.dict.hypersomnia)
      end,

      action = "insomnia",
      onstart = function ()
        send("insomnia", conf.commandecho)
      end
    },
    -- small cheat for insomnia being on diagnose
    aff = {
      oncompleted = function ()
        defences.got("insomnia")
      end
    },
    gone = {
      oncompleted = function(aff)
        defences.lost("insomnia")

        if aff and aff == "unknownany" then
          svo.dict.unknownany.count = svo.dict.unknownany.count - 1
          if svo.dict.unknownany.count <= 0 then
            svo.rmaff("unknownany")
            svo.dict.unknownany.count = 0
          else
            svo.updateaffcount(svo.dict.unknownany)
          end
        elseif aff and aff == "unknownmental" then
          svo.dict.unknownmental.count = svo.dict.unknownmental.count - 1
          if svo.dict.unknownmental.count <= 0 then
            svo.rmaff("unknownmental")
            svo.dict.unknownmental.count = 0
          else
            svo.updateaffcount(svo.dict.unknownmental)
          end
        end
      end,

      relaxed = function (line_spotted_on)
        if not conf.aillusion or not line_spotted_on or (line_spotted_on+1 == getLastLineNumber("main")) then
          defences.lost("insomnia")
        end
      end,
    }
  },
  myrrh = {
    gamename = "scholasticism",
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].myrrh and not defc.myrrh) or (conf.keepup and defkeepup[defs.mode].myrrh and not defc.myrrh))) or false
      end,

      oncompleted = function ()
        defences.got("myrrh")
      end,

      noeffect = function ()
        svo.dict.myrrh.herb.oncompleted ()
      end,

      eatcure = {"myrrh", "bisemutum"},
      onstart = function ()
        svo.eat(svo.dict.myrrh.herb)
      end,

      empty = function()
        defences.got("myrrh")
      end
    },
  },
  kola = {
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].kola and not defc.kola) or (conf.keepup and defkeepup[defs.mode].kola and not defc.kola))) or false
      end,

      oncompleted = function ()
        defences.got("kola")
      end,

      noeffect = function ()
        svo.dict.kola.herb.oncompleted ()
      end,

      eatcure = {"kola", "quartz"},
      onstart = function ()
        svo.eat(svo.dict.kola.herb)
      end,

      empty = function()
        defences.got("kola")
      end
    },
    gone = {
      oncompleted = function()
        if not conf.aillusion or not svo.pflags.k then
          defences.lost("kola")
        end
      end
    }
  },
  mass = {
    gamename = "density",
    salve = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].mass and not defc.mass) or (conf.keepup and defkeepup[defs.mode].mass and not defc.mass))) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        defences.got("mass")
      end,

      -- sometimes a salve cure can get misgiagnosed on a death (from a previous apply)
      noeffect = function() end,
      empty = function() end,

      applycure = {"mass", "density"},
      actions = {"apply mass to body", "apply mass", "apply density to body", "apply density"},
      onstart = function ()
        svo.apply(svo.dict.mass.salve, " to body")
      end,
    },
  },
  caloric = {
    salve = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].caloric and not defc.caloric) or (conf.keepup and defkeepup[defs.mode].caloric and not defc.caloric))) or false
      end,

      oncompleted = function ()
        svo.lostbal_salve()
        defences.got("caloric")
      end,

      noeffect = function ()
        svo.lostbal_salve()
      end,

      -- called from shivering or frozen cure
      gotcaloricdef = function (hypothermia)
        if not hypothermia then svo.rmaff({"frozen", "shivering"}) end
        svo.dict.caloric.salve.oncompleted ()
      end,

      applycure = {"caloric", "exothermic"},
      actions = {"apply caloric to body", "apply caloric", "apply exothermic to body", "apply exothermic"},
      onstart = function ()
        svo.apply(svo.dict.caloric.salve, " to body")
      end,
    },
    gone = {
      oncompleted = function(aff)
        defences.lost("caloric")

        if aff and aff == "unknownany" then
          svo.dict.unknownany.count = svo.dict.unknownany.count - 1
          if svo.dict.unknownany.count <= 0 then
            svo.rmaff("unknownany")
            svo.dict.unknownany.count = 0
          end
        elseif aff and aff == "unknownmental" then
          svo.dict.unknownmental.count = svo.dict.unknownmental.count - 1
          if svo.dict.unknownmental.count <= 0 then
            svo.rmaff("unknownmental")
            svo.dict.unknownmental.count = 0
          end
        end
      end
    }
  },
  blind = {
    gamename = "blindness",
    onservereignore = function()
      -- no blind skill: ignore serverside if it's not to be deffed up atm
      -- with blind skill: ignore serverside can use skill, or if it's not to be deffed up atm
      return
        (not svo.haveskillset('shindo') or (conf.shindoblind and not defc.dragonform)) or
        (not svo.haveskillset('kaido') or (conf.kaidoblind and not defc.dragonform)) or
        not ((sys.deffing and defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind))
    end,
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not affs.scalded and
          (not svo.haveskillset('shindo') or (defc.dragonform or (not conf.shindoblind))) and
          (not svo.haveskillset('kaido') or (defc.dragonform or (not conf.kaidoblind))) and
          ((sys.deffing and defdefup[defs.mode].blind and not defc.blind) or (conf.keepup and defkeepup[defs.mode].blind and not defc.blind)) and
          not svo.doingaction"waitingonblind") or false
      end,

      oncompleted = function ()
        defences.got("blind")
        svo.lostbal_herb()
      end,

      noeffect = function ()
        svo.dict.blind.herb.oncompleted()
      end,

      eatcure = {"bayberry", "arsenic"},
      onstart = function ()
        svo.eat(svo.dict.blind.herb)
      end,

      empty = function()
        defences.got("blind")
        svo.lostbal_herb()
      end
    },
    gone = {
      oncompleted = function()
        if not conf.aillusion or not svo.pflags.b then
          defences.lost("blind")
        end
      end
    }
  },
  waitingonblind = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        defences.got("blind")
      end,

      onstart = function ()
      end
    }
  },
  deaf = {
    gamename = "deafness",
    onservereignore = function()
      -- no deaf skill: ignore serverside if it's not to be deffed up atm
      -- with deaf skill: ignore serverside can use skill, or if it's not to be deffed up atm
      return (not svo.haveskillset('shindo') or (conf.shindodeaf and not defc.dragonform)) or
        (not svo.haveskillset('kaido') or (conf.kaidodeaf and not defc.dragonform)) or
        not ((sys.deffing and defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf))
    end,
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.deaf and
          (not svo.haveskillset('shindo') or (defc.dragonform or not conf.shindodeaf)) and
          (not svo.haveskillset('kaido') or (defc.dragonform or not conf.kaidodeaf)) and
         ((sys.deffing and defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf)) and not svo.doingaction("waitingondeaf")) or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.waitingondeaf.waitingfor)
        svo.lostbal_herb()
      end,

      eatcure = {"hawthorn", "calamine"},
      onstart = function ()
        svo.eat(svo.dict.deaf.herb)
      end,

      empty = function()
        svo.dict.deaf.herb.oncompleted()
      end
    },
    gone = {
      oncompleted = function()
        if not conf.aillusion or not svo.pflags.d then
          defences.lost("deaf")
        end
      end
    }
  },
  waitingondeaf = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        defences.got("deaf")
      end,

      onstart = function ()
      end
    }
  },


-- balance-related defences
  lyre = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.lyre and ((sys.deffing and defdefup[defs.mode].lyre) or (conf.keepup and defkeepup[defs.mode].lyre)) and not svo.will_take_balance() and not conf.lyre_step and not svo.doingaction("lyre") and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("lyre")

        if conf.lyre and not conf.paused then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end,

      ontimeout = function()
        if conf.paused and not defc.lyre then
          svo.echof("Lyre strum didn't happen - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
          svo.make_gnomes_work()
        end
      end,

      onkill = function()
        if conf.paused and not defc.lyre then
          svo.echof("Lyre strum cancelled - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
        end
      end,

      action = "strum lyre",
      onstart = function ()
        sys.sendonceonly = true
        -- small fix to make 'lyc' work and be in-order (as well as use batching)
        local send = send
        -- record in systemscommands, so it doesn't get killed later on in the controller and loop
        if conf.batch then send = function(what, ...) svo.sendc(what, ...) sk.systemscommands[what] = true end end

        if not conf.lyrecmd then
          send("strum lyre", conf.commandecho)
        else
          send(tostring(conf.lyrecmd), conf.commandecho)
        end
        sys.sendonceonly = false

        if conf.lyre and not conf.paused then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("lyre")

        -- as a special case for handling the following scenario:
        --[[(focus)
          Your prismatic barrier dissolves into nothing.
          You focus your mind intently on curing your mental maladies.
          Food is no longer repulsive to you. (7.548s)
          H: 3294 (50%), M: 4911 (89%) 28725e, 10294w 89.3% ex|cdk- 19:24:04.719(sip health|eat bayberry|outr bayberry|eat
          irid|outr irid)(+324h, 5.0%, -291m, 5.3%)
          You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.
          (p) H: 3294 (50%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:04.897
          Your prismatic barrier dissolves into nothing.
          You take a drink from a purple heartwood vial.
          The elixir heals and soothes you.
          H: 4767 (73%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:05.247(+1473h, 22.7%)
          You eat some bayberry bark.
          Your eyes dim as you lose your sight.
        ]]
        -- we want to kill lyre going up when it goes down and you're off balance, because you won't get it up off-bal

        -- but don't kill it if it is in lifevision - meaning we're going to get it:
        --[[
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
          (x) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}
          You have recovered equilibrium. (3.887s)
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
        ]]

        if not (bals.balance and bals.equilibrium) and svo.actions.lyre_physical and not svo.lifevision.l.lyre_physical then svo.killaction(svo.dict.lyre.physical) end

        -- unpause should we lose the lyre def for some reason - but not while we're doing lyc
        -- since we'll lose the lyre def and it'll come up right away
        if conf.lyre and conf.paused and not svo.actions.lyre_physical then conf.paused = false; raiseEvent("svo config changed", "paused") end
      end,
    }
  },
  breath = {
    gamename = "heldbreath",
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceless_act = true,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].breath and not defc.breath) or (conf.keepup and defkeepup[defs.mode].breath and not defc.breath)) and not svo.doingaction("breath") and not codepaste.balanceful_defs_codepaste() and not affs.aeon and not affs.asthma) or false
      end,

      oncompleted = function ()
        defences.got("breath")
      end,

      action = "hold breath",
      onstart = function ()
        if conf.gagbreath and not sys.sync then
          send("hold breath", false)
        else
          send("hold breath", conf.commandecho) end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("breath")
      end,
    }
  },
  dragonform = {
    physical = {
      aspriority = 0,
      spriority = 0,
      unpauselater = false,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].dragonform and not defc.dragonform) or (conf.keepup and defkeepup[defs.mode].dragonform and not defc.dragonform)) and not svo.doingaction("waitingfordragonform") and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.waitingfordragonform.waitingfor)
      end,

      alreadyhave = function ()
        svo.dict.waitingfordragonform.waitingfor.oncompleted()
      end,

      actions = {"dragonform", "dragonform red", "dragonform black", "dragonform silver", "dragonform gold", "dragonform blue", "dragonform green"},
      onstart = function ()
      -- user commands catching needs this check
        if not (bals.balance and bals.equilibrium) then return end

        if defc.flame and svo.haveskillset('metamorphosis') then
          send("relax flame", conf.commandecho)
        end
        send("dragonform", conf.commandecho)

        if not conf.paused then
          svo.dict.dragonform.physical.unpauselater = true
          conf.paused = true; raiseEvent("svo config changed", "paused")
          echo"\n" svo.echof("Temporarily pausing for dragonform.")
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("dragonform")
        svo.dict.dragonbreath.gone.oncompleted()
        svo.dict.dragonarmour.gone.oncompleted()
        signals.dragonform:emit()
      end,
    }
  },
  waitingfordragonform = {
    spriority = 0,
    waitingfor = {
      customwait = 20,

      oncompleted = function ()
        defences.got("dragonform")
        svo.dict.riding.gone.oncompleted()

        -- strip class defences that don't stay through dragon
        for def, deft in svo.defs_data:iter() do
          local skillset = deft.type
          if skillset ~= "general" and skillset ~= "enchantment" and skillset ~= "dragoncraft" and not deft.staysindragon and defc[def] then
            defences.lost(def)
          end
        end

        -- lifevision, via artefact, has to be removed as well
        if defc.lifevision and not svo.haveskillset('necromancy') then
          defences.lost("lifevision")
        end

        signals.dragonform:emit()

        if conf.paused and svo.dict.dragonform.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")

          echo"\n"
          if math.random(1, 20) == 1 then
            svo.echof("ROOOAR!")
          else
            svo.echof("Obtained dragonform, unpausing.")
          end
        end
        svo.dict.dragonform.physical.unpauselater = false
      end,

      cancelled = function ()
        signals.dragonform:emit()
        if conf.paused and svo.dict.dragonform.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          echo"\n" svo.echof("Unpausing.")
        end
        svo.dict.dragonform.physical.unpauselater = false
      end,

      ontimeout = function()
        svo.dict.waitingfordragonform.waitingfor.cancelled()
      end,

      onstart = function() end
    }
  },
  dragonbreath = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceless_act = true,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].dragonbreath and not defc.dragonbreath) or (conf.keepup and defkeepup[defs.mode].dragonbreath and not defc.dragonbreath)) and not codepaste.balanceful_defs_codepaste() and not svo.doingaction("dragonbreath") and not svo.doingaction("waitingfordragonbreath") and defc.dragonform and not svo.dict.dragonbreath.blocked and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function (def)
        if def then defences.got("dragonbreath")
        else svo.doaction(svo.dict.waitingfordragonbreath.waitingfor) end
      end,

      ontimeout = function ()
        if not affs.blackout then return end

        svo.dict.dragonbreath.blocked = true
        tempTimer(3, function () svo.dict.dragonbreath.blocked = false; svo.make_gnomes_work() end)
      end,

      alreadygot = function ()
        defences.got("dragonbreath")
      end,

      onstart = function ()
        send("summon "..(conf.dragonbreath and conf.dragonbreath or "unknown"), conf.commandecho)
      end
    },
    gone = {
      oncompleted = function()
        defences.lost("dragonbreath")
      end
    }
  },
  waitingfordragonbreath = {
    spriority = 0,
    waitingfor = {
      customwait = 2,

      onstart = function() end,

      oncompleted = function ()
        defences.got("dragonbreath")
      end
    }
  },
  dragonarmour = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].dragonarmour and not defc.dragonarmour) or (conf.keepup and defkeepup[defs.mode].dragonarmour and not defc.dragonarmour)) and not codepaste.balanceful_defs_codepaste() and defc.dragonform) or false
      end,

      oncompleted = function ()
        defences.got("dragonarmour")
      end,

      action = "dragonarmour on",
      onstart = function ()
        send("dragonarmour on", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function()
        defences.lost("dragonarmour")
      end
    }
  },
  selfishness = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (
          ((sys.deffing and defdefup[defs.mode].selfishness and not defc.selfishness)
            or (not sys.deffing and conf.keepup and ((defkeepup[defs.mode].selfishness and not defc.selfishness) or (not defkeepup[defs.mode].selfishness and defc.selfishness))))
          and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("selfishness")
      end,

      onstart = function ()
        if (sys.deffing and defdefup[defs.mode].selfishness and not defc.selfishness) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].selfishness and not defc.selfishness) then
          send("selfishness", conf.commandecho)
        else
          send("generosity", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("selfishness")

        -- if we've done sl off, _gone gets added, so _physical gets readded by action clear - kill physical here for that not to happen
        if svo.actions.selfishness_physical then
          svo.killaction(svo.dict.selfishness.physical)
        end
      end,
    }
  },
  riding = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (
          ((sys.deffing and defdefup[defs.mode].riding and not defc.riding)
            or (not sys.deffing and conf.keepup and ((defkeepup[defs.mode].riding and not defc.riding) or (not defkeepup[defs.mode].riding and defc.riding))))
          and not codepaste.balanceful_defs_codepaste() and not defc.dragonform and not affs.hamstring and (not affs.prone or svo.doingaction"prone") and not affs.crippledleftarm and not affs.crippledrightarm and not affs.mangledleftarm and not affs.mangledrightarm and not affs.mutilatedleftarm and not affs.mutilatedrightarm and not affs.unknowncrippledleg and not affs.parestolegs and not svo.doingaction"riding" and not affs.pinshot and not affs.paralysis) or false
      end,

      oncompleted = function ()
        if (not sys.deffing and conf.keepup and not defkeepup[defs.mode].riding and (defc.riding == true or defc.riding == nil)) then
          svo.dict.riding.gone.oncompleted()
        else
          defences.got("riding")
        end

        if bals.balance and not conf.freevault then
          svo.config.set("freevault", "yep", true)
        elseif not bals.balance and conf.freevault then
          svo.config.set("freevault", "nope", true)
        end
      end,

      alreadyon = function ()
        defences.got("riding")
      end,

      dragonform = function ()
        defences.got("dragonform")
        signals.dragonform:emit()
      end,

      hastring = function ()
        svo.dict.hamstring.aff.oncompleted()
      end,

      dismount = function ()
        defences.lost("riding")
        svo.dict.block.gone.oncompleted()
      end,

      onstart = function ()
        if (sys.deffing and defdefup[defs.mode].riding and not defc.riding) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].riding and not defc.riding) then
          send(string.format("%s %s", tostring(conf.ridingskill), tostring(conf.ridingsteed)), conf.commandecho)
        else
          send("dismount", conf.commandecho)
          if sys.sync or tostring(conf.ridingsteed) == "giraffe" then return end
          if conf.steedfollow then send(string.format("order %s follow me", tostring(conf.ridingsteed), conf.commandecho)) end
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("riding")
        svo.dict.block.gone.oncompleted()
      end,
    }
  },
  meditate = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].meditate and not defc.meditate) or (conf.keepup and defkeepup[defs.mode].meditate and not defc.meditate)) and not codepaste.balanceful_defs_codepaste() and not svo.doingaction'meditate' and (stats.currentwillpower < stats.maxwillpower or stats.currentmana < stats.maxmana)) or false
      end,

      oncompleted = function ()
        defences.got("meditate")
      end,

      actions = {"med", "meditate"},
      onstart = function ()
        send("meditate", conf.commandecho)
      end
    }
  },

  mindseye = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.mindseye and ((sys.deffing and defdefup[defs.mode].mindseye) or (conf.keepup and defkeepup[defs.mode].mindseye)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("mindseye")

        -- check if we need to re-classify deaf
        if (defc.deaf or affs.deafaff) and (defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf) or defc.mindseye then
          defences.got("deaf")
          svo.rmaff("deafaff")
        elseif (defc.deaf or affs.deafaff) then
          defences.lost("deaf")
          svo.addaffdict(svo.dict.deafaff)
        end

        -- check if we need to re-classify blind
        if (defc.blind or affs.blindaff) and (defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind) and (svo.me.class == "Apostate" or defc.mindseye) then
          defences.got("blind")
          svo.rmaff("blindaff")
        elseif (defc.blind or affs.blindaff) then
          defences.lost("blind")
          svo.addaffdict(svo.dict.blindaff)
        end
      end,

      action = "touch mindseye",
      onstart = function ()
        send("touch mindseye", conf.commandecho)
      end
    }
  },
  metawake = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.metawake and ((sys.deffing and defdefup[defs.mode].metawake) or (conf.keepup and defkeepup[defs.mode].metawake)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not svo.doingaction'metawake' and not affs.lullaby) or false
      end,

      oncompleted = function ()
        defences.got("metawake")
      end,

      action = "metawake on",
      onstart = function ()
        send("metawake on", conf.commandecho)
      end
    }
  },
  cloak = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.cloak and ((sys.deffing and defdefup[defs.mode].cloak) or (conf.keepup and defkeepup[defs.mode].cloak)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("cloak")
      end,

      action = "touch cloak",
      onstart = function ()
        send("touch cloak", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function()
        if not conf.aillusion or not svo.pflags.c then
          defences.lost("cloak")
        end
      end
    }
  },

  nightsight = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.nightsight and
          ((sys.deffing and defdefup[defs.mode].nightsight) or (conf.keepup and defkeepup[defs.mode].nightsight)) and
          not codepaste.balanceful_defs_codepaste() and
          sys.canoutr and
          not affs.prone and
          not svo.doingaction'nightsight'
          and (not svo.haveskillset('metamorphosis') or ((not affs.cantmorph and sk.morphsforskill.nightsight) or defc.dragonform))) or false
      end,

      oncompleted = function ()
        defences.got("nightsight")
      end,

      action = "nightsight on",
      onstart = function ()
if not svo.haveskillset('metamorphosis') then
        send("nightsight on", conf.commandecho)
else
        if not defc.dragonform and (not conf.transmorph and sk.inamorph() and not sk.inamorphfor"nightsight") then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not defc.dragonform and not sk.inamorphfor"nightsight" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.nightsight[1], conf.commandecho)
        elseif defc.dragonform or sk.inamorphfor"nightsight" then
          send("nightsight on", conf.commandecho)
        end
end
      end
    },
  },
  shield = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].shield and not defc.shield) or (conf.keepup and defkeepup[defs.mode].shield and not defc.shield)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not (affs.mangledleftarm and affs.mangledlrightarm) and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("shield")
        if defkeepup[defs.mode].shield and conf.oldts then
          defs.keepup("shield", false)
        end
      end,

      actions = {"touch shield", "angel aura"},
      onstart = function ()
if svo.haveskillset('spirituality') then
        if defc.dragonform or not defc.summon or stats.currentwillpower <= 10 then
          send("touch shield", conf.commandecho)
        else
          send("angel aura", conf.commandecho)
        end
else
        send("touch shield", conf.commandecho)
end
      end
    },
    gone = {
      oncompleted = function()
        defences.lost("shield")
      end
    }
  },
  sstosvoa = {
    addiction = "addiction",
    aeon = "aeon",
    agoraphobia = "agoraphobia",
    airdisrupt = "airdisrupt",
    airfisted = "galed",
    amnesia = "amnesia",
    anorexia = "anorexia",
    asthma = "asthma",
    blackout = "blackout",
    blindness = false,
    bound = "bound",
    brokenleftarm = "crippledleftarm",
    brokenleftleg = "crippledleftleg",
    brokenrightarm = "crippledrightarm",
    brokenrightleg = "crippledrightleg",
    bruisedribs = false,
    burning = "ablaze",
    cadmuscurse = "cadmus",
    claustrophobia = "claustrophobia",
    clumsiness = "clumsiness",
    concussion = "seriousconcussion",
    conflagration = false,
    confusion = "confusion",
    corruption = "corrupted",
    crackedribs = "crackedribs",
    daeggerimpale = false,
    damagedhead = "mildconcussion",
    damagedleftarm = "mangledleftarm",
    damagedleftleg = "mangledleftleg",
    damagedrightarm = "mangledrightarm",
    damagedrightleg = "mangledrightleg",
    darkshade = "darkshade",
    dazed = false,
    dazzled = false,
    deadening = "deadening",
    deafness = false,
    deepsleep = "sleep",
    degenerate = "degenerate",
    dehydrated = "dehydrated",
    dementia = "dementia",
    demonstain = "stain",
    depression = "depression",
    deteriorate = "deteriorate",
    disloyalty = "disloyalty",
    disrupted = "disrupt",
    dissonance = "dissonance",
    dizziness = "dizziness",
    earthdisrupt = "earthdisrupt",
    enlightenment = false,
    enmesh = false,
    entangled = "roped",
    entropy = false,
    epilepsy = "epilepsy",
    fear = "fear",
    firedisrupt = "firedisrupt",
    flamefisted = "burning",
    frozen = "frozen",
    generosity = "generosity",
    haemophilia = "haemophilia",
    hallucinations = "hallucinations",
    hamstrung = "hamstring",
    hatred = "hatred",
    healthleech = "healthleech",
    heartseed = "heartseed",
    hecatecurse = "hecate",
    hellsight = "hellsight",
    hindered = false,
    homunculusmercury = false,
    hypersomnia = "hypersomnia",
    hypochondria = "hypochondria",
    hypothermia = "hypothermia",
    icefisted = "icing",
    impaled = "impale",
    impatience = "impatience",
    inquisition = "inquisition",
    insomnia = false,
    internalbleeding = false,
    isolation = false,
    itching = "itching",
    justice = "justice",
    kaisurge = false,
    laceratedthroat = "laceratedthroat",
    lapsingconsciousness = false,
    lethargy = "lethargy",
    loneliness = "loneliness",
    lovers = "inlove",
    manaleech = "manaleech",
    mangledhead = "seriousconcussion",
    mangledleftarm = "mutilatedleftarm",
    mangledleftleg = "mutilatedleftleg",
    mangledrightarm = "mutilatedrightarm",
    mangledrightleg = "mutilatedrightleg",
    masochism = "masochism",
    mildtrauma = "mildtrauma",
    mindclamp = false,
    nausea = "illness",
    numbedleftarm = "numbedleftarm",
    numbedrightarm = "numbedrightarm",
    pacified = "pacifism",
    palpatarfeed = "palpatar",
    paralysis = "paralysis",
    paranoia = "paranoia",
    parasite = "parasite",
    peace = "peace",
    penitence = false,
    petrified = false,
    phlogisticated = "phlogistication",
    pinshot = "pinshot",
    prone = "prone",
    recklessness = "recklessness",
    retribution = "retribution",
    revealed = false,
    scalded = "scalded",
    scrambledbrains = false,
    scytherus = "relapsing",
    selarnia = "selarnia",
    sensitivity = "sensitivity",
    serioustrauma = "serioustrauma",
    shadowmadness = "shadowmadness",
    shivering = "shivering",
    shyness = "shyness",
    silver = false,
    skullfractures = "skullfractures",
    slashedthroat = "slashedthroat",
    sleeping = "sleep",
    slickness = "slickness",
    slimeobscure = "ninkharsag",
    spiritdisrupt = "spiritdisrupt",
    stupidity = "stupidity",
    stuttering = "stuttering",
    temperedcholeric = "cholerichumour",
    temperedmelancholic = "melancholichumour",
    temperedphlegmatic = "phlegmatichumour",
    temperedsanguine = "sanguinehumour",
    timeflux = "timeflux",
    timeloop = "timeloop",
    torntendons = "torntendons",
    transfixation = "transfixed",
    trueblind = false,
    unconsciousness = "unconsciousness",
    vertigo = "vertigo",
    vinewreathed = false,
    vitiated = false,
    vitrified = "vitrification",
    voidfisted = "voided",
    voyria = "voyria",
    waterdisrupt = "waterdisrupt",
    weakenedmind = "rixil",
    weariness = "weakness",
    webbed = "webbed",
    whisperingmadness = "madness",
    wristfractures = "wristfractures"
  },
  sstosvod = {
    acrobatics = "acrobatics",
    affinity = "affinity",
    aiming = false,
    airpocket = "waterbubble",
    alertness = "alertness",
    antiforce = "gaiartha",
    arctar = "arctar",
    aria = "aria",
    arrowcatching = "arrowcatch",
    astralform = "astralform",
    astronomy = "empower",
    balancing = "balancing",
    barkskin = "barkskin",
    basking = "bask",
    bedevilaura = "bedevil",
    belltattoo = "bell",
    blackwind = false,
    blademastery = "mastery",
    blessingofthegods = false,
    blindness = "blind",
    blocking = "block",
    bloodquell = "ukhia",
    bloodshield = false,
    blur = "blur",
    boartattoo = false,
    bodyaugment = "mainaas",
    bodyblock = "bodyblock",
    boostedregeneration = "boosting",
    chameleon = "chameleon",
    chargeshield = "chargeshield",
    circulate = "circulate",
    clinging = "clinging",
    cloak = "cloak",
    coldresist = "coldresist",
    consciousness = "consciousness",
    constitution = "constitution",
    curseward = "curseward",
    deafness = "deaf",
    deathaura = "deathaura",
    deathsight = "deathsight",
    deflect = "deflect",
    deliverance = false,
    demonarmour = "armour",
    demonfury = false,
    density = "mass",
    devilmark = "devilmark",
    diamondskin = "diamondskin",
    disassociate = false,
    distortedaura = "distortedaura",
    disperse = "disperse",
    dodging = "dodging",
    dragonarmour = "dragonarmour",
    dragonbreath = "dragonbreath",
    drunkensailor = "drunkensailor",
    durability = "tsuura",
    earthshield = "earthblessing",
    eavesdropping = "eavesdrop",
    electricresist = "electricresist",
    elusiveness = "elusiveness",
    enduranceblessing = "enduranceblessing",
    enhancedform = false,
    evadeblock = "evadeblock",
    evasion = false,
    extispicy = "extispicy",
    fangbarrier = "sileris",
    firefly = false,
    fireresist = "fireresist",
    firstaid = "firstaid",
    flailingstaff = "flail",
    fleetness = "fleetness",
    frenzied = false,
    frostshield = "frostblessing",
    fury = false,
    ghost = "ghost",
    golgothagrace = "golgotha",
    gripping = "grip",
    groundwatch = "groundwatch",
    harmony = "harmony",
    haste = false,
    heartsfury = "heartsfury",
    heldbreath = "breath",
    heresy = "heresy",
    hiding = "hiding",
    hypersense = "hypersense",
    hypersight = "hypersight",
    immunity = "immunity",
    insomnia = "insomnia",
    inspiration = "inspiration",
    insuflate = false,
    insulation = false,
    ironform = false,
    ironwill = "qamad",
    kaiboost = "kaiboost",
    kaitrance = "trance",
    kola = "kola",
    lament = false,
    lay = "lay",
    levitating = "levitation",
    lifegiver = false,
    lifesteal = false,
    lifevision = "lifevision",
    lipreading = "lipread",
    magicresist = "magicresist",
    megalithtattoo = false,
    mercury = "mercury",
    metawake = "metawake",
    mindcloak = "mindcloak",
    mindnet = "mindnet",
    mindseye = "mindseye",
    mindtelesense = "mindtelesense",
    moontattoo = false,
    morph = false,
    mosstattoo = false,
    nightsight = "nightsight",
    numbness = "numb",
    oxtattoo = false,
    pacing = "pacing",
    panacea = "panacea",
    phased = "phase",
    pinchblock = "pinchblock",
    poisonresist = "venom",
    preachblessing = false,
    precision = "trusad",
    prismatic = "lyre",
    projectiles = "projectiles",
    promosurcoat = false,
    putrefaction = "putrefaction",
    rebounding = "rebounding",
    reflections = "reflection",
    reflexes = false,
    regeneration = "regeneration",
    resistance = "resistance",
    retaliation = "retaliationstrike",
    satiation = "satiation",
    scales = "scales",
    scholasticism = "myrrh",
    scouting = "scout",
    secondsight = "secondsight",
    selfishness = "selfishness",
    setweapon = "impaling",
    shadowveil = "shadowveil",
    shield = "shield",
    shikudoform = false,
    shinbinding = "bind",
    shinclarity = "clarity",
    shinrejoinder = false,
    shintrance = "shintrance",
    shipwarning = "shipwarning",
    skywatch = "skywatch",
    slippery = "slipperiness",
    softfocusing = "softfocus",
    songbird = "songbird",
    soulcage = "soulcage",
    speed = "speed",
    spinning = "spinning",
    spinningstaff = false,
    spiritbonded = "bonding",
    spiritwalk = false,
    splitmind = "splitmind",
    standingfirm = "sturdiness",
    starburst = "starburst",
    stealth = "stealth",
    stonefist = "stonefist",
    stoneskin = "stoneskin",
    sulphur = "sulphur",
    swiftcurse = "swiftcurse",
    tekurastance = false,
    telesense = "telesense",
    temperance = "frost",
    tentacles = "tentacles",
    thermalshield = "thermalblessing",
    thirdeye = "thirdeye",
    tin = "tin",
    toughness = "toughness",
    treewatch = "treewatch",
    truestare = "truestare",
    tune = "tune",
    twoartsstance = false,
    vengeance = "vengeance",
    vigilance = "vigilance",
    vigour = "vigour",
    viridian = "viridian",
    vitality = "vitality",
    ward = false,
    waterwalking = "waterwalk",
    weakvigour = false,
    weathering = "weathering",
    weaving = "weaving",
    wildgrowth = "wildgrowth",
    willpowerblessing = "willpowerblessing",
    xporb = false,
  },
  svotossa = {},
  svotossd = {}
} -- end of dict

if svo.haveskillset('subterfuge') then
  svo.dict.sstosvod.shroud = "cloaking"
else
  svo.dict.sstosvod.shroud = "shroud"
end

if svo.haveskillset('weaponmastery') then
  svo.dict.prone.misc.actions = {"stand", "recover footing"}
else
  svo.dict.prone.misc.action = "stand"
end

-- undeffable since serverside can't morph to get a specific defence up
if svo.haveskillset('metamorphosis') then
  svo.dict.nightsight.physical.undeffable = true
end

if svo.haveskillset('shindo') then
  svo.dict.deaf.misc = {
    aspriority = 0,
    spriority = 0,
    def = true,

    isadvisable = function ()
      return (not defc.deaf and conf.shindodeaf and not defc.dragonform and ((sys.deffing and defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf)) and not svo.doingaction("waitingondeaf")) or false
    end,

    oncompleted = function ()
      svo.doaction(svo.dict.waitingondeaf.waitingfor)
    end,

    action = "deaf",
    onstart = function ()
      send("deaf", conf.commandecho)
    end
  }
end
if svo.haveskillset('kaido') then
  svo.dict.deaf.misc = {
    aspriority = 0,
    spriority = 0,
    def = true,

    isadvisable = function ()
      return (not defc.deaf and conf.kaidodeaf and not defc.dragonform and ((sys.deffing and defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf)) and not svo.doingaction("waitingondeaf")) or false
    end,

    oncompleted = function ()
      svo.doaction(svo.dict.waitingondeaf.waitingfor)
    end,

    action = "deaf",
    onstart = function ()
      send("deaf", conf.commandecho)
    end
  }
end
if svo.haveskillset('shindo') then
  svo.dict.blind.misc = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (conf.shindoblind and not defc.dragonform and ((sys.deffing and defdefup[defs.mode].blind and not defc.blind) or (conf.keepup and defkeepup[defs.mode].blind and not defc.blind)) and not svo.doingaction"waitingonblind") or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.waitingonblind.waitingfor)
      end,

      action = "blind",
      onstart = function ()
        send("blind", conf.commandecho)
      end
    }
end
if svo.haveskillset('kaido') then
  svo.dict.blind.misc = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (conf.kaidoblind and not defc.dragonform and ((sys.deffing and defdefup[defs.mode].blind and not defc.blind) or (conf.keepup and defkeepup[defs.mode].blind and not defc.blind)) and not svo.doingaction"waitingonblind") or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.waitingonblind.waitingfor)
      end,

      action = "blind",
      onstart = function ()
        send("blind", conf.commandecho)
      end
    }
end


-- skillset-specific defences
if svo.haveskillset('necromancy') then
  svo.dict.lifevision = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.lifevision and ((sys.deffing and defdefup[defs.mode].lifevision) or (conf.keepup and defkeepup[defs.mode].lifevision)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.prone and stats.currentmana >= 600) or false
      end,

      oncompleted = function ()
        defences.got("lifevision")
      end,

      action = "lifevision",
      onstart = function ()
        send("lifevision", conf.commandecho)
      end
    }
  }
end


if svo.haveskillset('devotion') then
  svo.dict.frostblessing = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.frostblessing and ((sys.deffing and defdefup[defs.mode].frostblessing) or (conf.keepup and defkeepup[defs.mode].frostblessing)) and not codepaste.balanceful_defs_codepaste() and not affs.prone and defc.air and defc.water and stats.currentmana >= 750) or false
      end,

      oncompleted = function ()
        defences.got("frostblessing")
      end,

      action = "bless me spiritshield frost",
      onstart = function ()
        send("bless me spiritshield frost", conf.commandecho)
      end
    }
  }
  svo.dict.willpowerblessing = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.willpowerblessing and ((sys.deffing and defdefup[defs.mode].willpowerblessing) or (conf.keepup and defkeepup[defs.mode].willpowerblessing)) and not codepaste.balanceful_defs_codepaste() and not affs.prone and defc.air and defc.water and defc.fire and stats.currentmana >= 750) or false
      end,

      oncompleted = function ()
        defences.got("willpowerblessing")
      end,

      action = "bless me willpower",
      onstart = function ()
        send("bless me willpower", conf.commandecho)
      end
    }
  }
  svo.dict.thermalblessing = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.thermalblessing and ((sys.deffing and defdefup[defs.mode].thermalblessing) or (conf.keepup and defkeepup[defs.mode].thermalblessing)) and not codepaste.balanceful_defs_codepaste() and not affs.prone and defc.spirit and defc.fire and stats.currentmana >= 750) or false
      end,

      oncompleted = function ()
        defences.got("thermalblessing")
      end,

      action = "bless me spiritshield thermal",
      onstart = function ()
        send("bless me spiritshield thermal", conf.commandecho)
      end
    }
  }
  svo.dict.earthblessing = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.earthblessing and ((sys.deffing and defdefup[defs.mode].earthblessing) or (conf.keepup and defkeepup[defs.mode].earthblessing)) and not codepaste.balanceful_defs_codepaste() and not affs.prone and defc.earth and defc.water and defc.fire and stats.currentmana >= 750) or false
      end,

      oncompleted = function ()
        defences.got("earthblessing")
      end,

      action = "bless me spiritshield earth",
      onstart = function ()
        send("bless me spiritshield earth", conf.commandecho)
      end
    }
  }
  svo.dict.enduranceblessing = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.enduranceblessing and ((sys.deffing and defdefup[defs.mode].enduranceblessing) or (conf.keepup and defkeepup[defs.mode].enduranceblessing)) and not codepaste.balanceful_defs_codepaste() and not affs.prone and defc.air and defc.earth and defc.water and defc.fire and stats.currentmana >= 750) or false
      end,

      oncompleted = function ()
        defences.got("enduranceblessing")
      end,

      action = "bless me endurance",
      onstart = function ()
        send("bless me endurance", conf.commandecho)
      end
    }
  }
end

if svo.haveskillset('spirituality') then
  svo.dict.mace = {
    physical = {
      aspriority = 0,
      spriority = 0,
      unpauselater = false,
      balanceful_act = true, -- it is balanceless, but this causes it to be bundled with a balanceful action - not desired
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].mace and not defc.mace) or (conf.keepup and defkeepup[defs.mode].mace and not defc.mace)) and not svo.doingaction("waitingformace") and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.waitingformace.waitingfor)
      end,

      alreadyhave = function ()
        svo.dict.waitingformace.waitingfor.oncompleted()
        send("wield mace", conf.commandecho)
      end,

      action = "summon mace",
      onstart = function ()
      -- user commands catching needs this check
        if not (bals.balance and bals.equilibrium) then return end

        send("summon mace", conf.commandecho)

        if not conf.paused then
          svo.dict.mace.physical.unpauselater = true
          conf.paused = true; raiseEvent("svo config changed", "paused")
          echo"\n" svo.echof("Temporarily pausing to summon the mace.")
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("mace")
      end,
    }
  }
  svo.dict.waitingformace = {
    spriority = 0,
    waitingfor = {
      customwait = 3,

      oncompleted = function ()
        defences.got("mace")

        if conf.paused and svo.dict.mace.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")

          svo.echof("Obtained mace, unpausing.")
        end
        svo.dict.mace.physical.unpauselater = false
      end,

      cancelled = function ()
        if conf.paused and svo.dict.mace.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          svo.echof("Oops, summoning interrupted. Unpausing.")
        end
        svo.dict.mace.physical.unpauselater = false
      end,

      ontimeout = function()
        if conf.paused and svo.dict.mace.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          svo.echof("Hm... doesn't seem the mace summon is happening. Going to try again.")
        end
        svo.dict.mace.physical.unpauselater = false
      end,

      onstart = function() end
    }
  }
  svo.dict.sacrifice = {
    description = "tracks whenever you've sent the angel sacrifice command - so an illusion on angel sacrifice won't trick the system into clearing all affs",
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return false
      end,

      oncompleted = function ()
      end,

      action = "angel sacrifice",
      onstart = function ()
        send("angel sacrifice", conf.commandecho)
      end
    }
  }
  svo.dict.summon = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.summon and ((sys.deffing and defdefup[defs.mode].summon) or (conf.keepup and defkeepup[defs.mode].summon)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("summon")
      end,

      action = "angel summon",
      onstart = function ()
        send("angel summon", conf.commandecho)
      end
    }
  }
  svo.dict.empathy = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.empathy and ((sys.deffing and defdefup[defs.mode].empathy) or (conf.keepup and defkeepup[defs.mode].empathy)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and defc.summon) or false
      end,

      oncompleted = function ()
        defences.got("empathy")
      end,

      action = "angel empathy on",
      onstart = function ()
        send("angel empathy on", conf.commandecho)
      end
    }
  }
  svo.dict.watch = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.watch and ((sys.deffing and defdefup[defs.mode].watch) or (conf.keepup and defkeepup[defs.mode].watch)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and defc.summon) or false
      end,

      oncompleted = function ()
        defences.got("watch")
      end,

      action = "angel watch on",
      onstart = function ()
        send("angel watch on", conf.commandecho)
      end
    }
  }
  svo.dict.care = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.care and ((sys.deffing and defdefup[defs.mode].care) or (conf.keepup and defkeepup[defs.mode].care)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and defc.summon) or false
      end,

      oncompleted = function ()
        defences.got("care")
      end,

      action = "angel care on",
      onstart = function ()
        send("angel care on", conf.commandecho)
      end
    }
  }
end

if svo.haveskillset('shindo') then
  svo.dict.phoenix = {
    description = "tracks whenever you've sent the shindo phoenix command - so an illusion on shindo phoenix won't trick the system into clearing all affs",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return false
      end,

      oncompleted = function ()
      end,

      action = "shin phoenix",
      onstart = function ()
        send("shin phoenix", conf.commandecho)
      end
    }
  }
end

if svo.haveskillset('twoarts') then
  svo.dict.doya = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].doya and not defc.doya) or (conf.keepup and defkeepup[defs.mode].doya and not defc.doya)) and not defc.thyr and not defc.mir and not defc.arash and not defc.sanya and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"doya", "thyr", "mir", "arash", "sanya"} do
          defences.lost(stance)
        end

        defences.got("doya")
      end,

      action = "doya",
      onstart = function ()
        send("doya", conf.commandecho)
      end
    },
  }
  svo.dict.thyr = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].thyr and not defc.thyr) or (conf.keepup and defkeepup[defs.mode].thyr)) and not defc.doya and not defc.thyr and not defc.mir and not defc.arash and not defc.sanya and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"doya", "thyr", "mir", "arash", "sanya"} do
          defences.lost(stance)
        end

        defences.got("thyr")
      end,

      action = "thyr",
      onstart = function ()
        send("thyr", conf.commandecho)
      end
    },
  }
  svo.dict.mir = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].mir and not defc.mir) or (conf.keepup and defkeepup[defs.mode].mir)) and not defc.doya and not defc.thyr and not defc.mir and not defc.arash and not defc.sanya and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"doya", "thyr", "mir", "arash", "sanya"} do
          defences.lost(stance)
        end

        defences.got("mir")
      end,

      action = "mir",
      onstart = function ()
        send("mir", conf.commandecho)
      end
    },
  }
  svo.dict.arash = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].arash and not defc.arash) or (conf.keepup and defkeepup[defs.mode].arash)) and not defc.doya and not defc.thyr and not defc.mir and not defc.arash and not defc.sanya and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"doya", "thyr", "mir", "arash", "sanya"} do
          defences.lost(stance)
        end

        defences.got("arash")
      end,

      action = "arash",
      onstart = function ()
        send("arash", conf.commandecho)
      end
    },
  }
  svo.dict.sanya = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].sanya and not defc.sanya) or (conf.keepup and defkeepup[defs.mode].sanya)) and not defc.doya and not defc.thyr and not defc.mir and not defc.arash and not defc.sanya and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"doya", "thyr", "mir", "arash", "sanya"} do
          defences.lost(stance)
        end

        defences.got("sanya")
      end,

      action = "sanya",
      onstart = function ()
        send("sanya", conf.commandecho)
      end
    },
  }
end

if svo.haveskillset('metamorphosis') then
  svo.dict.affinity = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.affinity and ((sys.deffing and defdefup[defs.mode].affinity) or (conf.keepup and defkeepup[defs.mode].affinity)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("affinity")
      end,

      action = "embrace spirit",
      onstart = function ()
        if sk.inamorph() then
          send("embrace spirit", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end

          if sk.skillmorphs.wyvern then
            send("morph wyvern", conf.commandecho)
          else
            send("morph "..sk.morphsforskill.nightsight[1], conf.commandecho)
          end
        end
      end
    }
  }
  svo.dict.fitness = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        if not (not affs.weakness and not defc.dragonform and bals.fitness and not codepaste.balanceful_defs_codepaste() and (defc.wyvern or defc.wolf or defc.hyena or defc.jaguar or defc.cheetah or defc.elephant or defc.hydra) and not affs.cantmorph and sk.morphsforskill.fitness) then
          return false
        end

        for name, func in pairs(svo.fitness) do
          if not me.disabledfitnessfunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function ()
        svo.rmaff("asthma")
        svo.lostbal_fitness()
      end,

      curedasthma = function ()
        svo.rmaff("asthma")
      end,

      weakness = function ()
        svo.addaffdict(svo.dict.weakness)
      end,

      allgood = function()
        svo.rmaff("asthma")
      end,

      actions = {"fitness"},
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"fitness" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"fitness" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.fitness[1], conf.commandecho)
        elseif sk.inamorphfor"fitness" then
          send("fitness", conf.commandecho)
        end
      end
    },
  }
  svo.dict.elusiveness = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.elusiveness and ((sys.deffing and defdefup[defs.mode].elusiveness) or (conf.keepup and defkeepup[defs.mode].elusiveness)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.elusiveness) or false
      end,

      oncompleted = function ()
        defences.got("elusiveness")
      end,

      action = "elusiveness on",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"elusiveness" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"elusiveness" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.elusiveness[1], conf.commandecho)
        elseif sk.inamorphfor"elusiveness" then
          send("elusiveness on", conf.commandecho)
        end
      end
    },
  }
  svo.dict.temperance = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.temperance and ((sys.deffing and defdefup[defs.mode].temperance) or (conf.keepup and defkeepup[defs.mode].temperance)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.temperance) or false
      end,

      oncompleted = function ()
        defences.got("temperance")
        defences.got("frost")
      end,

      action = "temperance",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"temperance" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"temperance" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.temperance[1], conf.commandecho)
        elseif sk.inamorphfor"temperance" then
          send("temperance", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("frost")
      end
    }
  }
  svo.dict.stealth = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.stealth and ((sys.deffing and defdefup[defs.mode].stealth) or (conf.keepup and defkeepup[defs.mode].stealth)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.stealth) or false
      end,

      oncompleted = function ()
        defences.got("stealth")
      end,

      action = "stealth on",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"stealth" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"stealth" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.stealth[1], conf.commandecho)
        elseif sk.inamorphfor"stealth" then
          send("stealth on", conf.commandecho)
        end
      end
    },
  }
  svo.dict.resistance = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.resistance and ((sys.deffing and defdefup[defs.mode].resistance) or (conf.keepup and defkeepup[defs.mode].resistance)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.resistance) or false
      end,

      oncompleted = function ()
        defences.got("resistance")
      end,

      action = "resistance",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"resistance" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"resistance" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.resistance[1], conf.commandecho)
        elseif sk.inamorphfor"resistance" then
          send("resistance", conf.commandecho)
        end
      end
    },
  }
  svo.dict.rest = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.rest and ((sys.deffing and defdefup[defs.mode].rest) or (conf.keepup and defkeepup[defs.mode].rest)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.rest) or false
      end,

      oncompleted = function ()
        defences.got("rest")
      end,

      action = "rest",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"rest" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"rest" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.rest[1], conf.commandecho)
        elseif sk.inamorphfor"rest" then
          send("rest", conf.commandecho)
        end
      end
    },
  }
  svo.dict.vitality = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        if (not defc.vitality and ((sys.deffing and defdefup[defs.mode].vitality) or (conf.keepup and defkeepup[defs.mode].vitality)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.vitality and not svo.doingaction"cantvitality") then

         if (stats.currenthealth >= stats.maxhealth and stats.currentmana >= stats.maxmana)
          then
            return true
          elseif not sk.gettingfullstats then
            svo.fullstats(true)
            svo.echof("Getting fullstats for vitality now...")
          end
        end
      end,

      oncompleted = function ()
        defences.got("vitality")
      end,

      action = "vitality",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"vitality" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"vitality" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.vitality[1], conf.commandecho)
        elseif sk.inamorphfor"vitality" then
          send("vitality", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("vitality")
        if not svo.actions.cantvitality_waitingfor then svo.doaction(svo.dict.cantvitality.waitingfor) end
      end
    }
  }
  -- nightsight = {
  --   physical = {
  --     aspriority = 0,
  --     spriority = 0,
  --     balanceful_act = true,
  --     def = true,

  --     isadvisable = function ()
  --       return (not defc.nightsight and ((sys.deffing and defdefup[defs.mode].nightsight) or (conf.keepup and defkeepup[defs.mode].nightsight)) and not codepaste.balanceful_defs_codepaste() and ((not affs.cantmorph and sk.morphsforskill.nightsight) or defc.dragonform)) or false
  --     end,

  --     oncompleted = function ()
  --       defences.got("nightsight")
  --     end,

  --     action = "nightsight on",
  --     onstart = function ()
  --       if not defc.dragonform and (not conf.transmorph and sk.inamorph() and not sk.inamorphfor"nightsight") then
  --         if defc.flame then send("relax flame", conf.commandecho) end
  --         send("human", conf.commandecho)
  --       elseif not defc.dragonform and not sk.inamorphfor"nightsight" then
  --         if defc.flame then send("relax flame", conf.commandecho) end
  --         send("morph "..sk.morphsforskill.nightsight[1], conf.commandecho)
  --       elseif defc.dragonform or sk.inamorphfor"nightsight" then
  --         send("nightsight on", conf.commandecho)
  --       end
  --     end
  --   },
  -- },
  svo.dict.flame = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.flame and ((sys.deffing and defdefup[defs.mode].flame) or (conf.keepup and defkeepup[defs.mode].flame)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.flame) or false
      end,

      oncompleted = function ()
        defences.got("flame")
      end,

      actions = {"summon flame", "summon fire"},
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"flame" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"flame" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.flame[1], conf.commandecho)
        elseif sk.inamorphfor"flame" then
          send("summon flame", conf.commandecho)
        end
      end
    },
  }
  svo.dict.squirrel = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.squirrel and ((sys.deffing and defdefup[defs.mode].squirrel) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].squirrel)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("squirrel")
      end,

      action = "morph squirrel",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph squirrel", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("squirrel")
      end,
    }
  }
  svo.dict.wildcat = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.wildcat and ((sys.deffing and defdefup[defs.mode].wildcat) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].wildcat)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("wildcat")
      end,

      action = "morph wildcat",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph wildcat", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("wildcat")
      end,
    }
  }
  svo.dict.wolf = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.wolf and ((sys.deffing and defdefup[defs.mode].wolf) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].wolf)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("wolf")
      end,

      action = "morph wolf",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph wolf", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("wolf")
      end,
    }
  }
  svo.dict.turtle = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.turtle and ((sys.deffing and defdefup[defs.mode].turtle) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].turtle)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("turtle")
      end,

      action = "morph turtle",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph turtle", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("turtle")
      end,
    }
  }
  svo.dict.jackdaw = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.jackdaw and ((sys.deffing and defdefup[defs.mode].jackdaw) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].jackdaw)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("jackdaw")
      end,

      action = "morph jackdaw",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph jackdaw", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("jackdaw")
      end,
    }
  }
  svo.dict.cheetah = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.cheetah and ((sys.deffing and defdefup[defs.mode].cheetah) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].cheetah)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("cheetah")
      end,

      action = "morph cheetah",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph cheetah", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("cheetah")
      end,
    }
  }
  svo.dict.owl = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.owl and ((sys.deffing and defdefup[defs.mode].owl) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].owl)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("owl")
      end,

      action = "morph owl",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph owl", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("owl")
      end,
    }
  }
  svo.dict.hyena = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.hyena and ((sys.deffing and defdefup[defs.mode].hyena) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].hyena)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("hyena")
      end,

      action = "morph hyena",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph hyena", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("hyena")
      end,
    }
  }
  svo.dict.condor = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.condor and ((sys.deffing and defdefup[defs.mode].condor) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].condor)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("condor")
      end,

      action = "morph condor",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph condor", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("condor")
      end,
    }
  }
  svo.dict.gopher = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.gopher and ((sys.deffing and defdefup[defs.mode].gopher) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].gopher)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("gopher")
      end,

      action = "morph gopher",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph gopher", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("gopher")
      end,
    }
  }
  svo.dict.sloth = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.sloth and ((sys.deffing and defdefup[defs.mode].sloth) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].sloth)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("sloth")
      end,

      action = "morph sloth",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph sloth", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("sloth")
      end,
    }
  }
  svo.dict.bear = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.bear and ((sys.deffing and defdefup[defs.mode].bear) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].bear)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("bear")
      end,

      action = "morph bear",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph bear", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("bear")
      end,
    }
  }
  svo.dict.nightingale = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.nightingale and ((sys.deffing and defdefup[defs.mode].nightingale) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].nightingale)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("nightingale")
      end,

      action = "morph nightingale",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph nightingale", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("nightingale")
      end,
    }
  }
  svo.dict.elephant = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.elephant and ((sys.deffing and defdefup[defs.mode].elephant) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].elephant)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("elephant")
      end,

      action = "morph elephant",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph elephant", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("elephant")
      end,
    }
  }
  svo.dict.wolverine = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.wolverine and ((sys.deffing and defdefup[defs.mode].wolverine) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].wolverine)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("wolverine")
      end,

      action = "morph wolverine",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph wolverine", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("wolverine")
      end,
    }
  }
  svo.dict.eagle = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.eagle and ((sys.deffing and defdefup[defs.mode].eagle) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].eagle)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("eagle")
      end,

      action = "morph eagle",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph eagle", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("eagle")
      end,
    }
  }
  svo.dict.gorilla = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.gorilla and ((sys.deffing and defdefup[defs.mode].gorilla) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].gorilla)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("gorilla")
      end,

      action = "morph gorilla",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph gorilla", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("gorilla")
      end,
    }
  }
  svo.dict.icewyrm = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.icewyrm and ((sys.deffing and defdefup[defs.mode].icewyrm) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].icewyrm)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("icewyrm")
      end,

      action = "morph icewyrm",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph icewyrm", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("icewyrm")
      end,
    }
  }
end

if svo.haveskillset('swashbuckling') then
  svo.dict.drunkensailor = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return ((sys.deffing and defdefup[defs.mode].drunkensailor and not defc.drunkensailor) or (conf.keepup and defkeepup[defs.mode].drunkensailor and not defc.drunkensailor) and not defc.heartsfury and not svo.doingaction"drunkensailor" and not affs.paralysis) or false
      end,

      oncompleted = function ()
        defences.got("drunkensailor")
      end,

      action = "drunkensailor",
      onstart = function ()
        send("drunkensailor", conf.commandecho)
      end
    },
  }
  svo.dict.heartsfury = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return ((sys.deffing and defdefup[defs.mode].heartsfury and not defc.heartsfury) or (conf.keepup and defkeepup[defs.mode].heartsfury and not defc.heartsfury) and not defc.drunkensailor and not svo.doingaction"heartsfury" and not affs.paralysis) or false
      end,

      oncompleted = function ()
        defences.got("heartsfury")
      end,

      action = "heartsfury",
      onstart = function ()
        send("heartsfury", conf.commandecho)
      end
    },
  }
end

if svo.haveskillset('voicecraft') then
  svo.dict.lay = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].lay and not defc.lay) or (conf.keepup and defkeepup[defs.mode].lay and not defc.lay)) and not codepaste.balanceful_defs_codepaste() and not svo.doingaction"lay" and bals.voice) or false
      end,

      oncompleted = function ()
        defences.got("lay")
        svo.lostbal_voice()
      end,

      action = "sing lay",
      onstart = function ()
        send("sing lay", conf.commandecho)
      end
    },
  }
  svo.dict.tune = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].tune and not defc.tune) or (conf.keepup and defkeepup[defs.mode].tune and not defc.tune)) and not codepaste.balanceful_defs_codepaste() and not svo.doingaction"tune" and bals.voice) or false
      end,

      oncompleted = function ()
        defences.got("tune")
        svo.lostbal_voice()
      end,

      action = "sing tune",
      onstart = function ()
        send("sing tune", conf.commandecho)
      end
    },
  }
  svo.dict.aria = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].aria and not defc.aria) or (conf.keepup and defkeepup[defs.mode].aria and not defc.aria)) and not codepaste.balanceful_defs_codepaste() and not svo.doingaction"aria" and bals.voice and not affs.deafaff and not defc.deaf) or false
      end,

      oncompleted = function ()
        defences.got("aria")
        svo.lostbal_voice()
      end,

      action = "sing aria at me",
      onstart = function ()
        send("sing aria at me", conf.commandecho)
      end
    },
  }
end

if svo.haveskillset('occultism') then
  svo.dict.astralform = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.astralform and ((sys.deffing and defdefup[defs.mode].astralform) or (conf.keepup and defkeepup[defs.mode].astralform)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("astralform")
        defences.lost("riding")
      end,

      action = "astralform",
      onstart = function ()
        send("astralform", conf.commandecho)
      end
    }
  }
end

if svo.haveskillset('healing') then
  svo.dict.bedevil = {
    gamename = "bedevilaura",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.bedevil and ((sys.deffing and defdefup[defs.mode].bedevil) or (conf.keepup and defkeepup[defs.mode].bedevil)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone and defc.air and defc.water and defc.fire and defc.earth and defc.spirit) or false
      end,

      oncompleted = function ()
        defences.got("bedevil")
      end,

      action = "bedevil",
      onstart = function ()
        send("bedevil", conf.commandecho)
      end
    }
  }
end

if svo.haveskillset('healing') or svo.haveskillset('elementalism') or svo.haveskillset('weatherweaving') then
  svo.dict.simultaneity = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.simultaneity and ((sys.deffing and defdefup[defs.mode].simultaneity) or (conf.keepup and defkeepup[defs.mode].simultaneity)) and not codepaste.balanceful_defs_codepaste() and stats.currentmana >= 1000) or false
      end,

      oncompleted = function ()
        defences.got("simultaneity")
      end,

      action = "simultaneity",
      onstart = function ()
        send("simultaneity", conf.commandecho)
      end
    }
  }
  svo.dict.air = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.air and ((sys.deffing and defdefup[defs.mode].air) or (conf.keepup and defkeepup[defs.mode].air)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("air")
        if defc.air and defc.earth and defc.water and (not svo.haveskillset('healing') or defc.spirit)
        and (svo.haveskillset('weatherweaving') or defc.fire) then
          defences.got("simultaneity")
        end
      end,

      action = "channel air",
      onstart = function ()
        send("channel air", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("air")
        defences.lost("simultaneity")
      end
    }
  }
  svo.dict.water = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.water and ((sys.deffing and defdefup[defs.mode].water) or (conf.keepup and defkeepup[defs.mode].water)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("water")
        if defc.air and defc.earth and defc.water and (not svo.haveskillset('healing') or defc.spirit)
        and (svo.haveskillset('weatherweaving') or defc.fire) then
          defences.got("simultaneity")
        end
      end,

      action = "channel water",
      onstart = function ()
        send("channel water", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("water")
        defences.lost("simultaneity")
      end
    }
  }
  svo.dict.earth = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.earth and ((sys.deffing and defdefup[defs.mode].earth) or (conf.keepup and defkeepup[defs.mode].earth)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("earth")
        if defc.air and defc.earth and defc.water and (not svo.haveskillset('healing') or defc.spirit)
        and (svo.haveskillset('weatherweaving') or defc.fire) then
          defences.got("simultaneity")
        end
      end,

      action = "channel earth",
      onstart = function ()
        send("channel earth", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("earth")
        defences.lost("simultaneity")
      end
    }
  }
if not svo.haveskillset('weatherweaving') then
  svo.dict.fire = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.fire and ((sys.deffing and defdefup[defs.mode].fire) or (conf.keepup and defkeepup[defs.mode].fire)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("fire")
        if defc.air and defc.fire and defc.earth and defc.water and (not svo.haveskillset('healing') or defc.spirit) then
          defences.got("simultaneity")
        end
      end,

      action = "channel fire",
      onstart = function ()
        send("channel fire", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("fire")
        defences.lost("simultaneity")
      end
    }
  }
end
if svo.haveskillset('healing') then
  svo.dict.spirit = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].spirit and not defc.spirit) or (conf.keepup and defkeepup[defs.mode].spirit and not defc.spirit))) or (conf.keepup and defkeepup[defs.mode].spirit and not defc.spirit)) and not codepaste.balanceful_defs_codepaste() and defc.air and defc.fire and defc.water and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("spirit")
        if defc.air and defc.fire and defc.earth and defc.water and defc.spirit then
          defences.got("simultaneity")
        end
      end,

      action = "channel spirit",
      onstart = function ()
        send("channel spirit", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("spirit")
        defences.lost("simultaneity")
      end
    }
  }
end
  svo.dict.bindall = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].bindall and not defc.bindall) or (conf.keepup and defkeepup[defs.mode].bindall and not defc.bindall))) or (conf.keepup and defkeepup[defs.mode].bindall and not defc.bindall)) and not codepaste.balanceful_defs_codepaste() and stats.currentmana >= 750 and defc.air and defc.earth and defc.water and (not svo.haveskillset('healing') or defc.spirit)
        and (svo.haveskillset('weatherweaving') or defc.fire)) or false
      end,

      oncompleted = function ()
        defences.got("bindall")
      end,

      action = "bind all",
      onstart = function ()
        send("bind all", conf.commandecho)
      end
    }
  }
  svo.dict.boundair = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].boundair and not defc.boundair) or (conf.keepup and defkeepup[defs.mode].boundair and not defc.boundair))) or (conf.keepup and defkeepup[defs.mode].boundair and not defc.boundair)) and not codepaste.balanceful_defs_codepaste() and defc.air) or false
      end,

      oncompleted = function ()
        defences.got("boundair")
        if defc.boundair and defc.boundearth and defc.boundwater and (not svo.haveskillset('healing') or defc.boundspirit) and (svo.haveskillset('weatherweaving') or defc.boundfire) then
          defences.got("bindall")
        end
      end,

      action = "bind air",
      onstart = function ()
        send("bind air", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("boundair")
        defences.lost("bindall")
      end
    }
  }
  svo.dict.boundwater = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].boundwater and not defc.boundwater) or (conf.keepup and defkeepup[defs.mode].boundwater and not defc.boundwater))) or (conf.keepup and defkeepup[defs.mode].boundwater and not defc.boundwater)) and not codepaste.balanceful_defs_codepaste() and defc.water) or false
      end,

      oncompleted = function ()
        defences.got("boundwater")
        if defc.boundair and defc.boundearth and defc.boundwater and (not svo.haveskillset('healing') or defc.boundspirit) and (svo.haveskillset('weatherweaving') or defc.boundfire) then
          defences.got("bindall")
        end
      end,

      action = "bind water",
      onstart = function ()
        send("bind water", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("boundwater")
        defences.lost("bindall")
      end
    }
  }
  if not svo.haveskillset('weatherweaving') then
    svo.dict.boundfire = {
      physical = {
        balanceful_act = true,
        aspriority = 0,
        spriority = 0,
        def = true,
        undeffable = true,

        isadvisable = function ()
          return (((((sys.deffing and defdefup[defs.mode].boundfire and not defc.boundfire) or (conf.keepup and defkeepup[defs.mode].boundfire and not defc.boundfire))) or (conf.keepup and defkeepup[defs.mode].boundfire and not defc.boundfire)) and not codepaste.balanceful_defs_codepaste() and defc.fire) or false
        end,

        oncompleted = function ()
          defences.got("boundfire")
          if defc.boundair and defc.boundfire and defc.boundearth and defc.boundwater and (not svo.haveskillset('healing') or defc.boundspirit) then
            defences.got("bindall")
          end
        end,

        action = "bind fire",
        onstart = function ()
          send("bind fire", conf.commandecho)
        end
      },
      gone = {
        oncompleted = function ()
          defences.lost("boundfire")
          defences.lost("bindall")
        end
      }
    }
  end
  svo.dict.boundearth = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].boundearth and not defc.boundearth) or (conf.keepup and defkeepup[defs.mode].boundearth and not defc.boundearth))) or (conf.keepup and defkeepup[defs.mode].boundearth and not defc.boundearth)) and not codepaste.balanceful_defs_codepaste() and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("boundearth")
        if defc.boundair and defc.boundearth and defc.boundwaterand (not svo.haveskillset('healing') or defc.boundspirit) and (svo.haveskillset('weatherweaving') or defc.boundfire) then
          defences.got("bindall")
        end
      end,

      action = "bind earth",
      onstart = function ()
        send("bind earth", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("boundearth")
        defences.lost("bindall")
      end
    }
  }
  if svo.haveskillset('healing') then
    svo.dict.boundspirit = {
      physical = {
        balanceful_act = true,
        aspriority = 0,
        spriority = 0,
        def = true,
        undeffable = true,

        isadvisable = function ()
          return (((((sys.deffing and defdefup[defs.mode].boundspirit and not defc.boundspirit) or (conf.keepup and defkeepup[defs.mode].boundspirit and not defc.boundspirit))) or (conf.keepup and defkeepup[defs.mode].boundspirit and not defc.boundspirit)) and not codepaste.balanceful_defs_codepaste() and defc.spirit) or false
        end,

        oncompleted = function ()
          defences.got("boundspirit")
          if defc.boundair and defc.boundfire and defc.boundearth and defc.boundwater and defc.boundspirit then
            defences.got("bindall")
          end
        end,

        action = "bind spirit",
        onstart = function ()
          send("bind spirit", conf.commandecho)
        end
      },
      gone = {
        oncompleted = function ()
          defences.lost("boundspirit")
          defences.lost("bindall")
        end
      }
    }
  end
  svo.dict.fortifyall = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].fortifyall and not defc.fortifyall) or (conf.keepup and defkeepup[defs.mode].fortifyall and not defc.fortifyall))) or (conf.keepup and defkeepup[defs.mode].fortifyall and not defc.fortifyall)) and not codepaste.balanceful_defs_codepaste() and stats.currentmana >= 600 and defc.air and defc.earth and defc.water and (not svo.haveskillset('healing') or defc.spirit) and (svo.haveskillset('weatherweaving') or defc.fire)) or false
      end,

      oncompleted = function ()
        defences.got("fortifyall")
      end,

      action = "fortify all",
      onstart = function ()
        send("fortify all", conf.commandecho)
      end
    }
  }
  svo.dict.fortifiedair = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].fortifiedair and not defc.fortifiedair) or (conf.keepup and defkeepup[defs.mode].fortifiedair and not defc.fortifiedair))) or (conf.keepup and defkeepup[defs.mode].fortifiedair and not defc.fortifiedair)) and not codepaste.balanceful_defs_codepaste() and defc.air) or false
      end,

      oncompleted = function ()
        defences.got("fortifiedair")
        if defc.fortifiedair and defc.fortifiedearth and defc.fortifiedwaterand and (not svo.haveskillset('healing') or defc.fortifiedspirit) and (svo.haveskillset('weatherweaving') or defc.fortifiedfire) then
          defences.got("fortifyall")
        end
      end,

      action = "fortify air",
      onstart = function ()
        send("fortify air", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("fortifiedair")
        defences.lost("fortifyall")
      end
    }
  }
  svo.dict.fortifiedwater = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].fortifiedwater and not defc.fortifiedwater) or (conf.keepup and defkeepup[defs.mode].fortifiedwater and not defc.fortifiedwater))) or (conf.keepup and defkeepup[defs.mode].fortifiedwater and not defc.fortifiedwater)) and not codepaste.balanceful_defs_codepaste() and defc.water) or false
      end,

      oncompleted = function ()
        defences.got("fortifiedwater")
        if defc.fortifiedair and defc.fortifiedearth and defc.fortifiedwater and (not svo.haveskillset('healing') or defc.fortifiedspirit) and (svo.haveskillset('weatherweaving') or defc.fortifiedfire) then
          defences.got("fortifyall")
        end
      end,

      action = "fortify water",
      onstart = function ()
        send("fortify water", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("fortifiedwater")
        defences.lost("fortifyall")
      end
    }
  }
  if not svo.haveskillset('weatherweaving') then
    svo.dict.fortifiedfire = {
      physical = {
        balanceful_act = true,
        aspriority = 0,
        spriority = 0,
        def = true,
        undeffable = true,

        isadvisable = function ()
          return (((((sys.deffing and defdefup[defs.mode].fortifiedfire and not defc.fortifiedfire) or (conf.keepup and defkeepup[defs.mode].fortifiedfire and not defc.fortifiedfire))) or (conf.keepup and defkeepup[defs.mode].fortifiedfire and not defc.fortifiedfire)) and not codepaste.balanceful_defs_codepaste() and defc.fire) or false
        end,

        oncompleted = function ()
          defences.got("fortifiedfire")
          if defc.fortifiedair and defc.fortifiedfire and defc.fortifiedearth and defc.fortifiedwater and (not svo.haveskillset('healing') or defc.fortifiedspirit) then
            defences.got("fortifyall")
          end
        end,

        action = "fortify fire",
        onstart = function ()
          send("fortify fire", conf.commandecho)
        end
      },
      gone = {
        oncompleted = function ()
          defences.lost("fortifiedfire")
          defences.lost("fortifyall")
        end
      }
    }
  end
  svo.dict.fortifiedearth = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].fortifiedearth and not defc.fortifiedearth) or (conf.keepup and defkeepup[defs.mode].fortifiedearth and not defc.fortifiedearth))) or (conf.keepup and defkeepup[defs.mode].fortifiedearth and not defc.fortifiedearth)) and not codepaste.balanceful_defs_codepaste() and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("fortifiedearth")
        if defc.fortifiedair and defc.fortifiedearth and defc.fortifiedwater and (not svo.haveskillset('healing') or defc.fortifiedspirit) and (svo.haveskillset('weatherweaving') or defc.fortifiedfire) then
          defences.got("fortifyall")
        end
      end,

      action = "fortify earth",
      onstart = function ()
        send("fortify earth", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("fortifiedearth")
        defences.lost("fortifyall")
      end
    }
  }
  if svo.haveskillset('healing') then
    svo.dict.fortifiedspirit = {
      physical = {
        balanceful_act = true,
        aspriority = 0,
        spriority = 0,
        def = true,
        undeffable = true,

        isadvisable = function ()
          return (((((sys.deffing and defdefup[defs.mode].fortifiedspirit and not defc.fortifiedspirit) or (conf.keepup and defkeepup[defs.mode].fortifiedspirit and not defc.fortifiedspirit))) or (conf.keepup and defkeepup[defs.mode].fortifiedspirit and not defc.fortifiedspirit)) and not codepaste.balanceful_defs_codepaste() and defc.spirit) or false
        end,

        oncompleted = function ()
          defences.got("fortifiedspirit")
          if defc.fortifiedair and defc.fortifiedfire and defc.fortifiedearth and defc.fortifiedwater and defc.fortifiedspirit then
            defences.got("fortifyall")
          end
        end,

        action = "fortify spirit",
        onstart = function ()
          send("fortify spirit", conf.commandecho)
        end
      },
      gone = {
        oncompleted = function ()
          defences.lost("fortifiedspirit")
          defences.lost("fortifyall")
        end
      }
    }
  end
end

if svo.haveskillset('elementalism') then
  svo.dict.waterweird = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.waterweird and ((sys.deffing and defdefup[defs.mode].waterweird) or (conf.keepup and defkeepup[defs.mode].waterweird)) and not codepaste.balanceful_defs_codepaste() and defc.water) or false
      end,

      oncompleted = function ()
        defences.got("waterweird")
      end,

      action = "cast waterweird at me",
      onstart = function ()
        send("cast waterweird at me", conf.commandecho)
      end
    }
  }
  svo.dict.chargeshield = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.chargeshield and ((sys.deffing and defdefup[defs.mode].chargeshield) or (conf.keepup and defkeepup[defs.mode].chargeshield)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone and defc.air) or false
      end,

      oncompleted = function ()
        defences.got("chargeshield")
      end,

      action = "cast chargeshield at me",
      onstart = function ()
        send("cast chargeshield at me", conf.commandecho)
      end
    }
  }
  svo.dict.stonefist = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.stonefist and ((sys.deffing and defdefup[defs.mode].stonefist) or (conf.keepup and defkeepup[defs.mode].stonefist)) and not codepaste.balanceful_defs_codepaste() and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("stonefist")
      end,

      action = "cast stonefist",
      onstart = function ()
        send("cast stonefist", conf.commandecho)
      end
    }
  }
  svo.dict.stoneskin = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.stoneskin and ((sys.deffing and defdefup[defs.mode].stoneskin) or (conf.keepup and defkeepup[defs.mode].stoneskin)) and not codepaste.balanceful_defs_codepaste() and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("stoneskin")
      end,

      action = "cast stoneskin",
      onstart = function ()
        send("cast stoneskin", conf.commandecho)
      end
    }
  }
  svo.dict.diamondskin = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.diamondskin and ((sys.deffing and defdefup[defs.mode].diamondskin) or (conf.keepup and defkeepup[defs.mode].diamondskin)) and not codepaste.balanceful_defs_codepaste() and defc.earth and defc.water and defc.fire) or false
      end,

      oncompleted = function ()
        defences.got("diamondskin")
      end,

      action = "cast diamondskin",
      onstart = function ()
        send("cast diamondskin", conf.commandecho)
      end
    }
  }
end
if svo.haveskillset('elementalism') or svo.haveskillset('weatherweaving') then
  svo.dict.reflection = {
    gamename = "reflections",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.reflection and ((sys.deffing and defdefup[defs.mode].reflection) or (conf.keepup and defkeepup[defs.mode].reflection)) and not codepaste.balanceful_defs_codepaste() and defc.air and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("reflection")
      end,

      action = "cast reflection at me",
      onstart = function ()
        send("cast reflection at me", conf.commandecho)
      end
    }
  }
end

if svo.haveskillset('apostasy') then
  svo.dict.baalzadeen = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        if (not defc.baalzadeen and ((sys.deffing and defdefup[defs.mode].baalzadeen) or (conf.keepup and defkeepup[defs.mode].baalzadeen)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone) then

          if (stats.mp >= 100) then
             return true
           elseif not sk.gettingfullstats then
             svo.fullstats(true)
             svo.echof("Getting fullstats for Baalzadeen summoning...")
           end
        end
      end,

      oncompleted = function ()
        defences.got("baalzadeen")
      end,

      action = "summon baalzadeen",
      onstart = function ()
        send("summon baalzadeen", conf.commandecho)
      end
    }
  }
  svo.dict.armour = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.armour and ((sys.deffing and defdefup[defs.mode].armour) or (conf.keepup and defkeepup[defs.mode].armour)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone and defc.baalzadeen) or false
      end,

      oncompleted = function ()
        defences.got("armour")
      end,

      action = "demon armour",
      onstart = function ()
        send("demon armour", conf.commandecho)
      end
    }
  }
  svo.dict.syphon = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.syphon and ((sys.deffing and defdefup[defs.mode].syphon) or (conf.keepup and defkeepup[defs.mode].syphon)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone and defc.baalzadeen) or false
      end,

      oncompleted = function ()
        defences.got("syphon")
      end,

      action = "demon syphon",
      onstart = function ()
        send("demon syphon", conf.commandecho)
      end
    }
  }
  svo.dict.mask = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.mask and ((sys.deffing and defdefup[defs.mode].mask) or (conf.keepup and defkeepup[defs.mode].mask)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone and defc.baalzadeen) or false
      end,

      oncompleted = function ()
        defences.got("mask")
      end,

      action = "mask",
      onstart = function ()
        send("mask", conf.commandecho)
      end
    }
  }
end

if svo.haveskillset('weatherweaving') then
  svo.dict.circulate = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.circulate and ((sys.deffing and defdefup[defs.mode].circulate) or (conf.keepup and defkeepup[defs.mode].circulate)) and not codepaste.balanceful_defs_codepaste() and defc.air and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("circulate")
      end,

      action = "cast circulate",
      onstart = function ()
        send("cast circulate", conf.commandecho)
      end
    }
  }
end






if svo.haveskillset('kaido') then
  svo.dict.boosting = {
    gamename = "boostedregeneration",
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].boosting and not defc.boosting) or (conf.keepup and defkeepup[defs.mode].boosting and not defc.boosting)) and not codepaste.balanceful_defs_codepaste() and defc.regeneration) or false
      end,

      oncompleted = function ()
        defences.got("boosting")
      end,

      action = "boost regeneration",
      onstart = function ()
        send("boost regeneration", conf.commandecho)
      end
    }
  }
  svo.dict.kaiboost = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].kaiboost and not defc.kaiboost) or (conf.keepup and defkeepup[defs.mode].kaiboost and not defc.kaiboost)) and not codepaste.balanceful_defs_codepaste() and stats.kai >= 11 and not svo.doingaction"kaiboost") or false
      end,

      oncompleted = function ()
        defences.got("kaiboost")
      end,

      action = "kai boost",
      onstart = function ()
        send("kai boost", conf.commandecho)
      end
    }
  }
  svo.dict.vitality = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        if (not defc.vitality and not defc.numb and ((sys.deffing and defdefup[defs.mode].vitality) or (conf.keepup and defkeepup[defs.mode].vitality)) and not codepaste.balanceful_defs_codepaste() and not svo.doingaction"cantvitality") then

          if (stats.currenthealth >= stats.maxhealth and stats.currentmana >= stats.maxmana) then
            return true
          elseif not sk.gettingfullstats then
            svo.fullstats(true)
            svo.echof("Getting fullstats for vitality now...")
          end
        end
      end,

      oncompleted = function ()
        defences.got("vitality")
      end,

      action = "vitality",
      onstart = function ()
        send("vitality", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("vitality")
        if not svo.actions.cantvitality_waitingfor then svo.doaction(svo.dict.cantvitality.waitingfor) end
      end
    }
  }
end



if svo.haveskillset('tarot') then
  svo.dict.devil = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.devil and ((sys.deffing and defdefup[defs.mode].devil) or (conf.keepup and defkeepup[defs.mode].devil)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("devil")
      end,

      action = "fling devil at ground",
      onstart = function ()
        sendAll("outd 1 devil","fling devil at ground","ind 1 devil", conf.commandecho)
      end
    }
  }
end

if svo.haveskillset('shikudo') then
  svo.dict.grip = {
    gamename = "gripping",
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      action = "grip",

      isadvisable = function()
        return (
          not defc.grip
          and (
            (sys.deffing and defdefup[defs.mode].grip)
            or (conf.keepup and defkeepup[defs.mode].grip)
          )
          and me.path == "shikudo"
          and not codepaste.balanceful_defs_codepaste()
          and sys.canoutr
          and not affs.paralysis
          and not affs.prone
        ) or false
      end,

      oncompleted = function()
        defences.got("grip")
      end,

      onstart = function()
        send("grip", conf.commandecho)
      end
    }
  }
  svo.dict.tykonos = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "adopt tykonos form",
      isadvisable = function() return shikudo_ability_isadvisable("tykonos") end,
      oncompleted = function() return shikudo_form_oncompleted("tykonos") end,

      onstart = function ()
        send("adopt tykonos form", conf.commandecho)
      end
    },
  }
  svo.dict.willow = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "adopt willow form",
      isadvisable = function() return shikudo_ability_isadvisable("willow") end,
      oncompleted = function() return shikudo_form_oncompleted("willow") end,

      onstart = function ()
        send("adopt willow form", conf.commandecho)
      end
    },
  }
  svo.dict.rain = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "adopt rain form",
      isadvisable = function() return shikudo_ability_isadvisable("rain") end,
      oncompleted = function() return shikudo_form_oncompleted("rain") end,

      onstart = function ()
        send("adopt rain form", conf.commandecho)
      end
    },
  }
  svo.dict.oak = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "adopt oak form",
      isadvisable = function() return shikudo_ability_isadvisable("oak") end,
      oncompleted = function() return shikudo_form_oncompleted("oak") end,

      onstart = function ()
        send("adopt oak form", conf.commandecho)
      end
    },
  }
  svo.dict.gaital = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "adopt gaital form",
      isadvisable = function() return shikudo_ability_isadvisable("gaital") end,
      oncompleted = function() return shikudo_form_oncompleted("gaital") end,

      onstart = function ()
        send("adopt gaital form", conf.commandecho)
      end
    },
  }
  svo.dict.maelstrom = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "adopt maelstrom form",
      isadvisable = function() return shikudo_ability_isadvisable("maelstrom") end,
      oncompleted = function() return shikudo_form_oncompleted("maelstrom") end,

      onstart = function ()
        send("adopt maelstrom form", conf.commandecho)
      end
    },
  }
end

if svo.haveskillset('tekura') then
  svo.dict.bodyblock = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      isadvisable = function() return tekura_ability_isadvisable("bodyblock") end,
      action = "bdb",

      oncompleted = function ()
        defences.got("bodyblock")
      end,

      onstart = function ()
        send("bdb", conf.commandecho)
      end
    },
  }
  svo.dict.evadeblock = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      action = "evb",
      isadvisable = function() return tekura_ability_isadvisable("evadeblock") end,

      oncompleted = function ()
        defences.got("evadeblock")
      end,

      onstart = function ()
        send("evb", conf.commandecho)
      end
    },
  }
  svo.dict.pinchblock = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      action = "pnb",
      isadvisable = function() return tekura_ability_isadvisable("pinchblock") end,

      oncompleted = function ()
        defences.got("pinchblock")
      end,

      onstart = function ()
        send("pnb", conf.commandecho)
      end
    },
  }
  svo.dict.horse = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "hrs",
      isadvisable = function() return tekura_ability_isadvisable("horse") end,
      oncompleted = function() return tekura_stance_oncompleted("horse") end,

      onstart = function ()
        send("hrs", conf.commandecho)
      end
    },
  }
  svo.dict.eagle = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "egs",
      isadvisable = function() return tekura_ability_isadvisable("eagle") end,
      oncompleted = function() return tekura_stance_oncompleted("eagle") end,

      onstart = function ()
        send("egs", conf.commandecho)
      end
    },
  }
  svo.dict.cat = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "cts",
      isadvisable = function() return tekura_ability_isadvisable("cat") end,
      oncompleted = function() return tekura_stance_oncompleted("cat") end,

      onstart = function ()
        send("cts", conf.commandecho)
      end
    },
  }
  svo.dict.bear = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "brs",
      isadvisable = function() return tekura_ability_isadvisable("bear") end,
      oncompleted = function() return tekura_stance_oncompleted("bear") end,

      onstart = function ()
        send("brs", conf.commandecho)
      end
    },
  }
  svo.dict.rat = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "rts",
      isadvisable = function() return tekura_ability_isadvisable("rat") end,
      oncompleted = function() return tekura_stance_oncompleted("rat") end,

      onstart = function ()
        send("rts", conf.commandecho)
      end
    },
  }
  svo.dict.scorpion = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "scs",
      isadvisable = function() return tekura_ability_isadvisable("scorpion") end,
      oncompleted = function() return tekura_stance_oncompleted("scorpion") end,

      onstart = function ()
        send("scs", conf.commandecho)
      end
    },
  }
  svo.dict.dragon = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,
      action = "drs",
      isadvisable = function() return tekura_ability_isadvisable("dragon") end,
      oncompleted = function() return tekura_stance_oncompleted("dragon") end,

      onstart = function ()
        send("drs", conf.commandecho)
      end
    },
  }
end



if svo.haveskillset('venom') then
  svo.dict.shrugging = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceless_act = true,

      isadvisable = function ()
        if not next(affs) or not bals.shrugging or affs.sleep or not conf.shrugging or affs.stun or affs.unconsciousness or affs.weakness or codepaste.nonstdcure() or defc.dragonform then return false end

        for name, func in pairs(svo.shrugging) do
          if not me.disabledshruggingfunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function (number)
        if number then
          -- empty
          if number+1 == getLineNumber() then
            empty.shrugging()
          end
        end
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        svo.lostbal_shrugging()
      end,

      action = "shrugging",
      onstart = function ()
        send("shrugging", conf.commandecho)
      end,

      offbal = function ()
        svo.lostbal_shrugging()
      end
    }
  }
end

if svo.haveskillset('alchemy') then
  svo.dict.extispicy = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.extispicy and ((sys.deffing and defdefup[defs.mode].extispicy) or (conf.keepup and defkeepup[defs.mode].extispicy)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("extispicy")
      end,

      norat = function()
        if svo.ignore.extispicy then return end

        svo.ignore.extispicy = true

        if sys.deffing then
          echo'\n' svo.echof("Looks like we have no rat - going to skip extispicy in this defup.")

          signals.donedefup:connect(function()
            svo.ignore.extispicy = nil
          end)
        else
          echo'\n' svo.echof("Looks like we have no rat for keepup - placing extispicy on ignore.")
        end
      end,

      action = "dissect rat",
      onstart = function ()
        send("dissect rat", conf.commandecho)
      end
    }
  }
end

if svo.haveskillset('woodlore') then
  svo.dict.impaling = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].impaling and not defc.impaling) or (conf.keepup and defkeepup[defs.mode].impaling and not defc.impaling)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("impaling")
      end,

      onstart = function ()
        send("set "..(conf.weapon and conf.weapon or "unknown"), conf.commandecho)
      end
    }
  }
  svo.dict.spinning = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].spinning and not defc.spinning) or (conf.keepup and defkeepup[defs.mode].spinning and not defc.spinning)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("spinning")
      end,

      onstart = function ()
        send("spin "..conf.weapon and conf.weapon or "unknown", conf.commandecho)
      end
    }
  }
end

if svo.haveskillset('propagation') then
  svo.dict.barkskin = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.barkskin and ((sys.deffing and defdefup[defs.mode].barkskin) or (conf.keepup and defkeepup[defs.mode].barkskin)) and not codepaste.balanceful_defs_codepaste() and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("barkskin")
      end,

      action = "barkskin",
      onstart = function ()
        send("barkskin", conf.commandecho)
      end
    }
  }
  svo.dict.viridian = {
    physical = {
      aspriority = 0,
      spriority = 0,
      unpauselater = false,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].viridian and not defc.viridian) or (conf.keepup and defkeepup[defs.mode].viridian and not defc.viridian)) and not svo.doingaction("waitingforviridian") and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function (def)
        if def and not defc.viridian then defences.got("viridian")
        else svo.doaction(svo.dict.waitingforviridian.waitingfor) end
      end,

      alreadyhave = function ()
        svo.dict.waitingforviridian.waitingfor.oncompleted()
      end,

      indoors = function ()
        if conf.paused and svo.dict.viridian.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          echo"\n" svo.echof("Unpaused - you must be outside to cast Viridian.")
        end
        svo.dict.viridian.physical.unpauselater = false
        defences.got("viridian")
      end,

      notonland = function ()
        if conf.paused and svo.dict.viridian.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          echo"\n" svo.echof("You must be in contact with the earth in order to call upon the might of the Viridian.")
        end
        svo.dict.viridian.physical.unpauselater = false
        defences.got("viridian")
      end,

      actions = {"assume viridian", "assume viridian staff"},
      onstart = function ()
        if defc.flail then
          send("assume viridian staff", conf.commandecho)
        else
          send("assume viridian", conf.commandecho)
        end

        if not conf.paused then
          svo.dict.viridian.physical.unpauselater = true
          conf.paused = true; raiseEvent("svo config changed", "paused")
          echo"\n" svo.echof("Temporarily pausing for viridian.")
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("viridian")
      end,
    }
  }
  svo.dict.waitingforviridian = {
    spriority = 0,
    waitingfor = {
      customwait = 20,

      oncompleted = function ()
        defences.got("viridian")
        svo.dict.riding.gone.oncompleted()

        if conf.paused and svo.dict.viridian.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")

          echo"\n"
          svo.echof("Obtained viridian, unpausing.")
        end
        svo.dict.viridian.physical.unpauselater = false
      end,

      cancelled = function ()
        if conf.paused and svo.dict.viridian.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          echo"\n" svo.echof("Unpausing.")
        end
        svo.dict.viridian.physical.unpauselater = false
      end,

      ontimeout = function()
        svo.dict.waitingforviridian.waitingfor.cancelled()
      end,

      onstart = function()
      end,
    }
  }
end

if svo.haveskillset('groves') then
  svo.dict.flail = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,
      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].flail and not defc.flail) or (conf.keepup and defkeepup[defs.mode].flail and not defc.flail)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("flail")
      end,

      onstart = function ()
        send('wield quarterstaff', conf.commandecho)
        send('flail quarterstaff', conf.commandecho)
      end
    }
  }
  svo.dict.lyre = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.lyre and not svo.doingaction("lyre") and ((sys.deffing and defdefup[defs.mode].lyre) or (conf.keepup and defkeepup[defs.mode].lyre)) and not svo.will_take_balance() and not conf.lyre_step and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("lyre")

        if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end,

      ontimeout = function()
        if conf.paused and not defc.lyre then
          svo.echof("Lyre strum didn't happen - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
          svo.make_gnomes_work()
        end
      end,

      onkill = function()
        if conf.paused and not defc.lyre then
          svo.echof("Lyre strum cancelled - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
        end
      end,

      action = "evoke barrier",
      onstart = function ()
        sys.sendonceonly = true

        -- small fix to make 'lyc' work and be in-order (as well as use batching)
        local send = send
        -- record in systemscommands, so it doesn't get killed later on in the controller and loop
        if conf.batch then send = function(what, ...) svo.sendc(what, ...) sk.systemscommands[what] = true end end

        if not defc.dragonform and (not conf.lyrecmd or conf.lyrecmd == "evoke barrier") then
          send("evoke barrier", conf.commandecho)
        else
          send(tostring(conf.lyrecmd), conf.commandecho)
        end
        sys.sendonceonly = false

        if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("lyre")

        -- as a special case for handling the following scenario:
        --[[(focus)
          Your prismatic barrier dissolves into nothing.
          You focus your mind intently on curing your mental maladies.
          Food is no longer repulsive to you. (7.548s)
          H: 3294 (50%), M: 4911 (89%) 28725e, 10294w 89.3% ex|cdk- 19:24:04.719(sip health|eat bayberry|outr bayberry|eat
          irid|outr irid)(+324h, 5.0%, -291m, 5.3%)
          You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.
          (p) H: 3294 (50%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:04.897
          Your prismatic barrier dissolves into nothing.
          You take a drink from a purple heartwood vial.
          The elixir heals and soothes you.
          H: 4767 (73%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:05.247(+1473h, 22.7%)
          You eat some bayberry bark.
          Your eyes dim as you lose your sight.
        ]]
        -- we want to kill lyre going up when it goes down and you're off balance, because you won't get it up off-bal

        -- but don't kill it if it is in lifevision - meaning we're going to get it:
        --[[
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
          (x) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}
          You have recovered equilibrium. (3.887s)
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
        ]]

        if not (bals.balance and bals.equilibrium) and svo.actions.lyre_physical and not svo.lifevision.l.lyre_physical then svo.killaction(svo.dict.lyre.physical) end

        -- unpause should we lose the lyre def for some reason - but not while we're doing lyc
        -- since we'll lose the lyre def and it'll come up right away
        if conf.lyre and conf.paused and not svo.actions.lyre_physical then conf.paused = false; raiseEvent("svo config changed", "paused") end
      end,
    }
  }
  svo.dict.rejuvenate = {
    description = "auto pauses/unpauses the system when you're rejuvenating the forests",
    physical = {
      aspriority = 0,
      spriority = 0,
      unpauselater = false,
      balanceful_act = true,

      isadvisable = function ()
        return false
      end,

      oncompleted = function ()
        svo.doaction(svo.dict.waitingforrejuvenate.waitingfor)
      end,

      action = "rejuvenate",
      onstart = function ()
      -- user commands catching needs this check
        if not (bals.balance and bals.equilibrium) then return end

        send("rejuvenate", conf.commandecho)

        if not conf.paused then
          svo.dict.rejuvenate.physical.unpauselater = true
          conf.paused = true; raiseEvent("svo config changed", "paused")
          echo"\n" svo.echof("Temporarily pausing to summon the rejuvenate.")
        end
      end
    }
  }
  svo.dict.waitingforrejuvenate = {
    spriority = 0,
    waitingfor = {
      customwait = 30,

      oncompleted = function ()
        if conf.paused and svo.dict.rejuvenate.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")

          svo.echof("Finished rejuvenating, unpausing.")
        end
        svo.dict.rejuvenate.physical.unpauselater = false
      end,

      cancelled = function ()
        if conf.paused and svo.dict.rejuvenate.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          svo.echof("Oops, interrupted rejuvenation. Unpausing.")
        end
        svo.dict.rejuvenate.physical.unpauselater = false
      end,

      ontimeout = function()
        svo.dict.waitingforrejuvenate.waitingfor.cancelled()
      end,

      onstart = function() end
    }
  }
end

-- override groves lyre, as druids can get 2 types of lyre (groves and nightingale)
if svo.haveskillset('metamorphosis') then
  svo.dict.lyre = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.lyre and ((sys.deffing and defdefup[defs.mode].lyre) or (conf.keepup and defkeepup[defs.mode].lyre)) and not svo.will_take_balance() and (not defc.dragonform or (not affs.cantmorph and sk.morphsforskill.lyre)) and not conf.lyre_step and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("lyre")

        if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end,

      ontimeout = function()
        if conf.paused and not defc.lyre then
          svo.echof("Lyre strum didn't happen - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
          svo.make_gnomes_work()
        end
      end,

      onkill = function()
        if conf.paused and not defc.lyre then
          svo.echof("Lyre strum cancelled - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
        end
      end,

      action = "sing melody",
      onstart = function ()
        if not defc.dragonform and (not conf.lyrecmd or conf.lyrecmd == "sing melody") then
          if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"lyre" then
            if defc.flame then send("relax flame", conf.commandecho) end
            send("human", conf.commandecho)
          elseif not sk.inamorphfor"lyre" then
            if defc.flame then send("relax flame", conf.commandecho) end
            send("morph "..sk.morphsforskill.lyre[1], conf.commandecho)

            if conf.transmorph then
              sys.sendonceonly = true
              send("sing melody", conf.commandecho)
              sys.sendonceonly = false
              if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
            end
          elseif sk.inamorphfor"lyre" then
            sys.sendonceonly = true
            send("sing melody", conf.commandecho)
            sys.sendonceonly = false

            if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
          end
        else
          -- small fix to make 'lyc' work and be in-order (as well as use batching)
          local send = send
        -- record in systemscommands, so it doesn't get killed later on in the controller and loop
        if conf.batch then send = function(what, ...) svo.sendc(what, ...) sk.systemscommands[what] = true end end

          sys.sendonceonly = true
          send(tostring(conf.lyrecmd), conf.commandecho)
          sys.sendonceonly = false

          if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("lyre")

        -- as a special case for handling the following scenario:
        --[[(focus)
          Your prismatic barrier dissolves into nothing.
          You focus your mind intently on curing your mental maladies.
          Food is no longer repulsive to you. (7.548s)
          H: 3294 (50%), M: 4911 (89%) 28725e, 10294w 89.3% ex|cdk- 19:24:04.719(sip health|eat bayberry|outr bayberry|eat
          irid|outr irid)(+324h, 5.0%, -291m, 5.3%)
          You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.
          (p) H: 3294 (50%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:04.897
          Your prismatic barrier dissolves into nothing.
          You take a drink from a purple heartwood vial.
          The elixir heals and soothes you.
          H: 4767 (73%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:05.247(+1473h, 22.7%)
          You eat some bayberry bark.
          Your eyes dim as you lose your sight.
        ]]
        -- we want to kill lyre going up when it goes down and you're off balance, because you won't get it up off-bal

        -- but don't kill it if it is in lifevision - meaning we're going to get it:
        --[[
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
          (x) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}
          You have recovered equilibrium. (3.887s)
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
        ]]

        if not (bals.balance and bals.equilibrium) and svo.actions.lyre_physical and not svo.lifevision.l.lyre_physical then svo.killaction(svo.dict.lyre.physical) end

        -- unpause should we lose the lyre def for some reason - but not while we're doing lyc
        -- since we'll lose the lyre def and it'll come up right away
        if conf.lyre and conf.paused and not svo.actions.lyre_physical then conf.paused = false; raiseEvent("svo config changed", "paused") end
      end,
    }
  }
end

if svo.haveskillset('domination') then
  svo.dict.arctar = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.arctar and ((sys.deffing and defdefup[defs.mode].arctar) or (conf.keepup and defkeepup[defs.mode].arctar)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and bals.entities) or false
      end,

      oncompleted = function ()
        defences.got("arctar")
      end,

      action = "command orb",
      onstart = function ()
        send("command orb", conf.commandecho)
      end
    }
  }
end
if svo.haveskillset('shadowmancy') then
  svo.dict.shadowcloak = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        local shadowcloak = me.getitem("a grim cloak")
        if not defc.dragonform and not defc.shadowcloak and ((sys.deffing and defdefup[defs.mode].shadowcloak) or (conf.keepup and defkeepup[defs.mode].shadowcloak) or (sys.deffing and defdefup[defs.mode].disperse) or (conf.keepup and defkeepup[defs.mode].disperse) or (sys.deffing and defdefup[defs.mode].shadowveil) or (conf.keepup and defkeepup[defs.mode].shadowveil) or (sys.deffing and defdefup[defs.mode].hiding) or (conf.keepup and defkeepup[defs.mode].hiding)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and stats.mp then
          if not shadowcloak then
            if stats.mp >= 100 then
              return true
            elseif not sk.gettingfullstats then
              svo.fullstats(true)
              svo.echof("Getting fullstats for Shadowcloak summoning...")
            end
          else
            return true
          end
        end
        return false
      end,

      oncompleted = function ()
        defences.got("shadowcloak")
      end,

      action = "shadow cloak",
      onstart = function ()
        local shadowcloak = me.getitem("a grim cloak")
        if not shadowcloak then
          send("shadow cloak", conf.commandecho)
        elseif not shadowcloak.attrib or not shadowcloak.attrib:find("w") then
          send("wear " .. shadowcloak.id, conf.commandecho)
        else
      defences.got("shadowcloak")
        end
      end
    }
  }
  svo.dict.disperse = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return not defc.dragonform and not defc.disperse and defc.shadowcloak and ((sys.deffing and defdefup[defs.mode].disperse) or (conf.keepup and defkeepup[defs.mode].disperse)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone
      end,

      oncompleted = function ()
        defences.got("disperse")
      end,

      action = "shadow disperse",
      onstart = function ()
        send("shadow disperse", conf.commandecho)
      end
    }
  }
  svo.dict.shadowveil = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return not defc.dragonform and not defc.shadowveil and defc.shadowcloak and ((sys.deffing and defdefup[defs.mode].shadowveil) or (conf.keepup and defkeepup[defs.mode].shadowveil)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone
      end,

      oncompleted = function ()
        defences.got("shadowveil")
      end,

      action = "shadow veil",
      onstart = function ()
        send("shadow veil", conf.commandecho)
      end
    }
  }
  svo.dict.hiding = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return not defc.dragonform and not defc.hiding and defc.shadowcloak and ((sys.deffing and defdefup[defs.mode].hiding) or (conf.keepup and defkeepup[defs.mode].hiding)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone
      end,

      oncompleted = function ()
        defences.got("hiding")
      end,

      action = "shadow veil",
      onstart = function ()
        send("shadow veil", conf.commandecho)
      end
    }
  }
end
if svo.haveskillset('aeonics') then
  svo.dict.dilation = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].dilation and not defc.dilation) or (conf.keepup and defkeepup[defs.mode].dilation and not defc.dilation)) and not codepaste.balanceful_defs_codepaste() and not svo.doingaction'dilation' and (stats.age and stats.age > 0)) or false
      end,

      oncompleted = function ()
        defences.got("dilation")
      end,

      actions = {"chrono dilation", "chrono dilation boost"},
      onstart = function ()
        send("chrono dilation", conf.commandecho)
      end
    }
  }
end
if svo.haveskillset('terminus') then
  svo.dict.trusad = {
    gamename = "precision",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.trusad and ((sys.deffing and defdefup[defs.mode].trusad) or (conf.keepup and defkeepup[defs.mode].trusad)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("trusad")
      end,

      action = "intone trusad",
      onstart = function ()
        send("intone trusad", conf.commandecho)
      end
    }
  }
  svo.dict.tsuura = {
    gamename = "durability",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.tsuura and ((sys.deffing and defdefup[defs.mode].tsuura) or (conf.keepup and defkeepup[defs.mode].tsuura)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("tsuura")
      end,

      action = "intone tsuura",
      onstart = function ()
        send("intone tsuura", conf.commandecho)
      end
    }
  }
  svo.dict.ukhia = {
    gamename = "bloodquell",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.ukhia and ((sys.deffing and defdefup[defs.mode].ukhia) or (conf.keepup and defkeepup[defs.mode].ukhia)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("ukhia")
      end,

      action = "intone ukhia",
      onstart = function ()
        send("intone ukhia", conf.commandecho)
      end
    }
  }
  svo.dict.qamad = {
    gamename = "ironwill",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.qamad and ((sys.deffing and defdefup[defs.mode].qamad) or (conf.keepup and defkeepup[defs.mode].qamad)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("qamad")
      end,

      action = "intone qamad",
      onstart = function ()
        send("intone qamad", conf.commandecho)
      end
    }
  }
  svo.dict.mainaas = {
    gamename = "bodyaugment",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.mainaas and ((sys.deffing and defdefup[defs.mode].mainaas) or (conf.keepup and defkeepup[defs.mode].mainaas)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("mainaas")
      end,

      action = "intone mainaas",
      onstart = function ()
        send("intone mainaas", conf.commandecho)
      end
    }
  }
  svo.dict.gaiartha = {
    gamename = "antiforce",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.gaiartha and ((sys.deffing and defdefup[defs.mode].gaiartha) or (conf.keepup and defkeepup[defs.mode].gaiartha)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("gaiartha")
      end,

      action = "intone gaiartha",
      onstart = function ()
        send("intone gaiartha", conf.commandecho)
      end
    }
  }
  svo.dict.lyre = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.lyre and not svo.doingaction("lyre") and ((sys.deffing and defdefup[defs.mode].lyre) or (conf.keepup and defkeepup[defs.mode].lyre)) and not svo.will_take_balance() and not conf.lyre_step and not affs.prone and (defc.dragonform or (conf.lyrecmd and conf.lyrecmd ~= "intone kail") or bals.word)) or false
      end,

      oncompleted = function ()
        defences.got("lyre")

        if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end,

      ontimeout = function()
        if conf.paused and not defc.lyre then
          svo.echof("Lyre strum didn't happen - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
          svo.make_gnomes_work()
        end
      end,

      onkill = function()
        if conf.paused and not defc.lyre then
          svo.echof("Lyre strum cancelled - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
        end
      end,

      action = "intone kail",
      onstart = function ()
        sys.sendonceonly = true

        -- small fix to make 'lyc' work and be in-order (as well as use batching)
        local send = send
        -- record in systemscommands, so it doesn't get killed later on in the controller and loop
        if conf.batch then send = function(what, ...) svo.sendc(what, ...) sk.systemscommands[what] = true end end

        if not defc.dragonform and not conf.lyrecmd then
          send("intone kail", conf.commandecho)
        elseif conf.lyrecmd then
          send(tostring(conf.lyrecmd), conf.commandecho)
        else
          send("strum lyre", conf.commandecho)
        end
        sys.sendonceonly = false

        if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("lyre")

        -- as a special case for handling the following scenario:
        --[[(focus)
          Your prismatic barrier dissolves into nothing.
          You focus your mind intently on curing your mental maladies.
          Food is no longer repulsive to you. (7.548s)
          H: 3294 (50%), M: 4911 (89%) 28725e, 10294w 89.3% ex|cdk- 19:24:04.719(sip health|eat bayberry|outr bayberry|eat
          irid|outr irid)(+324h, 5.0%, -291m, 5.3%)
          You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.
          (p) H: 3294 (50%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:04.897
          Your prismatic barrier dissolves into nothing.
          You take a drink from a purple heartwood vial.
          The elixir heals and soothes you.
          H: 4767 (73%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:05.247(+1473h, 22.7%)
          You eat some bayberry bark.
          Your eyes dim as you lose your sight.
        ]]
        -- we want to kill lyre going up when it goes down and you're off balance, because you won't get it up off-bal

        -- but don't kill it if it is in lifevision - meaning we're going to get it:
        --[[
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
          (x) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}
          You have recovered equilibrium. (3.887s)
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
        ]]

        if not (bals.balance and bals.equilibrium) and svo.actions.lyre_physical and not svo.lifevision.l.lyre_physical then svo.killaction(svo.dict.lyre.physical) end

        -- unpause should we lose the lyre def for some reason - but not while we're doing lyc
        -- since we'll lose the lyre def and it'll come up right away
        if conf.lyre and conf.paused and not svo.actions.lyre_physical then conf.paused = false; raiseEvent("svo config changed", "paused") end
      end,
    }
  }
end

if svo.me.class == "Sentinel" then
  svo.dict.basilisk = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.basilisk and ((sys.deffing and defdefup[defs.mode].basilisk) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].basilisk)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("basilisk")
      end,

      action = "morph basilisk",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph basilisk", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("basilisk")
      end,
    }
  }
end
if svo.me.class == "Sentinel" then
  svo.dict.jaguar = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.jaguar and ((sys.deffing and defdefup[defs.mode].jaguar) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].jaguar)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("jaguar")
      end,

      action = "morph jaguar",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph jaguar", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("jaguar")
      end,
    }
  }
end
if svo.me.class == "Druid" then
  svo.dict.wyvern = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.wyvern and ((sys.deffing and defdefup[defs.mode].wyvern) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].wyvern)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("wyvern")
      end,

      action = "morph wyvern",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph wyvern", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("wyvern")
      end,
    }
  }
  svo.dict.hydra = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.hydra and ((sys.deffing and defdefup[defs.mode].hydra) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].hydra)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("hydra")
      end,

      action = "morph hydra",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph hydra", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("hydra")
      end,
    }
  }
end
if svo.haveskillset('healing') then
  svo.dict.usehealing = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        if not next(affs) or not bals.balance or not bals.equilibrium or not bals.healing or conf.usehealing == "none" or not svo.can_usemana() or svo.doingaction"usehealing" or affs.transfixed or stats.currentwillpower <= 50 or defc.bedevil or ((affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm) and (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm)) then return false end

        -- we calculate here if we can use Healing on any of the affs we got; cache the result as well

        -- small func for getting the spriority of a thing
        local function getprio(what)
          local type = type
          for _,v in pairs(what) do
            if type(v) == "table" and v.spriority then
              return v.spriority
            end
          end
        end

        local t = {}
        for affname, _ in pairs(affs) do
          if sk.healingmap[affname] and not svo.ignore[affname] and not svo.doingaction(affname) and not svo.doingaction("curing"..affname) and sk.healingmap[affname]() then
            t[affname] = getprio(svo.dict[affname])
          end
        end

        if not next(t) then return false end
        svo.dict.usehealing.afftocure = svo.getHighestKey(t)
        return true
      end,

      oncompleted = function()
        if not svo.dict.usehealing.curingaff or (svo.dict.usehealing.curingaff ~= "deaf" and svo.dict.usehealing.curingaff ~= "blind") then
          svo.lostbal_healing()
        end

        svo.dict.usehealing.curingaff = nil
      end,

      empty = function ()
        if not svo.dict.usehealing.curingaff or (svo.dict.usehealing.curingaff ~= "deaf" and svo.dict.usehealing.curingaff ~= "blind") then
          svo.lostbal_healing()
        end

        if not svo.dict.usehealing.curingaff then return end
        svo.rmaff(svo.dict.usehealing.curingaff)
        svo.dict.usehealing.curingaff = nil
      end,

      -- haven't regained healing balance yet
      nobalance = function()
        if not svo.dict.usehealing.curingaff or (svo.dict.usehealing.curingaff ~= "deaf" and svo.dict.usehealing.curingaff ~= "blind") then
          svo.lostbal_healing()
        end

        svo.dict.usehealing.curingaff = nil
      end,

      -- have bedevil def up; can't use healing
      bedevilheal = function()
        svo.dict.usehealing.curingaff = nil
        defences.got("bedevil")
      end,

      onstart = function ()
        local aff = svo.dict.usehealing.afftocure
        local svonames = {
          blind = "blindness",
          deaf = "deafness",
          blindaff = "blindness",
          deafaff = "deafness",
          illness = "vomiting",
          weakness = "weariness",
          crippledleftarm = "arms",
          crippledrightarm = "arms",
          crippledleftleg = "legs",
          crippledrightleg = "legs",
          unknowncrippledleg = "legs",
          unknowncrippledarm = "arms",
          ablaze = "burning",
        }

        local use_no_name = {
          unknowncrippledlimb = true,
          blackout = true,
        }

        if use_no_name[aff] then
          send("heal", conf.commandecho)
        else
          send("heal me "..(svonames[aff] or aff), conf.commandecho)
        end
        svo.dict.usehealing.curingaff = svo.dict.usehealing.afftocure
        svo.dict.usehealing.afftocure = nil
      end
    }
  }
end
if svo.haveskillset('kaido') then
  svo.dict.transmute = {
    -- transmutespam is used to throttle bleed spamming so it doesn't get out of control
    transmutespam = false,
    transmutereps = 0,
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (conf.transmute ~= "none" and not defc.dragonform and (stats.currenthealth < sys.transmuteamount or (sk.gettingfullstats and stats.currenthealth < stats.maxhealth)) and not svo.doingaction"healhealth" and not svo.doingaction"transmute" and not codepaste.balanceful_codepaste() and svo.can_usemana() and (not affs.prone or svo.doingaction"prone") and not svo.dict.transmute.transmutespam) or false
      end,

      oncompleted = function()
        -- count down transmute reps, and if we can, cancel the transmute-blocking timer
        svo.dict.transmute.transmutereps = svo.dict.transmute.transmutereps - 1
        if svo.dict.transmute.transmutereps <= 0 then
          -- in case transmute expired and we finish after
          if svo.dict.transmute.transmutespam then killTimer(svo.dict.transmute.transmutespam); svo.dict.transmute.transmutespam = nil end
          svo.dict.transmute.transmutereps = 0
        end
      end,

      onstart = function ()
        local necessary_amount = (not sk.gettingfullstats and math.ceil(sys.transmuteamount - stats.currenthealth) or (stats.maxhealth - stats.currenthealth))
        local available_mana = math.floor(stats.currentmana - sys.manause)

        -- compute just how much of the necessary amount can we transmute given our available mana, and a 1:1 health gain/mana loss mapping
        necessary_amount = (available_mana > necessary_amount) and necessary_amount or available_mana

        svo.dict.transmute.transmutereps = 0
        local reps = math.floor(necessary_amount/1000)

        for _ = 1, reps do
          send("transmute 1000", conf.commandecho)
          svo.dict.transmute.transmutereps = svo.dict.transmute.transmutereps + 1
        end
        if necessary_amount % 1000 ~= 0 then
          send("transmute "..necessary_amount % 1000, conf.commandecho)
          svo.dict.transmute.transmutereps = svo.dict.transmute.transmutereps + 1
        end

        -- after sending a bunch of transmutes, wait a bit before doing it again
        if svo.dict.transmute.transmutespam then killTimer(svo.dict.transmute.transmutespam); svo.dict.transmute.transmutespam = nil end
        svo.dict.transmute.transmutespam = tempTimer(svo.getping()*1.5, function () svo.dict.transmute.transmutespam = nil; svo.dict.transmute.transmutereps = 0 svo.make_gnomes_work() end)
        -- if it's just one transmute, then we can get it done in ping time (but allow for flexibility) - otherwise do it in 2x ping time, as there's a big skip between the first and latter commands
      end
    }
  }
end
if svo.haveskillset('voicecraft') then
  svo.dict.dwinnu = {
    misc = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (conf.dwinnu and bals.voice and (affs.webbed or affs.roped) and codepaste.writhe() and not affs.paralysis and not defc.dragonform) or false
      end,

      oncompleted = function ()
        svo.rmaff{"webbed", "roped"}
        svo.lostbal_voice()
      end,

      action = "chant dwinnu",
      onstart = function ()
        send("chant dwinnu", conf.commandecho)
      end
    },
  }
end

if svo.haveskillset('chivalry') then
  svo.dict.rage = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        if not (conf.rage and bals.rage and (affs.inlove or affs.justice or affs.generosity or affs.pacifism or affs.peace) and not defc.dragonform and svo.can_usemana()) then return false end

        for name, func in pairs(svo.rage) do
          if not me.disabledragefunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function ()
        svo.lostbal_rage()
      end,

      empty = function ()
        svo.rmaff{"inlove", "justice", "generosity", "pacifism", "peace"}
        svo.lostbal_rage()
      end,

      action = "rage",
      onstart = function ()
        send("rage", conf.commandecho)
      end
    },
  }
end
if svo.haveskillset('metamorphosis') then
  svo.dict.cantmorph = {
    waitingfor = {
      customwait = 30,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,
      ontimeout = function ()
        svo.rmaff("cantmorph")
        echo"\n"svo.echof("We can probably morph again now.")
      end,

      oncompleted = function ()
        svo.rmaff("cantmorph")
      end
    },
    aff = {
      oncompleted = function ()
        svo.addaffdict(svo.dict.cantmorph)
      end
    },
    gone = {
      oncompleted = function ()
        svo.rmaff("cantmorph")
      end,
    }
  }
end
if svo.haveskillset('metamorphosis') or svo.haveskillset('kaido') then
  svo.dict.cantvitality = {
    waitingfor = {
      customwait = 122,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,
      ontimeout = function ()
        if not defc.vitality then
          echo"\n"svo.echof("We can vitality again now.")
          svo.make_gnomes_work()
        end
      end,

      oncompleted = function ()
        svo.dict.cantvitality.waitingfor.ontimeout()
      end
    },
    gone = {
      oncompleted = function ()
        svo.killaction(svo.dict.cantvitality.waitingfor)
      end
    }
  }
end
if svo.haveskillset('weaponmastery') then
  svo.dict.footingattack = {
    description = "Tracks attacks suitable for use with balanceless recover footing",
    happened = {
      oncompleted = function ()
        sk.didfootingattack = true
      end
    }
  }
end
if svo.haveskillset('aeonics') then
  svo.dict.age = {
    happened = {
      onstart = function () end,

      oncompleted = function(amount)
        if amount > 1400 then
          svo.ignore_illusion("Age went over the possible max")
          stats.age = 0
        elseif amount == 0 then
          if svo.dict.age.happened.timer then killTimer(svo.dict.age.happened.timer) end
          stats.age = 0
          svo.dict.age.happened.timer = nil
        else
          if svo.dict.age.happened.timer then killTimer(svo.dict.age.happened.timer) end
          svo.dict.age.happened.timer = tempTimer(6 + svo.getping(), function()
            svo.ignore_illusion("Age tick timed out")
            stats.age = 0
          end)
          stats.age = amount
        end
      end
    }
  }
end
if svo.haveskillset('chivalry') or svo.haveskillset('striking') or svo.haveskillset('kaido') then
  svo.dict.fitness = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      uncurable = true,

      isadvisable = function ()
        if not (not affs.weakness and not defc.dragonform and bals.fitness and not codepaste.balanceful_defs_codepaste()) then
          return false
        end

        for name, func in pairs(svo.fitness) do
          if not me.disabledfitnessfunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function ()
        svo.rmaff("asthma")
        svo.lostbal_fitness()
      end,

      curedasthma = function ()
        svo.rmaff("asthma")
        svo.lostbal_fitness()
      end,

      weakness = function ()
        svo.addaffdict(svo.dict.weakness)

      end,

      allgood = function()
        svo.rmaff("asthma")
      end,

      actions = {"fitness"},
      onstart = function ()
        send("fitness", conf.commandecho)
      end
    },
  }
end
if svo.haveskillset('devotion') then
  svo.dict.bloodsworntoggle = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (defc.bloodsworn and conf.bloodswornoff and stats.currenthealth <= sys.bloodswornoff and not svo.doingaction"bloodsworntoggle" and not defc.dragonform) or false
      end,

      oncompleted = function ()
        defences.lost("bloodsworn")
      end,

      action = "bloodsworn off",
      onstart = function ()
        send("bloodsworn off", conf.commandecho)
      end
    }
  }
end

function svo.basicdef(which, command, balanceless, gamename, undeffable)
  svo.dict[which] = {
    physical = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc[which] and ((sys.deffing and defdefup[defs.mode][which]) or (conf.keepup and defkeepup[defs.mode][which])) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone and (balanceless or not svo.doingaction(which))) or false
      end,

      oncompleted = function ()
        defences.got(which)
      end,

      action = command,
      onstart = function ()
        send(command, conf.commandecho)
      end
    }
  }
  if gamename then
    svo.dict[which].gamename = gamename
  end
  if balanceless then
    svo.dict[which].balanceless_act = true
  else
    svo.dict[which].balanceful_act = true
  end
  if undeffable then
    svo.dict[which].undeffable = true
  end
end
local basicdef = svo.basicdef

basicdef("satiation", "satiation")
basicdef("treewatch", "treewatch on", true)
basicdef("skywatch", "skywatch on", true)
basicdef("groundwatch", "groundwatch on", true)
basicdef("telesense", "telesense on", true)
basicdef("softfocus", "softfocus on", true, "softfocusing")
basicdef("vigilance", "vigilance on", true)
basicdef("magicresist", "activate magic resistance", true)
basicdef("fireresist", "activate fire resistance", true)
basicdef("coldresist", "activate cold resistance", true)
basicdef("electricresist", "activate electric resistance", true)
basicdef("alertness", "alertness on")
basicdef("bell", "touch bell", true, "belltattoo")
basicdef("hypersight", "hypersight on")
basicdef("curseward", "curseward")
basicdef("clinging", "cling")
if svo.haveskillset('necromancy') then
  basicdef("putrefaction", "putrefaction")
  basicdef("shroud", "shroud")
  basicdef("vengeance", "vengeance on")
  basicdef("deathaura", "deathaura on")
  basicdef("soulcage", "soulcage activate")
end
if svo.haveskillset('chivalry') then
  basicdef("mastery", "mastery on", true, "blademastery")
  basicdef("sturdiness", "stand firm", false, "standingfirm")
  basicdef("weathering", "weathering", true)
  basicdef("resistance", "resistance", true)
  basicdef("grip", "grip", true, "gripping")
  basicdef("fury", "fury on")
end
if svo.haveskillset('devotion') then
  basicdef("inspiration", "perform inspiration")
  basicdef("bliss", "perform bliss", nil, nil, true)
end
if svo.haveskillset('spirituality') then
  basicdef("heresy", "hunt heresy")
end
if svo.haveskillset('shindo') then
  basicdef("clarity", "clarity", nil, nil, true)
  basicdef("sturdiness", "stand firm", false, "standingfirm")
  basicdef("weathering", "weathering", true)
  basicdef("grip", "grip", true, "gripping")
  basicdef("toughness", "toughness", true)
  basicdef("mindnet", "mindnet on")
  basicdef("constitution", "constitution")
  basicdef("waterwalk", "waterwalk", false, "waterwalking")
  basicdef("retaliationstrike", "retaliationstrike", nil, "retaliation")
  basicdef("shintrance", "shin trance")
  basicdef("consciousness", "consciousness on")
  basicdef("bind", "binding on", nil, nil, true)
  basicdef("projectiles", "projectiles on")
  basicdef("dodging", "dodging on")
  basicdef("immunity", "immunity")
end
if svo.haveskillset('metamorphosis') then
  basicdef("bonding", "bond spirit", nil, nil, true)
end
if svo.haveskillset('swashbuckling') then
  basicdef("arrowcatch", "arrowcatch on", nil, "arrowcatching")
  basicdef("balancing", "balancing on")
  basicdef("acrobatics", "acrobatics on")
  basicdef("dodging", "dodging on")
  basicdef("grip", "grip", true, "gripping")
end
if svo.haveskillset('voicecraft') then
  basicdef("songbird", "whistle for songbird")
end
if svo.haveskillset('harmonics') then
  basicdef("lament", "play lament", nil, nil, true)
  basicdef("anthem", "play anthem", nil, nil, true)
  basicdef("harmonius", "play harmonius", nil, nil, true)
  basicdef("contradanse", "play contradanse", nil, nil, true)
  basicdef("paxmusicalis", "play paxmusicalis", nil, nil, true)
  basicdef("gigue", "play gigue", nil, nil, true)
  basicdef("bagatelle", "play bagatelle", nil, nil, true)
  basicdef("partita", "play partita", nil, nil, true)
  basicdef("berceuse", "play berceuse", nil, nil, true)
  basicdef("continuo", "play continuo", nil, nil, true)
  basicdef("wassail", "play wassail", nil, nil, true)
  basicdef("canticle", "play canticle", nil, nil, true)
  basicdef("reel", "play reel", nil, nil, true)
  basicdef("hallelujah", "play hallelujah", nil, nil, true)
end
if svo.haveskillset('occultism') then
  basicdef("shroud", "shroud")
  basicdef("astralvision", "astralvision", nil, nil, true)
  basicdef("distortedaura", "distortaura")
  basicdef("tentacles", "tentacles")
  basicdef("devilmark", "devilmark")
  basicdef("heartstone", "heartstone", nil, nil, true)
  basicdef("simulacrum", "simulacrum", nil, nil, true)
  basicdef("transmogrify", "transmogrify activate", nil, nil, true)
end
if svo.haveskillset('elementalism') then
  basicdef("efreeti", "cast efreeti", nil, nil, true)
end
if svo.haveskillset('apostasy') then
  basicdef("daegger", "summon daegger", nil, nil, true)
  basicdef("pentagram", "carve pentagram", nil, nil, true)
end
if svo.haveskillset('evileye') then
  basicdef("truestare", "truestare")
end
if svo.haveskillset('pranks') then
  basicdef("arrowcatch", "arrowcatch on", nil, "arrowcatching")
  basicdef("balancing", "balancing on")
  basicdef("acrobatics", "acrobatics on")
  basicdef("slipperiness", "slipperiness", nil, "slippery")
end
if svo.haveskillset('puppetry') or svo.haveskillset('vodun') then
  basicdef("grip", "grip", true, "gripping")
end
if svo.haveskillset('curses') then
  basicdef("swiftcurse", "swiftcurse")
end
if svo.haveskillset('kaido') then
  basicdef("numb", "numb", nil, nil, true)
  basicdef("weathering", "weathering", true)
  basicdef("nightsight", "nightsight on", true)
  basicdef("immunity", "immunity")
  basicdef("regeneration", "regeneration on", true)
  basicdef("resistance", "resistance", true)
  basicdef("toughness", "toughness", true)
  basicdef("trance", "kai trance", true, "kaitrance")
  basicdef("consciousness", "consciousness on", true)
  basicdef("projectiles", "projectiles on", true)
  basicdef("dodging", "dodging on", true)
  basicdef("constitution", "constitution")
  basicdef("splitmind", "split mind")
  basicdef("sturdiness", "stand firm", false, "standingfirm")
end
if svo.haveskillset('telepathy') then
  basicdef("mindtelesense", "mind telesense on", true)
  basicdef("hypersense", "mind hypersense on")
  basicdef("mindnet", "mindnet on", true)
  basicdef("mindcloak", "mind cloak on", true)
end
if svo.haveskillset('skirmishing') then
  basicdef("scout", "scout", nil, "scouting")
end
if svo.haveskillset('weaponmastery') then
  basicdef("deflect", "deflect", true)
end
if svo.haveskillset('subterfuge') then
  basicdef("scales", "scales")
  basicdef("hiding", "hide", false, "hiding", true)
  basicdef("pacing", "pacing on")
  basicdef("bask", "bask", false, "basking")
  basicdef("listen", "listen", false, false, true)
  basicdef("eavesdrop", "eavesdrop", false, "eavesdropping", true) -- serverside bugs out and doesn't accept it
  basicdef("lipread", "lipread", false, "lipreading", true) -- serverside bugs and does it while blind
  basicdef("weaving", "weaving on")
  basicdef("cloaking", "conjure cloak", false, "shroud")
  basicdef("ghost", "conjure ghost")
  basicdef("phase", "phase", false, "phased", true)
  basicdef("secondsight", "secondsight")
end
if svo.haveskillset('alchemy') then
  basicdef("lead", "educe lead", nil, nil, true)
  basicdef("tin", "educe tin")
  basicdef("sulphur", "educe sulphur")
  basicdef("mercury", "educe mercury")
  basicdef("empower", "astronomy empower me", nil, nil, true)
end
if svo.haveskillset('woodlore') then
  basicdef("barkskin", "barkskin")
  basicdef("fleetness", "fleetness")
  basicdef("hiding", "hide", false, "hiding", true)
  basicdef("firstaid", "firstaid on")
end
if svo.haveskillset('groves') then
  basicdef("panacea", "evoke panacea", false, false, true)
  basicdef("vigour", "evoke vigour", false, false, true)
  basicdef("roots", "grove roots", false, false, true)
  basicdef("wildgrowth", "evoke wildgrowth", false, false, true)
  basicdef("dampening", "evoke dampening", false, false, true)
  basicdef("snowstorm", "evoke snowstorm", false, false, true)
  basicdef("roots", "grove roots", false, false, true)
  basicdef("concealment", "grove concealment", false, false, true)
  basicdef("screen", "grove screen", false, false, true)
  basicdef("swarm", "call new swarm", false, false, true)
  basicdef("harmony", "evoke harmony me", false, false, true)
end
if svo.haveskillset('domination') then
  basicdef("golgotha", "summon golgotha", nil, "golgothagrace")
end

for ssa, svoa in pairs(svo.dict.sstosvoa) do
  if type(svoa) == "string" then svo.dict.svotossa[svoa] = ssa end
end

for ssd, svod in pairs(svo.dict.sstosvod) do
  if type(svod) == "string" then svo.dict.svotossd[svod] = ssd end
end

-- finds the lowest missing priority num for given balance
function svo.find_lowest_async(balance)
  local data = svo.make_prio_table(balance)
  local t = {}

  for k,_ in pairs(data) do
    t[#t+1] = k
  end

  table.sort(t)

  local function contains(value)
    for _, v in ipairs(t) do
      if v == value then return true end
    end
    return false
  end

  for i = 1, table.maxn(t) do
    if not contains(i) then return i end
  end

  return table.maxn(t)+1
end

function svo.find_lowest_sync()
  local data = svo.make_sync_prio_table("%s%s")
  local t = {}

  for k,_ in pairs(data) do
    t[#t+1] = k
  end

  table.sort(t)
  local function contains(value)
    for _, v in ipairs(t) do
      if v == value then return true end
    end
    return false
  end

  for i = 1, table.maxn(t) do
    if not contains(i) then return i end
  end

  return table.maxn(t)+1
end

local function dict_setup()
  svo.dict_balanceful  = {}
  svo.dict_balanceless = {}
  -- defence shortlists
  svo.dict_herb      = {}
  svo.dict_misc      = {}
  svo.dict_misc_def  = {}
  svo.dict_purgative = {}
  svo.dict_salve_def = {}
  svo.dict_smoke_def = {}

  local unassigned_actions      = {}
  local unassigned_sync_actions = {}

  for action, balance in pairs(svo.dict) do
    for balancename, balancedata in pairs(balance) do
      if type(balancedata) == "table" then
        if not balancedata.name then balancedata.name = action .. "_" .. balancename end
        if not balancedata.balance then balancedata.balance = balancename end
        if not balancedata.action_name then balancedata.action_name = action end
        if balancedata.aspriority == 0 then
          unassigned_actions[balancename] = unassigned_actions[balancename] or {}
          unassigned_actions[balancename][#unassigned_actions[balancename]+1] = action
        end
        if balancedata.spriority == 0 then
          unassigned_sync_actions[balancename] = unassigned_sync_actions[balancename] or {}
          unassigned_sync_actions[balancename][#unassigned_sync_actions[balancename]+1] = action
        end

        -- if it's a def, create the gone handler as well so lifevision will watch it
        if not balance.gone and balancedata.def then
          balance.gone = {
            name = action .. "_gone",
            balance = "gone",
            action_name = action,

            oncompleted = function ()
              defences.lost(action)
            end
          }
        end
      end
    end

    if not balance.name then balance.name = action end
    if balance.physical and balance.physical.balanceless_act and not balance.physical.def then svo.dict_balanceless[action] = {p = svo.dict[action]} end
    if balance.physical and balance.physical.balanceful_act and not balance.physical.def then svo.dict_balanceful[action] = {p = svo.dict[action]} end

    if balance.purgative and balance.purgative.def then
      svo.dict_purgative[action] = {p = svo.dict[action]} end

    -- balanceful and balanceless moved to a signal for dragonform!

    if balance.misc and balance.misc.def then
      svo.dict_misc_def[action] = {p = svo.dict[action]} end

    if balance.smoke and balance.smoke.def then
      svo.dict_smoke_def[action] = {p = svo.dict[action]} end

    if balance.salve and balance.salve.def then
      svo.dict_salve_def[action] = {p = svo.dict[action]} end

    if balance.misc and not balance.misc.def then
      svo.dict_misc[action] = {p = svo.dict[action]} end

    if balance.herb and balance.herb.def then
      svo.dict_herb[action] = {p = svo.dict[action]} end

    if balance.herb and not balance.herb.noeffect then
      balance.herb.noeffect = function()
        svo.lostbal_herb(true)
      end
    end

    -- mickey steals balance and gives illness
    if balance.herb and not balance.herb.mickey then
      balance.herb.mickey = function()
        svo.lostbal_herb(false, true)
        svo.addaffdict(svo.dict.illness)
      end
    end

    if balance.focus and not balance.focus.offbalance then
      balance.focus.offbalance = function()
        svo.lostbal_focus()
      end
    end
    if balance.salve and not balance.salve.offbalance then
      balance.salve.offbalance = function()
        svo.lostbal_salve()
      end
    end
    if balance.herb and not balance.herb.offbalance then
      balance.herb.offbalance = function()
        svo.lostbal_herb()
      end
    end
    if balance.smoke and not balance.smoke.offbalance then
      balance.smoke.offbalance = function()
        svo.lostbal_smoke()
      end
    end

    if balance.focus and not balance.focus.nomana then
      balance.focus.nomana = function ()
        if not svo.actions.nomana_waitingfor and stats.currentmana ~= 0 then
          svo.echof("Seems we're out of mana.")
          svo.doaction(svo.dict.nomana.waitingfor)
        end
      end
    end

    if not balance.sw then balance.sw = createStopWatch() end
  end -- went through the dict list once at this point

  for balancename, list in pairs(unassigned_actions) do
    if #list > 0 then
      -- shift up by # all actions for that balance to make room @ bottom
      for _,j in pairs(svo.dict) do
        for balance,l in pairs(j) do
          if balance == balancename and type(l) == "table" and l.aspriority and l.aspriority ~= 0 then
            l.aspriority = l.aspriority + #list
          end
        end
      end

      -- now setup the low id's
      for i, actionname in ipairs(list) do
        svo.dict[actionname][balancename].aspriority = i
      end
    end
  end

  local totalcount = 0
  for _, list in pairs(unassigned_sync_actions) do
    totalcount = totalcount + #list
  end

  for balancename, list in pairs(unassigned_sync_actions) do
    if totalcount > 0 then
      -- shift up by # all actions for that balance to make room @ bottom
      for _,j in pairs(svo.dict) do
        for _,l in pairs(j) do
          if type(l) == "table" and l.spriority and l.spriority ~= 0 then
            l.spriority = l.spriority + totalcount
          end
        end
      end

      -- now setup the low id's
      for i, actionname in ipairs(list) do
        svo.dict[actionname][balancename].spriority = i
      end
    end
  end

  -- we don't want stuff in svo.dict.lovers.map!
  svo.dict.lovers.map = {}
end
dict_setup() -- call once now to auto-setup missing dict() functions, and later on prio import to sort out the 0's.

function svo.dict_validate()
  -- basic theory is to create table keys for each table within svo.dict.#,
  -- store the dupe aspriority values inside in key-pair as well, and report
  -- what we got.
  local data = {}
  local dupes = {}
  local key = false

  -- check async ones first
  for i,j in pairs(svo.dict) do
    for k,l in pairs(j) do
      if type(l) == "table" and l.aspriority then
        local balance = k:split("_")[1]
        if not data[balance] then data[balance] = {} dupes[balance] = {} end
        key = svo.containsbyname(data[balance], l.aspriority)
          if key then
          -- store the new dupe that we found
          dupes[balance][(k:split("_")[2] and k:split("_")[2] .. " for " or "") .. i] = l.aspriority
          -- and store the previous one that we had already!
          dupes[balance][(key.balance:split("_")[2] and key.balance:split("_")[2] .. " for " or "") .. key.action_name] = l.aspriority
        end
        data[balance][l] = l.aspriority

      end
    end
  end

  -- if we got something, complain
  for i,j in pairs(dupes) do
    if next(j) then
        svo.echof("Meh, problem. The following actions in %s balance have the same priorities: %s", i, svo.oneconcatwithval(j))
    end
  end

  -- clear table for next use, don't re-make to not force rehashes
  for k in pairs(data) do
    data[k] = nil
  end
  for k in pairs(dupes) do
    dupes[k] = nil
  end

  -- check sync ones
  for _,j in pairs(svo.dict) do
    for _,l in pairs(j) do
      if type(l) == "table" and l.spriority then
        local balance = l.name
        local synckey = svo.containsbyname(data, l.spriority)
        if key then
          dupes[balance] = l.spriority
          dupes[synckey] = l.spriority
        end
        data[balance] = l.spriority

      end
    end
  end

  -- if we got something, complain
  if not next(dupes) then return end

  -- sort them first before complaining
  local sorted_dupes = {}
    -- stuff into table
  for i,j in pairs(dupes) do
    sorted_dupes[#sorted_dupes+1] = {name = i, prio = j}
  end

    -- sort table
  table.sort(sorted_dupes, function(a,b) return a.prio < b.prio end)

  local function a(tbl)
    svo.assert(type(tbl) == "table")
    local result = {}
    for _,j in pairs(tbl) do
      result[#result+1] = j.name .. "(" .. j.prio .. ")"
    end

    return table.concat(result, ", ")
  end

    -- complaining time
  svo.echof("Meh, problem. The following actions in sync mode have the same priorities: %s", a(sorted_dupes))
end

signals.dragonform:connect(function ()
  svo.dict_balanceful_def = {}
  svo.dict_balanceless_def = {}

  if not defc.dragonform then
    for i,j in pairs(svo.dict) do
      if j.physical and j.physical.balanceful_act and j.physical.def then
        svo.dict_balanceful_def[i] = {p = svo.dict[i]} end

      if j.physical and j.physical.balanceless_act and j.physical.def then
        svo.dict_balanceless_def[i] = {p = svo.dict[i]} end
    end
  else
    for i,j in pairs(svo.dict) do
      if j.physical and j.physical.balanceful_act and j.physical.def and svo.defs_data[i] and (svo.defs_data[i].type == "general" or svo.defs_data[i].type == "dragoncraft" or svo.defs_data[i].availableindragon) then
        svo.dict_balanceful_def[i] = {p = svo.dict[i]} end

      if j.physical and j.physical.balanceless_act and j.physical.def and svo.defs_data[i] and (svo.defs_data[i].type == "general" or svo.defs_data[i].type == "dragoncraft" or svo.defs_data[i].availableindragon) then
        svo.dict_balanceless_def[i] = {p = svo.dict[i]} end
    end

    -- special case for nightsight and monks: they have it
  end

end)
signals.systemstart:connect(function () signals.dragonform:emit() end)
signals.gmcpcharstatus:connect(function ()
  if gmcp.Char.Status.race then
    if gmcp.Char.Status.race:find("Dragon") then
      defences.got("dragonform")
    else
      defences.lost("dragonform")
    end
  end

  signals.dragonform:emit()
end)

svo.make_prio_table = function (filterbalance)
  local data = {}

  for action,balances in pairs(svo.dict) do
    for k,l in pairs(balances) do
      if k:sub(1, #filterbalance) == filterbalance and type(l) == "table" and l.aspriority then
        if #k ~= #filterbalance then
          data[l.aspriority] = k:sub(#filterbalance+2) .. " for " .. action
        else
          data[l.aspriority] = action
        end
      end
    end
  end

  return data
end

svo.make_sync_prio_table = function(format)
  local data, type, sformat = {}, type, string.format
  for i,j in pairs(svo.dict) do
    for k,l in pairs(j) do
      if type(l) == "table" and l.spriority then
        data[l.spriority] = sformat(format, i, k)
      end
    end
  end

  return data
end

-- func gets passed the action name to operate on, needs to return true for it to be added
svo.make_prio_tablef = function (filterbalance, func)
  local data = {}

  for action, balances in pairs(svo.dict) do
    for balance, l in pairs(balances) do
      if balance == filterbalance and type(l) == "table" and l.aspriority and (not func or func(action)) then
        data[l.aspriority] = action
      end
    end
  end

  return data
end

-- func gets passed the action name to operate on
-- skipbals is a key-value table, where a key is a balance to ignore
svo.make_sync_prio_tablef = function(format, func, skipbals)
  local data, type, sformat = {}, type, string.format
  for action, balances in pairs(svo.dict) do
    for balance, balancedata in pairs(balances) do
      if type(balancedata) == "table" and not skipbals[balance] and balancedata.spriority and (not func or func(action)) then
        data[balancedata.spriority] = sformat(format, action, balance)
      end
    end
  end

  return data
end

svo.clear_balance_prios = function(balance)
  for _,j in pairs(svo.dict) do
    for k,l in pairs(j) do
      if k == balance and type(l) == "table" and l.aspriority then
        l.aspriority = 0
      end
    end
  end
end

svo.clear_sync_prios = function()
  for _,j in pairs(svo.dict) do
    for _,l in pairs(j) do
      if type(l) == "table" and l.spriority then
        l.spriority = 0
      end
    end
  end
end

-- register various handlers
signals.curedwith_focus:connect(function (what)
  svo.dict.unknownmental.focus[what] ()
end)

svo.sk.check_retardation = function()
  if affs.retardation then
    svo.rmaff("retardation")
  end
end

if svo.haveskillset('subterfuge') then
signals.newroom:connect(function()
  if defc.listen then defences.lost("listen") end
end)
end

signals.newroom:connect(function()
  if defc.block then svo.dict.block.gone.oncompleted() end
  if defc.eavesdrop then defences.lost("eavesdrop") end
  if defc.lyre then defences.lost("lyre") end
end)

signals.newroom:connect(sk.check_retardation)
signals.newroom:block(sk.check_retardation)

-- reset impale
signals.newroom:connect(function()
  if not next(affs) then return end

  local removables = {"impale"}
  local escaped = {}
  for i = 1, #removables do
    if affs[removables[i]] then
      escaped[#escaped+1] = removables[i]
      svo.rmaff(removables[i])
    end
  end

  if #escaped > 0 then
    tempTimer(0, function()
      if stats.currenthealth > 0 then
        tempTimer(0, function()
          if not svo.find_until_last_paragraph("You scrabble futilely at the ground as", "substring") then
            svo.echof("Woo! We escaped from %s.", svo.concatand(escaped))
          end
        end)
      end
    end)
  end
end)

signals.systemstart:connect(function()
  sys.input_to_actions = {}

  for action, actiont in pairs(svo.dict) do
    for _, balancet in pairs(actiont) do
      -- ignore "check*" actions, as they are only useful when used by the system,
      -- and they can override actions that could be done by the user
      if type(balancet) == "table" and not action:find("^check") then
        if type(balancet.sipcure) == "string" then
          sys.input_to_actions["drink "..balancet.sipcure] = balancet
          sys.input_to_actions["sip "..balancet.sipcure] = balancet
        elseif type(balancet.sipcure) == "table" then
          for _, potion in ipairs(balancet.sipcure) do
            sys.input_to_actions["drink "..potion] = balancet
            sys.input_to_actions["sip "..potion] = balancet
          end

        elseif type(balancet.eatcure) == "string" then
          sys.input_to_actions["eat "..balancet.eatcure] = balancet
        elseif type(balancet.eatcure) == "table" then
          for _, thing in ipairs(balancet.eatcure) do
            sys.input_to_actions["eat "..thing] = balancet
          end

        elseif type(balancet.smokecure) == "string" then
          sys.input_to_actions["smoke "..balancet.smokecure] = balancet
          sys.input_to_actions["puff "..balancet.smokecure] = balancet
        elseif type(balancet.smokecure) == "table" then
          for _, thing in ipairs(balancet.smokecure) do
            sys.input_to_actions["smoke "..thing] = balancet
            sys.input_to_actions["puff "..thing] = balancet
          end
        end

        -- add action separately, as sileris has both eatcure and action
        if balancet.action then
          sys.input_to_actions[balancet.action] = balancet
        elseif balancet.actions then
          for _, balanceaction in pairs(balancet.actions) do
            sys.input_to_actions[balanceaction] = balancet
          end
        end
      end
    end
  end

end)


-- validate stuffs on our own
-- for i,j in pairs(svo.dict) do
--  for k,l in pairs(j) do
--   if type(l) == "table" and k == "focus" then
--     svo.echof("%s %s is focusable", i, k)
--   end
--   end
-- end
