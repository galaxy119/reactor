--[[
Conservative reactor control program.
Very simple to use, start the program and enjoy, no need to fiddle with configurations or settings.

Will display the Reactor state (on or off), reserve percentage, current RF/t production, fuel level, fuel reactivity level, temperatures and fuel rod insertion level.
Does NOT currently work on activly cooled reactors, this program is for passive cooled only.
Author: Joker119
]]


--The maximum amount of energy a reactor can store
local maxEnergy = 10000000

--Loading the required libraries
local component = require("component")
local keyboard = require("keyboard")
local term = require("term")

--This is true if there is no available screen or the option -s is used
local silent = not term.isAvailable()

local hasCustomValues, shouldChangeRods = false, false

local function serror(msg, msg2)
  msg2 = msg2 or msg
  if silent then
    error(msg, 2)
  else
    io.stderr:write(msg2)
    os.exit()
  end
end

do
  local shell = require("shell")
  local args, options = shell.parse(...)
  if options.s then silent = true end
  if options.b then shouldChangeRods = true end
  if #args > 0 then
    turnOn = tonumber(args[1])
    turnOff = tonumber(args[2])
    hasCustomValues = true
  end
end

--Check whether there is a Reactor Computer Port to access
if not component.isAvailable("br_reactor") then
  serror("No connected Reactor Computer Port found.", "This program requires a connected Reactor Computer Port to run.")
end

--Getting the primary port
local reactor = component.br_reactor

--Displays long numbers with commas
local function fancyNumber(n)
  return tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):gsub("%D$",""):reverse()
end

--Displays numbers with a special offset
local function offset(num, d, ext)
  if num == nil then return "" end
  if type(num) ~= "string" then
    if type(num) == "number" then
      if ext then
        return offset(tostring(math.floor(num * 100) / 100), d)
      else
        return offset(tostring(math.floor(num)), d)
      end
    end
    return offset(tostring(num), d)
  end
  if d <= #num then return num end
  return string.rep(" ", d - #num) .. num
end

if not silent then
  component.gpu.setResolution(component.gpu.maxResolution())
  term.clear()

  print("Press Ctrl+W to shutdown.")
end

--Get the current y position of the cursor for the RF display
local y, h
do
  local x,w
  x,y = term.getCursor()
  w,h = component.gpu.getResolution()
end

--The interface offset
local offs = #tostring(maxEnergy) + 5

local function handleReactor()
  --Get the current amount of energy stored
  local stored = reactor.getEnergyStored()
  local stored_pec = stored / maxEnergy * 100

  --Set Reactor Control Rod  based on energy stored
  reactor.setAllControlRodLevels(stored_pec)

  --Write the reactor state, the currently stored energy, the percentage value and the current production rate to screen
  if not silent then
    term.setCursor(1, y)
    term.clearLine()
    local state = reactor.getActive()
    if state then
      state = "On"
    else
      state = "Off"
      reactor.setActive(true)
    end
    term.write("Reactor State:         " .. offset(state, offs) .. "\n", false)
    term.clearLine()
    term.write("Reserve Level:         " .. offset(stored / maxEnergy * 100, offs) .. " %\n", false)
    term.clearLine()
    term.write("Current Output:    " .. offset(fancyNumber(reactor.getEnergyProducedLastTick()), offs) .. " RF/t\n", false)
    term.clearLine()
    term.write("Output Capacity:       " .. offset(reactor.getControlRodLevel(1), offs) .. " %\n", false)
    term.clearLine()
    term.write("Casing Temperature:    " .. offset(fancyNumber(reactor.getCasingTemperature()), offs) .. " c\n", false)
    term.clearLine()
    term.write("Fuel Rod Temperature:  " .. offset(fancyNumber(reactor.getFuelTemperature(), offs) .. " c\n", false)
    term.clearLine()
    term.write("Fuel Level:            " .. offset(fancyNumber(reactor.getFuelAmount() / reactor.getFuelAmountMax() * 100 + 1), offs) .. " %n", false)
    term.clearLine()
    term.write("Fuel Reactivity:       " .. offset(fancyNumber(reactor.getFuelReactivity()), offs) .. " %\n", false)
    term.clearLine()
    term.write("Fuel Consumption:      " .. offset(reactor.getFuelConsumedLastTick(), offs) .. " mB/t\n", false)
    term.clearLine()
  end
end

while true do
  handleReactor()

  --Check if the program has been terminated
  if keyboard.isKeyDown(keyboard.keys.w) and keyboard.isControlDown() then
    --Shut down the reactor, place cursor in a new line and exit
    if not silent then
      term.write("\nReactor shut down.\n")
    end
    reactor.setActive(false)
    os.exit()
  end
  os.sleep(1)
end
