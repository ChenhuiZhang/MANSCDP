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

      --local b = ByteArray.new(tostring(xml_body))

      print(buf)

      --print(tostring(ByteArray.tvb(b, "")))
      --print(xml_body)
      
      --local cmd = "<CmdType>Keepalive</CmdType>"

      if string.match(buf, "<CmdType>.*</CmdType>") then
        print(buf:match("<CmdType>(.*)</CmdType>"))
      end

      local cmd = buf:match("<CmdType>(.*)</CmdType>")

      --if xml_body.find(cmd:bytes()) then
       -- print "Keepalive"
      --end

      subtree:add(cmd_field, cmd)
      pinfo.cols.info:append(" " .. cmd)
    end

    --pinfo.cols['info'] = 'MANSCDP'

    --local tab = ByteArray.new("Message"):tvb("decode")
  
    --local tab_range = tab()

    --local subtree = tree:add(manscdp_protocol, tab_range)

    --subtree:add(tab_range, "asdflasdj"):add(tab_range, "aaaaaaaaaaaaaaaa")

  end


  register_postdissector (manscdp_protocol)

end

