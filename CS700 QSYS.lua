--      VARIABLES

--  CONNECTIONS
yamaha = TcpSocket.New()
yamaha.ReadTimeout = 0
yamaha.WriteTimeout = 0
yamaha.ReconnectTimeout = 5

-- NUMERIC AND TEXT

-- IP and PORT related
address = ""
port = 0

-- PAN, TILT and ZOOM movement related
operation = ""
press_comando = 0
operator = 0

-- indicates a correct LOGIN 
login = 0

-- CAMERA SCENE related
preset_save_activo = 0
save_id = 0




-- ARRAYS
bt_st_eng = {"Off", "Initializing", "Updating", "Pairing", "Enabled", "Connecting", "Connected"}
bt_st_esp = {"Apagado", "Iniciando", "Actualizando", "Vinculando", "Habilitado", "Conectando", "Conectado"} --translation to spanish
ptz_esc = { preset1 = {p=25, t=10, z=250}, preset2 = {p=25, t=10, z=250}, preset3 =  {p=25, t=10, z=250}, preset4 =  {p=25, t=10, z=250} }



-- TIMERS

press_timer = Timer.New()
pair_timer = Timer.New()
wol_timer = Timer.New()
beginning_timer = Timer.New()

-- INITIAL VALUES FOR SOME CONTROLS

Controls.status.Color = "red"
Controls.usb_con.Color = "blue"
Controls.bt_con.Color = "DODGERBLUE"
Controls.bt_con.Value = 0


Controls.status.Value = 1
Controls.spk_vol.Value = 7
Controls.bt_pair.Value = 0

Controls.bt_status[1].String = ""
Controls.bt_status[2].String = ""

for i=1, #Controls.sys_info do  -- Remove the text from info text field
  Controls.sys_info[i].String = ""
end


--        FUNCTIONS  
 
function begin() -- begin connection when both IP and Port has valid values
  if address == nil then
    Controls.status.Color = "red"
  elseif port ~= nil then
      yamaha:Connect(address, port)
      
      Controls.sys_info[4].String = ""

      Timer.CallAfter( function()
        initialize()
      end, 2)

      wol_timer:Start(300)
  end
end
-- * * * * * * * * * * * * * * * * * * Ending of BEGIN function

function translate_text(letters) -- it takes the status bluetooth and translates it to spanish
  if letters == nil then        -- plus, when bluetooth connects, it takes the name of the connected device
    letters = ""                -- plus enables blinking led when pairing
  end
  for i=1, #bt_st_eng do
    if letters:find(bt_st_eng[i]) then
      Controls.bt_status[1].String = bt_st_esp[i]
      if Controls.bt_status[1].String == "Conectado" then
        pair_timer:Stop()
        Controls.bt_con.Value = 1
        Timer.CallAfter (function()
          yamaha:Write("get bt-connected\r")
        end,1)
      elseif Controls.bt_status[1].String == "Vinculando" then
        pair_timer:Start(.27)
      else
        Controls.bt_con.Value = 0
        Controls.bt_status[2].String = ""
        pair_timer:Stop()
      end
    end
  end
end
-- * * * * * * * * * * * * * * * * * * Ending of BLUETOOTH STATUS TRANSLATION

function login_time() -- SUBMIT ACCESS CREDENTIALS
      if rx_data:find("cs700 login:") then
          yamaha:Write("roomcontrol\r")
      elseif rx_data:find("Password:") then
         yamaha:Write("Yamaha-CS-700\r")
      elseif rx_data:find("Welcome") then
        Timer.CallAfter ( function()
            yamaha:Write("regnotify\r")
        end, 1)
      elseif rx_data:find("regnotify success") then
        login = 1
        Controls.status.Color = "green"
      elseif rx_data:find("terminate_client") then
        print("no se inició corrrectamente")
        Controls.reset:Trigger()
      end
end
-- * * * * * * * * * * * * * * * * * * Ending of ACCESS CREDENTIALS

function initialize()             -- This function gets the initial info like SN, device name, volume status, among other values
  Timer.CallAfter (function()
    yamaha:Write("set echo 1\r")
    yamaha:Write("get usb-conn-status\r")
    
    Timer.CallAfter (function()
      yamaha:Write("get speaker-volume\r")
      
      Timer.CallAfter (function()
        yamaha:Write("get systemname\r")
        yamaha:Write("get base-ver\r")
        yamaha:Write("get base-sernum\r")
        
        Timer.CallAfter (function()
          yamaha:Write("get bt-enable\r")
          
          Timer.CallAfter (function()
            yamaha:Write("get bt-status\r")
          
          end,.5) 
        end,.5)
      end,.5)   
    end,.5) 
  end,.5)
end
-- * * * * * * * * * * * * * * * * * * Ending of INITIALIZE function

function parse_feedback (info)    -- Main Function that parses line by line what comes from the CS-700
    
  if info ~= nil and info:find("notify") or info:find("val") then
    if info:find("systemname")  then
      valor = info:match("%s([A-Za-z0-9]+%p?[A-Za-z0-9]+%p?[A-Za-z0-9]+)$")
      Controls.sys_info[1].String = valor
    elseif info:find("base") and info:find("ver") then
      valor = info:match("%d?%d?%d.%d?%d?%d.%d?%d?%d.%d?%d?%d")
      Controls.sys_info[2].String = valor
    elseif info:find("sernum") then
      valor = info:match("%a?%a?%a?%a?%d%d%d%d%d%d%d%d%d%d?")
      Controls.sys_info[3].String = valor
    elseif info:find("audio.mute")  then
      valor = info:match("%s(%d)")
      Controls.mic_mute.Value = valor
    elseif info:find("camera") and info:find("mute") then
      valor = info:match("%s(%d)")
      print (valor)
      Controls.cam_mute.Value = valor
   
    elseif info:find("camera") and info:find("pan") then
      valor = info:match("%s(%p?%d?%d)")
      if preset_save_activo == 1 then
        for k,v in pairs(ptz_esc) do
          if k == save_id then
            
            ptz_esc[k].p = valor
          end
        end
      end
      
    elseif info:find("camera") and info:find("tilt") then
      valor = info:match("%s(%p?%d?%d)")
      if preset_save_activo == 1 then
        for k,v in pairs(ptz_esc) do
          if k == save_id then
            
            ptz_esc[k].t = valor
          end
        end
      end    
      
    elseif info:find("camera") and info:find("zoom") then
      valor = info:match("%s(%d%d%d)")
      if preset_save_activo == 1 then
        for k,v in pairs(ptz_esc) do
          if k == save_id then
            
            ptz_esc[k].z = valor
          end
        end
      preset_save_activo = 0
      end
      Controls.zoom_level.Value = valor
    
    elseif info:find("speaker") and info:find("mute") then
      valor = info:match("%s(%d)")
      print (valor)
      Controls.spk_mute.Value = valor
    elseif info:find("speaker") and info:find("volume") then
      valor = info:match("%s(%d?%d)")
      print (valor)
      Controls.spk_vol.Value = valor
    elseif info:find("usb") and info:find("conn") then
      valor = info:match("%s(%d)")
      print (valor)
      Controls.usb_con.Value = valor
    elseif info:find("bt") and info:find("enble") then
      valor = info:match("%s(%d)")
      print (valor)
      Controls.bt_enable.Value = valor
    elseif info:find("bt") and info:find("status") then
      valor = info:match("%s(%w+)$")
      print (valor) 
      translate_text(valor)
    elseif info:find("bt") and info:find("connected") then
      valor = info:match(":%w%w%s([A-Za-z0-9]+%p?%s?[A-Za-z0-9]+%p?%s?[A-Za-z0-9]+%p?)$") -- It looks for a name with 3 words with mixed numbers and letters
      print (valor) 
      if valor == nil then
        Controls.bt_status[2].String = ""
      else
        Controls.bt_status[2].String = valor
      end
    end
  end
end

-- * * * * * * * * * * * * * * * * * * Ending of PARSING FUNCTION

function camera_function(action, digit)   -- This funciton do the camera movemient and volume control
    local temp = 0
    
    if action ~= "volumen" and action ~= "zoom" then
      yamaha:Write("cam-" .. action .. "\r")
    elseif action == "volumen" then
      if Controls.spk_vol.Value + digit ~= 0 then
        yamaha:Write("set speaker-volume " .. math.tointeger(Controls.spk_vol.Value + digit) .. "\r")
        Controls.spk_vol.Value = Controls.spk_vol.Value + digit
      end
    elseif action == "zoom" then
      if Controls.zoom_level.Value < 200 then
        digit = digit * 10
      elseif Controls.zoom_level.Value < 300 then
        digit = digit * 5
      elseif Controls.zoom_level.Value < 400 then
        digit = digit * 2
      end 
      temp = Controls.zoom_level.Value + digit
      if not (temp < 100 or temp > 400) then 
        yamaha:Write("set camera-zoom " .. math.tointeger(temp) .. "\r")
        Controls.zoom_level.Value = temp
      end
    end
    
end

-- * * * * * * * * * * * * * * * * * * Ending of function in charge of CAMERA MOVEMENT

--        EVENTHANDLERS

yamaha.EventHandler = function(sock, evt, err)  -- Main Handler for the Connection

  if evt == TcpSocket.Events.Connected then
    print( "Equipo Conectado" )
    beginning_timer:Stop()
  elseif evt == TcpSocket.Events.Reconnect then
    print( "Reconectando..." )
    Controls.status.Color = "yellow"
    if login == 1 then
      begin()
    else
      login = 0
    end
  elseif evt == TcpSocket.Events.Data then
    if login == 0 then
      rx_data = yamaha:Read(yamaha.BufferLength)
    else
      rx_data = yamaha:ReadLine(TcpSocket.EOL.Custom, "\n\r")
    end
    while (rx_data ~= nil) do
      rx_data = rx_data:gsub("%c", "")
      rx_data = rx_data:gsub("%c", "")
      print( "RX: " .. rx_data)
      if login == 0 then
        login_time()
      else
        parse_feedback (rx_data)
      end
      rx_data = yamaha:ReadLine(TcpSocket.EOL.Custom, "\n\r")
    end
  elseif evt == TcpSocket.Events.Closed then
    print( "Conexión cerrada por un remoto" )
    Controls.status.Color = "red"
    login = 0
  elseif evt == TcpSocket.Events.Error then
    print( "Conexión cerrada por un error: ", err )
    Controls.status.Color = "red"
    login = 0
  elseif evt == TcpSocket.Events.Timeout then
    print( "Conexión cerrada por un timeout." )
    Controls.status.Color = "red"
    login = 0
    login = 0
  else
    print( "unknown socket event", evt ) --should never happen
    Controls.status.Color = "red"
    login = 0
  end
end

-- * * * * * * * * * * * * * * * * * * Ending of Main Hander for the Connection

-- EVENTHANDLERS FOR SOUNDBAR CONTROLS

for i=1, 2 do 

  Controls.pan_btn[i].EventHandler = function()   -- Pan Buttons
    if Controls.pan_btn[i].Boolean == true and press_comando == 0 then
      press_timer:Start(.35)
      press_comando = 1
      if i == 1 then
        operation = "pan-left" 
      elseif i == 2 then 
        operation = "pan-right" 
      end
      camera_function (operation)
    elseif Controls.pan_btn[i].Boolean == false then
      press_timer:Stop()
      press_comando = 0
    end
  end
  
  Controls.tilt_btn[i].EventHandler = function()    -- Tilt Buttons
    if Controls.tilt_btn[i].Boolean == true and press_comando == 0 then
      press_timer:Start(.35)
      press_comando = 1
      operation = "tilt"
      if i == 1 then
        operation = "tilt-up" 
      elseif i == 2 then 
        operation = "tilt-down" 
      end
      camera_function (operation)
    elseif Controls.tilt_btn[i].Boolean == false then
      press_timer:Stop()
      press_comando = 0
    end
  end
  
  Controls.zoom_btn[i].EventHandler = function() -- Zoom Buttons
    if Controls.zoom_btn[i].Boolean == true and press_comando == 0 then
      press_timer:Start(.3)
      press_comando = 1
      operation = "zoom"
      if i == 1 then
        operator = 1 -- Zoom in
      elseif i == 2 then 
        operator = -1 -- Zoom out
      end
      camera_function (operation, operator)
    elseif Controls.zoom_btn[i].Boolean == false then
      press_timer:Stop()
      press_comando = 0
    end
  end

  Controls.spk_vol_btn[i].EventHandler = function() -- Speaker Volume
    if Controls.spk_vol_btn[i].Boolean == true and press_comando == 0 then
      press_timer:Start(.5)
      press_comando = 1
      
      operation = "volumen"
      if i == 1 then
        operator = -1 -- Raises volume
      elseif i == 2 then 
        operator = 1 -- Lowers volumen
      end
      camera_function (operation, operator)
    elseif Controls.spk_vol_btn[i].Boolean == false then
      press_timer:Stop()
      press_comando = 0
    end
  end
  
end


Controls.cam_mute.EventHandler = function()   -- Video Mute
  if Controls.cam_mute.Boolean == true then
    yamaha:Write("set camera-mute 1\r")
  else
    yamaha:Write("set camera-mute 0\r")
  end
end

Controls.cam_home.EventHandler = function()   -- camera home ****** forgot the command! not working
    yamaha:Write("set camera-mute 1\r")
end

Controls.spk_mute.EventHandler = function()   -- Speaker mute
  if Controls.spk_mute.Boolean == true then
    yamaha:Write("set speaker-mute 1\r")
  else
    yamaha:Write("set speaker-mute 0\r")
  end
end

Controls.mic_mute.EventHandler = function()   -- Mic Mute
  if Controls.mic_mute.Boolean == true then
    yamaha:Write("set mute 1\r")
  else
    yamaha:Write("set mute 0\r")
  end
end

Controls.bt_enable.EventHandler = function()  -- Enable/Disable BT
  if Controls.bt_enable.Boolean == true then
    yamaha:Write("set bt-enable 1\r")
  else
    yamaha:Write("set bt-enable 0\r")
  
  end
end

Controls.bt_pair.EventHandler = function()  -- Enable/Disable BT Pair
  if Controls.bt_pair.Boolean == true then
    print("pasa esto en true")
    yamaha:Write("bt-pair 1\r") 
  else
    print("pasa esto en false")
    yamaha:Write("bt-pair 0\r")
  end
end

Controls.nfc_enable.EventHandler = function() -- Enable/Disable NFC
  if Controls.nfc_enable.Boolean == true then
    yamaha:Write("set nfc-enable 1\r")
  else
    yamaha:Write("set nfc-enable 0\r")
  end
end

for index, control in pairs(Controls.pres_load) do -- Camera scene load (4 buttons)
  control.EventHandler = function()
    for preset, ptz in pairs (ptz_esc) do
      if preset == "preset" .. index then
          save_id = preset
          yamaha:Write("set camera-pan " .. math.tointeger(ptz.p) .."\r")
          yamaha:Write("set camera-tilt " .. math.tointeger(ptz.t) .."\r")
          yamaha:Write("set camera-zoom " .. math.tointeger(ptz.z) .."\r")
      end
    end
  end
end

for index, control in pairs(Controls.pres_store) do -- Camera scene store (4 buttons)
  control.EventHandler = function()
    for preset, ptz in pairs (ptz_esc) do
      if preset == "preset" .. index then
          save_id = preset
          preset_save_activo = 1
          yamaha:Write("get camera-pan\r")
          yamaha:Write("get camera-tilt\r")
          yamaha:Write("get camera-zoom\r")
          Timer.CallAfter ( function()
            Component.New("snap" .. tostring(index) ..".p")["integer.1"].Value = math.tointeger(ptz.p)
            Component.New("snap" .. tostring(index) ..".t")["integer.1"].Value = math.tointeger(ptz.t)
            Component.New("snap" .. tostring(index) ..".z")["integer.1"].Value = math.tointeger(ptz.z)
          end,2)
      end
    end
  end
end

Controls.ip.EventHandler = function() -- finds the correct format for IP and begins connection
  address = Controls.ip.String:match("%d?%d?%d.%d?%d?%d.%d?%d?%d.%d?%d?%d")
  beginning_timer:Start(1)
  begin()
end

Controls.port.EventHandler = function() -- finds the correct format for port and begins connection
  port = tonumber(Controls.port.String:match("%d?%d?%d?%d?%d?%d%d?"))
  beginning_timer:Start(1)
  begin()
end
 

Controls.test.EventHandler = function() -- For test commands
  yamaha:Write("get voip-capable\r")

end

-- TIMER'S EVENTHANDLERS

press_timer.EventHandler = function()
  camera_function (operation, operator)
end

pair_timer.EventHandler = function()
  if Controls.bt_con.Value == 1 then
    Controls.bt_con.Value = 0
  else
    Controls.bt_con.Value = 1
  end
end

wol_timer.EventHandler = function()
  yamaha:Write("get region\r")
end

beginning_timer.EventHandler = function()  -- Checks the IP and por every second in order to determine if the connection is possible
  if Controls.ip.String:match("%d?%d?%d.%d?%d?%d.%d?%d?%d.%d?%d?%d") == nil then
    Controls.sys_info[4].String = "IP Incorrecta"
    Controls.status.Color = "red"
  elseif tonumber(Controls.port.String:match("%d?%d?%d?%d?%d?%d%d?")) == nil then
    Controls.sys_info[4].String = "Puerto Incorrecto"
    Controls.status.Color = "red"
  elseif Controls.status.Color == "red" or Controls.status.Color == "yellow"then
    Controls.sys_info[4].String = "Posible IP o puerto Incorrectos"
    Controls.status.Color = "red"
  end
end 

--    MAIN

for index, control in pairs(Controls.pres_load) do  -- it takes stored values of the camera scenes from the fixed controls 
    for preset, ptz in pairs (ptz_esc) do
      if preset == "preset" .. index then
          ptz.p = math.tointeger(Component.New("snap" .. index ..".p")["integer.1"].Value)
          ptz.t = math.tointeger(Component.New("snap" .. index ..".t")["integer.1"].Value)
          ptz.z = math.tointeger(Component.New("snap" .. index ..".z")["integer.1"].Value)
      end
    end
end

address = Controls.ip.String:match("%d?%d?%d.%d?%d?%d.%d?%d?%d.%d?%d?%d")
port = tonumber(Controls.port.String:match("%d?%d?%d?%d?%d?%d%d?"))

beginning_timer:Start(1)

begin()



