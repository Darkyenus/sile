local _untraceable = function () return SILE.currentlyProcessingFile .. ":" or "<nowhere>" end

-- Helper function to identify items in stack with human readable locations
local _formatLocation = function(self, skipFile, withAttrs)
  local str = ""
  if self.file and not skipFile then
    str = self.file .. ":"
    if self.line then
      str = str .. self.line .. ":"
      if self.column then
        str = str .. self.column .. ":"
      end
      str = str .. " "
    end
  end
  if self.tag then
    -- Command
    str = str .. "\\" .. self.tag
    if withAttrs then
      str = str .. "["
      local first = true
      for key, value in pairs(self.options) do
        if first then
          first = false
        else
          str = str .. ", "
        end
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
    str = str .. '"' .. text .. '"'
  else
    -- Unknown
    str = str .. type(self.content) .. "(" .. self.content .. ")"
  end
  return str
end

-- A stack of objects which describe the call-stack of processing of the currently document
local traceStack = {

  -- Push-pop balance checking ID
  _lastPushedId = 0,

  -- Stores whatever object was last popped. Reset after a push.
  -- Helps to further specify current location in the processed document.
  _lastPopped = nil,

  -- Internal: Given an collection of frames and an _lastPopped, construct and return a human readable info string
  -- about the location in processed document. Similar to _formatLocation, but takes into account
  -- the _lastPopped and the fact, that not all frames may carry a location information.
  _formatTrace = function (self)
    local top = self[#self]
    if not top then
      -- Stack is empty, there is not much we can do
      return self.lastPopped and "after " .. self.lastPopped:_formatLocation() or nil
    end
    local info = top:_formatLocation()
    local locationFrame = top
    -- Not all stack traces have to carry location information.
    -- If the top stack trace does not carry it, find an item which does.
    -- Then append it, because its information may be useful.
    if not top.line then
      for i = #self - 1, 1, -1 do
        if self[i].line then
          locationFrame = self[i]
          info = info .. " near " .. self[i]:_formatLocation(self[i].file == top.file)
          break
        end
      end
    end
    -- Print after, if it is in a relevant file
    if self.lastPopped and (not locationFrame or self.lastPopped.file == locationFrame.file) then
      info = info .. " after " .. _self.lastPopped:formatLocation(true)
    end
    return info
  end,

  -- Push a command to the stack to record the execution trace for debugging.
  -- Carries information about the command call, not the command itself.
  -- Must be popped with `pop(returnOfPush)`.
  pushCommand = function(self, tag, options, file, line, column)
    if not tag then
      SU.warn("Tag should be specified for SILE.traceStack:pushCommand", true)
    end
    local file = file or SILE.currentlyProcessingFile
    return self:_push(file, line, column, tag, options)
  end,


  -- Push a command to the stack to record the execution trace for debugging.
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
    local pushId = #self + 1
    self[pushId] = {
      file = file,
      line = line,
      column = column,
      text = text,
      tag = tag,
      options = options or {},
      typesetter = SILE.typesetter,
      _formatLocation = toStringFunc or _formatLocation,
      pushId = pushId
    }
    SU.debug("commandStack", string.rep(" ", #self) .. "PUSH(" .. self[pushId]:_formatLocation() .. ")")
    self._lastPopped = nil
    self._lastPushedId = pushId
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
      if SILE.traceback or SU.debugging("commandStack") then
        message = message .. ". Expected " .. popped.pushId .. " - (" .. popped:_formatLocation() .. "), got " .. pushId
      end
      SU.warn(message, true)
    else
      self._lastPopped = popped
      self[#self] = nil
      SU.debug("commandStack", string.rep(" ", #self) .. "POP(" .. popped:_formatLocation(false, true) .. ")")
    end
  end,

  -- Returns short string with most relevant location information for user messages.
  locationInfo = function(self)
    return self:_formatTrace() or _untraceable()
  end,

  -- Returns multiline trace string, with full document location information for user messages.
  locationTrace = function(self)
    local prefix = "\t"
    local trace = _formatLocation(self[#self])
    if not trace then
      return prefix .. _untraceable() .. "\n"
    end
    trace = prefix .. trace .. "\n"
    -- Iterate backwards, skipping the last element
    for i = #self - 1, 1, -1 do
      trace = trace .. prefix .. self[i]:_formatLocation() .. "\n"
    end
    return trace
  end

}

return traceStack
