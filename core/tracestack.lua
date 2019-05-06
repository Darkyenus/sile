-- A stack of objects which describe the call-stack of processing of the currently document
local traceStack = {

  -- Internal: Push-pop balance checking ID
  _lastPushId = 0,

  -- Stores the frame which was last popped. Reset after a push.
  -- Helps to further specify current location in the processed document.
  afterFrame = nil,

  -- Internal function assigned to stack frames to convert them to human readable location
  _getLocation = function(self, skipFile, withAttrs)
    local str
    if skipFile or not self.file then
      str = ""
    else
      str = self.file .. " "
    end
    if self.line then
      str = str .. "l." .. self.line .. " "
      if self.column then
        str = str .. "col." .. self.column .. " "
      end
    end
    if self.tag then
      -- Command
      str = str .. "\\" .. self.tag
      if withAttrs then
        str = str .. "["
        local first = true
        for key, value in pairs(self.options) do
          if first then first = false else str = str .. ", " end
          str = str .. key .. "=" .. value
        end
        str = str .. "]"
      end
    elseif self.text then
      -- Literal string
      local text = self.text
      if text:len() > 20 then
        text = text:sub(1, 18) .. "…"
      end
      text = text:gsub("\n", "␤"):gsub("\t", "␉"):gsub("\v", "␋")

      str = str .. "\"" .. text .. "\""
    else
      -- Unknown
      str = str .. type(self.content) .. "(" .. self.content .. ")"
    end
    return str
  end,

  -- Internal: Given an collection of frames and an afterFrame, construct and return a human readable info string
  -- about the location in processed document. Similar to _getLocation, but takes into account
  -- the afterFrame and the fact, that not all frames may carry a location information.
  _formatTraceHead = function (self, traceStack, afterFrame)
    local top = traceStack[#traceStack]
    if not top then
      -- Stack is empty, there is not much we can do
      return afterFrame and "after " .. self:_getLocation() or nil
    end
    local info = top:_getLocation()
    local locationFrame = top
    -- Not all stack traces have to carry location information.
    -- If the top stack trace does not carry it, find a frame which does.
    -- Then append it, because its information may be useful.
    if not top.line then
      for i = #traceStack - 1, 1, -1 do
        if traceStack[i].line then
          -- Found a frame which does carry some relevant information.
          locationFrame = traceStack[i]
          info = info .. " near " .. traceStack[i]:_getLocation(--[[skipFile=]] traceStack[i].file == top.file)
          break
        end
      end
    end
    -- Print after, if it is in a relevant file
    if afterFrame and (not locationFrame or afterFrame.file == locationFrame.file) then
      info = info .. " after " .. afterFrame:_getLocation(--[[skipFile=]] true)
    end
    return info
  end,

  -- Push a command frame on to the stack to record the execution trace for debugging.
  -- Carries information about the command call, not the command itself.
  -- Must be popped with `pop(returnOfPush)`.
  pushCommand = function(self, tag, options, file, line, column)
    if not tag then
      SU.warn("Tag should be specified for SILE.traceStack:pushCommand", true)
    end
    local file = file or SILE.currentlyProcessingFile
    return self:_push(file, line, column, tag, options)
  end,


  -- Push a command frame on to the stack to record the execution trace for debugging.
  -- Command arguments are inferred from AST content, any item may be overridden.
  -- Must be popped with `pop(returnOfPush)`.
  pushContent = function(self, content, tag)
    local tag = tag or content.tag
    if type(content) ~= "table" then
      SU.warn("Content parameter of SILE.traceStack:pushContent must be a table", true)
      content = {}
    end
    if not tag then
      SU.warn("Tag should be specified or inferable for SILE.traceStack:pushContent", true)
    end
    local file = content.file or SILE.currentlyProcessingFile
    return self:_push(file, content.line, content.col, tag, content.attr)
  end,

  -- Push a text that is going to get typeset on to the stack to record the execution trace for debugging.
  -- Must be popped with `pop(returnOfPush)`.
  pushText = function(self, text)
    return self:_push(nil, nil, nil, nil, nil, text)
  end,

  _push = function (self, file, line, column, tag, options, text, toStringFunc)
    SU.debug("commandStack", string.rep(" ", #self) .. "PUSH(" .. self:_getLocation(false, true) .. ")")
    local pushId = #self + 1
    self[pushId] = {
      file = file,
      line = line,
      column = column,
      text = text,
      tag = tag or "???",
      options = options or {},
      typesetter = SILE.typesetter,
      _getLocation = toStringFunc or self._getLocation,
      pushId = pushId
    }
    self.afterFrame = nil
    self._lastPushId = pushId
    return pushId
  end,

  -- Pop previously pushed command from the stack.
  -- Return value of `push` function must be provided as argument to check for balanced usage.
  pop = function(self, pushId)
    if type(pushId) ~= "number" then
      SU.error("SILE.traceStack:pop's argument must be the result value of the corresponding push", true)
    end
    -- First verify that push/pop is balanced
    local popped = self[#self]
    if popped.pushId ~= pushId then
      local message = "Unbalanced content push/pop"
      local debug = SILE.traceback or SU.debugging("commandStack")
      if debug then
        message = message .. ". Expected " .. popped.pushId .. " - (" .. popped:_getLocation() .. "), got " .. pushId
      end
      SU.warn(message, debug)
    else
      -- Correctly balanced: pop the frame
      self.afterFrame = popped
      self[#self] = nil
      if SU.debugging("commandStack") then
        SU.debug("commandStack", string.rep(" ", #self) .. "POP(" .. popped:_getLocation(false, true) .. ")")
      end
    end
  end,

  -- Returns short string with most relevant location information for user messages.
  locationInfo = function(self)
    return self:_formatTraceHead(self.afterFrame) or SILE.currentlyProcessingFile or "<nowhere>"
  end,

  -- Returns multiline trace string, with full document location information for user messages.
  locationTrace = function(self)
    local prefix = "  at "
    local trace = self._formatTraceHead({ self[#self] } --[[we handle rest of the stack ourselves]], self.afterFrame)
    if not trace then
      -- There is nothing else then
      return prefix .. (SILE.currentlyProcessingFile or "<nowhere>") .. "\n"
    end
    trace = prefix .. trace .. "\n"
    -- Iterate backwards, skipping the last element
    for i = #self - 1, 1, -1 do
      local s = self[i]
      trace = trace .. prefix .. s:_getLocation() .. "\n"
    end
    return trace
  end

}

return traceStack
