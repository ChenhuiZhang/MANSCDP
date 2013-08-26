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
      str = str .. string.char(tonumber(string.sub(tostring(byte_array), i*2+1, i*2+2), 16))
    end

    return str
  end

  function num_to_bits(num)
    local table = {0,0,0,0,0,0,0,0}
    local index = 1

    num = tonumber(num, 16)

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

  function ptz_scan_display(cmd)
    local command_type = tonumber(cmd:sub(7,8), 16)

    if command_type == 0x89 then
        local scan = tonumber(cmd:sub(11,12), 16)
        if scan == 0x00 then
            return "START SCAN"
        elseif scan == 0x01 then
            return "SCAN LEFT"
        elseif scan == 0x02 then
            return "SCAN RIGHT"
        else
            return "Unknow scan command"
        end
    else
        local speed = tonumber(cmd:sub(11,12), 16) + tonumber(cmd:sub(13,14), 16) * 0xFF
        return "SCAN SPEED(" .. speed .. ")"
    end
  end

  function ptz_fi_display(cmd)
    local display = ""
    local bittable = num_to_bits(cmd:sub(7,8))
    local focus_speed = tonumber(cmd:sub(9,10), 16)
    local iris_speed = tonumber(cmd:sub(11,12), 16)

    if bittable[1] == 1 then display = display .. "Focus Far(" .. focus_speed .. ")" end
    if bittable[2] == 1 then display = display .. "Focus Near(" .. focus_speed .. ")" end
    if bittable[3] == 1 then display = display .. "Iris Open(" .. iris_speed .. ")" end
    if bittable[4] == 1 then display = display .. "Iris Close(" .. iris_speed .. ")" end

    if display:len() == 0 then display = "Focus/Iris Stop" end

    return display
  end

  function ptz_preset_display(cmd)
    local command_type = tonumber(cmd:sub(7,8), 16)
    local preset_index = tonumber(cmd:sub(11,12), 16)

    if command_type == 0x81 then return "Preset Set(" .. preset_index .. ")" end
    if command_type == 0x82 then return "Preset Goto(" .. preset_index .. ")" end
    if command_type == 0x83 then return "Preset Del(" .. preset_index .. ")" end

    return "Unkonw preset command"
  end

  function ptz_tour_display(cmd)
    local command_type = tonumber(cmd:sub(7,8), 16)
    local tour_index = tonumber(cmd:sub(9,10), 16)

    if command_type == 0x84 then
        local preset_index = tonumber(cmd:sub(11,12), 16)
        return "Tour(" .. tour_index ") Add Preset(" .. preset_index ")"
    elseif command_type == 0x85 then
        local preset_index = tonumber(cmd:sub(11,12), 16)
        return "Tour(" .. tour_index ") Remove Preset(" .. preset_index ")"
    elseif command_type == 0x86 then
        -- The high 4 bytes of the 7th Byte + the 8 bytes of the 6th Byte
        local tour_speed = tonumber(cmd:sub(13,14), 16)/0x0F * 0xFF + tonumber(cmd:sub(11,12), 16)
        return "Tour(" .. tour_index ") Set Speed(" .. tour_speed ")"
    elseif command_type == 0x87 then
        -- seconds
        local stop_time = tonumber(cmd:sub(13,14), 16)/0x0F * 0xFF + tonumber(cmd:sub(11,12), 16)
        return "Tour(" .. tour_index ") Set Stop Time(" .. stop_time ")"
    elseif command_type == 0x88 then
        return "Tour(" .. tour_index ") Start"
    else
        return "Unknow Tour command"
    end
  end

  function ptz_move_display(cmd)
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

  function ptz_display(cmd)
    -- the fouth byte is the command
    local bittable = num_to_bits(cmd:sub(7,8))
    local command_type = tonumber(cmd:sub(7,8), 16)

    if bittable[8] == 0 and bittable[7] == 0 then
        return ptz_move_display(cmd)
    elseif bittable[8] == 0 and bittable[7] == 1 then
        return ptz_fi_display(cmd)
    elseif command_type >= 0x81 and command_type <= 0x83 then
        return ptz_preset_display(cmd)
    elseif command_type >= 0x84 and command_type <= 0x88 then
        return ptz_tour_display(cmd)
    elseif command_type >= 0x89 and command_type <= 0x8A then
        return ptz_scan_display(cmd)
    else
        return "Unkonw ptz command"
    end
  end

  function handle_DeviceControl(xml, pinfo)
    local ptz = xml:match("<PTZCmd>(.*)</PTZCmd>")
    local boot = xml:match("<TeleBoot>Boot</TeleBoot>")
    local record = xml:match("<RecordCmd>(.*)</RecordCmd>")

    if ptz then
      pinfo.cols.info:append(" " .. ptz_display(ptz))
    end

    if boot then
      pinfo.cols.info:append(" " .. "Boot")
    end

    if record then
      pinfo.cols.info:append(" " .. record)
    end
  end

  function manscdp_protocol.dissector(tvb, pinfo, tree)
    local method = sip_method()

    if not method then return end

    if tostring(method) == "MESSAGE" then

      local raw = tostring(tvb:range(0, tvb:len()):bytes())

      local i, j = string.find(raw, "0D0A0D0A")

      local subtree = tree:add(manscdp_protocol, tvb:range(j/2))
      
      local xml_dissector = Dissector.get("xml")

      local xml_body = tvb:range(j/2):tvb()

      xml_dissector:call(xml_body, pinfo, subtree)

      local buf = hex_to_string(xml_body:range(0, xml_body:len()):bytes())

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

