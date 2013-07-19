-- Decode the content SIP body message follow the GB28181 standard
-- Author: Hermes Zhang (zhangchenhui2006@gmail.com)
-- 

do
  local manscdp_protocol = Proto ("MANSCDP", "MANSCDP decode")

  local sip_method = Field.new ("sip.Method")

  local cmd_field = ProtoField.string("manscdp.cmd","Command Type")

  manscdp_protocol.fields = {cmd_field}

  function hex_to_string(byte_array)
    local str = ''
    local i = 0

    print(byte_array)
    print(byte_array:len())

    for i=0,byte_array:len()-1 do
      --print(i)
      --print(string.sub(tostring(byte_array), i*2+1, i*2+2))
      --print(tonumber(string.sub(tostring(byte_array), i*2+1, i*2+2), 16))
      --print(string.char(tonumber(string.sub(tostring(byte_array), i*2+1, i*2+2), 16)))
      str = str .. string.char(tonumber(string.sub(tostring(byte_array), i*2+1, i*2+2), 16))
    end

    --print(str)
    return str
  end

  function num_to_bits(num)
    local table = {}
    local index = 1

    num = tonumber(num)

    while (num > 0) do
      local last_bit = math.mod(num, 2)
      if last_bit == 1 then
        table[index] = 1
      else
        table[index] = 0
      end

      num = (num - last_bit)/2
      index = index + 1
    end

    return table
  end

  function ptz_display(cmd)
    local bittable = num_to_bits(cmd:sub(7,8))

    local display = "PTZ: "
    -- pan/tilt speed is stroed in the byte 5/6, 00 ~ FF
    local pan_speed = tonumber(cmd:sub(9,10), 16)
    local tilt_speed = tonumber(cmd:sub(11,12), 16)
    -- zoom speed is stored in the high 4 bit, 0 ~ F
    local zoom_speed = tonumber(cmd:sub(13,14), 16)/16

    if bittable[1] == 1 then display = display .. "Right(" .. pan_speed .. ")" end
    if bittable[2] == 1 then display = display .. "Left(" .. pan_speed .. ")" end
    if bittable[3] == 1 then display = display .. "Down(" .. tilt_speed .. ")" end
    if bittable[4] == 1 then display = display .. "Up(" .. tilt_speed .. ")" end
    if bittable[5] == 1 then display = display .. "Zoom In(" .. zoom_speed .. ")" end
    if bittable[6] == 1 then display = display .. "Zoom Out(" .. zoom_speed .. ")" end

    -- No ptz command found, stop all
    if display:len() == 5 then display = display .. "Stop" end

    return display
  end

  function handle_DeviceControl(xml, pinfo)
    print(xml)

    local ptz = xml:match("<PTZCmd>(.*)</PTZCmd>")

    if ptz then
      pinfo.cols.info:append(" " .. ptz_display(ptz))
    end
  end

  function manscdp_protocol.dissector(tvb, pinfo, tree)
    local method = sip_method()

    if not method then return end

    if tostring(method) == "MESSAGE" then

      local raw = tostring(tvb:range(0, tvb:len()):bytes())

      print(raw)

      local i, j = string.find(raw, "0D0A0D0A")

      print(i, j)

      local subtree = tree:add(manscdp_protocol, tvb:range(j/2))
      
      local xml_dissector = Dissector.get("xml")

      local xml_body = tvb:range(j/2):tvb()

      xml_dissector:call(xml_body, pinfo, subtree)

      local buf = hex_to_string(xml_body:range(0, xml_body:len()):bytes())

      print(buf)

      --[[
      if string.match(buf, "<CmdType>.*</CmdType>") then
        print(buf:match("<CmdType>(.*)</CmdType>"))
      end
      ]]--

      local cmd = buf:match("<CmdType>(.*)</CmdType>")

      subtree:add(cmd_field, cmd)
      pinfo.cols.info:append(" " .. cmd)

      if cmd == "Keepalive" then
      elseif cmd == "Catalog" then
      elseif cmd == "DeviceControl" then
          handle_DeviceControl(buf, pinfo)
      elseif cmd == "Alarm" then
      elseif cmd == "DeviceInfo" then
      else
      end

    end

    --pinfo.cols['info'] = 'MANSCDP'

    --local tab = ByteArray.new("Message"):tvb("decode")
  
    --local tab_range = tab()

    --local subtree = tree:add(manscdp_protocol, tab_range)

    --subtree:add(tab_range, "asdflasdj"):add(tab_range, "aaaaaaaaaaaaaaaa")

  end


  register_postdissector (manscdp_protocol)

end

