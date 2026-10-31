do
--[[
    v.air —— 单文件打包产物（Gakuran）
    生成时间: 2026-11-01 03:16:37
    说明: 所有模块已内联，不需要任何本地服务器 / 远端仓库，直接执行即可。
]]

if (getgenv and getgenv().vluaBundleRunning) then
    warn('[v.air] 上一次打包产物还在运行，先卸载它');
end;

getgenv().vluaBundleRunning = true;
getgenv().isExecutorV3 = not not gethui;

--// 环境兜底（原 require-loader 里的同款）
if (type(getgenv().protectgui) ~= 'function') then
    getgenv().protectgui = function(gui)
        if (not gui or not gethui) then return end;

        pcall(function()
            gui.Parent = gethui();
        end);
    end;
end;

do
    local nativeChannel = getgenv().create_comm_channel;

    local function wrapCommEvent(event)
        return {
            _event = event,

            Connect = function(self, callback)
                return self._event.Event:Connect(callback);
            end,

            Fire = function(self, ...)
                self._event:Fire(...);
            end,
        };
    end;

    getgenv().create_comm_channel = function()
        if (type(nativeChannel) ~= 'function') then
            return tostring(os.time()), wrapCommEvent(Instance.new('BindableEvent'));
        end;

        local id, event = nativeChannel();

        if (typeof(event) == 'Instance') then
            event = wrapCommEvent(event);
        end;

        return id, event;
    end;

    local nativeGetChannel = getgenv().get_comm_channel;

    getgenv().get_comm_channel = function(id)
        if (typeof(id) == 'table') then
            return id;
        end;

        if (type(nativeGetChannel) ~= 'function') then
            return nil;
        end;

        local event = nativeGetChannel(id);

        if (typeof(event) == 'Instance') then
            event = wrapCommEvent(event);
        end;

        return event;
    end;
end;

getgenv().getServerConstant = getgenv().getServerConstant or function(...) return ... end;

--==============================================================
-- 内联模块表：只从 getgenv 上取共享引用。
--
--   绝对不要写成 `local MODULES = ... or getgenv().__vairModules or {}`：
--   Prometheus 的 WrapInFunction 会把整段代码再包一层函数，内层那个
--   `...` 不是 loader 传进来的表，而是一个 boolean 占位符 —— 于是
--   `... or X` 直接短路成 boolean，后面 MODULES['xxx'] 就把 boolean
--   当 key 用，报「argument #2 expects a string, but boolean was passed」。
--
--   loader 在执行每个 part 之前已经写好 getgenv().__vairModules，
--   所以从这里读是稳定通道。
--==============================================================
local MODULES = getgenv().__vairModules;

if (type(MODULES) ~= 'table') then
    MODULES = {};
    getgenv().__vairModules = MODULES;
end;

MODULES['UILibrary.lua'] = function()



local libraryLoadAt = tick();

local Signal = sharedRequire('utils/Signal.lua');
local Services = sharedRequire('utils/Services.lua');
local KeyBindVisualizer = sharedRequire('classes/KeyBindVisualizer.lua');

local CoreGui, Players, RunService, TextService, UserInputService, ContentProvider, HttpService, TweenService, GuiService, TeleportService = Services:Get('CoreGui', 'Players', 'RunService', 'TextService', 'UserInputService', 'ContentProvider', 'HttpService', 'TweenService', 'GuiService', 'TeleportService');

local toCamelCase = sharedRequire('utils/toCamelCase.lua');
local Maid = sharedRequire('utils/Maid.lua');
local ToastNotif = sharedRequire('@classes/ToastNotif.lua');
local MobileUI = sharedRequire('utils/MobileUI.lua');

local LocalPlayer = Players.LocalPlayer;
local visualizer;

if getgenv().library then
	getgenv().library:Unload();
end;


pcall(function()
    local legacyRoot, newRoot = 'v.lua', 'v.air';

    if (not isfolder(legacyRoot)) then return end;

    local function copyTree(from, to)
        if (not isfolder(from)) then return end;
        if (not isfolder(to)) then makefolder(to) end;

        for _, entry in next, listfiles(from) do
            local name = tostring(entry):match('[^/\\]+$');

            if (not name) then continue end;

            if (isfolder(entry)) then
                copyTree(entry, to .. '/' .. name);
            elseif (not isfile(to .. '/' .. name)) then
                pcall(function()
                    writefile(to .. '/' .. name, readfile(entry));
                end);
            end;
        end;
    end;

    copyTree(legacyRoot .. '/configs', newRoot .. '/configs');
    copyTree(legacyRoot .. '/CustomBackgrounds', newRoot .. '/CustomBackgrounds');
    copyTree(legacyRoot .. '/sounds', newRoot .. '/sounds');
end);

if (not isfile('v.air/configs')) then
    makefolder('v.air/configs');
end;

if (not isfile('v.air/configs/globalConf.bin')) then
    
    writefile('v.air/configs/globalConf.bin', 'true');
end;

local globalConfFilePath = 'v.air/configs/globalConf.bin';
local isGlobalConfigOn = readfile(globalConfFilePath) == 'true';

local library = {
    unloadMaid = Maid.new(),
	tabs = {},
	draggable = true,
	flags = {},
	title = string.format('v.air [%s]', (getgenv and getgenv().vairPayloadVersion) or scriptVersion or 'v1.0.0'),
	open = false,
	popup = nil,
	instances = {},
	connections = {},
	options = {},
	notifications = {},
    configVars = {},
	tabSize = 0,
	theme = {},
	foldername =  isGlobalConfigOn and 'v.air/configs/global' or string.format('v.air/configs/%s', tostring(LocalPlayer.UserId)),
	fileext = '.json',
    chromaColor = Color3.new()
}



local Palette = {
    Main     = Color3.fromRGB(11, 12, 16),
    Second   = Color3.fromRGB(17, 19, 24),
    Elevated = Color3.fromRGB(25, 28, 35),
    Rail     = Color3.fromRGB(7, 8, 11),
    Stroke   = Color3.fromRGB(38, 43, 54),
    Divider  = Color3.fromRGB(27, 30, 37),
    Text     = Color3.fromRGB(236, 239, 245),
    TextDim  = Color3.fromRGB(190, 198, 212),
    TextDark = Color3.fromRGB(154, 163, 178),
};


library.flags.menuAccentColor = Color3.fromRGB(255, 46, 99);




local function isTouchMode()
    return MobileUI.isTouch();
end;

local function isPrimaryInput(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch;
end;

local function isPrimaryMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch;
end;

library.originalTitle = library.title;

do 
    library.unloadMaid:GiveTask(task.spawn(function()
        while true do
            for i = 1, 360 do
                library.chromaColor = Color3.fromHSV(i / 360, 1, 1);
                task.wait(0.1);
            end;
        end;
    end));

    
        getgenv().library = library
    

    library.OnLoad = Signal.new();
    library.OnKeyPress = Signal.new();
    library.OnKeyRelease = Signal.new();

    library.OnFlagChanged = Signal.new();

    KeyBindVisualizer.init(library);

    library.unloadMaid:GiveTask(library.OnLoad);
    library.unloadMaid:GiveTask(library.OnKeyPress);
    library.unloadMaid:GiveTask(library.OnKeyRelease);
    library.unloadMaid:GiveTask(library.OnFlagChanged);

    visualizer = KeyBindVisualizer.new();
    local mouseMovement = Enum.UserInputType.MouseMovement;

    
    local dragging, dragInput, dragStart, startPos, dragObject

    local blacklistedKeys = { 
        Enum.KeyCode.Unknown,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Slash,Enum.KeyCode.Tab,Enum.KeyCode.Escape
    }
    local whitelistedMouseinputs = { 
        Enum.UserInputType.MouseButton1,Enum.UserInputType.MouseButton2,Enum.UserInputType.MouseButton3
    }

    local function onInputBegan(input, gpe)
        local inputType = input.UserInputType;
        if (inputType == mouseMovement) then return end;

        if (UserInputService:GetFocusedTextBox()) then return end;
        local inputKeyCode = input.KeyCode;

        local fastInputObject = {
            KeyCode = {
                Name = inputKeyCode.Name,
                Value = inputKeyCode.Value
            },

            UserInputType = {
                Name = inputType.Name,
                Value = inputType.Value
            },

            UserInputState = input.UserInputState,
            realKeyCode = inputKeyCode,
            realInputType = inputType
        };

        library.OnKeyPress:Fire(fastInputObject, gpe);
    end;

    local function onInputEnded(input)
        local inputType = input.UserInputType;
        if (inputType == mouseMovement) then return end;

        local inputKeyCode = input.KeyCode;

        local fastInputObject = {
            KeyCode = {
                Name = inputKeyCode.Name,
                Value = inputKeyCode.Value
            },

            UserInputType = {
                Name = inputType.Name,
                Value = inputType.Value
            },

            UserInputState = input.UserInputState,
            realKeyCode = inputKeyCode,
            realInputType = inputType
        };

        library.OnKeyRelease:Fire(fastInputObject);
    end;

    library.unloadMaid:GiveTask(UserInputService.InputBegan:Connect(onInputBegan));
    library.unloadMaid:GiveTask(UserInputService.InputEnded:Connect(onInputEnded));

    local function makeTooltip(interest, option)
        
        
        return;
    end;

    
    library.round = function(num, bracket)
        bracket = bracket or 1
        if typeof(num) == 'Vector2' then
            return Vector2.new(library.round(num.X), library.round(num.Y))
        elseif typeof(num) == 'Color3' then
            return library.round(num.r * 255), library.round(num.g * 255), library.round(num.b * 255)
        else
            return num - num % bracket;
        end
    end

    function library:Create(class, properties)
        properties = properties or {}
        if not class then return end
        local a = class == 'Square' or class == 'Line' or class == 'Text' or class == 'Quad' or class == 'Circle' or class == 'Triangle'
        local t = a and Drawing or Instance
        local inst = t.new(class)
        for property, value in next, properties do
            inst[property] = value
        end

        
        
        
        if (not a) then
            pcall(function()
                if (inst:IsA('Frame') or inst:IsA('ScrollingFrame') or inst:IsA('TextButton') or inst:IsA('ImageButton') or inst:IsA('TextBox')) then
                    inst:SetAttribute('transparencyBase', inst.BackgroundTransparency)
                end
            end)
        end

        table.insert(self.instances, {object = inst, method = a})
        return inst
    end

    function library:AddConnection(connection, name, callback)
        callback = type(name) == 'function' and name or callback
        connection = connection:Connect(callback)
        self.unloadMaid:GiveTask(connection);
        if name ~= callback then
            self.connections[name] = connection
        else
            table.insert(self.connections, connection)
        end
        return connection
    end

    function library:Unload()
        task.wait();
        visualizer:Remove();

        for _, o in next, self.options do
            if o.type == 'toggle' and not string.find(string.lower(o.flag), 'panic') and o.flag ~= 'saveconfigauto' then
                pcall(o.SetState, o, false);
            end;
        end;

        library.unloadMaid:Destroy();
    end

    local function readFileAndDecodeIt(filePath)
        if (not isfile(filePath)) then return; end;

        local suc, fileContent = pcall(readfile, filePath);
        if (not suc) then return; end;

        local suc2, configData = pcall(HttpService.JSONDecode, HttpService, fileContent);
        if (not suc2) then return; end;

        return configData;
    end;

    local function getConfigForGame(configData)
        local configValueName = library.gameName or 'Universal';

        if (not configData[configValueName]) then
            configData[configValueName] = {};
        end;

        return configData[configValueName];
    end;

    function library:LoadConfig(configName)
        if (not table.find(self:GetConfigs(), configName)) then
            return;
        end;

        local filePath = string.format('%s/%s.%s%s', self.foldername, configName, 'config', self.fileext);
        local configData = readFileAndDecodeIt(filePath);
        if (not configData) then print('no config', configName); return; end;
        configData = getConfigForGame(configData);

        
        library.loadedConfig = configName;
        library.options.configList:SetValue(configName);

        for _, option in next, self.options do
            if (not option.hasInit or option.type == 'button' or not option.flag or option.skipflag) then
                continue;
            end;

            local configDataVal = configData[option.flag];

            if (typeof(configDataVal) == 'nil') then
                continue;
            end;

            if (option.type == 'toggle') then
                task.spawn(option.SetState, option, configDataVal == 1);
            elseif (option.type == 'color') then
                task.spawn(option.SetColor, option, Color3.fromHex(configDataVal));

                if option.trans then
                    task.spawn(option.SetTrans, option, configData[option.flag .. 'Transparency']);
                end;
            elseif (option.type == 'bind') then
                task.spawn(option.SetKeys, option, configDataVal);
            else
                task.spawn(option.SetValue, option, configDataVal);
            end;
        end;

        return true;
    end;

    function library:SaveConfig(configName)
        local filePath = string.format('%s/%s.%s%s', self.foldername, configName, 'config', self.fileext);
        local allConfigData = readFileAndDecodeIt(filePath) or {};

        if (allConfigData.configVersion ~= '1') then
            allConfigData = {};
            allConfigData.configVersion = '1';
        end;

        local configData = getConfigForGame(allConfigData);

        debug.profilebegin('Set config value');
        for _, option in next, self.options do
            if (option.type == 'button' or not option.flag) then continue end;
            if (option.skipflag or option.noSave) then continue end;

            local flag = option.flag;

            if (option.type == 'toggle') then
                configData[flag] = option.state and 1 or 0;
            elseif (option.type == 'color') then
                configData[flag] = option.color:ToHex();
                if (not option.trans) then continue end;
                configData[flag .. 'Transparency'] = option.trans;
            elseif (option.type == 'bind' and option.key ~= 'none') then
                local toSave = {};
                for _, v in next, option.keys do
                    table.insert(toSave, v.Name);
                end;

                configData[flag] = toSave;
            elseif (option.type == 'list') then
                configData[flag] = option.value;
            elseif (option.type == 'box' and option.value ~= 'nil' and option.value ~= '') then
                configData[flag] = option.value;
            else
                configData[flag] = option.value;
            end;
        end;
        debug.profileend();

        local configVars = library.configVars;
        configVars.config = configName;

        debug.profilebegin('writefile');
        writefile(self.foldername .. '/' .. self.fileext, HttpService:JSONEncode(configVars));
        debug.profileend();

        debug.profilebegin('writefile');
        writefile(filePath, HttpService:JSONEncode(allConfigData));
        debug.profileend();
    end

    function library:GetConfigs()
        if not isfolder(self.foldername) then
            makefolder(self.foldername)
        end

        local configFiles = {};

        for i, v in next, listfiles(self.foldername) do
            
            
            
            
            local normalized = tostring(v):gsub('\\', '/');
            local fileName = normalized:match('([^/]+)$');
            local fileSubExtension = fileName and fileName:match('%.(.+)%.json');

            if (fileName and fileSubExtension == 'config') then
                table.insert(configFiles, fileName:match('(.-)%.config'));
            end;
        end;

        if (not table.find(configFiles, 'default')) then
            table.insert(configFiles, 'default');
        end;

        return configFiles;
    end

    function library:UpdateConfig()
        if (not library.hasInit) then return end;
        debug.profilebegin('Config Save');

        library:SaveConfig(library.loadedConfig or 'default');

        debug.profileend();
    end;

    local function createLabel(option, parent)
        
        
        
        
        option.main = library:Create('TextLabel', {
            LayoutOrder = option.position,
            Position = UDim2.new(0, 6, 0, 0),
            Size = UDim2.new(1, -12, 0, 16),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            TextSize = 15,
            Font = Enum.Font.Gotham,
            TextColor3 = Color3.new(1, 1, 1),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            RichText = true,
            Parent = parent
        })

        setmetatable(option, {__newindex = function(t, i, v)
            if i == 'Text' then
                option.main.Text = tostring(v)
            end
        end})

        option.Text = option.text
    end

    local function createDivider(option, parent)
        option.main = library:Create('Frame', {
            LayoutOrder = option.position,
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Parent = parent
        })

        library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(1, -24, 0, 1),
            BackgroundColor3 = Palette.Stroke,
            BorderColor3 = Color3.new(),
            Parent = option.main
        })

        option.title = library:Create('TextLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundColor3 = Palette.Second,
            BorderSizePixel = 0,
            TextColor3 =  Color3.new(1, 1, 1),
            TextSize = 15,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = option.main
        })

        local interest = option.main;
        makeTooltip(interest, option);

        setmetatable(option, {__newindex = function(t, i, v)
            if i == 'Text' then
                if v then
                    option.title.Text = tostring(v)
                    option.title.Size = UDim2.new(0, TextService:GetTextSize(option.title.Text, 15, Enum.Font.Gotham, Vector2.new(9e9, 9e9)).X + 12, 0, 20)
                    option.main.Size = UDim2.new(1, 0, 0, 18)
                else
                    option.title.Text = ''
                    option.title.Size = UDim2.new()
                    option.main.Size = UDim2.new(1, 0, 0, 6)
                end
            end
        end})
        option.Text = option.text
    end

    local function createToggle(option, parent)
        option.hasInit = true
        option.onStateChanged = Signal.new();

        option.main = library:Create('Frame', {
            LayoutOrder = option.position,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = parent
        })

        local tickbox
        local tickboxOverlay
        if option.style then
            tickbox = library:Create('ImageLabel', {
                Position = UDim2.new(0, 6, 0, 4),
                Size = UDim2.new(0, 12, 0, 12),
                BackgroundTransparency = 1,
                Image = 'rbxassetid://3570695787',
                ImageColor3 = Color3.new(),
                Parent = option.main
            })

            library:Create('ImageLabel', {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(1, -2, 1, -2),
                BackgroundTransparency = 1,
                Image = 'rbxassetid://3570695787',
                ImageColor3 = Palette.Stroke,
                Parent = tickbox
            })

            library:Create('ImageLabel', {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(1, -6, 1, -6),
                BackgroundTransparency = 1,
                Image = 'rbxassetid://3570695787',
                ImageColor3 = Palette.Elevated,
                Parent = tickbox
            })

            tickboxOverlay = library:Create('ImageLabel', {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(1, -6, 1, -6),
                BackgroundTransparency = 1,
                Image = 'rbxassetid://3570695787',
                ImageColor3 = library.flags.menuAccentColor,
                Visible = option.state,
                Parent = tickbox
            })

            library:Create('ImageLabel', {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Image = 'rbxassetid://5941353943',
                ImageTransparency = 0.6,
                Parent = tickbox
            })

            table.insert(library.theme, tickboxOverlay)
        else
            tickbox = library:Create('Frame', {
                Position = UDim2.new(0, 6, 0, 4),
                Size = UDim2.new(0, 12, 0, 12),
                BackgroundColor3 = library.flags.menuAccentColor,
                BorderColor3 = Color3.new(),
                Parent = option.main
            })

            tickboxOverlay = library:Create('ImageLabel', {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = option.state and 1 or 0,
                BackgroundColor3 = Palette.Elevated,
                BorderColor3 = Color3.new(),
                Image = 'rbxassetid://4155801252',
                ImageTransparency = 0.6,
                ImageColor3 = Color3.new(),
                Parent = tickbox
            })

            library:Create('UIStroke', {
                Color = Palette.Stroke,
                Thickness = 1,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Parent = tickbox
            })
            table.insert(library.theme, tickbox)
        end

        option.interest = library:Create('Frame', {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            Parent = option.main
        })

        option.title = library:Create('TextLabel', {
            Position = UDim2.new(0, 24, 0, 0),
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = option.text,
            TextColor3 =  option.state and Palette.Text or Palette.TextDim,
            TextSize = 15,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = option.interest
        })

        library.unloadMaid:GiveTask(option.interest.InputBegan:connect(function(input)
            if isPrimaryInput(input) then
                option:SetState(not option.state)
            end
            if input.UserInputType.Name == 'MouseMovement' then
                if not library.warning and not library.slider then
                    if option.style then
                        tickbox.ImageColor3 = library.flags.menuAccentColor
                    else
                        tickbox.BorderColor3 = library.flags.menuAccentColor
                        tickboxOverlay.BorderColor3 = library.flags.menuAccentColor
                    end
                end
                if option.tip then
                    library.tooltip.Text = option.tip;
                end
            end
        end))

        makeTooltip(option.interest, option);

        library.unloadMaid:GiveTask(option.interest.InputEnded:connect(function(input)
            if input.UserInputType.Name == 'MouseMovement' then
                if option.style then
                    tickbox.ImageColor3 = Color3.new()
                else
                    tickbox.BorderColor3 = Color3.new()
                    tickboxOverlay.BorderColor3 = Color3.new()
                end
            end
        end));

        function option:SetState(state, nocallback)
            state = typeof(state) == 'boolean' and state
            state = state or false
            library.flags[self.flag] = state
            self.state = state
            option.title.TextColor3 = state and Palette.Text or Palette.TextDark
            if option.style then
                tickboxOverlay.Visible = state
            else
                tickboxOverlay.BackgroundTransparency = state and 1 or 0
            end

            if not nocallback then
                task.spawn(self.callback, state);
            end

            option.onStateChanged:Fire(state);
            library.OnFlagChanged:Fire(self);
        end

        task.defer(function()
            option:SetState(option.state);
        end);

        setmetatable(option, {__newindex = function(t, i, v)
            if i == 'Text' then
                option.title.Text = tostring(v)
            else
                rawset(t, i, v);
            end
        end})
    end

    local function createButton(option, parent)
        option.hasInit = true

        option.main = option.sub and option:getMain() or library:Create('Frame', {
            LayoutOrder = option.position,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            Parent = parent
        })

        option.title = library:Create('TextLabel', {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -5),
            Size = UDim2.new(1, -12, 0, 18),
            BackgroundColor3 = Palette.Elevated,
            BorderColor3 = Color3.new(),
            Text = option.text,
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 15,
            Font = Enum.Font.Gotham,
            Parent = option.main
        })

        if (option.sub) then
            if (not option.parent.subInit) then
                option.parent.subInit = true;

                

                option.parent.title.Size = UDim2.fromOffset(0, 18);

                option.parent.listLayout = library:Create('UIGridLayout', {
                    Parent = option.parent.main,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    FillDirection = Enum.FillDirection.Vertical,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    CellSize = UDim2.new(1 / (#option.main:GetChildren()-1), -8, 0, 18)
                });
            end;

            option.parent.listLayout.CellSize = UDim2.new(1 / (#option.parent.main:GetChildren()-1), -8, 0, 18);
        end;

        library:Create('UIStroke', {
            Color = Palette.Stroke,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = option.title
        })
        library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Palette.TextDim),
                ColorSequenceKeypoint.new(1, Palette.Text),
            }),
            Rotation = -90,
            Parent = option.title
        })

        library.unloadMaid:GiveTask(option.title.InputBegan:connect(function(input)
            if isPrimaryInput(input) then
                option.callback()
                if library then
                    library.flags[option.flag] = true
                end
                if option.tip then
                    library.tooltip.Text = option.tip;
                end
            end
            if input.UserInputType.Name == 'MouseMovement' then
                if not library.warning and not library.slider then
                    option.title.BorderColor3 = library.flags.menuAccentColor;
                end
                if option.tip then
                    library.tooltip.Text = option.tip;
                end
            end
        end));

        makeTooltip(option.title, option);

        library.unloadMaid:GiveTask(option.title.InputEnded:connect(function(input)
            if input.UserInputType.Name == 'MouseMovement' then
                option.title.BorderColor3 = Color3.new();
            end
        end));
    end

    local function createBind(option, parent)
        option.hasInit = true

        local Loop
        local maid = Maid.new()

        library.unloadMaid:GiveTask(function()
            maid:Destroy();
        end);

        if option.sub then
            option.main = option:getMain()
        else
            option.main = option.main or library:Create('Frame', {
                LayoutOrder = option.position,
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                Parent = parent
            })

            option.title = library:Create('TextLabel', {
                Position = UDim2.new(0, 6, 0, 0),
                Size = UDim2.new(1, -12, 1, 0),
                BackgroundTransparency = 1,
                Text = option.text,
                TextSize = 15,
                Font = Enum.Font.Gotham,
                TextColor3 = Palette.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = option.main
            })
        end

        local bindinput = library:Create(option.sub and 'TextButton' or 'TextLabel', {
            Position = UDim2.new(1, -6 - (option.subpos or 0), 0, option.sub and 2 or 3),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            BackgroundColor3 = Palette.Second,
            BorderSizePixel = 0,
            TextSize = 15,
            Font = Enum.Font.Gotham,
            TextColor3 = Palette.TextDark,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = option.main
        })

        if option.sub then
            bindinput.AutoButtonColor = false
        end

        local interest = option.sub and bindinput or option.main;
        local maid = Maid.new();

        local function formatKey(key)
            if (key:match('Mouse')) then
                key = key:gsub('Button', ''):gsub('Mouse', 'M');
            elseif (key:match('Shift') or key:match('Alt') or key:match('Control')) then
                key = key:gsub('Left', 'L'):gsub('Right', 'R');
            end;

            return key:gsub('Control', 'CTRL'):upper();
        end;

        local function formatKeys(keys)
            if (not keys) then return {}; end;
            local ret = {};

            for _, key in next, keys do
                table.insert(ret, formatKey(typeof(key) == 'string' and key or key.Name));
            end;

            return ret;
        end;

        local busy = false;

        makeTooltip(interest, option);

        library.unloadMaid:GiveTask(interest.InputEnded:connect(function(input)
            
            
            if (isTouchMode() and input.UserInputType == Enum.UserInputType.Touch) then
                if (tick() - (library.lastTouchBindTip or 0) > 1) then
                    library.lastTouchBindTip = tick();

                    pcall(function()
                        ToastNotif.new({text = '手机端不支持改键，请在 PC 上设置', duration = 3});
                    end);
                end;

                return;
            end;

            if isPrimaryInput(input) and not busy then
                busy = true;
                library.disableKeyBind = true;

                bindinput.Text = '[...]'
                bindinput.Size = UDim2.new(0, -TextService:GetTextSize(bindinput.Text, 16, Enum.Font.Gotham, Vector2.new(9e9, 9e9)).X, 0, 16)
                bindinput.TextColor3 = library.flags.menuAccentColor

                local displayKeys = {};
                local keys = {};

                maid.keybindLoop = RunService.Heartbeat:Connect(function()
                    for _, key in next, UserInputService:GetKeysPressed() do
                        local value = formatKey(key.KeyCode.Name);

                        if (value == 'BACKSPACE') then
                            maid.keybindLoop = nil;
                            option:SetKeys('none');
                            return;
                        end;

                        if (table.find(displayKeys, value)) then continue; end;
                        table.insert(displayKeys, value);
                        table.insert(keys, key.KeyCode);
                    end;

                    for _, mouseBtn in next, UserInputService:GetMouseButtonsPressed() do
                        local value = formatKey(mouseBtn.UserInputType.Name);

                        if (option.nomouse) then continue end;
                        if (not table.find(whitelistedMouseinputs, mouseBtn.UserInputType)) then continue end;

                        if (table.find(displayKeys, value)) then continue; end;

                        table.insert(displayKeys, value);
                        table.insert(keys, mouseBtn.UserInputType);
                    end;

                    bindinput.Text = '[' .. table.concat(displayKeys, '+') .. ']';

                    if (#displayKeys == 3) then
                        maid.keybindLoop = nil;
                    end;
                end);

                task.wait(0.05);
                maid.onInputEnded = UserInputService.InputEnded:Connect(function(input)
                    if(input.UserInputType ~= Enum.UserInputType.Keyboard and not input.UserInputType.Name:find('MouseButton')) then return; end;

                    maid.keybindLoop = nil;
                    maid.onInputEnded = nil;

                    option:SetKeys(keys);
                    library.disableKeyBind = false;
                    task.wait(0.2);
                    busy = false;
                end);
            end
        end));

        local function isKeybindPressed()
            local foundCount = 0;

            for _, key in next, UserInputService:GetKeysPressed() do
                if (table.find(option.keys, key.KeyCode)) then
                    foundCount += 1;
                end;
            end;

            for _, key in next, UserInputService:GetMouseButtonsPressed() do
                if (table.find(option.keys, key.UserInputType)) then
                    foundCount += 1;
                end;
            end;

            return foundCount == #option.keys;
        end;

        local debounce = false;

        function option:SetKeys(keys)
            if (typeof(keys) == 'string') then
                keys = {keys};
            end;

            keys = keys or {option.key ~= 'none' and option.key or nil};

            for i, key in next, keys do
                if (typeof(key) == 'string' and key ~= 'none') then
                    local isMouse = key:find('MouseButton');

                    if (isMouse) then
                        keys[i] = Enum.UserInputType[key];
                    else
                        keys[i] = Enum.KeyCode[key];
                    end;
                end;
            end;

            bindinput.TextColor3 = Palette.TextDark

            if Loop then
                Loop:Disconnect()
                Loop = nil;
                library.flags[option.flag] = false
                option.callback(true, 0)
            end

            self.keys = keys;

            if self.keys[1] == 'Backspace' or #self.keys == 0 then
                self.key = 'none'
                bindinput.Text = '[NONE]'

                
                
                
                visualizer:RemoveText(self.text);
            else
                local formattedKey = formatKeys(self.keys);
                bindinput.Text = '[' .. table.concat(formattedKey, '+') .. ']';
                self.key = table.concat(formattedKey, '+');

                
                
                if (self.parentFlag and self.key ~= 'none' and library.flags[self.parentFlag]) then
                    visualizer:AddText(self.text);
                end;
            end

            bindinput.Size = UDim2.new(0, -TextService:GetTextSize(bindinput.Text, 16, Enum.Font.Gotham, Vector2.new(9e9, 9e9)).X, 0, 16)

            if (self.key == 'none') then
                maid.onKeyPress = nil;
                maid.onKeyRelease = nil;
            else
                maid.onKeyPress = library.OnKeyPress:Connect(function()
                    if (library.disableKeyBind or #option.keys == 0 or debounce) then return end;
                    if (not isKeybindPressed()) then return; end;

                    debounce = true;

                    if option.mode == 'toggle' then
                        library.flags[option.flag] = not library.flags[option.flag]
                        option.callback(library.flags[option.flag], 0)
                    else
                        library.flags[option.flag] = true

                        if Loop then
                            Loop:Disconnect();
                            Loop = nil;
                            option.callback(true, 0);
                        end;

                        Loop = library:AddConnection(RunService.Heartbeat, function(step)
                            if not UserInputService:GetFocusedTextBox() then
                                option.callback(nil, step)
                            end
                        end)
                    end
                end);

                maid.onKeyRelease = library.OnKeyRelease:Connect(function()
                    if (debounce and not isKeybindPressed()) then debounce = false; end;
                    if (option.mode ~= 'hold') then return; end;

                    local bindKey = option.key;
                    if (bindKey == 'none') then return end;

                    if not isKeybindPressed() then
                        if Loop then
                            Loop:Disconnect()
                            Loop = nil;

                            library.flags[option.flag] = false
                            option.callback(true, 0)
                        end
                    end
                end);
            end;
        end;

        option:SetKeys();
    end

    local function createSlider(option, parent)
        option.hasInit = true

        if option.sub then
            option.main = option:getMain()
        else
            option.main = library:Create('Frame', {
                LayoutOrder = option.position,
                Size = UDim2.new(1, 0, 0, option.textpos and 24 or 40),
                BackgroundTransparency = 1,
                Parent = parent
            })
        end

        option.slider = library:Create('Frame', {
            Position = UDim2.new(0, 6, 0, (option.sub and 22 or option.textpos and 4 or 20)),
            Size = UDim2.new(1, -12, 0, 16),
            BackgroundColor3 = Palette.Elevated,
            BorderColor3 = Color3.new(),
            Parent = option.main
        })

        option.fill = library:Create('Frame', {
            BackgroundColor3 = library.flags.menuAccentColor,
            BorderSizePixel = 0,
            Parent = option.slider
        })

        library:Create('UIStroke', {
            Color = Palette.Stroke,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = option.slider
        })
        option.title = library:Create('TextBox', {
            Position = UDim2.new((option.sub or option.textpos) and 0.5 or 0, (option.sub or option.textpos) and 0 or 6, 0, 0),
            Size = UDim2.new(0, 0, 0, (option.sub or option.textpos) and 14 or 18),
            BackgroundTransparency = 1,
            Text = (option.text == 'nil' and '' or option.text .. ': ') .. option.value .. option.suffix,
            TextSize = (option.sub or option.textpos) and 14 or 15,
            Font = Enum.Font.Gotham,
            TextColor3 = Palette.Text,
            TextXAlignment = Enum.TextXAlignment[(option.sub or option.textpos) and 'Center' or 'Left'],
            Parent = (option.sub or option.textpos) and option.slider or option.main
        })
        table.insert(library.theme, option.fill)

        library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Palette.Divider),
                ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
            }),
            Rotation = -90,
            Parent = option.fill
        })

        if option.min >= 0 then
            option.fill.Size = UDim2.new((option.value - option.min) / (option.max - option.min), 0, 1, 0)
        else
            option.fill.Position = UDim2.new((0 - option.min) / (option.max - option.min), 0, 0, 0)
            option.fill.Size = UDim2.new(option.value / (option.max - option.min), 0, 1, 0)
        end

        local manualInput
        library.unloadMaid:GiveTask(option.title.Focused:connect(function()
            if not manualInput then
                option.title:ReleaseFocus()
                option.title.Text = (option.text == 'nil' and '' or option.text .. ': ') .. option.value .. option.suffix
            end
        end));

        library.unloadMaid:GiveTask(option.title.FocusLost:connect(function()
            option.slider.BorderColor3 = Color3.new()
            if manualInput then
                if tonumber(option.title.Text) then
                    option:SetValue(tonumber(option.title.Text))
                else
                    option.title.Text = (option.text == 'nil' and '' or option.text .. ': ') .. option.value .. option.suffix
                end
            end
            manualInput = false
        end));

        local interest = (option.sub or option.textpos) and option.slider or option.main
        library.unloadMaid:GiveTask(interest.InputBegan:connect(function(input)
            if isPrimaryInput(input) then
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
                    manualInput = true
                    option.title:CaptureFocus()
                else
                    library.slider = option
                    option.slider.BorderColor3 = library.flags.menuAccentColor

                    
                    if (library.mobileUI) then
                        library.mobileUI:lockScroll()
                    end
                    option:SetValue(option.min + ((input.Position.X - option.slider.AbsolutePosition.X) / option.slider.AbsoluteSize.X) * (option.max - option.min))
                end
            end
            if input.UserInputType.Name == 'MouseMovement' then
                if not library.warning and not library.slider then
                    option.slider.BorderColor3 = library.flags.menuAccentColor
                end
                if option.tip then
                    library.tooltip.Text = option.tip;
                end
            end
        end));

        makeTooltip(interest, option);

        library.unloadMaid:GiveTask(interest.InputEnded:connect(function(input)
            if input.UserInputType.Name == 'MouseMovement' then
                if option ~= library.slider then
                    option.slider.BorderColor3 = Color3.new();
                end;
            end;
        end));

        if (option.parent) then
            local oldParent = option.slider.Parent;

            option.parent.onStateChanged:Connect(function(state)
                option.slider.Parent = state and oldParent or nil;
            end);
        end;

        local tweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

        function option:SetValue(value, nocallback)
            value = value or self.value;

            value = library.round(value, option.float)
            value = math.clamp(value, self.min, self.max)

            if self.min >= 0 then
                TweenService:Create(option.fill, tweenInfo, {Size = UDim2.new((value - self.min) / (self.max - self.min), 0, 1, 0)}):Play();
            else
                TweenService:Create(option.fill, tweenInfo, {
                    Size = UDim2.new(value / (self.max - self.min), 0, 1, 0),
                    Position = UDim2.new((0 - self.min) / (self.max - self.min), 0, 0, 0)
                }):Play();
            end
            library.flags[self.flag] = value
            self.value = value
            option.title.Text = (option.text == 'nil' and '' or option.text .. ': ') .. string.format(option.float == 1 and '%d' or '%.02f', option.value) .. option.suffix
            if not nocallback then
                task.spawn(self.callback, value)
            end

            library.OnFlagChanged:Fire(self)
        end

        task.defer(function()
            if library then
                option:SetValue(option.value)
            end
        end)
    end

    local function createList(option, parent)
        option.hasInit = true

        if option.sub then
            option.main = option:getMain()
            option.main.Size = UDim2.new(1, 0, 0, 48)
        else
            option.main = library:Create('Frame', {
                LayoutOrder = option.position,
                Size = UDim2.new(1, 0, 0, option.text == 'nil' and 30 or 48),
                BackgroundTransparency = 1,
                Parent = parent
            })

            if option.text ~= 'nil' then
                library:Create('TextLabel', {
                    Position = UDim2.new(0, 6, 0, 0),
                    Size = UDim2.new(1, -12, 0, 18),
                    BackgroundTransparency = 1,
                    Text = option.text,
                    TextSize = 15,
                    Font = Enum.Font.Gotham,
                    TextColor3 = Palette.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = option.main
                })
            end
        end

        if(option.playerOnly) then
            library.OnLoad:Connect(function()
                option.values = {};

                for i,v in next, Players:GetPlayers() do
                    if (v == LocalPlayer) then continue end;
                    option:AddValue(v.Name);
                end;

                library.unloadMaid:GiveTask(Players.PlayerAdded:Connect(function(plr)
                    option:AddValue(plr.Name);
                end));

                library.unloadMaid:GiveTask(Players.PlayerRemoving:Connect(function(plr)
                    option:RemoveValue(plr.Name);
                end));
            end);
        end;

        local function getMultiText()
            local t = {};

            
            
            if (option.value == nil) then
                return '';
            end;

            if (option.playerOnly and option.multiselect) then
                for i, v in next, option.values do
                    if (option.value[i]) then
                        table.insert(t, tostring(i));
                    end;
                end;
            else
                for i, v in next, option.values do
                    if (option.value[v]) then
                        table.insert(t, tostring(v));
                    end;
                end;
            end;

            return table.concat(t, ', ');
        end

        option.listvalue = library:Create('TextBox', {
            Position = UDim2.new(0, 6, 0, (option.text == 'nil' and not option.sub) and 4 or 22),
            Size = UDim2.new(1, -12, 0, 22),
            BackgroundColor3 = Palette.Elevated,
            BorderColor3 = Color3.new(),
            Active = false,
            ClearTextOnFocus = false,
            Text = ' ' .. (typeof(option.value) == 'string' and option.value or getMultiText()),
            TextSize = 15,
            Font = Enum.Font.Gotham,
            TextColor3 = Color3.new(1, 1, 1),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = option.main
        })

        library:Create('UIStroke', {
            Color = Palette.Stroke,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = option.listvalue
        })
        option.arrow = library:Create('ImageLabel', {
            Position = UDim2.new(1, -16, 0, 7),
            Size = UDim2.new(0, 8, 0, 8),
            Rotation = 90,
            BackgroundTransparency = 1,
            Image = 'rbxassetid://4918373417',
            ImageColor3 = Color3.new(1, 1, 1),
            ScaleType = Enum.ScaleType.Fit,
            ImageTransparency = 0.4,
            Parent = option.listvalue
        })

        option.holder = library:Create('TextButton', {
            ZIndex = 4,
            BackgroundColor3 = Palette.Elevated,
            BorderColor3 = Color3.new(),
            Text = '',
            TextColor3 = Color3.fromRGB(255,255, 255),
            AutoButtonColor = false,
            Visible = false,
            Parent = library.base
        })

        option.content = library:Create('ScrollingFrame', {
            ZIndex = 4,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarImageColor3 = Palette.Stroke,
            ScrollBarThickness = 6,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            VerticalScrollBarInset = Enum.ScrollBarInset.Always,
            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            Parent = option.holder
        })

        library:Create('UIStroke', {
            Color = Palette.Stroke,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = option.holder
        })
        local layout = library:Create('UIListLayout', {
            Padding = UDim.new(0, 2),
            Parent = option.content
        })

        library:Create('UIPadding', {
            PaddingTop = UDim.new(0, 4),
            PaddingLeft = UDim.new(0, 4),
            Parent = option.content
        })

        local valueCount = 0;

        local function updateHolder(newValueCount)
            option.holder.Size = UDim2.new(0, option.listvalue.AbsoluteSize.X, 0, 8 + ((newValueCount or valueCount) > option.max and (-2 + (option.max * 22)) or layout.AbsoluteContentSize.Y))
            option.content.CanvasSize = UDim2.new(0, 0, 0, 8 + layout.AbsoluteContentSize.Y)
        end;

        library.unloadMaid:GiveTask(layout.Changed:Connect(function() updateHolder(); end));
        local interest = option.sub and option.listvalue or option.main
        local focused = false;

        library.unloadMaid:GiveTask(option.listvalue.Focused:Connect(function() focused = true; end));
        library.unloadMaid:GiveTask(option.listvalue.FocusLost:Connect(function() focused = false; end));

        library.unloadMaid:GiveTask(option.listvalue:GetPropertyChangedSignal('Text'):Connect(function()
            if (not focused) then return end;
            local newText = option.listvalue.Text;

            if (newText:sub(1, 1) ~= ' ') then
                newText = ' ' .. newText;
                option.listvalue.Text = newText;
                option.listvalue.CursorPosition = 2;
            end;

            local search = string.lower(newText:sub(2));
            local matchedResults = 0;

            for name, label in next, option.labels do
                if (string.find(string.lower(name), search)) then
                    matchedResults += 1;
                    label.Visible = true;
                else
                    label.Visible = false;
                end;
            end;

            updateHolder(matchedResults);
        end));

        library.unloadMaid:GiveTask(option.listvalue.InputBegan:connect(function(input)
            if isPrimaryInput(input) then
                if library.popup == option then library.popup:Close() return end
                if library.popup then
                    library.popup:Close()
                end
                option.arrow.Rotation = -90
                option.open = true
                option.holder.Visible = true
                
                
                local basePosition = library.base.AbsolutePosition
                local boxPosition = option.listvalue.AbsolutePosition
                local boxSize = option.listvalue.AbsoluteSize

                updateHolder()

                local popupHeight = option.holder.Size.Y.Offset
                local baseHeight = library.base.AbsoluteSize.Y
                local popupX = (option.main.AbsolutePosition.X - basePosition.X) + 6
                local popupY = (boxPosition.Y + boxSize.Y - basePosition.Y) + 4

                
                local availableBelow = baseHeight - popupY - 8

                if (baseHeight > 0 and availableBelow < popupHeight) then
                    if (availableBelow >= 66) then
                        option.holder.Size = UDim2.new(0, option.listvalue.AbsoluteSize.X, 0, availableBelow)
                    else
                        local aboveY = (boxPosition.Y - basePosition.Y) - popupHeight - 4

                        popupY = math.max(4, aboveY)
                    end
                end

                option.holder.Position = UDim2.new(0, popupX, 0, popupY)
                library.popup = option
                option.listvalue.BorderColor3 = library.flags.menuAccentColor
                option.listvalue:CaptureFocus();
                option.listvalue.CursorPosition = string.len(typeof(option.value) == 'string' and option.value or getMultiText() or option.value) + 2;

                if (option.multiselect) then
                    option.listvalue.Text = ' ';
                end;
            end
            if input.UserInputType.Name == 'MouseMovement' then
                if not library.warning and not library.slider then
                    option.listvalue.BorderColor3 = library.flags.menuAccentColor
                end
            end
        end));

        library.unloadMaid:GiveTask(option.listvalue.InputEnded:connect(function(input)
            if input.UserInputType.Name == 'MouseMovement' then
                if not option.open then
                    option.listvalue.BorderColor3 = Color3.new()
                end
            end
        end));

        library.unloadMaid:GiveTask(interest.InputBegan:connect(function(input)
            if input.UserInputType.Name == 'MouseMovement' then
                if option.tip then
                    library.tooltip.Text = option.tip;
                end
            end
        end));

        makeTooltip(interest, option);

        function option:AddValue(value, state)
            if self.labels[value] then return end
            state = state or (option.playerOnly and false)

            valueCount = valueCount + 1

            if self.multiselect then
                self.values[value] = state
            else
                if not table.find(self.values, value) then
                    table.insert(self.values, value)
                end
            end

            local label = library:Create('TextLabel', {
                ZIndex = 4,
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                Text = value,
                TextSize = 15,
                Font = Enum.Font.Gotham,
                TextTransparency = self.multiselect and (self.value[value] and 1 or 0) or self.value == value and 1 or 0,
                TextColor3 = Palette.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = option.content
            })

            self.labels[value] = label

            local labelOverlay = library:Create('TextLabel', {
                ZIndex = 4,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 0.8,
                Text = ' ' ..value,
                TextSize = 15,
                Font = Enum.Font.Gotham,
                TextColor3 = library.flags.menuAccentColor,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = self.multiselect and self.value[value] or self.value == value,
                Parent = label
            });

            table.insert(library.theme, labelOverlay)

            library.unloadMaid:GiveTask(label.InputBegan:connect(function(input)
                if isPrimaryInput(input) then
                    if self.multiselect then
                        self.value[value] = not self.value[value]
                        self:SetValue(self.value);
                        self.listvalue.Text = ' ';
                        self.listvalue.CursorPosition = 2;
                        self.listvalue:CaptureFocus();
                    else
                        self:SetValue(value)
                        self:Close()
                    end
                end
            end));
        end

        for i, value in next, option.values do
            option:AddValue(tostring(typeof(i) == 'number' and value or i))
        end

        function option:RemoveValue(value)
            local label = self.labels[value]
            if label then
                label:Destroy()
                self.labels[value] = nil
                valueCount = valueCount - 1
                if self.multiselect then
                    self.values[value] = nil
                    self:SetValue(self.value)
                else
                    table.remove(self.values, table.find(self.values, value))
                    if self.value == value then
                        self:SetValue(self.values[1] or '')

                        if (not self.values[1]) then
                            option.listvalue.Text = '';
                        end;
                    end
                end
            end
        end

        function option:SetValue(value, nocallback)
            if self.multiselect and typeof(value) ~= 'table' then
                value = {}
                for i,v in next, self.values do
                    value[v] = false
                end
            end

            if (not value) then return end;

            self.value = self.multiselect and value or self.values[table.find(self.values, value) or 1];
            if (self.playerOnly and not self.multiselect) then
                self.value = Players:FindFirstChild(value);
            end;

            if (not self.value) then return end;

            library.flags[self.flag] = self.value;
            option.listvalue.Text = ' ' .. (self.multiselect and getMultiText() or tostring(self.value));

            for name, label in next, self.labels do
                local visible = self.multiselect and self.value[name] or self.value == name;
                label.TextTransparency = visible and 1 or 0;
                if label:FindFirstChild'TextLabel' then
                    label.TextLabel.Visible = visible;
                end;
            end;

            if not nocallback then
                self.callback(self.value)
            end
        end

        task.defer(function()
            if library and not option.noload then
                option:SetValue(option.value)
            end
        end)

        function option:Close()
            library.popup = nil
            option.arrow.Rotation = 90
            self.open = false
            option.holder.Visible = false
            option.listvalue.BorderColor3 = Color3.new()
            option.listvalue:ReleaseFocus();
            option.listvalue.Text = ' ' .. (self.multiselect and getMultiText() or tostring(self.value));

            for _, label in next, option.labels do
                label.Visible = true;
            end;
        end

        return option
    end

    local function createBox(option, parent)
        option.hasInit = true

        option.main = library:Create('Frame', {
            LayoutOrder = option.position,
            Size = UDim2.new(1, 0, 0, option.text == 'nil' and 28 or 44),
            BackgroundTransparency = 1,
            Parent = parent
        })

        if option.text ~= 'nil' then
            option.title = library:Create('TextLabel', {
                Position = UDim2.new(0, 6, 0, 0),
                Size = UDim2.new(1, -12, 0, 18),
                BackgroundTransparency = 1,
                Text = option.text,
                TextSize = 15,
                Font = Enum.Font.Gotham,
                TextColor3 = Palette.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = option.main
            })
        end

        option.holder = library:Create('Frame', {
            Position = UDim2.new(0, 6, 0, option.text == 'nil' and 4 or 20),
            Size = UDim2.new(1, -12, 0, 20),
            BackgroundColor3 = Palette.Elevated,
            BorderColor3 = Color3.new(),
            Parent = option.main
        })

        library:Create('UIStroke', {
            Color = Palette.Stroke,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = option.holder
        })
        local inputvalue = library:Create('TextBox', {
            Position = UDim2.new(0, 4, 0, 0),
            Size = UDim2.new(1, -4, 1, 0),
            BackgroundTransparency = 1,
            Text = '  ' .. option.value,
            TextSize = 15,
            Font = Enum.Font.Gotham,
            TextColor3 = Color3.new(1, 1, 1),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            ClearTextOnFocus = false,
            Parent = option.holder
        })

        library.unloadMaid:GiveTask(inputvalue.FocusLost:connect(function(enter)
            option.holder.BorderColor3 = Color3.new()
            option:SetValue(inputvalue.Text, enter)
        end));

        library.unloadMaid:GiveTask(inputvalue.Focused:connect(function()
            option.holder.BorderColor3 = library.flags.menuAccentColor
        end));

        library.unloadMaid:GiveTask(inputvalue.InputBegan:connect(function(input)
            if input.UserInputType.Name == 'MouseMovement' then
                if not library.warning and not library.slider then
                    option.holder.BorderColor3 = library.flags.menuAccentColor
                end
                if option.tip then
                    library.tooltip.Text = option.tip;
                end
            end
        end));

        makeTooltip(inputvalue, option);

        library.unloadMaid:GiveTask(inputvalue.InputEnded:connect(function(input)
            if input.UserInputType.Name == 'MouseMovement' then
                if not inputvalue:IsFocused() then
                    option.holder.BorderColor3 = Color3.new();
                end;
            end;
        end));

        function option:SetValue(value, enter)
            if (value:gsub('%s+', '') == '') then
                value = '';
            end;

            library.flags[self.flag] = tostring(value);
            self.value = tostring(value);
            inputvalue.Text = self.value;
            self.callback(value, enter);

            library.OnFlagChanged:Fire(self);
        end
        task.defer(function()
            if library then
                option:SetValue(option.value)
            end
        end)
    end

    local function createColorPickerWindow(option)
        option.mainHolder = library:Create('TextButton', {
            ZIndex = 4,
            
            Size = UDim2.new(0, option.trans and 200 or 184, 0, 264),
            BackgroundColor3 = Palette.Elevated,
            BorderColor3 = Color3.new(),
            AutoButtonColor = false,
            Visible = false,
            Parent = library.base
        })

        option.rgbBox = library:Create('Frame', {
            Position = UDim2.new(0, 6, 0, 214),
            Size = UDim2.new(0, (option.mainHolder.AbsoluteSize.X - 12), 0, 20),
            BackgroundColor3 = Palette.Elevated,
            BorderColor3 = Color3.new(),
            ZIndex = 5;
            Parent = option.mainHolder
        })

        library:Create('UIStroke', {
            Color = Palette.Stroke,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = option.rgbBox
        })
        local r, g, b = library.round(option.color);
        local colorText = table.concat({r, g, b}, ',');

        option.rgbInput = library:Create('TextBox', {
            Position = UDim2.new(0, 4, 0, 0),
            Size = UDim2.new(1, -4, 1, 0),
            BackgroundTransparency = 1,
            Text = colorText,
            TextSize = 14,
            Font = Enum.Font.Gotham,
            TextColor3 = Color3.new(1, 1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextWrapped = true,
            ClearTextOnFocus = false,
            ZIndex = 6;
            Parent = option.rgbBox
        })

        option.hexBox = option.rgbBox:Clone()
        option.hexBox.Position = UDim2.new(0, 6, 0, 238)
        
        option.hexBox.Parent = option.mainHolder
        option.hexInput = option.hexBox.TextBox;

        library:Create('UIStroke', {
            Color = Palette.Stroke,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = option.mainHolder
        })
        local hue, sat, val = Color3.toHSV(option.color)
        hue, sat, val = hue == 0 and 1 or hue, sat + 0.005, val - 0.005
        local editinghue
        local editingsatval
        local editingtrans

        local transMain
        if option.trans then
            transMain = library:Create('ImageLabel', {
                ZIndex = 5,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Image = 'rbxassetid://2454009026',
                ImageColor3 = Color3.fromHSV(hue, 1, 1),
                Rotation = 180,
                Parent = library:Create('ImageLabel', {
                    ZIndex = 4,
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -6, 0, 6),
                    Size = UDim2.new(0, 10, 1, -60),
                    BorderColor3 = Color3.new(),
                    Image = 'rbxassetid://4632082392',
                    ScaleType = Enum.ScaleType.Tile,
                    TileSize = UDim2.new(0, 5, 0, 5),
                    Parent = option.mainHolder
                })
            })

            option.transSlider = library:Create('Frame', {
                ZIndex = 5,
                Position = UDim2.new(0, 0, option.trans, 0),
                Size = UDim2.new(1, 0, 0, 2),
                BackgroundColor3 = Color3.fromRGB(38, 41, 65),
                BorderColor3 = Color3.fromRGB(255, 255, 255),
                Parent = transMain
            })

            library.unloadMaid:GiveTask(transMain.InputBegan:connect(function(Input)
                if isPrimaryInput(Input) then
                    editingtrans = true
                    option:SetTrans(1 - ((Input.Position.Y - transMain.AbsolutePosition.Y) / transMain.AbsoluteSize.Y))
                end
            end));

            library.unloadMaid:GiveTask(transMain.InputEnded:connect(function(Input)
                if isPrimaryInput(Input) then
                    editingtrans = false
                end
            end));
        end

        local hueMain = library:Create('Frame', {
            ZIndex = 4,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 6, 1, -54),
            Size = UDim2.new(1, option.trans and -28 or -12, 0, 10),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderColor3 = Color3.new(),
            Parent = option.mainHolder
        })

        library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
            }),
            Parent = hueMain
        })

        local hueSlider = library:Create('Frame', {
            ZIndex = 4,
            Position = UDim2.new(1 - hue, 0, 0, 0),
            Size = UDim2.new(0, 2, 1, 0),
            BackgroundColor3 = Color3.fromRGB(38, 41, 65),
            BorderColor3 = Color3.fromRGB(255, 255, 255),
            Parent = hueMain
        })

        library.unloadMaid:GiveTask(hueMain.InputBegan:connect(function(Input)
            if isPrimaryInput(Input) then
                editinghue = true
                local X = (hueMain.AbsolutePosition.X + hueMain.AbsoluteSize.X) - hueMain.AbsolutePosition.X
                X = math.clamp((Input.Position.X - hueMain.AbsolutePosition.X) / X, 0, 0.995)
                option:SetColor(Color3.fromHSV(1 - X, sat, val))
            end
        end));

        library.unloadMaid:GiveTask(hueMain.InputEnded:connect(function(Input)
            if isPrimaryInput(Input) then
                editinghue = false
            end
        end));

        local satval = library:Create('ImageLabel', {
            ZIndex = 4,
            Position = UDim2.new(0, 6, 0, 6),
            Size = UDim2.new(1, option.trans and -28 or -12, 1, -74),
            BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
            BorderColor3 = Color3.new(),
            Image = 'rbxassetid://4155801252',
            ClipsDescendants = true,
            Parent = option.mainHolder
        })

        local satvalSlider = library:Create('Frame', {
            ZIndex = 4,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(sat, 0, 1 - val, 0),
            Size = UDim2.new(0, 4, 0, 4),
            Rotation = 45,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = satval
        })

        library.unloadMaid:GiveTask(satval.InputBegan:connect(function(Input)
            if isPrimaryInput(Input) then
                editingsatval = true
                local X = (satval.AbsolutePosition.X + satval.AbsoluteSize.X) - satval.AbsolutePosition.X
                local Y = (satval.AbsolutePosition.Y + satval.AbsoluteSize.Y) - satval.AbsolutePosition.Y
                X = math.clamp((Input.Position.X - satval.AbsolutePosition.X) / X, 0.005, 1)
                Y = math.clamp((Input.Position.Y - satval.AbsolutePosition.Y) / Y, 0, 0.995)
                option:SetColor(Color3.fromHSV(hue, X, 1 - Y))
            end
        end));

        library:AddConnection(UserInputService.InputChanged, function(Input)
            if (not editingsatval and not editinghue and not editingtrans) then return end;

            if Input.UserInputType.Name == 'MouseMovement' then
                if editingsatval then
                    local X = (satval.AbsolutePosition.X + satval.AbsoluteSize.X) - satval.AbsolutePosition.X
                    local Y = (satval.AbsolutePosition.Y + satval.AbsoluteSize.Y) - satval.AbsolutePosition.Y
                    X = math.clamp((Input.Position.X - satval.AbsolutePosition.X) / X, 0.005, 1)
                    Y = math.clamp((Input.Position.Y - satval.AbsolutePosition.Y) / Y, 0, 0.995)
                    option:SetColor(Color3.fromHSV(hue, X, 1 - Y))
                elseif editinghue then
                    local X = (hueMain.AbsolutePosition.X + hueMain.AbsoluteSize.X) - hueMain.AbsolutePosition.X
                    X = math.clamp((Input.Position.X - hueMain.AbsolutePosition.X) / X, 0, 0.995)
                    option:SetColor(Color3.fromHSV(1 - X, sat, val))
                elseif editingtrans then
                    option:SetTrans(1 - ((Input.Position.Y - transMain.AbsolutePosition.Y) / transMain.AbsoluteSize.Y))
                end
            end
        end)

        library.unloadMaid:GiveTask(satval.InputEnded:connect(function(Input)
            if isPrimaryInput(Input) then
                editingsatval = false
            end
        end));

        option.hexInput.Text = option.color:ToHex();

        library.unloadMaid:GiveTask(option.rgbInput.FocusLost:connect(function()
            local color = Color3.fromRGB(unpack(option.rgbInput.Text:split(',')));
            return option:SetColor(color)
        end));

        library.unloadMaid:GiveTask(option.hexInput.FocusLost:connect(function()
            local color = Color3.fromHex(option.hexInput.Text);
            return option:SetColor(color);
        end));

        function option:updateVisuals(Color)
            hue, sat, val = Color:ToHSV();
            hue, sat, val = math.clamp(hue, 0, 1), math.clamp(sat, 0, 1), math.clamp(val, 0, 1);

            hue = hue == 0 and 1 or hue
            satval.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
            if option.trans then
                transMain.ImageColor3 = Color3.fromHSV(hue, 1, 1)
            end
            hueSlider.Position = UDim2.new(1 - hue, 0, 0, 0)
            satvalSlider.Position = UDim2.new(sat, 0, 1 - val, 0)

            local color = Color3.fromHSV(hue, sat, val);
            local r, g, b = library.round(color);

            option.hexInput.Text = color:ToHex();
            option.rgbInput.Text = table.concat({r, g, b}, ',');
        end

        return option
    end

    local function createColor(option, parent)
        option.hasInit = true

        if option.sub then
            option.main = option:getMain()
        else
            option.main = library:Create('Frame', {
                LayoutOrder = option.position,
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                Parent = parent
            })

            option.title = library:Create('TextLabel', {
                Position = UDim2.new(0, 6, 0, 0),
                Size = UDim2.new(1, -12, 1, 0),
                BackgroundTransparency = 1,
                Text = option.text,
                TextSize = 15,
                Font = Enum.Font.Gotham,
                TextColor3 = Palette.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = option.main
            })
        end

        option.visualize = library:Create(option.sub and 'TextButton' or 'Frame', {
            Position = UDim2.new(1, -(option.subpos or 0) - 24, 0, 4),
            Size = UDim2.new(0, 18, 0, 12),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            BackgroundColor3 = option.color,
            BorderColor3 = Color3.new(),
            Parent = option.main
        })

        library:Create('UIStroke', {
            Color = Palette.Stroke,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = option.visualize
        })
        local interest = option.sub and option.visualize or option.main

        if option.sub then
            option.visualize.Text = ''
            option.visualize.AutoButtonColor = false
        end

        library.unloadMaid:GiveTask(interest.InputBegan:connect(function(input)
            if isPrimaryInput(input) then
                if not option.mainHolder then
                    createColorPickerWindow(option)
                end
                if library.popup == option then library.popup:Close() return end
                if library.popup then library.popup:Close() end
                option.open = true
                local pos = option.main.AbsolutePosition
                option.mainHolder.Position = UDim2.new(0, pos.X + 36 + (option.trans and -16 or 0), 0, pos.Y + 56)
                option.mainHolder.Visible = true
                library.popup = option
                option.visualize.BorderColor3 = library.flags.menuAccentColor
            end
            if input.UserInputType.Name == 'MouseMovement' then
                if not library.warning and not library.slider then
                    option.visualize.BorderColor3 = library.flags.menuAccentColor
                end
                if option.tip then
                    library.tooltip.Text = option.tip;
                end
            end
        end));

        makeTooltip(interest, option);

        library.unloadMaid:GiveTask(interest.InputEnded:connect(function(input)
            if input.UserInputType.Name == 'MouseMovement' then
                if not option.open then
                    option.visualize.BorderColor3 = Color3.new();
                end;
            end;
        end));

        function option:SetColor(newColor, nocallback, noFire)
            newColor = newColor or Color3.new(1, 1, 1)
            if self.mainHolder then
                self:updateVisuals(newColor)
            end
            option.visualize.BackgroundColor3 = newColor
            library.flags[self.flag] = newColor
            self.color = newColor

            if not nocallback then
                task.spawn(self.callback, newColor)
            end

            if (not noFire) then
                library.OnFlagChanged:Fire(self);
            end;
        end

        if option.trans then
            function option:SetTrans(value, manual)
                value = math.clamp(tonumber(value) or 0, 0, 1)
                if self.transSlider then
                    self.transSlider.Position = UDim2.new(0, 0, value, 0)
                end
                self.trans = value
                library.flags[self.flag .. 'Transparency'] = 1 - value
                task.spawn(self.calltrans, value)
            end
            option:SetTrans(option.trans)
        end

        task.defer(function()
            if library then
                option:SetColor(option.color)
            end
        end)

        function option:Close()
            library.popup = nil
            self.open = false
            self.mainHolder.Visible = false
            option.visualize.BorderColor3 = Color3.new()
        end
    end

    function library:AddTab(title, pos)
        local tab = {canInit = true, columns = {}, title = tostring(title)}
        table.insert(self.tabs, pos or #self.tabs + 1, tab)

        function tab:AddColumn()
            local column = {sections = {}, position = #self.columns, canInit = true, tab = self}
            table.insert(self.columns, column)

            function column:AddSection(title)
                local section = {title = tostring(title), options = {}, canInit = true, column = self}
                table.insert(self.sections, section)

                function section:AddLabel(text)
                    local option = {text = text}
                    option.section = self
                    option.type = 'label'
                    option.position = #self.options
                    table.insert(self.options, option)

                    if library.hasInit and self.hasInit then
                        createLabel(option, self.content)
                    else
                        option.Init = createLabel
                    end

                    return option
                end

                function section:AddDivider(text, tip)
                    local option = {text = text, tip = tip}
                    option.section = self
                    option.type = 'divider'
                    option.position = #self.options
                    table.insert(self.options, option)

                    if library.hasInit and self.hasInit then
                        createDivider(option, self.content)
                    else
                        option.Init = createDivider
                    end

                    return option
                end

                function section:AddToggle(option)
                    option = typeof(option) == 'table' and option or {}
                    option.section = self
                    option.text = tostring(option.text)
                    option.state = typeof(option.state) == 'boolean' and option.state or false
                    option.default = option.state;
                    option.callback = typeof(option.callback) == 'function' and option.callback or function() end
                    option.type = 'toggle'
                    option.position = #self.options
                    option.flag = (library.flagprefix or '') .. toCamelCase(option.flag or option.text)
                    option.subcount = 0
                    option.tip = option.tip and tostring(option.tip)
                    option.style = option.style == 2
                    library.flags[option.flag] = option.state
                    table.insert(self.options, option)
                    library.options[option.flag] = option

                    function option:AddColor(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        subOption.subpos = self.subcount * 24
                        function subOption:getMain() return option.main end
                        self.subcount = self.subcount + 1
                        return section:AddColor(subOption)
                    end

                    function option:AddBind(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        subOption.subpos = self.subcount * 24
                        function subOption:getMain() return option.main end
                        self.subcount = self.subcount + 1
                        return section:AddBind(subOption)
                    end

                    function option:AddList(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        function subOption:getMain() return option.main end
                        self.subcount = self.subcount + 1
                        return section:AddList(subOption)
                    end

                    function option:AddSlider(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        function subOption:getMain() return option.main end
                        self.subcount = self.subcount + 1

                        subOption.parent = option;
                        return section:AddSlider(subOption)
                    end

                    if library.hasInit and self.hasInit then
                        createToggle(option, self.content)
                    else
                        option.Init = createToggle
                    end

                    return option
                end

                function section:AddButton(option)
                    option = typeof(option) == 'table' and option or {}
                    option.section = self
                    option.text = tostring(option.text)
                    option.callback = typeof(option.callback) == 'function' and option.callback or function() end
                    option.type = 'button'
                    option.position = #self.options
                    option.flag = (library.flagprefix or '') .. toCamelCase(option.flag or option.text)
                    option.subcount = 0
                    option.tip = option.tip and tostring(option.tip)
                    table.insert(self.options, option)
                    library.options[option.flag] = option

                    function option:AddBind(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        subOption.subpos = self.subcount * 24
                        function subOption:getMain() option.main.Size = UDim2.new(1, 0, 0, 40) return option.main end
                        self.subcount = self.subcount + 1
                        return section:AddBind(subOption)
                    end

                    function option:AddColor(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        subOption.subpos = self.subcount * 24
                        function subOption:getMain() option.main.Size = UDim2.new(1, 0, 0, 40) return option.main end
                        self.subcount = self.subcount + 1
                        return section:AddColor(subOption)
                    end

                    function option:AddButton(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        subOption.subpos = self.subcount * 24
                        function subOption:getMain() return option.main end
                        self.subcount = self.subcount + 1
                        subOption.parent = option;
                        section:AddButton(subOption)

                        return option;
                    end;

                    function option:SetText(text)
                        option.title.Text = text;
                    end;

                    if library.hasInit and self.hasInit then
                        createButton(option, self.content)
                    else
                        option.Init = createButton
                    end

                    return option
                end

                function section:AddBind(option)
                    option = typeof(option) == 'table' and option or {}
                    option.section = self
                    option.text = tostring(option.text)
                    option.key = (option.key and option.key.Name) or option.key or 'none'
                    option.nomouse = typeof(option.nomouse) == 'boolean' and option.nomouse or false
                    option.mode = typeof(option.mode) == 'string' and ((option.mode == 'toggle' or option.mode == 'hold') and option.mode) or 'toggle'
                    option.callback = typeof(option.callback) == 'function' and option.callback or function() end
                    option.type = 'bind'
                    option.position = #self.options
                    option.flag = (library.flagprefix or '') .. toCamelCase(option.flag or option.text)
                    option.tip = option.tip and tostring(option.tip)
                    table.insert(self.options, option)
                    library.options[option.flag] = option

                    if library.hasInit and self.hasInit then
                        createBind(option, self.content)
                    else
                        option.Init = createBind
                    end

                    return option
                end

                function section:AddSlider(option)
                    option = typeof(option) == 'table' and option or {}
                    option.section = self
                    option.text = tostring(option.text)
                    option.min = typeof(option.min) == 'number' and option.min or 0
                    option.max = typeof(option.max) == 'number' and option.max or 0
                    option.value = option.min < 0 and 0 or math.clamp(typeof(option.value) == 'number' and option.value or option.min, option.min, option.max)
                    option.default = option.value;
                    option.callback = typeof(option.callback) == 'function' and option.callback or function() end
                    option.float = typeof(option.value) == 'number' and option.float or 1
                    option.suffix = option.suffix and tostring(option.suffix) or ''
                    option.textpos = option.textpos == 2
                    option.type = 'slider'
                    option.position = #self.options
                    option.flag = (library.flagprefix or '') .. toCamelCase(option.flag or option.text)
                    option.subcount = 0
                    option.tip = option.tip and tostring(option.tip)
                    library.flags[option.flag] = option.value
                    table.insert(self.options, option)
                    library.options[option.flag] = option

                    function option:AddColor(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        subOption.subpos = self.subcount * 24
                        function subOption:getMain() return option.main end
                        self.subcount = self.subcount + 1
                        return section:AddColor(subOption)
                    end

                    function option:AddBind(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        subOption.subpos = self.subcount * 24
                        function subOption:getMain() return option.main end
                        self.subcount = self.subcount + 1
                        return section:AddBind(subOption)
                    end

                    if library.hasInit and self.hasInit then
                        createSlider(option, self.content)
                    else
                        option.Init = createSlider
                    end

                    return option
                end

                function section:AddList(option)
                    option = typeof(option) == 'table' and option or {}
                    option.section = self
                    option.text = tostring(option.text)
                    option.values = typeof(option.values) == 'table' and option.values or {}
                    option.callback = typeof(option.callback) == 'function' and option.callback or function() end
                    option.multiselect = typeof(option.multiselect) == 'boolean' and option.multiselect or false
                    
                    option.value = option.multiselect and (typeof(option.value) == 'table' and option.value or {}) or tostring(option.value or option.values[1] or '')
                    if option.multiselect then
                        for i,v in next, option.values do
                            option.value[v] = false
                        end
                    end
                    option.max = option.max or 6
                    option.open = false
                    option.type = 'list'
                    option.position = #self.options
                    option.labels = {}
                    option.flag = (library.flagprefix or '') .. toCamelCase(option.flag or option.text)
                    option.subcount = 0
                    option.tip = option.tip and tostring(option.tip)
                    library.flags[option.flag] = option.value
                    table.insert(self.options, option)
                    library.options[option.flag] = option

                    function option:AddValue(value, state)
                        if self.multiselect then
                            self.values[value] = state
                        else
                            table.insert(self.values, value)
                        end
                    end

                    function option:AddColor(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        subOption.subpos = self.subcount * 24
                        function subOption:getMain() return option.main end
                        self.subcount = self.subcount + 1
                        return section:AddColor(subOption)
                    end

                    function option:AddBind(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        subOption.subpos = self.subcount * 24
                        function subOption:getMain() return option.main end
                        self.subcount = self.subcount + 1
                        return section:AddBind(subOption)
                    end

                    if library.hasInit and self.hasInit then
                        createList(option, self.content)
                    else
                        option.Init = createList
                    end

                    return option
                end

                function section:AddBox(option)
                    option = typeof(option) == 'table' and option or {}
                    option.section = self
                    option.text = tostring(option.text)
                    option.value = tostring(option.value or '')
                    option.callback = typeof(option.callback) == 'function' and option.callback or function() end
                    option.type = 'box'
                    option.position = #self.options
                    option.flag = (library.flagprefix or '') .. toCamelCase(option.flag or option.text)
                    option.tip = option.tip and tostring(option.tip)
                    library.flags[option.flag] = option.value
                    table.insert(self.options, option)
                    library.options[option.flag] = option

                    if library.hasInit and self.hasInit then
                        createBox(option, self.content)
                    else
                        option.Init = createBox
                    end

                    return option
                end

                function section:AddColor(option)
                    option = typeof(option) == 'table' and option or {}
                    option.section = self
                    option.text = tostring(option.text)
                    option.color = typeof(option.color) == 'table' and Color3.new(option.color[1], option.color[2], option.color[3]) or option.color or Color3.new(1, 1, 1)
                    option.callback = typeof(option.callback) == 'function' and option.callback or function() end
                    option.calltrans = typeof(option.calltrans) == 'function' and option.calltrans or (option.calltrans == 1 and option.callback) or function() end
                    option.open = false
                    option.default = option.color;
                    option.trans = tonumber(option.trans)
                    option.subcount = 1
                    option.type = 'color'
                    option.position = #self.options
                    option.flag = (library.flagprefix or '') .. toCamelCase(option.flag or option.text)
                    option.tip = option.tip and tostring(option.tip)
                    library.flags[option.flag] = option.color
                    table.insert(self.options, option)
                    library.options[option.flag] = option

                    function option:AddColor(subOption)
                        subOption = typeof(subOption) == 'table' and subOption or {}
                        subOption.sub = true
                        subOption.subpos = self.subcount * 24
                        function subOption:getMain() return option.main end
                        self.subcount = self.subcount + 1
                        return section:AddColor(subOption)
                    end

                    if option.trans then
                        library.flags[option.flag .. 'Transparency'] = option.trans
                    end

                    if library.hasInit and self.hasInit then
                        createColor(option, self.content)
                    else
                        option.Init = createColor
                    end

                    return option
                end

                function section:SetTitle(newTitle)
                    self.title = tostring(newTitle)
                    if self.titleText then
                        self.titleText.Text = tostring(newTitle)
                    end
                end

                function section:Init()
                    if self.hasInit then return end
                    self.hasInit = true

                    self.main = library:Create('Frame', {
                        BackgroundColor3 = Palette.Second,
                        BorderColor3 = Color3.new(),
                        Parent = column.main
                    })

                    self.content = library:Create('Frame', {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundColor3 = Palette.Second,
                        BorderColor3 = Palette.Stroke,
                        BorderMode = Enum.BorderMode.Inset,
                        Parent = self.main
                    })

                    table.insert(library.theme, library:Create('Frame', {
                        Size = UDim2.new(1, 0, 0, 1),
                        BackgroundColor3 = library.flags.menuAccentColor,
                        BorderSizePixel = 0,
                        BorderMode = Enum.BorderMode.Inset,
                        Parent = self.main
                    }))

                    local layout = library:Create('UIListLayout', {
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 2),
                        Parent = self.content
                    })

                    library:Create('UIPadding', {
                        PaddingTop = UDim.new(0, 12),
                        Parent = self.content
                    })

                    self.titleText = library:Create('TextLabel', {
                        AnchorPoint = Vector2.new(0, 0.5),
                        Position = UDim2.new(0, 12, 0, 0),
                        Size = UDim2.new(0, TextService:GetTextSize(self.title, 15, Enum.Font.Gotham, Vector2.new(9e9, 9e9)).X + 10, 0, 3),
                        BackgroundColor3 = Palette.Second,
                        BorderSizePixel = 0,
                        Text = self.title,
                        TextSize = 15,
                        Font = Enum.Font.Gotham,
                        TextColor3 = Color3.new(1, 1, 1),
                        Parent = self.main
                    })

                    library.unloadMaid:GiveTask(layout.Changed:connect(function()
                        self.main.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y + 16)
                    end));

                    for _, option in next, self.options do
                        option.Init(option, self.content)
                    end
                end

                if library.hasInit and self.hasInit then
                    section:Init()
                end

                return section
            end

            function column:Init()
                if self.hasInit then return end
                self.hasInit = true

                self.main = library:Create('ScrollingFrame', {
                    ZIndex = 2,
                    Position = UDim2.new(0, 6 + (self.position * 239), 0, 2),
                    Size = UDim2.new(0, 233, 1, -4),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ScrollBarImageColor3 = Color3.fromRGB(),
                    ScrollBarThickness = 4,
                    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
                    ScrollingDirection = Enum.ScrollingDirection.Y,
                    Visible = true
                })

                local layout = library:Create('UIListLayout', {
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 12),
                    Parent = self.main
                })

                library:Create('UIPadding', {
                    PaddingTop = UDim.new(0, 8),
                    PaddingLeft = UDim.new(0, 2),
                    PaddingRight = UDim.new(0, 2),
                    Parent = self.main
                })

                library.unloadMaid:GiveTask(layout.Changed:connect(function()
                    self.main.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 14)
                end));

                for _, section in next, self.sections do
                    if section.canInit and #section.options > 0 then
                        section:Init()
                    end
                end
            end

            if library.hasInit and self.hasInit then
                column:Init()
            end

            return column
        end

        function tab:Init()
            if self.hasInit then return end
            self.hasInit = true

            local size = TextService:GetTextSize(self.title, 18, Enum.Font.Gotham, Vector2.new(9e9, 9e9)).X + 10

            self.button = library:Create('TextLabel', {
                Position = UDim2.new(0, library.tabSize, 0, 22),
                Size = UDim2.new(0, size, 0, 30),
                BackgroundTransparency = 1,
                Text = self.title,
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 15,
                Font = Enum.Font.Gotham,
                TextWrapped = true,
                ClipsDescendants = true,
                Parent = (library.mobileUI and library.mobileUI.tabStrip) or library.main
            });

            library.tabSize = library.tabSize + size

            library.unloadMaid:GiveTask(self.button.InputBegan:connect(function(input)
                if isPrimaryInput(input) then
                    library:selectTab(self);
                end;
            end));

            for _, column in next, self.columns do
                if column.canInit then
                    column:Init();
                end;
            end;
        end;

        if self.hasInit then
            tab:Init()
        end

        return tab
    end

    function library:AddWarning(warning)
        warning = typeof(warning) == 'table' and warning or {}
        warning.text = tostring(warning.text)
        warning.type = warning.type == 'confirm' and 'confirm' or ''

        local answer
        function warning:Show()
            library.warning = warning
            if warning.main and warning.type == '' then
                warning.main:Destroy();
                warning.main = nil;
            end
            if library.popup then library.popup:Close() end
            if not warning.main then
                warning.main = library:Create('TextButton', {
                    ZIndex = 2,
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 0.3,
                    BackgroundColor3 = Color3.new(),
                    BorderSizePixel = 0,
                    Text = '',
                    AutoButtonColor = false,
                    Parent = library.main
                })

                
                
                
                warning.message = library:Create('TextLabel', {
                    ZIndex = 2,
                    AnchorPoint = Vector2.new(0.5, 1),
                    Position = UDim2.new(0.5, 0, 0.5, -8),
                    Size = UDim2.new(1, -40, 0, 40),
                    BackgroundTransparency = 1,
                    TextSize = 16,
                    Font = Enum.Font.Gotham,
                    TextColor3 = Color3.new(1, 1, 1),
                    TextWrapped = true,
                    RichText = true,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Bottom,
                    Parent = warning.main
                })

                if warning.type == 'confirm' then
                    local button = library:Create('TextLabel', {
                        ZIndex = 2,
                        Position = UDim2.new(0.5, -105, 0.5, 8),
                        Size = UDim2.new(0, 100, 0, 20),
                        BackgroundColor3 = Palette.Elevated,
                        BorderColor3 = Color3.new(),
                        Text = 'Yes',
                        TextSize = 16,
                        Font = Enum.Font.Gotham,
                        TextColor3 = Color3.new(1, 1, 1),
                        Parent = warning.main
                    })

                    library:Create('UIStroke', {
                        Color = Palette.Stroke,
                        Thickness = 1,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                        Parent = button
                    })
                    local button1 = library:Create('TextLabel', {
                        ZIndex = 2,
                        Position = UDim2.new(0.5, 5, 0.5, 8),
                        Size = UDim2.new(0, 100, 0, 20),
                        BackgroundColor3 = Palette.Elevated,
                        BorderColor3 = Color3.new(),
                        Text = 'No',
                        TextSize = 16,
                        Font = Enum.Font.Gotham,
                        TextColor3 = Color3.new(1, 1, 1),
                        Parent = warning.main
                    })

                    library:Create('UIStroke', {
                        Color = Palette.Stroke,
                        Thickness = 1,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                        Parent = button1
                    })
                    library.unloadMaid:GiveTask(button.InputBegan:connect(function(input)
                        if isPrimaryInput(input) then
                            answer = true
                        end
                    end));

                    library.unloadMaid:GiveTask(button1.InputBegan:connect(function(input)
                        if isPrimaryInput(input) then
                            answer = false
                        end
                    end));
                else
                    local button = library:Create('TextLabel', {
                        ZIndex = 2,
                        Position = UDim2.new(0.5, -50, 0.5, 8),
                        Size = UDim2.new(0, 100, 0, 20),
                        BackgroundColor3 = Palette.Second,
                        BorderColor3 = Color3.new(),
                        Text = 'OK',
                        TextSize = 16,
                        Font = Enum.Font.Gotham,
                        TextColor3 = Color3.new(1, 1, 1),
                        Parent = warning.main
                    })

                    library.unloadMaid:GiveTask(button.InputEnded:connect(function(input)
                        if isPrimaryInput(input) then
                            answer = true
                        end
                    end));
                end
            end
            warning.main.Visible = true
            warning.message.Text = warning.text

            
            
            local messageWidth = math.max(120, warning.message.AbsoluteSize.X)

            if (messageWidth <= 0) then
                messageWidth = math.max(160, (library.main and library.main.AbsoluteSize.X or 500) - 40)
            end

            local okSize, bounds = pcall(function()
                return TextService:GetTextSize(warning.text, 16, Enum.Font.Gotham, Vector2.new(messageWidth, math.huge))
            end)

            local messageHeight = 24

            if (okSize and typeof(bounds) == 'Vector2') then
                messageHeight = math.clamp(bounds.Y + 8, 24, 240)
            end

            warning.message.Size = UDim2.new(1, -40, 0, messageHeight)

            repeat task.wait() until answer ~= nil;
            library.warning = nil;

            local answerCopy = answer;
            warning:Close();

            return answerCopy;
        end

        function warning:Close()
            answer = nil
            if not warning.main then return end
            warning.main.Visible = false
        end

        return warning
    end

    function library:Close()
        self.open = not self.open

        if self.main then
            if self.popup then
                self.popup:Close()
            end

            self.base.Enabled = self.open
        end

        library.tooltip.Position = UDim2.fromScale(10, 10);
    end

    function library:Init(silent)
        if self.hasInit then return end

        self.hasInit = true
        
        
        
        local ignoreInset = not isTouchMode();

        self.base = library:Create('ScreenGui', {
            Name = 'Vlua',
            IgnoreGuiInset = ignoreInset,
            AutoLocalize = false,
            Enabled = not silent,
        })
        self.dummyBox = library:Create('TextBox', {Visible = false, Parent = self.base});
        self.dummyModal = library:Create('TextButton', {Visible = false, Modal = true, Parent = self.base});

        self.unloadMaid:GiveTask(self.base);

        if RunService:IsStudio() then
            self.base.Parent = script.Parent.Parent
        else
            
            
            
            local player = Players.LocalPlayer
            local playerGui = player and player:FindFirstChild('PlayerGui')

            local candidates = {}

            if (type(gethui) == 'function') then
                local ok, hidden = pcall(gethui)

                if (ok and hidden) then
                    table.insert(candidates, hidden)
                end
            end

            table.insert(candidates, CoreGui)

            if (playerGui) then
                table.insert(candidates, playerGui)
            end

            local attached = false

            for _, parent in ipairs(candidates) do
                if (parent) then
                    local ok = pcall(function()
                        self.base.Parent = parent
                    end)

                    if (ok and self.base.Parent == parent) then
                        attached = true

                        break
                    end
                end
            end

            if (not attached) then
                
                error('[Vlua] 无法挂载界面容器：gethui / CoreGui / PlayerGui 全都不可写')
            end

            pcall(protectgui, self.base)
        end

        
        local function getWindowHeight()
            local camera = workspace.CurrentCamera;
            local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720);

            if (isTouchMode()) then
                return math.clamp(viewport.Y - 40, 300, 600);
            end;

            return 600;
        end;

        self.main = self:Create('ImageButton', {
            AutoButtonColor = false,
            Position = UDim2.new(0, 100, 0, 46),
            Size = UDim2.new(0, 500, 0, getWindowHeight()),
            BackgroundColor3 = Palette.Main,
            BorderColor3 = Color3.new(),
            ScaleType = Enum.ScaleType.Tile,
            Visible = true,
            Parent = self.base
        })

        
        self.mainScale = self:Create('UIScale', {
            Scale = 1,
            Parent = self.main
        });

        local function applyMainScale()
            if (not self.mainScale or not self.main) then return end;

            
            if (self.mobileUI) then
                return self.mobileUI:applyScale();
            end;

            local camera = workspace.CurrentCamera;
            local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720);
            local width = self.main.Size.X.Offset;
            local height = self.main.Size.Y.Offset;

            if (width <= 0 or height <= 0) then return end;

            local scale = math.min((viewport.X - 24) / width, (viewport.Y - 24) / height, 1);
            self.mainScale.Scale = math.clamp(scale, 0.5, 1);
        end;

        applyMainScale();
        self:AddConnection(workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'), applyMainScale);

        
        
        if (not isTouchMode()) then
            task.spawn(function()
                task.wait();

                local main = self.main;

                if (not main or not main.Parent) then return end;

                local desired = Vector2.new(100, 46);
                local actual = main.AbsolutePosition;

                
                if (actual.X == 0 and actual.Y == 0) then
                    task.wait();
                    actual = main.AbsolutePosition;
                end;

                if (actual.X == 0 and actual.Y == 0) then return end;

                local diff = desired - actual;

                if (math.abs(diff.X) > 1 or math.abs(diff.Y) > 1) then
                    main.Position = UDim2.fromOffset(
                        math.floor(desired.X + diff.X + 0.5),
                        math.floor(desired.Y + diff.Y + 0.5)
                    );
                end;
            end);
        end;

        
        

        local top = self:Create('Frame', {
            Size = UDim2.new(1, 0, 0, 52),
            BackgroundColor3 = Palette.Second,
            BorderColor3 = Color3.new(),
            Parent = self.main
        })

        self.titleLabel = self:Create('TextLabel', {
            Position = UDim2.new(0, 6, 0, -1),
            Size = UDim2.new(0, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = tostring(self.title),
            Font = Enum.Font.GothamBold,
            TextSize = 17,
            TextColor3 = Palette.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = self.main
        })

        
        self:Create('Frame', {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0, 51),
            BackgroundColor3 = Palette.Divider,
            BorderSizePixel = 0,
            Parent = self.main
        })

        
        self:Create('Frame', {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.94,
            BorderSizePixel = 0,
            Parent = self.main
        })

        self.tabHighlight = self:Create('Frame', {
            BackgroundColor3 = library.flags.menuAccentColor,
            BorderSizePixel = 0,
            Parent = self.main
        })
        table.insert(library.theme, self.tabHighlight)

        self.columnHolder = self:Create('Frame', {
            Position = UDim2.new(0, 5, 0, 55),
            Size = UDim2.new(1, -10, 1, -60),
            BackgroundTransparency = 1,
            Parent = self.main
        })

        self.tooltip = self:Create('TextLabel', {
            ZIndex = 2,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            TextSize = 15,
            Size = UDim2.fromOffset(0, 0),
            Position = UDim2.fromScale(10, 10),
            Font = Enum.Font.Gotham,
            TextColor3 = Color3.new(1, 1, 1),
            Visible = false,   
            Active = false,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = self.base,
            AutomaticSize = Enum.AutomaticSize.XY
        })

        self:Create('UISizeConstraint', {
            Parent = self.tooltip,
            MaxSize = Vector2.new(400, 1000),
            MinSize = Vector2.new(0, 0),
        });

        self:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.new(1, 10, 1, 0),
            Active = false,
            Style = Enum.FrameStyle.RobloxRound,
            Parent = self.tooltip
        })

        self:Create('UIStroke', {
            Color = Palette.Stroke,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = self.main
        })

        
        
        if (isTouchMode()) then
            self.mobileUI = MobileUI.new(self, {
                palette = Palette,
                isPrimaryInput = isPrimaryInput
            });

            self.mobileUI:install();
        end;

        library.unloadMaid:GiveTask(top.InputBegan:connect(function(input)
            if isPrimaryInput(input) then
                dragObject = self.main
                dragging = true
                dragStart = input.Position
                startPos = dragObject.Position
                if library.popup then library.popup:Close() end
            end
        end));

        library.unloadMaid:GiveTask(top.InputChanged:connect(function(input)
            if dragging and isPrimaryMove(input) then
                dragInput = input
            end
        end));

        library.unloadMaid:GiveTask(top.InputEnded:connect(function(input)
            if isPrimaryInput(input) then
                dragging = false
            end
        end));

        local titleTextSize = TextService:GetTextSize(self.titleLabel.Text, 18, Enum.Font.Gotham, Vector2.new(1000, 0));

        local searchLabel = library:Create('ImageLabel', {
            Position = UDim2.new(0, titleTextSize.X + 10, 0.5, -8),
            Size = UDim2.new(0, 16, 0, 16),
            BackgroundTransparency = 1,
            Image = 'rbxasset://textures/ui/Settings/ShareGame/icons.png',
            ImageRectSize = Vector2.new(16, 16),
            ImageRectOffset = Vector2.new(6, 106),
            ClipsDescendants = true,
            Parent = self.titleLabel
        });

        local searchBox = library:Create('TextBox', {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(searchLabel.AbsolutePosition.X-80, 5),
            Size = UDim2.fromOffset(50, 15),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = self.titleLabel,
            Text = '',
            PlaceholderText = 'Type something to search...',
            Visible = false
        });

        
        self.searchBox = searchBox;
        self.searchLabel = searchLabel;

        local searchContainer = library:Create('ScrollingFrame', {
            BackgroundTransparency = 1,
            Visible = false,
            Size = UDim2.fromScale(1, 1),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Parent = library.columnHolder,
            BorderSizePixel = 0,
            ScrollBarImageColor3 = Palette.Stroke,
            ScrollBarThickness = 6,
            CanvasSize = UDim2.new(),
            ScrollingDirection = Enum.ScrollingDirection.Y,
            VerticalScrollBarInset = Enum.ScrollBarInset.Always,
            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
        });

        library:Create('UIListLayout', {
            Parent = searchContainer
        })

        self.searchContainer = searchContainer;

        local allFoundResults = {};
        local modifiedNames = {};

        local function clearFoundResult()
            for _, option in next, allFoundResults do
                option.main.Parent = option.originalParent;
            end;

            for _, option in next, modifiedNames do
                option.title.Text = option.text;
                option.main.Parent = option.originalParent;
            end;

            table.clear(allFoundResults);
            table.clear(modifiedNames);
        end;

        local sFind, sLower = string.find, string.lower;

        library.unloadMaid:GiveTask(searchBox:GetPropertyChangedSignal('Text'):Connect(function()
            local text = string.lower(searchBox.Text):gsub('%s', '');

            for _, v in next, library.options do
                if (not v.originalParent) then
                    v.originalParent = v.main.Parent;
                end;
            end;

            clearFoundResult();

            for _, v in next, library.currentTab.columns do
                v.main.Visible = text == '' and true or false;
            end;

            if (text == '') then return; end;
            local matchedResults = false;

            for _, v in next, library.options do
                local main = v.main;

                if (v.text == 'Enable' or v.parentFlag) then
                    if (v.type == 'toggle' or v.type == 'bind') then
                        local parentName = v.parentFlag and 'Bind' or v.section.title;
                        v.title.Text = string.format('%s [%s]', v.text, parentName);

                        table.insert(modifiedNames, v);
                    end;
                end;

                if (sFind(sLower(v.text), text) or sFind(sLower(v.flag), text)) then
                    matchedResults = true;
                    main.Parent = searchContainer;
                    table.insert(allFoundResults, v);
                else
                    main.Parent = v.originalParent;
                end;
            end;

            searchContainer.Visible = matchedResults;
        end));

        library.unloadMaid:GiveTask(searchLabel.InputBegan:Connect(function(inputObject)
            if (not isPrimaryInput(inputObject)) then return end;
            searchBox.Visible = true;
            searchBox:CaptureFocus();
        end));

        library.unloadMaid:GiveTask(searchBox.FocusLost:Connect(function()
            if (searchBox.Text:gsub('%s', '') ~= '') then return end;
            searchBox.Visible = false;
        end));


        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

        function self:selectTab(tab)
            if self.currentTab == tab then return end
            if library.popup then library.popup:Close() end
            clearFoundResult();
            searchBox.Visible = false;
            searchBox.Text = '';

            if self.currentTab then
                self.currentTab.button.TextColor3 = Color3.fromRGB(255, 255, 255)
                for _, column in next, self.currentTab.columns do
                    column.main.Parent = nil;
                    column.main.Visible = true;
                end
            end
            self.main.Size = UDim2.new(0, 16 + ((#tab.columns < 2 and 2 or #tab.columns) * 239), 0, getWindowHeight());
            applyMainScale();
            self.currentTab = tab
            tab.button.TextColor3 = library.flags.menuAccentColor;

            TweenService:Create(self.tabHighlight, tweenInfo, {
                Position = UDim2.new(0, tab.button.Position.X.Offset, 0, 51),
                Size = UDim2.new(0, tab.button.AbsoluteSize.X, 0, -1)
            }):Play();

            for _, column in next, tab.columns do
                column.main.Parent = self.columnHolder
            end
        end

        task.spawn(function()
            while library do
                local Configs = self:GetConfigs()
                for _, config in next, Configs do
                    if config ~= 'nil' and not table.find(self.options.configList.values, config) then
                        self.options.configList:AddValue(config)
                    end
                end
                for _, config in next, self.options.configList.values do
                    if config ~= 'nil' and not table.find(Configs, config) then
                        self.options.configList:RemoveValue(config)
                    end
                end
                task.wait(1);
            end
        end)

        for _, tab in next, self.tabs do
            if tab.canInit then
                tab:Init();
            end;
        end;

        if (self.mobileUI) then
            self.mobileUI:afterInit();
        end;

        self:AddConnection(UserInputService.InputEnded, function(input)
            if (isPrimaryInput(input)) and self.slider then
                self.slider.slider.BorderColor3 = Color3.new();
                self.slider = nil;

                if (self.mobileUI) then
                    self.mobileUI:unlockScroll();
                end;
            end;
        end);

        self:AddConnection(UserInputService.InputChanged, function(input)
            if self.open then
                if input == dragInput and dragging and library.draggable then
                    local delta = input.Position - dragStart;
                    local yPos = (startPos.Y.Offset + delta.Y) < -36 and -36 or startPos.Y.Offset + delta.Y;

                    dragObject:TweenPosition(UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, yPos), 'Out', 'Quint', 0.1, true);
                end;

                if self.slider and isPrimaryMove(input) then
                    self.slider:SetValue(self.slider.min + ((input.Position.X - self.slider.slider.AbsolutePosition.X) / self.slider.slider.AbsoluteSize.X) * (self.slider.max - self.slider.min));
                end;
            end;
        end);

        local configData = readFileAndDecodeIt(library.foldername .. '/' .. library.fileext);

        if (configData) then
            library.configVars = configData;
            library:LoadConfig(configData.config);

            library.OnLoad:Connect(function()
                library.options.configList:SetValue(library.loadedConfig or 'default');
            end);
        else
            print('[Script] [Config Loader] An error has occured', configData);
        end;

        self:selectTab(self.tabs[1]);

        if (not silent) then
            self:Close();
        else
            self.open = false;
        end;

        library.OnLoad:Fire();
        library.OnLoad:Destroy();

        
        
        
        
        
        
        library.OnLoad = {
            Connect = function() return { Disconnect = function() end } end;
            Fire = function() end;
            Destroy = function() end;
        };
    end;

    function library:SetTitle(text)
        if (not self.titleLabel) then
            return;
        end;

        self.titleLabel.Text = text;
    end;

    do 
        local configWarning = library:AddWarning({type = 'confirm'})
        local messageWarning = library:AddWarning();

        function library:ShowConfirm(text)
            configWarning.text = text;
            return configWarning:Show();
        end;

        function library:ShowMessage(text)
            messageWarning.text = text;
            return messageWarning:Show();
        end

        local function showBasePrompt(text)
            local r, g, b = library.round(library.flags.menuAccentColor);

            local configName = text == 'create' and library.flags.configName or library.flags.configList;
            local trimedValue = configName:gsub('%s', '');

            if(trimedValue == '') then
                library:ShowMessage(string.format('Can not %s a config with no name !', text));
                return false;
            end;

            return library:ShowConfirm(string.format(
                'Are you sure you want to %s config <font color=\'rgb(%s, %s, %s)\'>%s</font>',
                text,
                r,
                g,
                b,
                configName
            ));
        end;

        
        local AUTHOR_QQ = '2016893080';

        local maid = Maid.new();
        library.unloadMaid:GiveTask(function()
            maid:Destroy();
        end);

        local settingsTab       = library:AddTab('设置', 100);
        local settingsColumn    = settingsTab:AddColumn();
        local settingsColumn1   = settingsTab:AddColumn();
        local settingsMain      = settingsColumn:AddSection('主要');
        local settingsMenu      = settingsColumn:AddSection('菜单');
        local configSection     = settingsColumn1:AddSection('配置');
        local contactSection    = settingsColumn:AddSection('联系方式');
        local BackgroundArray   = {};

        local Backgrounds = {
            ['默认'] = 74117830423217,
            Floral  = 5553946656,
            Flowers = 6071575925,
            Circles = 6071579801,
            Hearts  = 6073763717,
        };

        task.spawn(function()
            for i, v in next, Backgrounds do
                table.insert(BackgroundArray, 'rbxassetid://' .. v);
            end;

            ContentProvider:PreloadAsync(BackgroundArray);
        end);

        local lastShownNotifAt = 0;

        local function setCustomBackground()
            local imageURL = library.flags.customBackground;
            imageURL = imageURL:gsub('%s', '');

            if (imageURL == '') then return end;

            if (not isfolder('v.air/CustomBackgrounds')) then
                makefolder('v.air/CustomBackgrounds');
            end;

            local path = string.format('v.air/CustomBackgrounds/%s.bin', hash(imageURL));

            if (not isfile(path)) then
                local suc, httpRequest = pcall(request, {
                    Url = imageURL,
                });

                if (not suc) then return library:ShowMessage('The url you have specified for the custom background is invalid.'); end;

                if (not httpRequest.Success) then return library:ShowMessage(string.format('Request failed %d', httpRequest.StatusCode)); end;
                local imgType = httpRequest.Headers['Content-Type']:lower();
                if (imgType ~= 'image/png' and imgType ~= 'image/jpeg') then return library:ShowMessage('Only PNG and JPEG are supported'); end;

                writefile(path, httpRequest.Body);
            end;

            library.main.Image = getsynasset(path);

            local acColor = library.flags.menuBackgroundColor;
            local r, g, b = acColor.R * 255, acColor.G * 255, acColor.B * 255;

            if (r <= 100 and g <= 100 and b <= 100 and tick() - lastShownNotifAt > 1) then
                lastShownNotifAt = tick();
                ToastNotif.new({text = 'Your menu accent color is dark custom background may not show.', duration = 20});
            end;
        end;

        
        function library:SetMenuTransparency(percent)
            local value = math.clamp((tonumber(percent) or 0) / 100, 0, 1);

            library.transparencyValue = value;

            
            local function baseOf(gui)
                local baseTransparency = gui:GetAttribute('transparencyBase');

                if (baseTransparency == nil) then
                    baseTransparency = gui.BackgroundTransparency;
                    pcall(function() gui:SetAttribute('transparencyBase', baseTransparency) end);
                end;

                return baseTransparency;
            end;

            local main = library.main;

            if (main) then
                local base = baseOf(main);
                main.BackgroundTransparency = base + (1 - base) * value;
            end;

            for _, gui in next, library.base:GetDescendants() do
                local isPanel = gui:IsA('Frame') or gui:IsA('ScrollingFrame') or gui:IsA('TextButton') or gui:IsA('ImageButton') or gui:IsA('TextBox');

                if (isPanel and gui ~= main) then
                    local baseTransparency = baseOf(gui);

                    
                    
                    if (gui:IsA('ScrollingFrame')) then
                        local scrollBase = gui:GetAttribute('scrollBarBase');

                        if (scrollBase == nil) then
                            scrollBase = gui.ScrollBarImageTransparency;
                            gui:SetAttribute('scrollBarBase', scrollBase);
                        end;

                        gui.ScrollBarImageTransparency = scrollBase + (1 - scrollBase) * value;
                    end;

                    
                    
                    if (baseTransparency < 0.95) then
                        local size = gui.AbsoluteSize;
                        local isIndicator = (size.Y <= 12) or (size.X <= 40 and size.Y <= 40);

                        if (not isIndicator and size.X >= 100) then
                            gui.BackgroundTransparency = baseTransparency + (1 - baseTransparency) * value;
                        elseif (value == 0) then
                            gui.BackgroundTransparency = baseTransparency;
                        end;
                    end;
                end;
            end;
        end;

        
        task.spawn(function()
            while (library) do
                task.wait(0.5);

                if ((library.transparencyValue or 0) > 0) then
                    pcall(library.SetMenuTransparency, library, library.transparencyValue * 100);
                end;
            end;
        end);

        settingsMain:AddSlider({
            text = '面板透明度', flag = 'Menu Transparency',
            min = 0, max = 100, value = 0, suffix = '%',
            tip = '调高之后面板底色变透明，能看到背后的背景图',
            callback = function(value)
                library:SetMenuTransparency(value);
            end,
        });

settingsMain:AddBox({
            text = '自定义背景', flag = 'Custom Background',
            tip = 'Put a valid image link here',
            callback = setCustomBackground
        });

        library.OnLoad:Connect(function()
            local customBackground = library.flags.customBackground;
            if (customBackground:gsub('%s', '') == '') then return end;

            task.defer(setCustomBackground);
        end);

        do
            local scaleTypes = {};

            for _, scaleType in next, Enum.ScaleType:GetEnumItems() do
                table.insert(scaleTypes, scaleType.Name);
            end;

            settingsMain:AddList({
                text = '背景缩放方式', flag = 'Background Scale Type',
                values = scaleTypes,
                callback = function()
                    library.main.ScaleType = Enum.ScaleType[library.flags.backgroundScaleType];
                end
            });
        end;

        settingsMain:AddButton({
            text = '卸载菜单', flag = 'Unload Menu',
            nomouse = true,
            callback = function()
                library:Unload()
            end
        });

        settingsMain:AddBind({
            text = '卸载热键', flag = 'Unload Key',
            nomouse = true,
            callback = library.options.unloadMenu.callback
        });

        
        
        

        settingsMenu:AddBind({
            text = '开 / 关',
            flag = 'UI Toggle',
            nomouse = true,
            key = 'LeftAlt',
            callback = function() library:Close() end
        })

        settingsMenu:AddColor({
            text = '主题色',
            flag = 'Menu Accent Color',
            color = Color3.fromRGB(255, 46, 99),
            callback = function(Color)
                if library.currentTab then
                    library.currentTab.button.TextColor3 = Color
                end

                for _, obj in next, library.theme do
                    obj[(obj.ClassName == 'TextLabel' and 'TextColor3') or (obj.ClassName == 'ImageLabel' and 'ImageColor3') or 'BackgroundColor3'] = Color
                end
            end
        })

        settingsMenu:AddToggle({
            text = '按键可视化', flag = 'Keybind Visualizer',
            state = true,
            callback = function(state)
                return visualizer:SetEnabled(state);
            end
        }):AddColor({
            text = '按键可视化颜色', flag = 'Keybind Visualizer Color',
            callback = function(color)
                return visualizer:UpdateColor(color);
            end
        });

        settingsMenu:AddToggle({
            text = '按键可视化彩虹色', flag = 'Rainbow Keybind Visualizer',
            callback = function(t)
                if (not t) then
                    return maid.rainbowKeybindVisualizer;
                end;

                maid.rainbowKeybindVisualizer = task.spawn(function()
                    while task.wait() do
                        visualizer:UpdateColor(library.chromaColor);
                    end;
                end);
            end
        })

        
        local function ensureBackgroundTint()
            local color = library.flags.menuBackgroundColor;

            if (typeof(color) ~= 'Color3' or (color.R == 0 and color.G == 0 and color.B == 0)) then
                library.options.menuBackgroundColor:SetColor(Color3.new(1, 1, 1));
            end;
        end;

        settingsMenu:AddList({
            text = '背景',
            flag = 'UI Background',
            values = {'默认', 'Floral', 'Flowers', 'Circles', 'Hearts'},
            callback = function(Value)
                if (not Backgrounds[Value]) then return end;

                library.main.Image = 'rbxassetid://' .. Backgrounds[Value];
                ensureBackgroundTint();
            end
        }):AddColor({
            flag = 'Menu Background Color',
            color = Color3.new(1, 1, 1),
            trans = 1,
            callback = function(Color)
                library.main.ImageColor3 = Color
            end,
            calltrans = function(Value)
                library.main.ImageTransparency = 1 - Value
            end
        });

        
        library.OnLoad:Connect(function()
            if (not library.main or library.main.Image ~= '') then return end;

            library.main.Image = 'rbxassetid://' .. Backgrounds['默认'];
            library.main.ImageTransparency = 0;

            ensureBackgroundTint();
        end);

        settingsMenu:AddSlider({
            text = '平铺尺寸', flag = 'Tile Size',
            value = 90,
            min = 50,
            max = 500,
            callback = function(Value)
                library.main.TileSize = UDim2.new(0, Value, 0, Value)
            end
        })

        configSection:AddBox({
            text = '配置名称', flag = 'Config Name',
            skipflag = true,
        })

        local function getAllConfigs()
            local files = {};

            for _, v in next, listfiles('v.air/configs') do
                if (not isfolder(v)) then continue; end;

                for _, v2 in next, listfiles(v) do
                    local configName = v2:match('(%w+).config.json');
                    if (not configName) then continue; end;

                    
                    
                    
                    local normalized = tostring(v):gsub('\\', '/');
                    local folderName = normalized:match('configs/([^/]+)') or 'default';
                    local fullConfigName = string.format('%s - %s', tostring(folderName), tostring(configName));

                    table.insert(files, fullConfigName);
                end;
            end;

            return files;
        end;

        local function updateAllConfigs()
            for _, v in next, library.options.loadFromList.values do
                library.options.loadFromList:RemoveValue(v);
            end;

            for _, configName in next, getAllConfigs() do
                library.options.loadFromList:AddValue(configName);
            end;
        end

        configSection:AddList({
            text = '配置',
            skipflag = true,
            value = '',
            flag = 'Config List',
            values = library:GetConfigs(),
        })

        configSection:AddButton({
            text = '创建', flag = 'Create',
            callback = function()
                if (showBasePrompt('create')) then
                    library.options.configList:AddValue(library.flags.configName);
                    library.options.configList:SetValue(library.flags.configName);
                    library:SaveConfig(library.flags.configName);
                    library:LoadConfig(library.flags.configName);

                    updateAllConfigs();
                end;
            end
        })

        local btn;
        btn = configSection:AddButton({
            text = isGlobalConfigOn and 'Switch To Local Config' or 'Switch to Global Config';

            callback = function()
                isGlobalConfigOn = not isGlobalConfigOn;
                writefile(globalConfFilePath, tostring(isGlobalConfigOn));

                btn:SetText(isGlobalConfigOn and 'Switch To Local Config' or 'Switch to Global Config');
                library:ShowMessage('Note: Switching from Local to Global requires script relaunch.');
            end
        });

        configSection:AddButton({
            text = '保存', flag = 'Save',
            callback = function()
                if (showBasePrompt('save')) then
                    library:SaveConfig(library.flags.configList);
                end;
            end
        }):AddButton({
            text = '读取', flag = 'Load',
            callback = function()
                if (showBasePrompt('load')) then
                    library:UpdateConfig(); 
                    library:LoadConfig(library.flags.configList);
                end
            end
        }):AddButton({
            text = '删除', flag = 'Delete',
            callback = function()
                if (showBasePrompt('delete')) then
                    local Config = library.flags.configList
                    local configFilePath = library.foldername .. '/' .. Config .. '.config' .. library.fileext;

                    if table.find(library:GetConfigs(), Config) and isfile(configFilePath) then
                        library.options.configList:RemoveValue(Config)
                        delfile(configFilePath);
                    end
                end;
            end
        })

        configSection:AddList({
            text = '载入方式',
            flag = 'Load From List',
            values = getAllConfigs()
        });

        configSection:AddButton({
            text = '载入方式', flag = 'Load From',
            callback = function()
                if (not showBasePrompt('load from')) then return; end;
                if (isGlobalConfigOn) then return library:ShowMessage('You can not load a config from another user if you are in global config mode.'); end;

                local folderName, configName = library.flags.loadFromList:match('(%w+) %p (.+)');
                local fullConfigName = string.format('%s.config.json', configName);

                if (isfile(library.foldername .. '/' .. fullConfigName)) then
                    

                    if (not library:ShowConfirm('There is already a config with this name in your config folder. Would you like to delete it? Pressing no will cancel the operation')) then
                        return;
                    end;
                end;

                local configData = readfile(string.format('v.air/configs/%s/%s', folderName, fullConfigName));
                writefile(string.format('%s/%s', library.foldername, fullConfigName), configData);

                library:LoadConfig(configName);
            end
        })

        configSection:AddToggle({
            text = '自动保存配置',
            state = true,
            flag = 'saveConfigAuto',
            callback = function(toggle)
                

                if(not toggle) then
                    maid.saveConfigAuto = nil;
                    library:UpdateConfig(); 
                    return;
                end;

                maid.saveConfigAuto = task.spawn(function()
                    while true do
                        task.wait(60);
                        library:UpdateConfig();
                    end;
                end);
            end,
        })

        local function saveConfigBeforeGameLeave()
            if (not library.flags.saveconfigauto) then return; end;
            library:UpdateConfig();
        end;

        library.unloadMaid:GiveTask(GuiService.NativeClose:Connect(saveConfigBeforeGameLeave));

        
        library.unloadMaid:GiveTask(GuiService.MenuOpened:Connect(saveConfigBeforeGameLeave));

        library.unloadMaid:GiveTask(LocalPlayer.OnTeleport:Connect(function(state)
            if (state ~= Enum.TeleportState.Started and state ~= Enum.TeleportState.RequestedFromServer) then return end;
            saveConfigBeforeGameLeave();
        end));

        contactSection:AddButton({
            text = '复制作者QQ号', flag = 'Copy Author QQ',
            callback = function() return setclipboard(AUTHOR_QQ) end
        });
    end;
end;

warn(string.format('[Script] [Library] Loaded in %.02f seconds', tick() - libraryLoadAt));




local function findBindOption(parentFlag)
    for _, option in next, library.options do
        if (option.type == 'bind' and option.parentFlag == parentFlag) then
            return option;
        end;
    end;
end;

library.OnFlagChanged:Connect(function(data)
    local bindOption = findBindOption(data.flag);

    if (not bindOption) then return end;

    if (library.flags[data.flag]) then
        if (bindOption.key and bindOption.key ~= 'none') then
            visualizer:AddText(bindOption.text);
        end;
    else
        
        
        visualizer:RemoveText(bindOption.text);
    end
end);

return library;
end;

MODULES['classes/AnalyticsAPI.lua'] = function()
local HttpService = game:GetService('HttpService');

local Analytics = {}
Analytics.__index = Analytics;

do
    function Analytics.new(id)
        local self = setmetatable({}, Analytics);

        self._id = id;

        return self;
    end;

    function Analytics:Report(Category, Action, Value)
        local Label = string.format('AH:%s', accountData.username);

        task.spawn(request, {
            Url = 'http://www.google-analytics.com/collect',
            Method = 'POST',
            Body = string.format('v=1&t=event&sc=start&tid=%s&cid=%s&ec=%s&ea=%s&el=%s&ev=%s', self._id, accountData.uuid, HttpService:UrlEncode(Category), HttpService:UrlEncode(Action), HttpService:UrlEncode(Label), HttpService:UrlEncode(Value)),
            Headers = {
                ['Content-Type'] = 'application/x-www-form-urlencoded'
            }
        })
    end;
end;

return Analytics;
end;

MODULES['classes/EntityESP.lua'] = function()

local library = sharedRequire('../UILibrary.lua');
local Utility = sharedRequire('../utils/Utility.lua');
local Services = sharedRequire('../utils/Services.lua');

local RunService, UserInputService, HttpService, Players = Services:Get('RunService', 'UserInputService', 'HttpService', 'Players');


local wallCheckParams = RaycastParams.new();
wallCheckParams.FilterType = Enum.RaycastFilterType.Exclude;
wallCheckParams.IgnoreWater = true;

local EntityESP = {};

local worldToViewportPoint = clonefunction(Instance.new('Camera').WorldToViewportPoint);
local vectorToWorldSpace = CFrame.new().VectorToWorldSpace;
local getMouseLocation = clonefunction(UserInputService.GetMouseLocation);

local id = HttpService:GenerateGUID(false);

local lerp = Color3.new().lerp;
local flags = library.flags;

local vector3New = Vector3.new;
local Vector2New = Vector2.new;

local mathFloor = math.floor;

local mathRad = math.rad;
local mathCos = math.cos;
local mathSin = math.sin;
local mathAtan2 = math.atan2;

local showTeam;
local allyColor;
local enemyColor;
local maxEspDistance;
local toggleBoxes;
local toggleTracers;
local unlockTracers;
local showHealthBar;
local proximityArrows;
local maxProximityArrowDistance;

local scalarPointAX, scalarPointAY;
local scalarPointBX, scalarPointBY;

local labelOffset, tracerOffset;
local boxOffsetTopRight, boxOffsetBottomLeft;

local healthBarOffsetTopRight, healthBarOffsetBottomLeft;
local healthBarValueOffsetTopRight, healthBarValueOffsetBottomLeft;

local realGetRPProperty;

local setRP;
local getRPProperty;
local destroyRP;

local scalarSize = 20;

if (not isExecutorV3) then
	local lineUpvalues = getupvalue(Drawing.new, 4).__index;
	local lineUpvalues2 = getupvalue(Drawing.new, 4).__newindex;

	
	local realSetRP = getupvalue(lineUpvalues2, 4);
    local realDestroyRP = getupvalue(lineUpvalues, 3);
    realGetRPProperty = getupvalue(lineUpvalues, 4);

    assert(realSetRP);
    assert(realDestroyRP);
    assert(realGetRPProperty);

    setRP = function(object, p, v)
		local cache = object._cache;
        local cacheVal = cache[p];
        if (cacheVal == v) then return end;

        cache[p] = v;
        realSetRP(object.__OBJECT, p, v);
    end;

    getRPProperty = function(object, p)
        local cacheVal = object._cache[p];
        if (not cacheVal) then
            object._cache[p] = realGetRPProperty(object.__OBJECT, p);
            cacheVal = object._cache[p];
        end;

        return cacheVal;
    end;

    destroyRP = function(object)
        return realDestroyRP(object.__OBJECT);
    end;
else
	getRPProperty = function(self, p, v)
		return self[p];
	end;

	setRP = function(self, p, v)
		self[p] = v;
	end;

	destroyRP = function(self)
		return self:Remove();
	end;

    realGetRPProperty = getRPProperty;
end;

local ESP_RED_COLOR, ESP_GREEN_COLOR = Color3.fromRGB(192, 57, 43), Color3.fromRGB(39, 174, 96)
local TRIANGLE_ANGLE = mathRad(45);

do 
    EntityESP = {};
    EntityESP.__index = EntityESP;
    EntityESP.__ClassName = 'entityESP';

    EntityESP.id = 0;

    local emptyTable = {};

    function EntityESP.new(player)
        EntityESP.id += 1;

        local self = setmetatable({}, EntityESP);

        self._id = EntityESP.id;
        self._player = player;
        self._playerName = player.Name;

        self._triangle = Drawing.new('Triangle');
        self._triangle.Visible = true;
        self._triangle.Thickness = 0;
        self._triangle.Color = Color3.fromRGB(255, 255, 255);
        self._triangle.Filled = true;

        self._label = Drawing.new('Text');
        self._label.Visible = false;
        self._label.Center = true;
        self._label.Outline = true;
        self._label.Text = '';
        self._label.Font = Drawing.Fonts[library.flags.espFont];
        self._label.Size = library.flags.textSize;
        self._label.Color = Color3.fromRGB(255, 255, 255);

        self._box = Drawing.new('Quad');
        self._box.Visible = false;
        self._box.Thickness = 1;
        self._box.Filled = false;
        self._box.Color = Color3.fromRGB(255, 255, 255);

        self._healthBar = Drawing.new('Quad');
        self._healthBar.Visible = false;
        self._healthBar.Thickness = 1;
        self._healthBar.Filled = false;
        self._healthBar.Color = Color3.fromRGB(255, 255, 255);

        self._healthBarValue = Drawing.new('Quad');
        self._healthBarValue.Visible = false;
        self._healthBarValue.Thickness = 1;
        self._healthBarValue.Filled = true;
        self._healthBarValue.Color = Color3.fromRGB(0, 255, 0);

        self._line = Drawing.new('Line');
        self._line.Visible = false;
        self._line.Color = Color3.fromRGB(255, 255, 255);

        for i, v in next, self do
            if (typeof(v) == 'table' and rawget(v, '__OBJECT')) then
                rawset(v, '_cache', {});
            end;
        end;

        self._labelObject = isExecutorV3 and self._label or self._label.__OBJECT;

        return self;
    end;

    function EntityESP:Plugin()
        return emptyTable;
    end;

    function EntityESP:ConvertVector(...)
        
            
        
            return vectorToWorldSpace(self._cameraCFrame, vector3New(...));
        
    end;

    function EntityESP:GetOffsetTrianglePosition(closestPoint, radiusOfDegree)
        local cosOfRadius, sinOfRadius = mathCos(radiusOfDegree), mathSin(radiusOfDegree);
        local closestPointX, closestPointY = closestPoint.X, closestPoint.Y;

        local sameBCCos = (closestPointX + scalarPointBX * cosOfRadius);
        local sameBCSin = (closestPointY + scalarPointBX * sinOfRadius);

        local sameACSin = (scalarPointAY * sinOfRadius);
        local sameACCos = (scalarPointAY * cosOfRadius)

        local pointX1 = (closestPointX + scalarPointAX * cosOfRadius) - sameACSin;
        local pointY1 = closestPointY + (scalarPointAX * sinOfRadius) + sameACCos;

        local pointX2 = sameBCCos - (scalarPointBY * sinOfRadius);
        local pointY2 = sameBCSin + (scalarPointBY * cosOfRadius);

        local pointX3 = sameBCCos - sameACSin;
        local pointY3 = sameBCSin + sameACCos;

        return Vector2New(mathFloor(pointX1), mathFloor(pointY1)), Vector2New(mathFloor(pointX2), mathFloor(pointY2)), Vector2New(mathFloor(pointX3), mathFloor(pointY3));
    end;

    function EntityESP:Update(t)
        
        if (not self._label or not self._box) then return end;

        local camera = self._camera;
        if(not camera) then return self:Hide() end;

        
        if (not self._player or not self._player.Parent) then return self:Hide() end;

        local character, maxHealth, floatHealth, health, rootPart = Utility:getCharacter(self._player);
        if(not character or not character.Parent) then return self:Hide() end;

        
        
        
        
        if (not character:IsDescendantOf(workspace)) then
            local parentName = character.Parent and character.Parent.Name;

            if (parentName ~= '__CharacterCullStorage') then
                return self:Hide();
            end;
        end;

        rootPart = rootPart or Utility:getRootPart(self._player);
        if(not rootPart or not rootPart.Parent) then return self:Hide() end;

        local rootPartPosition = rootPart.Position;

        
        
        
        
        if (library.flags.espWallCheck) then
            local ignoreList = { character };
            local localCharacter = Players.LocalPlayer and Players.LocalPlayer.Character;

            if (localCharacter) then
                table.insert(ignoreList, localCharacter);
            end;

            local function isSolidBlocker(instance)
                if (not (instance and instance:IsA('BasePart'))) then return false end;
                if (not instance.CanCollide) then return false end;
                if (instance.Transparency >= 0.6) then return false end;

                local size = instance.Size;

                if (math.min(size.X, size.Y, size.Z) < 0.8) then return false end;

                return true;
            end;

            local function isOccluded(destination, origin)
                local probeList = table.clone(ignoreList);

                for attempt = 1, 6 do
                    wallCheckParams.FilterDescendantsInstances = probeList;

                    local hit = workspace:Raycast(origin, destination - origin, wallCheckParams);

                    if (not hit) then return false end;
                    if (isSolidBlocker(hit.Instance)) then return true end;

                    table.insert(probeList, hit.Instance);
                end;

                return false;
            end;

            local origin = self._cameraPosition;

            if (origin) then
                
                
                local torso = character:FindFirstChild('UpperTorso') or character:FindFirstChild('LowerTorso') or character:FindFirstChild('Torso');
                local head = character:FindFirstChild('Head');
                local cameraCFrame = self._cameraCFrame or CFrame.new(origin);
                local rightVector = cameraCFrame.RightVector;

                local samplePoints = {};

                if (head) then table.insert(samplePoints, head.Position) end;

                if (torso) then
                    table.insert(samplePoints, torso.Position);
                    table.insert(samplePoints, torso.Position + rightVector * 1.3);
                    table.insert(samplePoints, torso.Position - rightVector * 1.3);
                end;

                table.insert(samplePoints, rootPartPosition);

                local allBlocked = true;

                for _, point in next, samplePoints do
                    if (not isOccluded(point, origin)) then
                        allBlocked = false;

                        break;
                    end;
                end;

                if (allBlocked) then return self:Hide() end;
            end;
        end;

        local labelPos, visibleOnScreen = worldToViewportPoint(camera, rootPartPosition + labelOffset);
        local triangle = self._triangle;

        local isTeamMate = Utility:isTeamMate(self._player);
        if(isTeamMate and not showTeam) then return self:Hide() end;

        local distance = (rootPartPosition - self._cameraPosition).Magnitude;
        if(distance > maxEspDistance) then return self:Hide() end;

        local espColor = isTeamMate and allyColor or enemyColor;
        local canView = false;

        if (proximityArrows and not visibleOnScreen and distance < maxProximityArrowDistance) then
            local vectorUnit;

            if (labelPos.Z < 0) then
                vectorUnit = -(Vector2.new(labelPos.X, labelPos.Y) - self._viewportSizeCenter).Unit; 
            else
                vectorUnit = (Vector2.new(labelPos.X, labelPos.Y) - self._viewportSizeCenter).Unit; 
            end;

            local degreeOfCorner = -mathAtan2(vectorUnit.X, vectorUnit.Y) - TRIANGLE_ANGLE;
            local closestPointToPlayer = self._viewportSizeCenter + vectorUnit * scalarSize 

            local pointA, pointB, pointC = self:GetOffsetTrianglePosition(closestPointToPlayer, degreeOfCorner);

            setRP(triangle, 'PointA', pointA);
            setRP(triangle, 'PointB', pointB);
            setRP(triangle, 'PointC', pointC);

            setRP(triangle, 'Color', espColor);
            canView = true;
        end;

        setRP(triangle, 'Visible', canView);
        if (not visibleOnScreen) then return self:Hide(true) end;

        self._visible = visibleOnScreen;

        local label, box, line, healthBar, healthBarValue = self._label, self._box, self._line, self._healthBar, self._healthBarValue;
        local pluginData = self:Plugin();

        
        
        local text = '[' .. (pluginData.playerName or self._playerName) .. '] [' .. mathFloor(distance) .. ']\n[' .. mathFloor(health) .. '/' .. mathFloor(maxHealth) .. '] [' .. mathFloor(floatHealth) .. ' %]' .. (pluginData.text or '');

        setRP(label, 'Visible', visibleOnScreen);
        setRP(label, 'Position', Vector2New(labelPos.X, labelPos.Y - realGetRPProperty(self._labelObject, 'TextBounds').Y));
        setRP(label, 'Text', text);
        setRP(label, 'Color', espColor);

        if(toggleBoxes) then
            local boxTopRight = worldToViewportPoint(camera, rootPartPosition + boxOffsetTopRight);
            local boxBottomLeft = worldToViewportPoint(camera, rootPartPosition + boxOffsetBottomLeft);

            local topRightX, topRightY = boxTopRight.X, boxTopRight.Y;
            local bottomLeftX, bottomLeftY = boxBottomLeft.X, boxBottomLeft.Y;

            setRP(box, 'Visible', visibleOnScreen);

            setRP(box, 'PointA', Vector2New(topRightX, topRightY));
            setRP(box, 'PointB', Vector2New(bottomLeftX, topRightY));
            setRP(box, 'PointC', Vector2New(bottomLeftX, bottomLeftY));
            setRP(box, 'PointD', Vector2New(topRightX, bottomLeftY));
            setRP(box, 'Color', espColor);
        else
            setRP(box, 'Visible', false);
        end;

        if(toggleTracers) then
            local linePosition = worldToViewportPoint(camera, rootPartPosition + tracerOffset);

            setRP(line, 'Visible', visibleOnScreen);

            setRP(line, 'From', unlockTracers and getMouseLocation(UserInputService) or self._viewportSize);
            setRP(line, 'To', Vector2New(linePosition.X, linePosition.Y));
            setRP(line, 'Color', espColor);
        else
            setRP(line, 'Visible', false);
        end;

        if(showHealthBar) then
            local healthBarValueHealth = (1 - (floatHealth / 100)) * 7.4;

            local healthBarTopRight = worldToViewportPoint(camera, rootPartPosition + healthBarOffsetTopRight);
            local healthBarBottomLeft = worldToViewportPoint(camera, rootPartPosition + healthBarOffsetBottomLeft);

            local healthBarTopRightX, healthBarTopRightY = healthBarTopRight.X, healthBarTopRight.Y;
            local healthBarBottomLeftX, healthBarBottomLeftY = healthBarBottomLeft.X, healthBarBottomLeft.Y;

            local healthBarValueTopRight = worldToViewportPoint(camera, rootPartPosition + healthBarValueOffsetTopRight - self:ConvertVector(0, healthBarValueHealth, 0));
            local healthBarValueBottomLeft = worldToViewportPoint(camera, rootPartPosition - healthBarValueOffsetBottomLeft);

            local healthBarValueTopRightX, healthBarValueTopRightY = healthBarValueTopRight.X, healthBarValueTopRight.Y;
            local healthBarValueBottomLeftX, healthBarValueBottomLeftY = healthBarValueBottomLeft.X, healthBarValueBottomLeft.Y;

            setRP(healthBar, 'Visible', visibleOnScreen);
            setRP(healthBar, 'Color', espColor);

            setRP(healthBar, 'PointA', Vector2New(healthBarTopRightX, healthBarTopRightY));
            setRP(healthBar, 'PointB', Vector2New(healthBarBottomLeftX, healthBarTopRightY));
            setRP(healthBar, 'PointC', Vector2New(healthBarBottomLeftX, healthBarBottomLeftY));
            setRP(healthBar, 'PointD', Vector2New(healthBarTopRightX, healthBarBottomLeftY));

            setRP(healthBarValue, 'Visible', visibleOnScreen);
            setRP(healthBarValue, 'Color', lerp(ESP_RED_COLOR, ESP_GREEN_COLOR, floatHealth / 100));

            setRP(healthBarValue, 'PointA', Vector2New(healthBarValueTopRightX, healthBarValueTopRightY));
            setRP(healthBarValue, 'PointB', Vector2New(healthBarValueBottomLeftX, healthBarValueTopRightY));
            setRP(healthBarValue, 'PointC', Vector2New(healthBarValueBottomLeftX, healthBarValueBottomLeftY));
            setRP(healthBarValue, 'PointD', Vector2New(healthBarValueTopRightX, healthBarValueBottomLeftY));
        else
            setRP(healthBar, 'Visible', false);
            setRP(healthBarValue, 'Visible', false);
        end;
    end;

    function EntityESP:Destroy()
        if (not self._label) then return end;

        destroyRP(self._label);
        self._label = nil;

        destroyRP(self._box);
        self._box = nil;

        destroyRP(self._line);
        self._line = nil;

        destroyRP(self._healthBar);
        self._healthBar = nil;

        destroyRP(self._healthBarValue);
        self._healthBarValue = nil;

        destroyRP(self._triangle);
        self._triangle = nil;
    end;

    function EntityESP:Hide(bypassTriangle)
        if (not bypassTriangle) then
            setRP(self._triangle, 'Visible', false);
        end;

        
        
        
        self._visible = false;

        setRP(self._label, 'Visible', false);
        setRP(self._box, 'Visible', false);
        setRP(self._line, 'Visible', false);

        setRP(self._healthBar, 'Visible', false);
        setRP(self._healthBarValue, 'Visible', false);
    end;

    function EntityESP:SetFont(font)
        setRP(self._label, 'Font', font);
    end;

    function EntityESP:SetTextSize(textSize)
        setRP(self._label, 'Size', textSize);
    end;

    local function updateESP()
        local camera = workspace.CurrentCamera;
        EntityESP._camera = camera;
        if (not camera) then return end;

        EntityESP._cameraCFrame = EntityESP._camera.CFrame;
        EntityESP._cameraPosition = EntityESP._cameraCFrame.Position;

        local viewportSize = camera.ViewportSize;

        EntityESP._viewportSize = Vector2New(viewportSize.X / 2, viewportSize.Y - 10);
        EntityESP._viewportSizeCenter = viewportSize / 2;

        showTeam = flags.showTeam;
        allyColor = flags.allyColor;
        enemyColor = flags.enemyColor;
        maxEspDistance = flags.maxEspDistance;
        toggleBoxes = flags.toggleBoxes;
        toggleTracers = flags.toggleTracers;
        unlockTracers = flags.unlockTracers;
        showHealthBar = flags.showHealthBar;
        maxProximityArrowDistance = flags.maxProximityArrowDistance;
        proximityArrows = flags.proximityArrows;

        scalarSize = library.flags.proximityArrowsSize or 20;

        scalarPointAX, scalarPointAY = scalarSize, scalarSize;
        scalarPointBX, scalarPointBY = -scalarSize, -scalarSize;

        labelOffset = EntityESP:ConvertVector(0, 3.25, 0);
        tracerOffset = EntityESP:ConvertVector(0, -4.5, 0);

        boxOffsetTopRight = EntityESP:ConvertVector(2.5, 3, 0);
        boxOffsetBottomLeft = EntityESP:ConvertVector(-2.5, -4.5, 0);

        healthBarOffsetTopRight = EntityESP:ConvertVector(-3, 3, 0);
        healthBarOffsetBottomLeft = EntityESP:ConvertVector(-3.5, -4.5, 0);

        healthBarValueOffsetTopRight = EntityESP:ConvertVector(-3.05, 2.95, 0);
        healthBarValueOffsetBottomLeft = EntityESP:ConvertVector(3.45, 4.45, 0);
    end;

    updateESP();
    RunService:BindToRenderStep(id, Enum.RenderPriority.Camera.Value, updateESP);
end;

return EntityESP;
end;

MODULES['classes/KeyBindVisualizer.lua'] = function()


local Services = sharedRequire('@utils/Services.lua');
local Maid = sharedRequire('@utils/Maid.lua');

local UserInputService = Services:Get('UserInputService');

local keybindVisualizer = {};
keybindVisualizer.__index = keybindVisualizer;




local TEXT_SIZE = 19;              
local LINE_GAP = 4;                
local DEFAULT_RIGHT_OFFSET = 180;  
local TOP_MARGIN = 36;             
local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255);
local FONT = Enum.Font.Gotham;     

local library;




local function resolveGuiParent()
    local candidates = {};

    if (type(gethui) == 'function') then
        local ok, hidden = pcall(gethui);

        if (ok and hidden) then
            candidates[#candidates + 1] = hidden;
        end;
    end;

    local okCore, coreGui = pcall(function()
        return game:GetService('CoreGui');
    end);

    if (okCore and coreGui) then
        candidates[#candidates + 1] = coreGui;
    end;

    local okPlayer, playerGui = pcall(function()
        local player = game:GetService('Players').LocalPlayer;

        return player and player:FindFirstChild('PlayerGui');
    end);

    if (okPlayer and playerGui) then
        candidates[#candidates + 1] = playerGui;
    end;

    for _, parent in ipairs(candidates) do
        local ok = pcall(function()
            local probe = Instance.new('Folder');
            probe.Name = 'vairKbvProbe';
            probe.Parent = parent;
            probe:Destroy();
        end);

        if (ok) then
            return parent;
        end;
    end;

    return nil;
end;

local function getViewport()
    local camera = workspace.CurrentCamera;

    return camera and camera.ViewportSize or Vector2.new(1280, 720);
end;




function keybindVisualizer.new()
    
    
    if (not library) then
        library = getgenv().library;
    end;

    if (not library) then
        library = {
            configVars = {},
            OnLoad = { Connect = function() return { Disconnect = function() end } end },
        };
    end;

    local self = setmetatable({}, keybindVisualizer);

    self._maid = Maid.new();
    self._entries = {};          
    self._order = {};            
    self._color = DEFAULT_COLOR;
    self._enabled = true;
    self._destroyed = false;

    self:_init();

    return self;
end;

function keybindVisualizer:_init()
    local parent = resolveGuiParent();

    if (not parent) then
        
        self._destroyed = true;

        return;
    end;

    local viewport = getViewport();

    
    pcall(function()
        for _, child in ipairs(parent:GetChildren()) do
            if (child:IsA('ScreenGui') and child.Name == 'VluaKeyBinds') then
                child:Destroy();
            end;
        end;
    end);

    self._gui = Instance.new('ScreenGui');
    self._gui.Name = 'VluaKeyBinds';
    self._gui.IgnoreGuiInset = true;
    self._gui.ResetOnSpawn = false;
    self._gui.DisplayOrder = 2147481000;
    self._gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;

    
    self._frame = Instance.new('Frame');
    self._frame.Name = 'KeyBindHost';
    self._frame.BackgroundTransparency = 1;
    self._frame.BorderSizePixel = 0;
    self._frame.AnchorPoint = Vector2.new(0, 1);
    self._frame.Position = UDim2.fromOffset(viewport.X - DEFAULT_RIGHT_OFFSET, viewport.Y / 2);
    self._frame.Size = UDim2.new(0, 0, 0, 0);
    self._frame.AutomaticSize = Enum.AutomaticSize.XY;
    self._frame.Parent = self._gui;

    local layout = Instance.new('UIListLayout');
    layout.FillDirection = Enum.FillDirection.Vertical;
    layout.SortOrder = Enum.SortOrder.LayoutOrder;
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left;
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom;
    layout.Padding = UDim.new(0, LINE_GAP);
    layout.Parent = self._frame;

    
    
    
    
    self._frame.Active = true;

    self._gui.Parent = parent;

    self:_hookDrag();
    self:_restorePosition();

    
    if (library.OnLoad and type(library.OnLoad.Connect) == 'function') then
        self._maid:GiveTask(library.OnLoad:Connect(function()
            self:_restorePosition();
        end));
    end;
end;




function keybindVisualizer:_restorePosition()
    if (self._destroyed or not self._frame) then return end;

    local stored = library.configVars and library.configVars.keybindVisualizerPos;

    if (type(stored) ~= 'string' or stored == '') then return end;

    
    
    local x, y = string.match(stored, '(-?%d+%.?%d*)%s*,%s*(-?%d+%.?%d*)');

    x = tonumber(x);
    y = tonumber(y);

    if (not x or not y) then return end;

    local viewport = getViewport();

    x = math.clamp(x, 0, viewport.X - 20);
    y = math.clamp(y, TOP_MARGIN, viewport.Y);

    self._frame.Position = UDim2.fromOffset(x, y);
end;

function keybindVisualizer:_savePosition()
    if (self._destroyed or not self._frame) then return end;
    if (type(library.configVars) ~= 'table') then return end;

    local pos = self._frame.Position;

    library.configVars.keybindVisualizerPos = string.format('%.0f, %.0f', pos.X.Offset, pos.Y.Offset);
end;

function keybindVisualizer:_hookDrag()
    local dragging = false;
    local dragStart = nil;
    local startOffset = nil;

    local function isPrimary(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch;
    end;

    local function isMove(input)
        return input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch;
    end;

    self._maid:GiveTask(self._frame.InputBegan:Connect(function(input)
        if (self._destroyed or not isPrimary(input)) then return end;

        dragging = true;
        dragStart = input.Position;

        local pos = self._frame.Position;
        startOffset = Vector2.new(pos.X.Offset, pos.Y.Offset);
    end));

    self._maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
        if (self._destroyed or not dragging or not isMove(input)) then return end;

        local delta = input.Position - dragStart;

        self._frame.Position = UDim2.fromOffset(
            startOffset.X + delta.X,
            startOffset.Y + delta.Y
        );
    end));

    self._maid:GiveTask(UserInputService.InputEnded:Connect(function(input)
        if (not dragging) then return end;
        if (not isPrimary(input)) then return end;

        dragging = false;

        
        self:_savePosition();
    end));
end;






local function displayLength(text)
    if (utf8 and utf8.len) then
        local ok, length = pcall(utf8.len, text);

        if (ok and length) then
            return length;
        end;
    end;

    return #text;
end;

local function sortKeys(keys)
    
    table.sort(keys, function(a, b)
        local lengthA = displayLength(a);
        local lengthB = displayLength(b);

        if (lengthA == lengthB) then
            return a < b;
        end;

        return lengthA < lengthB;
    end);

    return keys;
end;

function keybindVisualizer:_rebuild()
    if (self._destroyed) then return end;

    for index, text in ipairs(sortKeys(self._order)) do
        local label = self._entries[text];

        if (label) then
            label.LayoutOrder = index;
        end;
    end;
end;

function keybindVisualizer:AddText(txt)
    if (self._destroyed) then return end;

    txt = tostring(txt);

    if (self._entries[txt]) then return end;

    local label = Instance.new('TextLabel');
    label.Name = 'KeyBind';
    label.BackgroundTransparency = 1;
    label.Size = UDim2.new(0, 0, 0, 0);
    label.AutomaticSize = Enum.AutomaticSize.XY;
    label.Font = FONT;
    label.TextSize = TEXT_SIZE;
    label.Text = txt;
    label.TextColor3 = self._color;
    label.TextTransparency = 0;
    label.TextWrapped = false;
    label.TextXAlignment = Enum.TextXAlignment.Left;
    label.TextYAlignment = Enum.TextYAlignment.Top;
    label.ZIndex = 1;
    label.Parent = self._frame;

    self._entries[txt] = label;
    table.insert(self._order, txt);

    self:_rebuild();
end;

function keybindVisualizer:RemoveText(txt)
    if (self._destroyed) then return end;

    txt = tostring(txt);

    local label = self._entries[txt];

    
    if (not label) then return end;

    self._entries[txt] = nil;

    local index = table.find(self._order, txt);

    if (index) then
        table.remove(self._order, index);
    end;

    pcall(function()
        label:Destroy();
    end);

    self:_rebuild();
end;




function keybindVisualizer:UpdateColor(color)
    if (self._destroyed) then return end;

    color = color or DEFAULT_COLOR;

    
    local current = self._color;

    if (current == color) then return end;

    self._color = color;

    for _, label in next, self._entries do
        pcall(function()
            label.TextColor3 = self._color;
        end);
    end;
end;

function keybindVisualizer:SetEnabled(state)
    if (self._destroyed) then return end;

    self._enabled = state and true or false;

    if (self._gui) then
        self._gui.Enabled = self._enabled;
    end;
end;


function keybindVisualizer:GetLargest()
    local widest = Vector2.new(0, TEXT_SIZE);

    for text in next, self._entries do
        local width = #text * TEXT_SIZE * 0.62;

        if (width > widest.X) then
            widest = Vector2.new(width, TEXT_SIZE);
        end;
    end;

    return widest;
end;

function keybindVisualizer:MouseInFrame()
    if (self._destroyed or not self._frame) then return false end;

    local pos = self._frame.AbsolutePosition;
    local size = self._frame.AbsoluteSize;
    local mouse = UserInputService:GetMouseLocation();

    return mouse.X >= pos.X and mouse.X <= pos.X + size.X
        and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y;
end;

function keybindVisualizer:Remove()
    if (self._destroyed) then return end;

    self._destroyed = true;

    pcall(function()
        self._maid:Destroy();
    end);

    pcall(function()
        if self._gui then self._gui:Destroy() end;
    end);

    self._entries = {};
    self._order = {};
end;

function keybindVisualizer.init(newLibrary)
    library = newLibrary;
end;

return keybindVisualizer;
end;

MODULES['classes/TextLogger.lua'] = function()
local library = sharedRequire('@UILibrary.lua');




if (not library) then
    library = getgenv().library;
end;

if (not library) then
    library = {
        configVars = {};
        options = {};
        OnLoad = { Connect = function() return { Disconnect = function() end } end };
        OnKeyPress = { Connect = function() return { Disconnect = function() end } end };
        OnKeyRelease = { Connect = function() return { Disconnect = function() end } end };
        OnFlagChanged = { Connect = function() return { Disconnect = function() end } end };
        unloadMaid = { GiveTask = function() end };
    };
end;
local Services = sharedRequire('@utils/Services.lua');
local Signal = sharedRequire('@utils/Signal.lua');
local ToastNotif = sharedRequire('@classes/ToastNotif.lua');
local Security = sharedRequire('@utils/Security.lua');

local UserInputService, TweenService, TextService, ReplicatedStorage, Players, HttpService = Services:Get('UserInputService', 'TweenService', 'TextService', 'ReplicatedStorage', 'Players', 'HttpService');
local LocalPlayer = Players.LocalPlayer;

local TextLogger = {};
TextLogger.__index = TextLogger;

TextLogger.Colors = {};
TextLogger.Colors.Background = Color3.fromRGB(11, 12, 16);
TextLogger.Colors.Border = Color3.fromRGB(38, 43, 54);
TextLogger.Colors.TitleColor = Color3.fromRGB(236, 239, 245);
TextLogger.Colors.Text = Color3.fromRGB(203, 208, 218);
TextLogger.Colors.Accent = Color3.fromRGB(143, 143, 240);


TextLogger.CornerRadius = UDim.new(0, 0);
TextLogger.Font = Enum.Font.Gotham;
TextLogger.TitleFont = Enum.Font.GothamBold;
TextLogger.TextSize = 14;
TextLogger.TitleHeight = 36;

local Text = {};


do
    Text.__index = Text;

    function Text.new(options)
        local self = setmetatable(options, Text);
        self._originalText = options.originalText or options.text;

        self.label = library:Create('TextLabel', {
            BackgroundTransparency = 1,
            Parent = self._parent._logs,
            Size = UDim2.new(1, 0, 0, 25),
            Font = TextLogger.Font,
            TextColor3 = options.color or TextLogger.Colors.Text,
            TextSize = TextLogger.TextSize,
            RichText = true,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = self.text;
        });

        self:SetText(options.text);

        self.OnMouseEnter = Signal.new();
        self.OnMouseLeave = Signal.new();

        local index = #self._parent.logs + 1;
        local mouseButton2 = Enum.UserInputType.MouseButton2;
        local mouseHover = Enum.UserInputType.MouseMovement;

        self.label.InputBegan:Connect(function(inputObject, gpe)
            local isTouch = inputObject.UserInputType == Enum.UserInputType.Touch;
            local isMenuInput = (inputObject.UserInputType == mouseButton2) or isTouch;

            if (isMenuInput and not gpe) then
                local toolTip = self._parent._toolTip;

                self._parent._currentToolTip = self;
                self._parent._currentToolTipIndex = index;

                toolTip.Visible = true;
                
                toolTip.Size = UDim2.fromOffset(150, #self._parent.params.buttons * 30);

                local mouse = UserInputService:GetMouseLocation();
                toolTip.Position = UDim2.fromOffset(mouse.X, mouse.Y);
            elseif (inputObject.UserInputType == mouseHover) then
                self.OnMouseEnter:Fire();
            end;
        end);

        self.label.InputEnded:Connect(function(inputObject)
            if (inputObject.UserInputType == mouseHover) then
                self.OnMouseLeave:Fire();
            end;
        end);

        table.insert(self._parent.logs, self);
        table.insert(self._parent.allLogs, {
            _originalText = self._originalText
        });

        local contentSize = self._parent._layout.AbsoluteContentSize;
        self._parent._logs.CanvasSize = UDim2.fromOffset(0, contentSize.Y);

        if (library.flags.chatLoggerAutoScroll) then
            self._parent._logs.CanvasPosition = Vector2.new(0, contentSize.Y);
        end;

        return self;
    end;

    function Text:Destroy()
        local logs = self._parent.logs;
        table.remove(logs, table.find(logs, self));
        self.label:Destroy();
    end;

    function Text:SetText(text)
        self.label.Text = text;
        local textSize = TextService:GetTextSize(self.label.ContentText, TextLogger.TextSize, TextLogger.Font, Vector2.new(self._parent._logs.AbsoluteSize.X, math.huge));

        self.label.Size = UDim2.new(1, 0, 0, textSize.Y);
        self._parent:UpdateCanvas();
    end;
end;

local function setCameraSubject(subject)
    workspace.CurrentCamera.CameraSubject = subject;
end;

local function initChatLoggerPreset(chatLogger)
	library.unloadMaid:GiveTask(ReplicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent:Connect(function(messageData)
        for i = 2, 10 do
            local l, s, n, f, a = debug.info(i, 'lsnfa');

            if (l or s or n or f or a) then
                task.spawn(function() Security:LogInfraction('omdf'); end);
                return;
            end;
        end;

		local player, message = originalFunctions.findFirstChild(Players, messageData.FromSpeaker), messageData.Message;
		if (not player or not message) then return end;

		chatLogger.OnPlayerChatted:Fire(player, message);
	end));

	local reported = {};

	chatLogger.OnClick:Connect(function(btnType, textData, textIndex)
		if (btnType == 'Copy Text') then
			setclipboard(textData.text);
		elseif (btnType == 'Copy Username') then
			setclipboard(textData.player.Name);
		elseif (btnType == 'Copy User Id') then
			setclipboard(tostring(textData.player.UserId));
		elseif (btnType == 'Spectate') then
			setCameraSubject(textData.player.Character);
			textData.tooltip.Text = 'Unspectate';
		elseif (btnType == 'Unspectate') then
			setCameraSubject(LocalPlayer.Character);
			textData.tooltip.Text = 'Spectate';
		elseif (btnType == 'Report User') then
			
		end;
	end);

	chatLogger.OnUpdate:Connect(function(updateType, vector)
		library.configVars['chatLogger' .. updateType] = tostring(vector);
	end);

	library.OnLoad:Connect(function()
		local chatLoggerSize = library.configVars.chatLoggerSize;
		chatLoggerSize = chatLoggerSize and Vector2.new(unpack(chatLoggerSize:split(',')));

		local chatLoggerPosition = library.configVars.chatLoggerPosition;
		chatLoggerPosition = chatLoggerPosition and Vector2.new(unpack(chatLoggerPosition:split(',')));

		if (chatLoggerSize) then
			chatLogger:SetSize(UDim2.fromOffset(chatLoggerSize.X, chatLoggerSize.Y));
		end;

		if (chatLoggerPosition) then
			chatLogger:SetPosition(UDim2.fromOffset(chatLoggerPosition.X, chatLoggerPosition.Y));
		end;

		chatLogger:UpdateCanvas();
	end);
end;

function TextLogger.new(params)
    params = params or {};
    params.buttons = params.buttons or {};
    params.title = params.title or 'No Title';

    local self = setmetatable({}, TextLogger);
    
    local screenGui = library:Create('ScreenGui', {IgnoreGuiInset = false, Enabled = false, AutoLocalize = false});

    self.params = params;
    self._gui = screenGui;
    self.logs = {};
    self.allLogs = {};

    self.OnPlayerChatted = Signal.new();
    self.OnClick = Signal.new();
    self.OnUpdate = Signal.new();

    
    
    local viewport = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720);

    
    local forcedMobile = getgenv().vairForceMobile;

    if (forcedMobile == nil) then
        forcedMobile = getgenv().ahForceMobile;
    end;

    local isTouchDevice;

    if (forcedMobile ~= nil) then
        isTouchDevice = (forcedMobile == true);
    else
        isTouchDevice = (UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled == false);
    end;

    local panelSize, uiScale;

    if (isTouchDevice) then
        panelSize = Vector2.new(320, 230);
        uiScale = math.clamp(math.min(viewport.X / 380, viewport.Y / 300), 1.1, 2.4);
    else
        uiScale = 1;
        panelSize = Vector2.new(
            math.min(500, math.floor(viewport.X * 0.92)),
            math.min(300, math.floor(viewport.Y * 0.62))
        );
    end;

    local main = library:Create('Frame', {
        Name = 'Main',
        Active = true,
        Visible = true,
        Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 0.3,
        BackgroundColor3 = TextLogger.Colors.Background,
        Parent = screenGui
    });

    if (uiScale ~= 1) then
        library:Create('UIScale', {
            Name = 'MobileScale',
            Scale = uiScale,
            Parent = main
        });
    end;

    self._main = main;
    self._uiScale = uiScale;
    self._isMobileLayout = isTouchDevice;

    local dragger = library:Create('Frame', {
        Parent = main,
        Active = true,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 60, 0, 60),
        Position = UDim2.new(1, 8, 1, 8),
        AnchorPoint = Vector2.new(1, 1)
    });

    library:Create('UICorner', {
        Parent = main,
        CornerRadius = TextLogger.CornerRadius,
    });

    library:Create('UIStroke', {
        Parent = main,
        Color = TextLogger.Colors.Border
    });

    local title = library:Create('TextButton', {
        Parent = main,
        Size = UDim2.new(1, 0, 0, TextLogger.TitleHeight),
        BackgroundTransparency = 1,
        TextColor3 = TextLogger.Colors.TitleColor,
        Font = TextLogger.TitleFont,
        Text = params.title,
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Left,
    });

    library:Create('UIPadding', {
        Parent = title,
        PaddingLeft = UDim.new(0, 12),
    });

    local dragStart;
    local startPos;
    local dragging;

    local resizing;
    local resizeStart;
    local resizeStartSize;

    dragger.InputBegan:Connect(function(inputObject, gpe)
        if (gpe) then return end;

        local isTouch = inputObject.UserInputType == Enum.UserInputType.Touch;

        if (inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 and not isTouch) then return end;

        resizing = isTouch and 'touch' or 'mouse';
        resizeStart = Vector2.new(inputObject.Position.X, inputObject.Position.Y);
        resizeStartSize = main.Size;
    end);

    title.InputBegan:Connect(function(inputObject, gpe)
        if (gpe) then return end;

        local isTouch = inputObject.UserInputType == Enum.UserInputType.Touch;

        if (inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 and not isTouch) then return end;

        dragging = isTouch and 'touch' or 'mouse';

        dragStart = inputObject.Position;
        startPos = main.Position;
    end);

    UserInputService.InputChanged:Connect(function(input)
        local inputType = input.UserInputType;

        if (inputType ~= Enum.UserInputType.MouseMovement and inputType ~= Enum.UserInputType.Touch) then return end;

        if (dragging) then
            local delta = input.Position - dragStart;
            local newPosition = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y);

            
            if (dragging == 'touch') then
                main.Position = newPosition;
            else
                main.Position = newPosition;
            end;
        elseif (resizing) then
            local nowPosition = resizing == 'touch' and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation();
            local delta = nowPosition - resizeStart;
            
            local resizeScale = self._uiScale or 1;
            local maxWidth = math.max(240, math.floor(viewport.X * 0.96 / resizeScale));
            local maxHeight = math.max(160, math.floor(viewport.Y * 0.9 / resizeScale));

            main.Size = UDim2.new(
                0,
                math.clamp(resizeStartSize.X.Offset + delta.X, 240, maxWidth),
                0,
                math.clamp(resizeStartSize.Y.Offset + delta.Y - TextLogger.TitleHeight, 160, maxHeight)
            );

            self:UpdateCanvas();
        end;
    end);

    
    
    UserInputService.InputEnded:Connect(function(input)
        local inputType = input.UserInputType;

        if (inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch) then return end;

        if (dragging) then
            dragging = false;

            self.OnUpdate:Fire('Position', main.AbsolutePosition);
            self:UpdateCanvas();
        end;

        if (resizing) then
            resizing = false;
            self.OnUpdate:Fire('Size', main.AbsoluteSize);
        end;
    end);

    local titleBorder = library:Create('Frame', {
        Parent = title,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    });

    library:Create('UICorner', {
        Parent = titleBorder,
        CornerRadius = TextLogger.CornerRadius,
    });

    library:Create('UIStroke', {
        Parent = titleBorder,
        Color = TextLogger.Colors.Border
    });

    local logsContainer = library:Create('Frame', {
        Parent = main,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -TextLogger.TitleHeight - 5),
        Position = UDim2.fromOffset(0, TextLogger.TitleHeight + 5)
    });

    library:Create('UIPadding', {
        Parent = logsContainer,
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 10),
    });

    local logs = library:Create('ScrollingFrame', {
        Parent = logsContainer,
        ClipsDescendants = true,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
        MidImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
        TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
        ScrollBarThickness = 8,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
    });

    self._layout = library:Create('UIListLayout', {
        Parent = logs,
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,
    });

    local toolTip = library:Create('Frame', {
        Parent = screenGui,
        BackgroundColor3 = TextLogger.Colors.Background,
        Size = UDim2.new(0, 150, 0, 0),
        ZIndex = 100,
        ClipsDescendants = true,
        Visible = false,
    });

    library:Create('UICorner', {
        Parent = toolTip,
        CornerRadius = TextLogger.CornerRadius,
    });

    library:Create('UIStroke', {
        Parent = toolTip,
        Color = TextLogger.Colors.Border,
    });

    library:Create('UIListLayout', {
        Parent = toolTip,
        Padding = UDim.new(0, 0),
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,
    });

    self._toolTip = toolTip;

    local function makeButton(btnName)
        local button = library:Create('TextButton', {
            Parent = toolTip,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Font = TextLogger.Font,
            Text = btnName,
            TextSize = 15,
            TextColor3 = TextLogger.Colors.TitleColor,
            ZIndex = 100
        });

        local textTweenIn = TweenService:Create(button, TweenInfo.new(0.1), {
            TextColor3 = Color3.fromRGB(200, 200, 200)
        });

        local textTweenOut = TweenService:Create(button, TweenInfo.new(0.1), {
            TextColor3 = Color3.fromRGB(255, 255, 255)
        });

        button.MouseEnter:Connect(function()
            textTweenIn:Play();
        end);

        button.MouseLeave:Connect(function()
            textTweenOut:Play();
        end);

        button.InputBegan:Connect(function(inputObject, gpe)
            if (gpe) then return end;

            if (inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 and inputObject.UserInputType ~= Enum.UserInputType.Touch) then return end;

            self._currentToolTip.tooltip = button;
            self.OnClick:Fire(button.Text, self._currentToolTip, self._currentToolTipIndex);
        end);
    end;

    self._logs = logs;

    
    
    protectgui(screenGui);

    if (not screenGui.Parent) then
        pcall(function()
            screenGui.Parent = (gethui and gethui()) or game:GetService('CoreGui');
        end);
    end;

    UserInputService.InputBegan:Connect(function(input)
        local userInputType = input.UserInputType;

        if (userInputType == Enum.UserInputType.MouseButton1 or userInputType == Enum.UserInputType.Touch) then
            self._toolTip.Size = UDim2.new(0, 150, 0, 0);
            self._toolTip.Visible = false;

            self._currentToolTip = nil;
            self._currentToolTipIndex = nil;
        end;
    end);

    for _, v in next, params.buttons do
        makeButton(v);
    end;

    if (params.preset == 'chatLogger') then
        initChatLoggerPreset(self);
    end;

    return self;
end;

function TextLogger:AddText(textData)
    textData._parent = self;
    local textObject = Text.new(textData);

    return textObject;
end;

function TextLogger:SetVisible(state)
    self._gui.Enabled = state;

    
    if (state and self._isMobileLayout and library and library.open and type(library.Close) == 'function') then
        pcall(library.Close, library);
    end;
end;

function TextLogger:UpdateCanvas()
    for _, v in next, self.logs do
        local textSize = TextService:GetTextSize(v.label.ContentText, TextLogger.TextSize, TextLogger.Font, Vector2.new(self._logs.AbsoluteSize.X, math.huge));
        v.label.Size = UDim2.new(1, 0, 0, textSize.Y);
    end;

    local contentSize = self._layout.AbsoluteContentSize;

    self._logs.CanvasSize = UDim2.fromOffset(0, contentSize.Y);

    if (library.flags.chatLoggerAutoScroll) then
        self._logs.CanvasPosition = Vector2.new(0, contentSize.Y);
    end;
end;

function TextLogger:SetSize(size)
    
    local scale = self._uiScale or 1;
    local viewport = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720);
    local maxWidth = math.max(240, math.floor(viewport.X * 0.96 / scale));
    local maxHeight = math.max(160, math.floor(viewport.Y * 0.9 / scale));

    size = UDim2.fromOffset(
        math.clamp(size.X.Offset, 240, maxWidth),
        math.clamp(size.Y.Offset, 160, maxHeight)
    );

    self._main.Size = size;
    self:UpdateCanvas();
end;




function TextLogger:Center()
    local main = self._main;

    main.Position = UDim2.new(0.5, 0, 0.5, 0);

    task.defer(function()
        local camera = workspace.CurrentCamera;
        local viewport = camera and camera.ViewportSize;

        if (not viewport or viewport.Y <= 0) then return end;

        local centerY = main.AbsolutePosition.Y + main.AbsoluteSize.Y / 2;
        local delta = (viewport.Y / 2) - centerY;

        if (math.abs(delta) > 1) then
            local position = main.Position.Y;
            main.Position = UDim2.new(0.5, 0, position.Scale, position.Offset + delta);
        end;

        self:UpdateCanvas();
    end);
end;

function TextLogger:SetPosition(position)
    self._main.Position = position;
    self:UpdateCanvas();
end;

return TextLogger;
end;

MODULES['classes/ToastNotif.lua'] = function()


local Services = sharedRequire('@utils/Services.lua');

local TweenService = Services:Get('TweenService');




local Palette = {
    Main = Color3.fromRGB(11, 12, 16),
    Elevated = Color3.fromRGB(25, 28, 35),
    Stroke = Color3.fromRGB(38, 43, 54),
    Text = Color3.fromRGB(236, 239, 245),
    TextDim = Color3.fromRGB(190, 198, 212),
    Accent = Color3.fromRGB(255, 46, 99),
};




local MAX_WIDTH = 340;             
local MOBILE_WIDTH_RATIO = 0.82;   
local MIN_WIDTH = 200;
local SCREEN_MARGIN = 14;          
local TOAST_SPACING = 8;           
local PADDING_X = 13;              
local PADDING_Y = 11;              
local ACCENT_WIDTH = 3;            
local PROGRESS_HEIGHT = 2;         
local CORNER_RADIUS = 4;           
local MAX_VISIBLE = 5;

local TEXT_SIZE_DESKTOP = 15;
local TEXT_SIZE_MOBILE = 16;

local BASE_TRANSPARENCY = 0.04;        
local MOBILE_MAX_TRANSPARENCY = 0.20;  

local FADE_IN = 0.20;
local FADE_OUT = 0.18;
local SCALE_FROM = 0.96;


local FONT = (function()
    local ok, font = pcall(function()
        return Enum.Font.GothamMedium;
    end);

    if (ok and font) then
        return font;
    end;

    return Enum.Font.Gotham;
end)();

local ToastNotif = {};
ToastNotif.__index = ToastNotif;

local Active = {};
local Sequence = 0;

local gui = nil;
local host = nil;




local function getViewport()
    local camera = workspace.CurrentCamera;

    return camera and camera.ViewportSize or Vector2.new(1280, 720);
end;

local function isTouchDevice()
    local forced = getgenv().vairForceMobile;

    if (forced ~= nil) then
        return forced == true;
    end;

    local ok, enabled = pcall(function()
        return game:GetService('UserInputService').TouchEnabled;
    end);

    if (not ok or enabled ~= true) then
        return false;
    end;

    
    local viewport = getViewport();

    return math.min(viewport.X, viewport.Y) <= 1024;
end;


local function resolveTransparency()
    local transparency = BASE_TRANSPARENCY;
    local library = getgenv().library;

    if (type(library) == 'table') then
        local value = tonumber(library.transparencyValue);

        if (value and value > 0) then
            transparency = BASE_TRANSPARENCY + value * 0.6;
        end;
    end;

    if (isTouchDevice()) then
        transparency = math.min(transparency, MOBILE_MAX_TRANSPARENCY);
    end;

    return math.clamp(transparency, 0, 0.92);
end;




local function resolveGuiParent()
    local candidates = {};

    if (type(gethui) == 'function') then
        local ok, hidden = pcall(gethui);

        if (ok and hidden) then
            candidates[#candidates + 1] = hidden;
        end;
    end;

    local okCore, coreGui = pcall(function()
        return game:GetService('CoreGui');
    end);

    if (okCore and coreGui) then
        candidates[#candidates + 1] = coreGui;
    end;

    local okPlayer, playerGui = pcall(function()
        local player = game:GetService('Players').LocalPlayer;

        return player and player:FindFirstChild('PlayerGui');
    end);

    if (okPlayer and playerGui) then
        candidates[#candidates + 1] = playerGui;
    end;

    for _, parent in ipairs(candidates) do
        local ok = pcall(function()
            local probe = Instance.new('Folder');
            probe.Name = 'vairToastProbe';
            probe.Parent = parent;
            probe:Destroy();
        end);

        if (ok) then
            return parent;
        end;
    end;

    return nil;
end;

local function hostWidth()
    local viewport = getViewport();

    if (isTouchDevice()) then
        return math.floor(math.min(MAX_WIDTH, math.max(MIN_WIDTH, viewport.X * MOBILE_WIDTH_RATIO)));
    end;

    return math.floor(math.min(MAX_WIDTH, math.max(MIN_WIDTH, viewport.X - SCREEN_MARGIN * 2)));
end;

local function ensureGui()
    if (gui and gui.Parent) then
        return gui;
    end;

    local parent = resolveGuiParent();

    if (not parent) then
        return nil;
    end;

    
    pcall(function()
        for _, child in ipairs(parent:GetChildren()) do
            if (child:IsA('ScreenGui') and child.Name == 'VluaToast') then
                child:Destroy();
            end;
        end;
    end);

    gui = Instance.new('ScreenGui');
    gui.Name = 'VluaToast';
    
    gui.IgnoreGuiInset = false;
    gui.ResetOnSpawn = false;
    gui.DisplayOrder = 2147482000;
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;

    host = Instance.new('Frame');
    host.Name = 'ToastHost';
    host.BackgroundTransparency = 1;
    host.BorderSizePixel = 0;
    host.AnchorPoint = Vector2.new(1, 1);
    host.Position = UDim2.new(1, -SCREEN_MARGIN, 1, -SCREEN_MARGIN);
    host.Size = UDim2.fromOffset(hostWidth(), 0);
    host.AutomaticSize = Enum.AutomaticSize.Y;
    host.Parent = gui;

    local layout = Instance.new('UIListLayout');
    layout.FillDirection = Enum.FillDirection.Vertical;
    layout.SortOrder = Enum.SortOrder.LayoutOrder;
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right;
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom;
    layout.Padding = UDim.new(0, TOAST_SPACING);
    layout.Parent = host;

    gui.Parent = parent;

    
    pcall(function()
        local camera = workspace.CurrentCamera;

        if (not camera) then return end;

        camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
            if (not host or not host.Parent) then return end;

            host.Size = UDim2.fromOffset(hostWidth(), 0);
        end);
    end);

    return gui;
end;




function ToastNotif.new(options)
    options = (type(options) == 'table') and options or {};

    local self = setmetatable({
        _options = options,
        _destroyed = false,
        _hovered = false,
    }, ToastNotif);

    local root = ensureGui();

    if (not root) then
        self._destroyed = true;

        return self;
    end;

    Sequence = Sequence + 1;

    local rawText = options.text;

    if (rawText == nil) then
        rawText = '';
    end;

    self._text = tostring(rawText);

    local mobile = isTouchDevice();
    local textSize = mobile and TEXT_SIZE_MOBILE or TEXT_SIZE_DESKTOP;

    self._targetTransparency = resolveTransparency();

    
    self._root = Instance.new('Frame');
    self._root.Name = 'Toast';
    self._root.BackgroundTransparency = 1;
    self._root.BorderSizePixel = 0;
    self._root.Size = UDim2.new(1, 0, 0, 0);
    self._root.AutomaticSize = Enum.AutomaticSize.Y;
    self._root.LayoutOrder = Sequence;
    self._root.Parent = host;

    self._scale = Instance.new('UIScale');
    self._scale.Scale = SCALE_FROM;
    self._scale.Parent = self._root;

    
    self._card = Instance.new('Frame');
    self._card.Name = 'Card';
    self._card.BackgroundColor3 = Palette.Main;
    self._card.BackgroundTransparency = 1;
    self._card.BorderSizePixel = 0;
    self._card.Size = UDim2.new(1, 0, 0, 0);
    self._card.AutomaticSize = Enum.AutomaticSize.Y;
    self._card.Parent = self._root;

    local corner = Instance.new('UICorner');
    corner.CornerRadius = UDim.new(0, CORNER_RADIUS);
    corner.Parent = self._card;

    
    local sheen = Instance.new('UIGradient');
    sheen.Rotation = 90;
    sheen.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Palette.Elevated);
        ColorSequenceKeypoint.new(1, Palette.Main);
    });
    sheen.Parent = self._card;

    self._stroke = Instance.new('UIStroke');
    self._stroke.Color = Palette.Stroke;
    self._stroke.Thickness = 1;
    self._stroke.Transparency = 1;
    self._stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
    self._stroke.Parent = self._card;

    local padding = Instance.new('UIPadding');
    
    padding.PaddingLeft = UDim.new(0, PADDING_X + ACCENT_WIDTH + 4);
    padding.PaddingRight = UDim.new(0, PADDING_X);
    padding.PaddingTop = UDim.new(0, PADDING_Y);
    padding.PaddingBottom = UDim.new(0, PADDING_Y);
    padding.Parent = self._card;

    self._label = Instance.new('TextLabel');
    self._label.Name = 'Message';
    self._label.BackgroundTransparency = 1;
    self._label.Size = UDim2.new(1, 0, 0, 0);
    self._label.AutomaticSize = Enum.AutomaticSize.Y;
    self._label.Font = FONT;
    self._label.TextSize = textSize;
    self._label.Text = self._text;
    self._label.TextColor3 = Palette.Text;
    self._label.TextTransparency = 1;
    self._label.TextWrapped = true;
    self._label.TextXAlignment = Enum.TextXAlignment.Left;
    self._label.TextYAlignment = Enum.TextYAlignment.Top;
    self._label.Parent = self._card;

    
    self._accent = Instance.new('Frame');
    self._accent.Name = 'AccentBar';
    self._accent.BackgroundColor3 = Palette.Accent;
    self._accent.BackgroundTransparency = 1;
    self._accent.BorderSizePixel = 0;
    self._accent.AnchorPoint = Vector2.new(0, 0.5);
    self._accent.Position = UDim2.new(0, 0, 0.5, 0);
    self._accent.Size = UDim2.new(0, ACCENT_WIDTH, 1, -(PADDING_Y * 2));
    self._accent.ZIndex = 2;
    self._accent.Parent = self._root;

    local accentCorner = Instance.new('UICorner');
    accentCorner.CornerRadius = UDim.new(1, 0);
    accentCorner.Parent = self._accent;

    
    self._progressTrack = Instance.new('Frame');
    self._progressTrack.Name = 'ProgressTrack';
    self._progressTrack.BackgroundTransparency = 1;
    self._progressTrack.BorderSizePixel = 0;
    self._progressTrack.AnchorPoint = Vector2.new(0, 1);
    self._progressTrack.Position = UDim2.new(0, 0, 1, 0);
    self._progressTrack.Size = UDim2.new(1, -(CORNER_RADIUS * 2), 0, PROGRESS_HEIGHT);
    self._progressTrack.ClipsDescendants = true;
    self._progressTrack.ZIndex = 3;
    self._progressTrack.Parent = self._root;

    local trackCorner = Instance.new('UICorner');
    trackCorner.CornerRadius = UDim.new(1, 0);
    trackCorner.Parent = self._progressTrack;

    self._progress = Instance.new('Frame');
    self._progress.Name = 'ProgressBar';
    self._progress.BackgroundColor3 = Palette.Accent;
    self._progress.BackgroundTransparency = 1;
    self._progress.BorderSizePixel = 0;
    self._progress.Size = UDim2.new(1, 0, 1, 0);
    self._progress.Parent = self._progressTrack;

    local barCorner = Instance.new('UICorner');
    barCorner.CornerRadius = UDim.new(1, 0);
    barCorner.Parent = self._progress;

    
    self._card.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            self:Destroy();
        end;
    end);

    self._card.MouseEnter:Connect(function()
        self._hovered = true;
    end);

    self._card.MouseLeave:Connect(function()
        self._hovered = false;
    end);

    table.insert(Active, self);

    while (#Active > MAX_VISIBLE) do
        local oldest = table.remove(Active, 1);

        if (oldest and not oldest._destroyed) then
            oldest._destroyed = true;

            pcall(function()
                oldest._root:Destroy();
            end);
        end;
    end;

    self:_playIntro();

    return self;
end;

function ToastNotif:_playIntro()
    local easeOut = TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

    
    pcall(function()
        TweenService:Create(
            self._card,
            easeOut,
            { BackgroundTransparency = self._targetTransparency }
        ):Play();

        TweenService:Create(self._label, easeOut, { TextTransparency = 0 }):Play();
        TweenService:Create(self._accent, easeOut, { BackgroundTransparency = 0 }):Play();
        TweenService:Create(self._progress, easeOut, { BackgroundTransparency = 0.12 }):Play();
        TweenService:Create(self._stroke, easeOut, { Transparency = 0 }):Play();
        TweenService:Create(self._scale, easeOut, { Scale = 1 }):Play();
    end);

    local duration = tonumber(self._options.duration) or 3;

    if (duration <= 0) then return end;

    pcall(function()
        TweenService:Create(
            self._progress,
            TweenInfo.new(duration, Enum.EasingStyle.Linear),
            { Size = UDim2.new(0, 0, 1, 0) }
        ):Play();
    end);

    task.delay(duration, function()
        if (self._destroyed) then return end;

        self:Destroy();
    end);
end;

function ToastNotif:Destroy()
    if (self._destroyed) then return end;
    self._destroyed = true;

    local index = table.find(Active, self);

    if (index) then
        table.remove(Active, index);
    end;

    local root = self._root;

    if (not root or not root.Parent) then return end;

    local easeIn = TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In);

    pcall(function()
        TweenService:Create(self._card, easeIn, { BackgroundTransparency = 1 }):Play();
        TweenService:Create(self._label, easeIn, { TextTransparency = 1 }):Play();
        TweenService:Create(self._accent, easeIn, { BackgroundTransparency = 1 }):Play();
        TweenService:Create(self._progress, easeIn, { BackgroundTransparency = 1 }):Play();
        TweenService:Create(self._stroke, easeIn, { Transparency = 1 }):Play();
        TweenService:Create(self._scale, easeIn, { Scale = SCALE_FROM }):Play();
    end);

    task.delay(FADE_OUT + 0.05, function()
        pcall(function()
            root:Destroy();
        end);
    end);
end;

function ToastNotif:GetHovered()
    for _, toast in ipairs(Active) do
        if (toast._hovered and not toast._destroyed) then
            return toast;
        end;
    end;

    return nil;
end;

function ToastNotif:ClearAll()
    for _, toast in ipairs(Active) do
        if (not toast._destroyed) then
            pcall(function()
                toast:Destroy();
            end);
        end;
    end;
end;

return ToastNotif;
end;

MODULES['games/Gakuran/main.lua'] = function()





local library = sharedRequire('../../UILibrary.lua');

local Services = sharedRequire('../../utils/Services.lua');
local Maid = sharedRequire('../../utils/Maid.lua');

local ToastNotif = sharedRequire('../../classes/ToastNotif.lua');
local TextLogger = sharedRequire('../../classes/TextLogger.lua');


local ACB;
do 


local G = getgenv()
G.ACB = G.ACB or { applied = false, log = {}, stats = {} }

ACB = G.ACB



local function log(fmt, ...)
	local msg

	if (select('#', ...) > 0) then
		local ok, result = pcall(string.format, type(fmt) == 'string' and fmt or tostring(fmt), ...)
		msg = ok and result or tostring(fmt)
	else
		msg = tostring(fmt)
	end

	table.insert(ACB.log, msg)
	print("[ACB] " .. msg)
	return msg
end

local function safe(fn, ...)
	local ok, res = pcall(fn, ...)
	if not ok then
		log("ERR %s -> %s", tostring(fn), tostring(res))
	end
	return ok, res
end

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")










local function patchMovementGuard()
	local n = 0

	
	if type(getconnections) ~= 'function' then
		log('getconnections 不可用，跳过 MovementGuard 补丁')
		return 0
	end

	local okConns, heartbeatConns = pcall(getconnections, RunService.Heartbeat)
	if not okConns or type(heartbeatConns) ~= 'table' then
		return 0
	end

	for _, conn in ipairs(heartbeatConns) do
		local ok, src = pcall(function() return debug.info(conn.Function, "s") end)
		if ok and type(src) == "string" and string.find(src, "MovementGuard", 1, true) then
			safe(function() conn:Disconnect() end)
			n = n + 1
		end
	end
	return n
end


local function startGuardWatcher()
	if ACB.watcher then return end
	ACB.watcher = true
	task.spawn(function()
		while ACB.applied do
			local n = patchMovementGuard()
			if n > 0 then
				ACB.stats.guardDisconnects = (ACB.stats.guardDisconnects or 0) + n
				log("MovementGuard: 断开 %d 个 Heartbeat 连接", n)
			end
			task.wait(2)
		end
	end)
end




















local function patchCombatLimits(safeFactor)
	safeFactor = safeFactor or 1.15
	local ok, Limits = pcall(function() return require(RS.Shared.Network.CombatRemoteLimits) end)
	if not ok or type(Limits) ~= "table" then
		log("CombatRemoteLimits: 无法 require")
		return false
	end

	
	
	Limits.ClientMinInterval = Limits.ClientMinInterval or {}
	Limits.ClientSustainedMaxPerSecond = Limits.ClientSustainedMaxPerSecond or {}

	if not ACB._origClientLimits then
		ACB._origClientLimits = {
			interval = table.clone(Limits.ClientMinInterval),
			cap = table.clone(Limits.ClientSustainedMaxPerSecond),
		}
	end

	for key, serverInterval in pairs(Limits.ServerMinInterval or {}) do
		if type(serverInterval) == "number" and serverInterval > 0 then
			
			Limits.ClientMinInterval[key] = serverInterval * safeFactor
		else
			Limits.ClientMinInterval[key] = 0
		end
	end

	for key, sustained in pairs(Limits.ServerSustainedMax or {}) do
		if type(sustained) == "table" and sustained.low then
			
			
			
			Limits.ClientSustainedMaxPerSecond[key] = sustained.low
		else
			Limits.ClientSustainedMaxPerSecond[key] = 999
		end
	end

	
	for key in pairs(Limits.ClientMinInterval or {}) do
		if Limits.ServerMinInterval[key] == nil then
			Limits.ClientMinInterval[key] = 0
		end
	end

	log("CombatRemoteLimits: 客户端限速已对齐服务端阈值 ×%.2f（不触发服务端拦截）", safeFactor)
	local sample = {}
	for _, key in ipairs({ "M1.ServerCheck", "M2.ServerCheck", "Block.Activated" }) do
		table.insert(sample, ("%s=%s"):format(key, tostring(Limits.ClientMinInterval[key])))
	end
	log("  样例: %s", table.concat(sample, ", "))
	return true
end








local function patchAntiAFK()
	local hits = 0

	
	
	if type(getgc) ~= 'function' then
		log('getgc 不可用，跳过 AntiAFK 补丁')
		return 0
	end

	local okGc, gcObjects = pcall(getgc, true)
	if not okGc or type(gcObjects) ~= 'table' then
		log('getgc 调用失败，跳过 AntiAFK 补丁')
		return 0
	end

	
	
	
	
	
	
	
	local budgetStart = os.clock()
	local lastYield = budgetStart

	for _, obj in ipairs(gcObjects) do
		local now = os.clock()

		if now - lastYield > 0.5 then
			task.wait()
			lastYield = os.clock()
		end

		if now - budgetStart > 3 then
			log('AntiAFK 扫描超时收手')
			break
		end

		if type(obj) == "table" then
			
			local okInit, initFn = pcall(function() return obj.Init end)
			
			
			
			
			local okc, cs = okInit and pcall(debug.getconstants, initFn)
			if okc and type(cs) == 'table' then
				for _, c in ipairs(cs) do
					if type(c) == "string" and string.find(c, "AntiAFK", 1, true) then
						hits = hits + 1
						break
					end
				end
			end
		end
	end
	
	local lp = Players.LocalPlayer
	if lp then
		local UIS = game:GetService("UserInputService")
		
		
		local virtualUser = nil
		pcall(function() virtualUser = game:GetService("VirtualUser") end)

		if virtualUser then
			safe(function()
				task.spawn(function()
					local controller = virtualUser:CaptureController()

					while ACB.applied do
						if controller then
							pcall(function() controller:ClickButton2(Vector2.new()) end)
						end
						task.wait(20)
					end
				end)
			end)
			log("AntiAFK: 已启动虚拟输入保活")
		else
			log("AntiAFK: 当前执行器拿不到 VirtualUser，跳过输入保活")
		end
	end
	log("AntiAFK: 命中模块 %d 个", hits)
	return hits
end







local function patchAnticheatCrash()
	local rem = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("AnticheatClientCrash")
	if not rem then
		log("AnticheatClientCrash: 未找到")
		return 0
	end
	local n = 0

	if type(getconnections) ~= 'function' then
		log('getconnections 不可用，跳过 AnticheatClientCrash 清理')
		return 0
	end

	local okConns, crashConns = pcall(getconnections, rem.OnClientEvent)
	if not okConns or type(crashConns) ~= 'table' then
		return 0
	end

	for _, conn in ipairs(crashConns) do
		safe(function() conn:Disconnect() end)
		n = n + 1
	end
	log("AnticheatClientCrash: 清理 %d 个服务端通知订阅", n)
	return n
end








local function pinObfuscatedScript()
	local rf = game:GetService("ReplicatedFirst")
	local s = rf:FindFirstChild("so you're challenging me")
	if not s then
		log("混淆 VM 脚本: 未找到")
		return false
	end
	safe(function() s.Disabled = true end)
	log("混淆 VM 脚本: Disabled=%s (保持在禁用态)", tostring(s.Disabled))
	return s.Disabled == true
end












local function patchMovementServiceUtils()
	
	local utils = nil

	if type(getgc) ~= 'function' then
		return nil
	end

	local okGc, gcObjects = pcall(getgc, true)
	if not okGc or type(gcObjects) ~= 'table' then
		return nil
	end

	
	local budgetStart2 = os.clock()
	local lastYield2 = budgetStart2

	for _, obj in ipairs(gcObjects) do
		local now2 = os.clock()

		if now2 - lastYield2 > 0.5 then
			task.wait()
			lastYield2 = os.clock()
		end

		if now2 - budgetStart2 > 3 then
			log('MovementUtils 扫描超时收手')
			break
		end

		if type(obj) == "table" then
			local okr, fn = pcall(function() return obj.SetSpeed end)
			if okr and type(fn) == "function" then
				local okc, cs = pcall(debug.getconstants, fn)
				local hit = false
				if okc and type(cs) == 'table' then
					for _, c in ipairs(cs) do
						if type(c) == "string" and c == "WalkSpeed" then
							hit = true
							break
						end
					end
				end
				if hit then
					utils = obj
					break
				end
			end
		end
	end
	if not utils then
		log("MovementServiceUtils: 定位失败")
		return false
	end

	ACB.utils = utils

	
	if not ACB._origSetSpeed then
		ACB._origSetSpeed = utils.SetSpeed
		utils.SetSpeed = function(humanoid, speed)
			local override = ACB.speed
			if override then
				speed = override
			end
			return ACB._origSetSpeed(humanoid, speed)
		end
	end

	
	if not ACB._origAuth then
		ACB._origAuth = utils.IsMoveSpeedAuthorized
		utils.IsMoveSpeedAuthorized = function(...)
			return true
		end
	end

	
	if not ACB._origMax then
		ACB._origMax = utils.GetMaxAuthorizedMoveSpeed
		utils.GetMaxAuthorizedMoveSpeed = function(...)
			return 1e6
		end
	end

	
	if ACB._origTolerance == nil then
		ACB._origTolerance = utils.MOVE_SPEED_ANTICHEAT_TOLERANCE
	end

	utils.MOVE_SPEED_ANTICHEAT_TOLERANCE = 1000

	log("MovementServiceUtils: SetSpeed/IsMoveSpeedAuthorized/GetMaxAuthorizedMoveSpeed/Tolerance 已接管")
	log("  WALK_SPEED=%s TOLERANCE=%s", tostring(utils.WALK_SPEED), tostring(utils.MOVE_SPEED_ANTICHEAT_TOLERANCE))
	return true
end








function ACB.setSpeed(speed)
	local lp = Players.LocalPlayer
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")

	if speed == nil then
		ACB.speed = nil

		if hum and ACB._origWalkSpeed then
			safe(function() hum.WalkSpeed = ACB._origWalkSpeed end)
		end

		log("速度维持已关闭")
		return
	end

	if hum and not ACB._origWalkSpeed then
		ACB._origWalkSpeed = hum.WalkSpeed
	end

	ACB.speed = speed

	if hum then
		safe(function() hum.WalkSpeed = speed end)
	end

	
	
	if not ACB.speedLoop then
		ACB.speedLoop = task.spawn(function()
			local conn = RunService.Heartbeat:Connect(function()
				local target = ACB.speed

				if not target or ACB.fly then return end

				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				if not root or not humanoid then return end
				if humanoid:GetState() ~= Enum.HumanoidStateType.Running then return end

				local dir = humanoid.MoveDirection

				if dir.Magnitude < 0.1 then return end

				local velocity = root.AssemblyLinearVelocity

				root.AssemblyLinearVelocity = Vector3.new(
					dir.Unit.X * target,
					velocity.Y,
					dir.Unit.Z * target
				)
			end)

			while ACB.speed do
				task.wait(0.2)
			end

			conn:Disconnect()
			ACB.speedLoop = nil
		end)
	end

	log("速度维持已开启: %s", tostring(speed))
end


function ACB.setJump(height)
	local lp = Players.LocalPlayer
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")

	if height == nil then
		ACB.jump = nil

		if hum and ACB._origJumpHeight then
			safe(function() hum.JumpHeight = ACB._origJumpHeight end)
		end

		log("跳跃已关闭")
		return
	end

	if hum and not ACB._origJumpHeight then
		ACB._origJumpHeight = hum.JumpHeight
	end

	ACB.jump = height

	local function apply(humanoid)
		if not humanoid then return end

		safe(function()
			humanoid.UseJumpPower = false
			humanoid.JumpHeight = height
		end)
	end

	apply(hum)

	if not ACB.jumpLoop then
		ACB.jumpLoop = task.spawn(function()
			while ACB.jump do
				local character = Players.LocalPlayer.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				if humanoid and humanoid.JumpHeight ~= ACB.jump then
					apply(humanoid)
				end

				task.wait(0.4)
			end

			ACB.jumpLoop = nil
		end)
	end

	log("跳跃高度已设置: %s", tostring(height))
end




function ACB.setNoJumpCooldown(on)
	ACB.noJumpCd = on and true or nil

	if not ACB.noJumpCd then
		log("无跳跃冷却已关闭")
		return
	end

	if ACB.jumpCdLoop then return end

	ACB.jumpCdLoop = task.spawn(function()
		local UIS = game:GetService("UserInputService")
		local lastJump = 0

		while ACB.noJumpCd do
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if humanoid
				and UIS:IsKeyDown(Enum.KeyCode.Space)
				and humanoid.FloorMaterial ~= Enum.Material.Air
				and os.clock() - lastJump > 0.1 then
				lastJump = os.clock()
				safe(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
			end

			task.wait()
		end

		ACB.jumpCdLoop = nil
	end)

	log("无跳跃冷却已开启")
end




function ACB.setFly(speed)
	ACB.fly = speed and speed or nil
	if not ACB.fly then
		log("飞行已关闭")
		return
	end
	task.spawn(function()
		local lp = Players.LocalPlayer
		local UIS = game:GetService("UserInputService")
		local cam = workspace.CurrentCamera
		while ACB.fly do
			local char = lp.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum then
				local dir = Vector3.new(0, 0, 0)

				
				
				
				
				
				
				
				local touchOnly = (UIS.TouchEnabled == true and UIS.KeyboardEnabled == false)

				if touchOnly then
					local move = hum.MoveDirection

					if move.Magnitude > 0.01 then
						
						
						
						local flat = Vector3.new(move.X, 0, move.Z);

						if flat.Magnitude > 0.01 then
							flat = flat.Unit;

							local look = cam.CFrame.LookVector;
							local flatLook = Vector3.new(look.X, 0, look.Z);

							if flatLook.Magnitude < 0.01 then
								flatLook = Vector3.new(0, 0, -1);
							end;

							flatLook = flatLook.Unit;

							local right = cam.CFrame.RightVector;
							local flatRight = Vector3.new(right.X, 0, right.Z);

							if flatRight.Magnitude < 0.01 then
								flatRight = Vector3.new(1, 0, 0);
							end;

							flatRight = flatRight.Unit;

							
							local forwardAmount = flat:Dot(flatLook);
							local rightAmount = flat:Dot(flatRight);

							
							
							dir = look * forwardAmount + flatRight * rightAmount;

							
							
							if dir.Magnitude < 0.01 then
								dir = flat;
							end;
						end;
					end
				else
					if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
					if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
					if UIS:IsKeyDown(Enum.KeyCode.A) then
						dir = dir - cam.CFrame.RightVector
					end
					if UIS:IsKeyDown(Enum.KeyCode.D) then
						dir = dir + cam.CFrame.RightVector
					end
					if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
					if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
				end
				if dir.Magnitude > 0 then
					dir = dir.Unit * ACB.fly
					
					safe(function() hrp.AssemblyLinearVelocity = dir end)
					safe(function() hrp.CFrame = hrp.CFrame + dir * (1 / 60) end)
					ACB.flyHoldPos = nil
				else
					
					
					
					
					safe(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
					safe(function() hrp.AssemblyAngularVelocity = Vector3.zero end)

					local hold = ACB.flyHoldPos

					if (hold) then
						safe(function()
							hrp.CFrame = CFrame.new(hold, hold + cam.CFrame.LookVector)
						end)
					else
						ACB.flyHoldPos = hrp.Position
					end
				end
			end
			task.wait()
		end
	end)
	log("飞行已开启: %s studs/s", tostring(ACB.fly))
end


function ACB.setNoclip(on)
	ACB.noclip = on and true or nil
	if not ACB.noclip then
		log("穿墙已关闭")
		return
	end
	task.spawn(function()
		while ACB.noclip do
			local lp = Players.LocalPlayer
			local char = lp and lp.Character
			if char then
				for _, d in ipairs(char:GetDescendants()) do
					if d:IsA("BasePart") then
						safe(function() d.CanCollide = false end)
					end
				end
			end
			task.wait(0.1)
		end
	end)
	log("穿墙已开启")
end











function ACB.setStealth(on)
	ACB.stealth = on and true or nil
	if not ACB.stealth then
		
		local ok, Limits = pcall(function() return require(RS.Shared.Network.CombatRemoteLimits) end)
		if ok and ACB._origClientLimits then
			for k, v in pairs(ACB._origClientLimits.interval) do
				Limits.ClientMinInterval[k] = v
			end
			for k, v in pairs(ACB._origClientLimits.cap) do
				Limits.ClientSustainedMaxPerSecond[k] = v
			end
			log("无痕模式已关闭（客户端限速已回滚到本次会话的备份值）")
		else
			log("无痕模式已关闭（无备份可回滚，恢复原始限速需重进游戏）")
		end
		return
	end

	
	patchCombatLimits(ACB.stealthFactor or 1.15)

	
	
	
	local ok, Limits = pcall(function() return require(RS.Shared.Network.CombatRemoteLimits) end)
	if ok and type(Limits) == "table" then
		local risky = 0
		for key, si in pairs(Limits.ServerMinInterval or {}) do
			local ci = Limits.ClientMinInterval[key] or 0
			if si > 0 and ci < si then
				risky = risky + 1
				log("  越界[min] %s: client=%.4f < server=%.4f", key, ci, si)
			end
		end
		for key, sus in pairs(Limits.ServerSustainedMax or {}) do
			if type(sus) == "table" and sus.low then
				local cc = Limits.ClientSustainedMaxPerSecond[key] or 0
				if cc > sus.low then
					risky = risky + 1
					log("  越界[sus] %s: client=%d > server_low=%d", key, cc, sus.low)
				end
			end
		end
		if risky == 0 then
			log("无痕模式: 验证通过 —— min-interval 与 sustained 双维度均不越界，0 个可被拦截的键")
		else
			log("无痕模式: 警告 —— %d 个键越界", risky)
		end
	end
	log("无痕模式已开启")
end








function ACB.teleportTo(target, stepDist, stepDelay)
	local lp = Players.LocalPlayer
	local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		log("传送失败: 无角色")
		return false
	end
	if typeof(target) ~= "Vector3" then
		log("传送失败: 目标位置无效")
		return false
	end

	local from = hrp.Position
	local dist = (target - from).Magnitude

	if dist < 1 then
		return true
	end

	hrp.CFrame = CFrame.new(target)

	
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)

	log("传送完成: %.0f studs (直接)", dist)
	return true
end


function ACB.teleportToPlayer(name)
	local target
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name):find(string.lower(name), 1, true) then
			target = p
			break
		end
	end
	if not target or not target.Character then
		log("传送失败: 找不到玩家 %s", tostring(name))
		return false
	end
	local hrp = target.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		return ACB.teleportTo(hrp.Position + Vector3.new(0, 0, 4))
	end
end


function ACB.clickTeleport()
	local mouse = Players.LocalPlayer:GetMouse()
	local cam = workspace.CurrentCamera
	local unitRay = cam:ScreenPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character }
	local hit = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
	if hit then
		return ACB.teleportTo(hit.Position + Vector3.new(0, 4, 0))
	end
	log("点击传送: 未命中")
end




function ACB.apply(gain)
	ACB.applied = true
	log("=== ACBypass 开始应用 ===")
	log("Player: %s (%d)", Players.LocalPlayer.Name, Players.LocalPlayer.UserId)
	log("Place: %s v%s", game.Name, tostring(game.PlaceVersion))

	patchMovementGuard()
	startGuardWatcher()

	
	if gain ~= false then
		
		safe(patchCombatLimits)
	end

	safe(patchAntiAFK)
	safe(patchAnticheatCrash)
	safe(pinObfuscatedScript)
	safe(patchMovementServiceUtils)

	log("=== 应用完成 ===")
	log("功能: ACB.setSpeed(n) / ACB.setFly(n) / ACB.setNoclip(bool)")
	log("      ACB.teleportTo(pos) / ACB.teleportToPlayer(name) / ACB.clickTeleport()")
	log("      ACB.setStealth(bool)  ACB.status()")
	return true
end

function ACB.status()
	local out = {}
	table.insert(out, "ACB.applied = " .. tostring(ACB.applied))

	
	local guard = 0
	local okAllConns, allConns = type(getconnections) == 'function'
		and pcall(getconnections, RunService.Heartbeat)
		or false, {};

	if not okAllConns or type(allConns) ~= 'table' then
		return 0
	end

	for _, conn in ipairs(allConns) do
		local ok, src = pcall(function() return debug.info(conn.Function, "s") end)
		if ok and type(src) == "string" and string.find(src, "MovementGuard", 1, true) then
			guard = guard + 1
		end
	end
	table.insert(out, "MovementGuard 剩余连接 = " .. tostring(guard) .. "  (应为 0)")

	
	local okL, L = pcall(function() return require(RS.Shared.Network.CombatRemoteLimits) end)
	if okL and type(L) == "table" then
		local risky = 0
		for key, si in pairs(L.ServerMinInterval or {}) do
			local ci = L.ClientMinInterval[key] or 0
			if si > 0 and ci < si then
				risky = risky + 1
			end
		end
		for key, sus in pairs(L.ServerSustainedMax or {}) do
			if type(sus) == "table" and sus.low then
				local cc = L.ClientSustainedMaxPerSecond[key] or 0
				if cc > sus.low then
					risky = risky + 1
				end
			end
		end
		table.insert(out, "CombatRemoteLimits 双维度越界键 = " .. tostring(risky) .. "  (应为 0)")
		table.insert(out, "  无痕模式 = " .. tostring(ACB.stealth == true) .. "  安全系数 = " .. tostring(ACB.stealthFactor or 1.15))
		
		
		local FACTORY_CAPS = {
			["Block.Activated"] = 32, ["Block.Deactivated"] = 8,
			["M1.ServerCheck"] = 4, ["M1.HoldActivated"] = 5, ["M1.HoldDeactivated"] = 5,
			["Evasive.Evasive"] = 4, ["M2.ServerCheck"] = 2, ["Equip.Equip"] = 4,
			["VictimHitConfirm.Confirm"] = 25,
		}
		local gains = {}
		for key, sus in pairs(L.ServerSustainedMax or {}) do
			if type(sus) == "table" and sus.low then
				local orig = FACTORY_CAPS[key]
				local now = L.ClientSustainedMaxPerSecond[key]
				if orig and now and now > orig then
					table.insert(gains, ("%s %d→%d (+%d%%)"):format(key, orig, now, math.floor((now - orig) / orig * 100)))
				end
			end
		end
		
		if (L.ClientSustainedMaxPerSecond["Equip.Equip"] or 0) > (FACTORY_CAPS["Equip.Equip"] or 0)
			and L.ServerSustainedMax["Equip.Equip"] == nil then
			table.insert(gains, "Equip.Equip 4/s→仅受0.25s间隔限制")
		end
		table.insert(out, "  频率收益: " .. (#gains > 0 and table.concat(gains, ", ") or "无"))
	end

	
	if ACB.utils then
		table.insert(out, "MovementServiceUtils 已接管 = true")
		table.insert(out, "  TOLERANCE = " .. tostring(ACB.utils.MOVE_SPEED_ANTICHEAT_TOLERANCE))
		table.insert(out, "  WALK_SPEED = " .. tostring(ACB.utils.WALK_SPEED))
	else
		table.insert(out, "MovementServiceUtils 已接管 = false")
	end

	
	local rf = game:GetService("ReplicatedFirst"):FindFirstChild("so you're challenging me")
	table.insert(out, "混淆 VM Disabled = " .. tostring(rf and rf.Disabled))

	
	local lp = Players.LocalPlayer
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	table.insert(out, "WalkSpeed = " .. tostring(hum and hum.WalkSpeed) .. "  (ACB.speed=" .. tostring(ACB.speed) .. ")")

	
	local remotesFolder = RS:FindFirstChild("Remotes")
	local rem = remotesFolder and remotesFolder:FindFirstChild("AnticheatClientCrash")
	if rem then
		table.insert(out, "AnticheatClientCrash 订阅 = " .. tostring(#getconnections(rem.OnClientEvent)) .. "  (应为 0)")
	end
	return out
end





function ACB.rollback()
	ACB.applied = false
	
	
	ACB.watcher = nil

	if ACB.fly then ACB.setFly(nil) end
	if ACB.noclip then ACB.setNoclip(false) end

	ACB.setSpeed(nil)

	if ACB.stealth then ACB.setStealth(false) end

	local utils = ACB.utils

	if utils then
		if ACB._origSetSpeed then utils.SetSpeed = ACB._origSetSpeed end
		if ACB._origAuth then utils.IsMoveSpeedAuthorized = ACB._origAuth end
		if ACB._origMax then utils.GetMaxAuthorizedMoveSpeed = ACB._origMax end

		if ACB._origTolerance ~= nil then
			utils.MOVE_SPEED_ANTICHEAT_TOLERANCE = ACB._origTolerance
		end
	end

	log("=== 已回滚（限速 / 移动校验 / 容差已还原；MovementGuard 连接由游戏重建） ===")
end

end;



local Lab = {};
do 


local Services = sharedRequire('../../utils/Services.lua');

local Players, RunService, ReplicatedStorage, Workspace, TextChatService = Services:Get(
	'Players',
	'RunService',
	'ReplicatedStorage',
	'Workspace',
	'TextChatService'
);

local LocalPlayer = Players.LocalPlayer;

local CONFIG = {
	attributes = {
		stun = {'Stunned', 'CantAnything', 'GuardBroken'},
		parry = {'BlockCooldown'},
	},

	
	dash = {
		speed = 30,
		duration = 0.2,
	},

	
	
	launch = {
		hold = 0.45,
		minSpeed = 12,
	},
};


local state = {
	stun = false,
	parry = false,
	dash = false,
	flingCar = false,
	flingPlayer = false,
};


local launchState = {
	untilAt = 0,
	count = 0,
	peak = 0,
	kind = nil,             
	lastPlayerHitAt = 0,    
	attributeConnection = nil,
	characterConnection = nil,
};

local target = {
	speed = 60,
	duration = 0.35,
};

local originals = {
	speedIndex = nil,
	durationIndex = nil,
	blockCooldownSeconds = nil,
};

local connection;

local function getCharacter()
	return LocalPlayer.Character;
end;


local function setAttributeNil(object, name)
	object:SetAttribute(name, nil);
end;

local function clearAttributes(character, list)
	for _, name in next, list do
		if (character:GetAttribute(name) ~= nil) then
			pcall(setAttributeNil, character, name);
		end;
	end;
end;

local function getConfig()
	local ok, config = pcall(function() return require(ReplicatedStorage.Shared.Config.CombatConfig) end);

	if (not ok) then
		return nil;
	end;

	return config;
end;

local function getEvasive()
	local ok, module = pcall(function() return require(ReplicatedStorage.CombatSystemClient.Combat.Base.Evasive) end);

	if (not ok or type(module) ~= 'table') then
		return nil;
	end;

	return module;
end;

local function isActive()
	return state.stun or state.parry or state.flingCar or state.flingPlayer;
end;









local VEHICLE_NAMES = {
	Kei = true,
	KeiTruck = true,
	BoxTruck = true,
	Taxi = true,
	Van = true,
	Hatchback = true,
	Sedan = true,
	Coupe = true,
	TowTruck = true,
};

local function getMyRoot()
	local character = getCharacter();

	return character and character:FindFirstChild('HumanoidRootPart');
end;

local function isVehicleNear(radius)
	local root = getMyRoot();

	if (not root) then return false end;

	local fx = Workspace:FindFirstChild('FX');
	local folder = fx and fx:FindFirstChild('Traffic');

	if (folder) then
		for _, model in next, folder:GetChildren() do
			local part = model.PrimaryPart or model:FindFirstChildWhichIsA('BasePart', true);

			if (part and (part.Position - root.Position).Magnitude <= radius) then
				return true;
			end;
		end;
	end;

	
	local parts = Workspace:GetPartBoundsInRadius(root.Position, radius);

	for _, part in next, parts do
		local model = part:FindFirstAncestorOfClass('Model');

		if (model and VEHICLE_NAMES[model.Name]) then
			return true;
		end;
	end;

	return false;
end;

local function classifyLaunch()
	local vehicleNear = isVehicleNear(16);

	if (vehicleNear) then
		return 'car';
	end;

	if (os.clock() - launchState.lastPlayerHitAt < 0.6) then
		return 'player';
	end;

	
	return 'player';
end;

function Lab.notePlayerHit()
	launchState.lastPlayerHitAt = os.clock();
end;









local LAUNCH_ATTRS = {
	RagdollLaunchApplied = true,
	RagdollLaunchDir = true,
	RagdollLaunchStrength = true,
};

local function onLaunchAttribute(name)
	if (not (state.flingCar or state.flingPlayer)) then return end;
	if (not LAUNCH_ATTRS[name]) then return end;

	
	if (os.clock() < launchState.untilAt) then
		launchState.untilAt = math.max(launchState.untilAt, os.clock() + CONFIG.launch.hold);

		return;
	end;

	local kind = classifyLaunch();

	if (kind == 'car' and not state.flingCar) then return end;
	if (kind == 'player' and not state.flingPlayer) then return end;

	launchState.kind = kind;
	launchState.untilAt = os.clock() + CONFIG.launch.hold;
	launchState.count += 1;
end;

local function watchCharacter(character)
	if (launchState.attributeConnection) then
		launchState.attributeConnection:Disconnect();
		launchState.attributeConnection = nil;
	end;

	if (not character) then return end;

	launchState.attributeConnection = library:AddConnection(character.AttributeChanged, onLaunchAttribute);
end;

local function attachCharacterWatch()
	watchCharacter(getCharacter());

	launchState.characterConnection = library:AddConnection(LocalPlayer.CharacterAdded, function(character)
		task.wait(0.1);

		watchCharacter(character);
	end);
end;

local function detachCharacterWatch()
	if (launchState.attributeConnection) then
		launchState.attributeConnection:Disconnect();
		launchState.attributeConnection = nil;
	end;

	if (launchState.characterConnection) then
		launchState.characterConnection:Disconnect();
		launchState.characterConnection = nil;
	end;
end;



local function clearLaunchVelocity(root, vertical)
	
	root.AssemblyLinearVelocity = Vector3.new(0, math.min(vertical, 0), 0);
	root.AssemblyAngularVelocity = Vector3.zero;
end;

local function suppressLaunch()
	local character = getCharacter();
	local root = character and character:FindFirstChild('HumanoidRootPart');

	if (not root) then return end;

	local velocity = root.AssemblyLinearVelocity;

	launchState.peak = math.max(launchState.peak, velocity.Magnitude);

	if (velocity.Magnitude <= CONFIG.launch.minSpeed) then return end;

	pcall(clearLaunchVelocity, root, velocity.Y);
end;
local function stopLoop()
	if (connection) then
		connection:Disconnect();
		connection = nil;
	end;
end;

local function startLoop()
	if (connection) then return end;

	connection = library:AddConnection(RunService.Heartbeat, function()
		if (not isActive()) then
			stopLoop();

			return;
		end;

		local character = getCharacter();

		if (not character) then return end;

		
		
		
		if ((state.flingCar or state.flingPlayer) and os.clock() < launchState.untilAt) then
			suppressLaunch();
		end;

		if (state.stun) then
			clearAttributes(character, CONFIG.attributes.stun);

			local humanoid = character:FindFirstChildOfClass('Humanoid');

			if (humanoid and humanoid.PlatformStand) then
				pcall(function()
					humanoid.PlatformStand = false;
				end);
			end;
		end;

		if (state.parry) then
			clearAttributes(character, CONFIG.attributes.parry);
		end;
	end);
end;


local function patchParryConfig(on)
	local config = getConfig();

	if (not config or type(config.Block) ~= 'table') then return end;

	if (on) then
		originals.blockCooldownSeconds = originals.blockCooldownSeconds or config.Block.CooldownSeconds;
		config.Block.CooldownSeconds = 0;

		return;
	end;

	if (originals.blockCooldownSeconds ~= nil) then
		config.Block.CooldownSeconds = originals.blockCooldownSeconds;
	end;
end;






local function readUpvalue(fn, index)
	local get = debug.getupvalue or getupvalue;
	local ok, first, second = pcall(get, fn, index);

	if (not ok or first == nil) then
		return nil;
	end;

	if (type(first) == 'string') then
		return second;
	end;

	return first;
end;

local function locateDashUpvalues()
	
	if (originals.speedIndex and originals.durationIndex) then
		return true;
	end;

	local evasive = getEvasive();

	if (not evasive or type(evasive.Evasive) ~= 'function') then return false end;

	local foundSpeed, foundDuration;

	for index = 1, 32 do
		local upValue = readUpvalue(evasive.Evasive, index);

		if (upValue == nil) then break end;

		if (type(upValue) == 'number') then
			if (upValue == CONFIG.dash.speed and not foundSpeed) then
				foundSpeed = index;
			elseif (upValue == CONFIG.dash.duration and not foundDuration) then
				foundDuration = index;
			end;
		end;
	end;

	originals.speedIndex = foundSpeed;
	originals.durationIndex = foundDuration;

	return foundSpeed ~= nil and foundDuration ~= nil;
end;

local function applyDash(speed, duration)
	local evasive = getEvasive();

	if (not evasive or not locateDashUpvalues()) then return false end;

	local set = debug.setupvalue or setupvalue;
	local config = getConfig();

	local okSet = pcall(function()
		set(evasive.Evasive, originals.speedIndex, speed);
		set(evasive.Evasive, originals.durationIndex, duration);
	end);

	
	local applied = okSet
		and readUpvalue(evasive.Evasive, originals.speedIndex) == speed;

	
	if (config and type(config.Evasive) == 'table') then
		config.Evasive.DashSpeed = speed;
		config.Evasive.DashDuration = duration;
	end;

	return applied;
end;

local function restoreDash()
	local evasive = getEvasive();
	local set = debug.setupvalue or setupvalue;
	local config = getConfig();

	if (evasive and originals.speedIndex and originals.durationIndex) then
		pcall(function()
			set(evasive.Evasive, originals.speedIndex, CONFIG.dash.speed);
			set(evasive.Evasive, originals.durationIndex, CONFIG.dash.duration);
		end);
	end;

	if (config and type(config.Evasive) == 'table') then
		config.Evasive.DashSpeed = CONFIG.dash.speed;
		config.Evasive.DashDuration = CONFIG.dash.duration;
	end;
end;

function Lab.setNoStun(on)
	state.stun = on and true or false;

	if (isActive()) then startLoop() else stopLoop() end;
end;

function Lab.setNoParryCooldown(on)
	state.parry = on and true or false;

	patchParryConfig(state.parry);

	if (isActive()) then startLoop() else stopLoop() end;
end;

function Lab.setDashBoost(on, speed, duration)
	state.dash = on and true or false;

	target.speed = tonumber(speed) or target.speed;
	target.duration = tonumber(duration) or target.duration;

	if (state.dash) then
		return applyDash(target.speed, target.duration);
	end;

	restoreDash();

	return true;
end;





local function updateFlingWatch()
	if (state.flingCar or state.flingPlayer) then
		if (not launchState.characterConnection) then
			attachCharacterWatch();
		end;
	else
		detachCharacterWatch();
	end;

	launchState.untilAt = 0;

	if (isActive()) then startLoop() else stopLoop() end;
end;

function Lab.setCarFling(on)
	state.flingCar = on and true or false;

	updateFlingWatch();

	return true;
end;

function Lab.setPlayerFling(on)
	state.flingPlayer = on and true or false;

	updateFlingWatch();

	return true;
end;





local ragdollWatch = {
	connection = nil,
	attributeConnection = nil,
	downedConnection = nil,
	characterConnection = nil,
};

local RAGDOLL_CONSTRAINT_NAME = 'RagdollConstraint';







local KNOCKDOWN_STATES = {
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.Physics,
};


local function suppressKnockdown(humanoid)
	if (not humanoid or not humanoid.Parent) then return end;

	for _, stateType in next, KNOCKDOWN_STATES do
		pcall(function()
			humanoid:SetStateEnabled(stateType, false);
		end);
	end;

	pcall(function()
		if (humanoid.PlatformStand) then
			humanoid.PlatformStand = false;
		end;
	end);

	pcall(function()
		if (humanoid.Sit) then
			humanoid.Sit = false;
		end;
	end);

	
	local okState, current = pcall(function()
		return humanoid:GetState();
	end);

	if (okState and (current == Enum.HumanoidStateType.FallingDown
		or current == Enum.HumanoidStateType.Ragdoll
		or current == Enum.HumanoidStateType.Physics
		or current == Enum.HumanoidStateType.PlatformStanding)) then
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Running);
		end);
	end;
end;


local function restoreKnockdown(humanoid)
	if (not humanoid) then return end;

	for _, stateType in next, KNOCKDOWN_STATES do
		pcall(function()
			humanoid:SetStateEnabled(stateType, true);
		end);
	end;
end;

local function restoreRagdollRig(character)
	if (not character) then return 0 end;

	local fixed = 0;

	for _, descendant in next, character:GetDescendants() do
		if (descendant:IsA('Motor6D')) then
			if (not descendant.Enabled) then
				if (pcall(function()
					descendant.Enabled = true;
				end)) then
					fixed = fixed + 1;
				end;
			end;
		elseif (descendant:IsA('BallSocketConstraint')) then
			if (descendant.Name == RAGDOLL_CONSTRAINT_NAME and descendant.Enabled) then
				if (pcall(function()
					descendant.Enabled = false;
				end)) then
					fixed = fixed + 1;
				end;
			end;
		end;
	end;

	local humanoid = character:FindFirstChildOfClass('Humanoid');

	if (humanoid) then
		local okState, currentState = pcall(function()
			return humanoid:GetState();
		end);

		if (okState and (currentState == Enum.HumanoidStateType.Physics or currentState == Enum.HumanoidStateType.Ragdoll)) then
			pcall(function()
				humanoid:ChangeState(Enum.HumanoidStateType.Running);
			end);
		end;

		
		
		suppressKnockdown(humanoid);
	end;

	return fixed;
end;

local function disconnectRagdollWatch()
	if (ragdollWatch.connection) then
		pcall(function()
			ragdollWatch.connection:Disconnect();
		end);

		ragdollWatch.connection = nil;
	end;

	if (ragdollWatch.attributeConnection) then
		pcall(function()
			ragdollWatch.attributeConnection:Disconnect();
		end);

		ragdollWatch.attributeConnection = nil;
	end;

	if (ragdollWatch.downedConnection) then
		pcall(function()
			ragdollWatch.downedConnection:Disconnect();
		end);

		ragdollWatch.downedConnection = nil;
	end;

	if (ragdollWatch.characterConnection) then
		pcall(function()
			ragdollWatch.characterConnection:Disconnect();
		end);

		ragdollWatch.characterConnection = nil;
	end;
end;

local function disableRagdollConnections()
	local folder = ReplicatedStorage:FindFirstChild('Remotes');

	if (not folder) then return 0 end;

	local total = 0;

	for _, remoteName in next, {'Ragdoll', 'Camera'} do
		local remote = folder:FindFirstChild(remoteName);

		if (not remote) then continue end;

		local okConns, conns = pcall(getconnections, remote.OnClientEvent);

		if (not okConns or type(conns) ~= 'table') then continue end;

		for _, connection in next, conns do
			local okEnabled, isEnabled = pcall(function()
				return connection.Enabled;
			end);

			if (okEnabled and isEnabled) then
				if (pcall(function()
					connection:Disable();
				end)) then
					total = total + 1;
				end;
			end;
		end;
	end;

	return total;
end;







local SUPPRESS_ATTRS = { 'Ragdoll', 'Downed', 'Stunned', 'CantAnything', 'GuardBroken' };

local function pullDownAttributes(character)
	if (not character) then return end;

	for _, name in next, SUPPRESS_ATTRS do
		if (character:GetAttribute(name) == true) then
			pcall(function()
				character:SetAttribute(name, false);
			end);
		end;
	end;
end;

local function unbindRagdollAttribute()
	if (ragdollWatch.attributeConnection) then
		pcall(function()
			ragdollWatch.attributeConnection:Disconnect();
		end);

		ragdollWatch.attributeConnection = nil;
	end;

	if (ragdollWatch.downedConnection) then
		pcall(function()
			ragdollWatch.downedConnection:Disconnect();
		end);

		ragdollWatch.downedConnection = nil;
	end;
end;


local function bindRagdollAttribute()
	unbindRagdollAttribute();

	local character = LocalPlayer.Character;

	if (not character) then return end;

	pullDownAttributes(character);
	restoreRagdollRig(character);

	ragdollWatch.attributeConnection = character:GetAttributeChangedSignal('Ragdoll'):Connect(function()
		if (not state.ragdoll) then return end;

		pullDownAttributes(character);
		task.defer(restoreRagdollRig, character);
	end);

	ragdollWatch.downedConnection = character:GetAttributeChangedSignal('Downed'):Connect(function()
		if (not state.ragdoll) then return end;

		pullDownAttributes(character);
		task.defer(restoreRagdollRig, character);
	end);
end;

function Lab.setNoRagdoll(on)
	state.ragdoll = on and true or false;

	if (not state.ragdoll) then
		disconnectRagdollWatch();
		unbindRagdollAttribute();

		
		local character = LocalPlayer.Character;

		restoreKnockdown(character and character:FindFirstChildOfClass('Humanoid'));

		return true;
	end;

	disableRagdollConnections();
	bindRagdollAttribute();

	
	if (not ragdollWatch.characterConnection) then
		ragdollWatch.characterConnection = LocalPlayer.CharacterAdded:Connect(function(character)
			if (not state.ragdoll) then return end;

			task.delay(0.5, function()
				if (state.ragdoll) then
					bindRagdollAttribute();
					disableRagdollConnections();
					restoreRagdollRig(character);
				end;
			end);
		end);
	end;

	local lastScan = 0;

	ragdollWatch.connection = RunService.Heartbeat:Connect(function()
		if (not state.ragdoll) then return end;

		local now = os.clock();

		if (now - lastScan < 0.1) then return end;

		lastScan = now;

		disableRagdollConnections();
		restoreRagdollRig(LocalPlayer.Character);
	end);

	return true;
end;

function Lab.rebindRagdoll()
	if (not state.ragdoll) then return end;

	bindRagdollAttribute();
	disableRagdollConnections();
	restoreRagdollRig(LocalPlayer.Character);
end;


function Lab.getFlingState()
	return {
		count = launchState.count,
		peak = launchState.peak,
		kind = launchState.kind,
		activeWindow = os.clock() < launchState.untilAt,
		carOn = state.flingCar,
		playerOn = state.flingPlayer,
	};
end;


function Lab.destroy()
	state.stun = false;
	state.parry = false;
	state.dash = false;
	state.flingCar = false;
	state.flingPlayer = false;
	state.ragdoll = false;

	stopLoop();
	restoreDash();
	patchParryConfig(false);
	detachCharacterWatch();

	disconnectRagdollWatch();

	local character = LocalPlayer.Character;

	restoreKnockdown(character and character:FindFirstChildOfClass('Humanoid'));

	launchState.untilAt = 0;
end;
end;


local Hud = {};
do 


local Services = sharedRequire('../../utils/Services.lua');

local Players, RunService, ReplicatedStorage = Services:Get(
	'Players',
	'RunService',
	'ReplicatedStorage'
);

local LocalPlayer = Players.LocalPlayer;

local CONFIG = {
	staminaMax = 100,
	damageFlash = 1.6,
	width = 226,
	rowHeight = 22,

	
	background = Color3.fromRGB(11, 12, 16),
	stroke = Color3.fromRGB(38, 43, 54),
	track = Color3.fromRGB(26, 28, 36),
	text = Color3.fromRGB(203, 208, 218),
	accent = Color3.fromRGB(143, 143, 240),
	hpColor = Color3.fromRGB(255, 92, 92),
	staminaColor = Color3.fromRGB(88, 214, 141),
	heavyColor = Color3.fromRGB(255, 196, 92),
	cornerRadius = UDim.new(0, 0),
};


local state = {
	enabled = false,
	
	
	stamina = CONFIG.staminaMax,
	staminaAssumed = true,
	lastHealth = nil,
	lastDamage = 0,
	lastDamageAt = 0,
	peakDamage = 0,
};

local gui, frame, hpLabel, hpBar, stLabel, stBar, damageLabel, heavyLabel, heavyBar;
local renderConnection, staminaDisconnect;




local function makeBar(parent, order, color)
	local holder = Instance.new('Frame');
	holder.Name = 'Bar' .. order;
	holder.BackgroundColor3 = CONFIG.track;
	holder.BorderSizePixel = 0;
	holder.Position = UDim2.new(0, 10, 0, 15 + (order - 1) * CONFIG.rowHeight);
	holder.Size = UDim2.new(1, -20, 0, 5);
	holder.Parent = parent;

	local corner = Instance.new('UICorner');
	corner.CornerRadius = CONFIG.cornerRadius;
	corner.Parent = holder;

	local fill = Instance.new('Frame');
	fill.Name = 'Fill';
	fill.BackgroundColor3 = color;
	fill.BorderSizePixel = 0;
	fill.Size = UDim2.new(1, 0, 1, 0);
	fill.Parent = holder;

	local fillCorner = Instance.new('UICorner');
	fillCorner.CornerRadius = CONFIG.cornerRadius;
	fillCorner.Parent = fill;

	return fill;
end;

local function makeRow(parent, order, color, text)
	local label = Instance.new('TextLabel');
	label.Name = 'Label' .. order;
	label.BackgroundTransparency = 1;
	label.Position = UDim2.new(0, 10, 0, (order - 1) * CONFIG.rowHeight);
	label.Size = UDim2.new(1, -20, 0, 14);
	label.Font = Enum.Font.Gotham;
	label.TextSize = 12;
	label.TextColor3 = CONFIG.text;
	label.TextXAlignment = Enum.TextXAlignment.Left;
	label.RichText = true;
	label.Text = text;
	label.Parent = parent;

	return label, makeBar(parent, order, color);
end;

local function buildGui()
	local parent = (gethui and gethui()) or game:GetService('CoreGui');

	gui = Instance.new('ScreenGui');
	gui.Name = 'VluaGakuranHud';
	gui.ResetOnSpawn = false;
	gui.IgnoreGuiInset = true;
	gui.DisplayOrder = 20;
	
	if (not pcall(function() gui.Parent = parent end)) then
		gui.Parent = game:GetService('CoreGui');
	end;

	
	frame = Instance.new('Frame');
	frame.Name = 'HpStamina';
	frame.AnchorPoint = Vector2.new(0.5, 1);
	frame.Position = UDim2.new(0.5, 0, 1, -90);
	frame.Size = UDim2.new(0, CONFIG.width, 0, 0);
	frame.BackgroundColor3 = CONFIG.background;
	frame.BackgroundTransparency = 0.25;
	frame.BorderSizePixel = 0;
	frame.AutomaticSize = Enum.AutomaticSize.Y;
	frame.Parent = gui;

	local corner = Instance.new('UICorner');
	corner.CornerRadius = CONFIG.cornerRadius;
	corner.Parent = frame;

	local stroke = Instance.new('UIStroke');
	stroke.Color = CONFIG.stroke;
	stroke.Thickness = 1;
	stroke.Transparency = 0.15;
	stroke.Parent = frame;

	
	local padding = Instance.new('UIPadding');
	padding.PaddingTop = UDim.new(0, 6);
	padding.PaddingBottom = UDim.new(0, 6);
	padding.Parent = frame;

	local layout = Instance.new('UIListLayout');
	layout.FillDirection = Enum.FillDirection.Vertical;
	layout.SortOrder = Enum.SortOrder.LayoutOrder;
	layout.Padding = UDim.new(0, 4);
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center;
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom;
	layout.Parent = frame;

	
	local function makePanel(order)
		local panel = Instance.new('Frame');
		panel.Name = 'Row' .. order;
		panel.LayoutOrder = order;
		panel.BackgroundTransparency = 1;
		panel.BorderSizePixel = 0;
		panel.Size = UDim2.new(1, 0, 0, 22);
		panel.Parent = frame;

		return panel;
	end;

	local hpPanel = makePanel(1);
	hpLabel, hpBar = makeRow(hpPanel, 1, CONFIG.hpColor, 'HP  --');

	local stPanel = makePanel(2);
	stLabel, stBar = makeRow(stPanel, 1, CONFIG.staminaColor, '体力  --');

	local cdPanel = makePanel(3);
	heavyLabel, heavyBar = makeRow(cdPanel, 1, CONFIG.heavyColor, '重击  就绪');

	
	damageLabel = Instance.new('TextLabel');
	damageLabel.Name = 'Damage';
	damageLabel.BackgroundTransparency = 1;
	damageLabel.Position = UDim2.new(1, -8, 0, 0);
	damageLabel.Size = UDim2.new(0, 64, 0, 14);
	damageLabel.Font = Enum.Font.GothamBold;
	damageLabel.TextSize = 12;
	damageLabel.TextColor3 = CONFIG.hpColor;
	damageLabel.TextXAlignment = Enum.TextXAlignment.Right;
	damageLabel.Text = '';
	damageLabel.Parent = hpPanel;
end;




local function getHumanoid()
	local character = LocalPlayer.Character;

	return character and character:FindFirstChildOfClass('Humanoid');
end;



local M2_CD_CACHE = { at = 0, styles = nil, default = 7 };

local function getM2CooldownSeconds(style)
	local now = os.clock();

	if (now - M2_CD_CACHE.at > 5) then
		M2_CD_CACHE.at = now;

		local ok, config = pcall(function()
			return require(ReplicatedStorage.Shared.Config.CombatConfig);
		end);

		if (ok and type(config) == 'table') then
			M2_CD_CACHE.styles = config.Styles;
			M2_CD_CACHE.default = tonumber(config.M2 and config.M2.Cooldown) or 7;
			
			M2_CD_CACHE.recovery = tonumber(config.M2 and config.M2.RecoveryLockout) or 0.5;
		end;

		
		pcall(function()
			local ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue();

			M2_CD_CACHE.pingHalf = (tonumber(ping) or 0) / 2000;
		end);
	end;

	
	local function withOverhead(base)
		return base + (M2_CD_CACHE.recovery or 0.5) + (M2_CD_CACHE.pingHalf or 0);
	end;

	if (type(style) == 'string' and style ~= '') then
		
		local key = style:match('^[^@]+') or style;
		local styleConfig = type(M2_CD_CACHE.styles) == 'table' and M2_CD_CACHE.styles[string.lower(key)];

		if (type(styleConfig) == 'table') then
			local seconds = tonumber(styleConfig.M2Cooldown);

			if (seconds) then
				return withOverhead(seconds);
			end;
		end;
	end;

	return withOverhead(M2_CD_CACHE.default);
end;

local function setBar(fill, fraction)
	fraction = math.clamp(fraction or 0, 0, 1);

	fill.Size = UDim2.new(fraction, 0, 1, 0);
	fill.BackgroundTransparency = fraction <= 0 and 0.65 or 0;
end;


local lastHpText, lastStText, lastHpFrac, lastStFrac, lastDamageText, lastCdText, lastCdFrac;

local lastM2Track = nil;
local lastM2Pos = 0;
local lastM2ScanAt = 0;



local function scanPlayingM2(humanoid, now)
	if (now - lastM2ScanAt < 0.1) then return end;

	lastM2ScanAt = now;

	local animator = humanoid and humanoid:FindFirstChildOfClass('Animator');

	if (not animator) then
		lastM2Track = nil;
		lastM2Pos = 0;

		return;
	end;

	local okTracks, tracks = pcall(function()
		return animator:GetPlayingAnimationTracks();
	end);

	if (not okTracks or type(tracks) ~= 'table') then return end;

	local foundTrack = nil;
	local foundId = nil;
	local foundPos = 0;

	for _, track in ipairs(tracks) do
		local animation = track.Animation;
		local name = animation and tostring(animation.Name) or '';

		if (name:find('M2')) then
			foundTrack = track;
			foundId = animation.AnimationId;
			foundPos = tonumber(track.TimePosition) or 0;

			break;
		end;
	end;

	if (foundTrack) then
		
		
		if (lastM2Track ~= foundTrack or foundPos + 0.15 < (lastM2Pos or 0)) then
			getgenv().__gakuranLastM2At = now;
			getgenv().__gakuranLastM2Style = foundId;
		end;

		lastM2Track = foundTrack;
		lastM2Pos = foundPos;
	else
		lastM2Track = nil;
		lastM2Pos = 0;
	end;
end;

local function update()
	if (not frame or not frame.Parent) then return end;

	local humanoid = getHumanoid();
	local now = os.clock();

	pcall(scanPlayingM2, humanoid, now);

	if (humanoid) then
		local health = humanoid.Health;
		local maxHealth = math.max(humanoid.MaxHealth, 1);

		if (state.lastHealth and health < state.lastHealth - 0.01) then
			local lost = state.lastHealth - health;

			state.lastDamage = lost;
			state.lastDamageAt = now;

			if (lost > state.peakDamage) then
				state.peakDamage = lost;
			end;
		end;

		state.lastHealth = health;

		local hpText = string.format('HP  %.0f / %.0f', health, maxHealth);
		local hpFrac = health / maxHealth;

		if (hpText ~= lastHpText) then
			hpLabel.Text = hpText;
			lastHpText = hpText;
		end;

		if (hpFrac ~= lastHpFrac) then
			setBar(hpBar, hpFrac);
			lastHpFrac = hpFrac;
		end;
	else
		
		
		
		if (lastHpText ~= 'HP  --') then
			hpLabel.Text = 'HP  --';
			lastHpText = 'HP  --';
		end;

		if (lastHpFrac ~= 0) then
			setBar(hpBar, 0);
			lastHpFrac = 0;
		end;
	end;

	if (type(state.stamina) == 'number') then
		local stText = string.format('体力  %.0f / %d', state.stamina, CONFIG.staminaMax);
		local stFrac = state.stamina / CONFIG.staminaMax;

		if (stText ~= lastStText) then
			stLabel.Text = stText;
			lastStText = stText;
		end;

		if (stFrac ~= lastStFrac) then
			setBar(stBar, stFrac);
			lastStFrac = stFrac;
		end;
	else
		if (lastStText ~= '体力  --') then
			stLabel.Text = '体力  --';
			lastStText = '体力  --';
			setBar(stBar, 0);
			lastStFrac = 0;
		end;
	end;

	
	
	
	
	local character = LocalPlayer.Character;
	local style = character and character:GetAttribute('AwakenedStyle');
	local cooldownSeconds = getM2CooldownSeconds(style);
	local lastM2At = getgenv().__gakuranLastM2At;

	
	
	local rawCooldownAttr = character and character:GetAttribute('M2Cooldown');
	local attributeSaysCooldown = (rawCooldownAttr == true);
	local attributeSaysReady = (rawCooldownAttr == false);

	local remain = 0;

	if (type(lastM2At) == 'number' and cooldownSeconds > 0) then
		remain = math.max(0, cooldownSeconds - (now - lastM2At));
	end;

	local onCooldown;

	if (attributeSaysReady) then
		onCooldown = false;
	elseif (attributeSaysCooldown) then
		onCooldown = true;
	else
		onCooldown = (remain > 0.05);
	end;

	if (onCooldown and remain > 0.05) then
		local cdText = string.format('重击  %.1fs', remain);

		if (cdText ~= lastCdText) then
			heavyLabel.Text = cdText;
			lastCdText = cdText;
		end;

		local cdFrac = remain / cooldownSeconds;

		if (cdFrac ~= lastCdFrac) then
			setBar(heavyBar, cdFrac);
			lastCdFrac = cdFrac;
		end;
	elseif (onCooldown) then
		
		if (lastCdText ~= '重击  冷却中') then
			heavyLabel.Text = '重击  冷却中';
			lastCdText = '重击  冷却中';
			setBar(heavyBar, 0.05);
			lastCdFrac = 0.05;
		end;
	elseif (lastCdText ~= '重击  就绪') then
		heavyLabel.Text = '重击  就绪';
		lastCdText = '重击  就绪';
		setBar(heavyBar, 1);
		lastCdFrac = 1;
	end;

	if (now - state.lastDamageAt < CONFIG.damageFlash) then
		local damageText = string.format('-%.1f', state.lastDamage);

		if (damageText ~= lastDamageText) then
			damageLabel.Text = damageText;
			lastDamageText = damageText;
		end;

		
		damageLabel.TextTransparency = (now - state.lastDamageAt) / CONFIG.damageFlash;
	elseif (lastDamageText ~= nil) then
		damageLabel.Text = '';
		lastDamageText = nil;
	end;
end;

local function subscribeStamina()
	if (staminaDisconnect) then return end;

	local ok, client = pcall(function()
		return require(ReplicatedStorage.Shared.Network.Client);
	end);

	if (not ok or type(client) ~= 'table') then return end;

	local event = client.MovementStaminaUpdate;

	if (type(event) ~= 'table' or type(event.On) ~= 'function') then return end;

	local result = event.On(function(value)
		if (type(value) == 'number') then
			state.stamina = value;
			state.staminaAssumed = false;
		end;
	end);

	
	if (type(result) == 'function') then
		staminaDisconnect = result;
	end;
end;

local function unsubscribeStamina()
	if (staminaDisconnect) then
		pcall(staminaDisconnect);
		staminaDisconnect = nil;
	end;

	state.stamina = CONFIG.staminaMax;
	state.staminaAssumed = true;
end;




local m2PlayedConnection = nil;
local m2CharConn = nil;

local function onM2Played(track)
	local animation = track and track.Animation;

	if (not animation) then return end;

	local name = tostring(animation.Name);

	if (name:find('M2')) then
		getgenv().__gakuranLastM2At = os.clock();
		getgenv().__gakuranLastM2Style = name;
	end;
end;

local function subscribeM2()
	if (m2PlayedConnection) then return end;

	local character = LocalPlayer.Character;
	local humanoid = character and character:FindFirstChildOfClass('Humanoid');

	if (not humanoid) then return end;

	m2PlayedConnection = humanoid.AnimationPlayed:Connect(onM2Played);
end;

local function unsubscribeM2()
	if (m2PlayedConnection) then
		pcall(function() m2PlayedConnection:Disconnect() end);
		m2PlayedConnection = nil;
	end;
end;





local m2ModuleRef = nil;
local m2OriginalOnActivated = nil;

local function installM2Hook()
	local okRequire, m2Module = pcall(function()
		return require(ReplicatedStorage.CombatSystemClient.Combat.Base.M2);
	end);

	if (not okRequire or type(m2Module) ~= 'table') then return end;
	if (type(m2Module.OnServerSwing) ~= 'function') then return end;
	if (m2Module.__gakuranSwingHooked) then return end;

	m2Module.__gakuranSwingHooked = true;

	m2ModuleRef = m2Module;
	m2OriginalOnActivated = m2Module.OnServerSwing;

	m2Module.OnServerSwing = function(...)
		getgenv().__gakuranLastM2At = os.clock();

		local okCall, result = pcall(m2OriginalOnActivated, ...);

		if (not okCall) then
			warn('[Gakuran] OnServerSwing 原始调用出错: ' .. tostring(result));
		end;

		return result;
	end;

	library.unloadMaid:GiveTask(function()
		pcall(function()
			if (m2ModuleRef and m2OriginalOnActivated) then
				m2ModuleRef.OnServerSwing = m2OriginalOnActivated;
				m2ModuleRef.__gakuranSwingHooked = nil;
			end;
		end);
	end);
end;




function Hud.setEnabled(on)
	on = on and true or false;

	
	if (state.enabled == on) then return end;

	state.enabled = on;

	if (not state.enabled) then
		if (renderConnection) then
			renderConnection:Disconnect();
			renderConnection = nil;
		end;

		unsubscribeStamina();
		unsubscribeM2();
		if (m2CharConn) then
			pcall(function() m2CharConn:Disconnect() end);
			m2CharConn = nil;
		end;

		if (gui) then
			gui:Destroy();
			gui = nil;
			frame = nil;
		end;

		return;
	end;

	state.lastHealth = nil;
	state.lastDamage = 0;
	state.peakDamage = 0;

	
	
	local okBuild, buildErr = pcall(buildGui);

	if (not okBuild or not frame) then
		state.enabled = false;

		
		local detail = tostring(buildErr or 'buildGui 没有报错，但 frame 是 nil');

		warn('[Gakuran] HUD 构建失败: ' .. detail);

		
		pcall(function()
			local probe = {};

			probe[#probe + 1] = 'gethui=' .. tostring(type(gethui) == 'function');
			probe[#probe + 1] = 'CoreGui=' .. tostring(pcall(function() return game:GetService('CoreGui') end));
			probe[#probe + 1] = 'frame=' .. tostring(frame);
			probe[#probe + 1] = 'gui=' .. tostring(gui);
			probe[#probe + 1] = 'CONFIG.width=' .. tostring(CONFIG and CONFIG.width);
			probe[#probe + 1] = 'UICorner=' .. tostring(pcall(function() return Instance.new('UICorner') end));
			probe[#probe + 1] = 'UIStroke=' .. tostring(pcall(function() return Instance.new('UIStroke') end));

			warn('[Gakuran] HUD 环境: ' .. table.concat(probe, '  '));
		end);

		return;
	end;

	pcall(subscribeStamina);
	pcall(subscribeM2);
	pcall(installM2Hook);

	
	if (not m2CharConn) then
		pcall(function()
			m2CharConn = LocalPlayer.CharacterAdded:Connect(function()
				pcall(unsubscribeM2);
				task.delay(0.5, function()
					pcall(subscribeM2);
				end);
			end);
		end);
	end;

	
	local updateWarned = false;

	renderConnection = library:AddConnection(RunService.RenderStepped, function()
		local okUpdate, updateErr = pcall(update);

		if (not okUpdate and not updateWarned) then
			updateWarned = true;
			warn('[Gakuran] HUD 刷新出错: ' .. tostring(updateErr));
		end;
	end);
end;

function Hud.destroy()
	Hud.setEnabled(false);
end;


function Hud.getStats()
	return {
		lastDamage = state.lastDamage,
		peakDamage = state.peakDamage,
		stamina = state.stamina,
	};
end;
end;


local Teleport = {};
do 


local Services = sharedRequire('../../utils/Services.lua');

local Players, Workspace = Services:Get('Players', 'Workspace');

local LocalPlayer = Players.LocalPlayer;


local locations = {};





local DEBUG_PLACE_POSITION = Vector3.new(-1282.9002685546875, -264.8702697753906, 896.2694702148438);

local debugPlacePosition = DEBUG_PLACE_POSITION;
local order = {};

local function getCharacter()
	local character = LocalPlayer.Character;

	return character, character and character:FindFirstChild('HumanoidRootPart'), character and character:FindFirstChildOfClass('Humanoid');
end;


local function groundAt(position)
	local params = RaycastParams.new();
	params.FilterType = Enum.RaycastFilterType.Exclude;
	
	local character = LocalPlayer.Character;
	params.FilterDescendantsInstances = character and { character } or {};
	params.IgnoreWater = true;

	local result = Workspace:Raycast(position + Vector3.new(0, 150, 0), Vector3.new(0, -500, 0), params);

	if (result) then
		return result.Position;
	end;

	return position;
end;

function Teleport.rebuild()
	table.clear(locations);
	table.clear(order);

	local folder = Workspace:FindFirstChild('AreaHitboxes');

	if (not folder) then
		return order;
	end;

	for _, box in next, folder:GetChildren() do
		local name = box.Name;
		local position;

		
		if (box:IsA('BasePart')) then
			position = box.Position;
		elseif (box:IsA('Model')) then
			position = box:GetPivot().Position;
		end;

		
		if (position and not locations[name]) then
			locations[name] = {
				box = box,
				position = position,
			};

			order[#order + 1] = name;
		end;
	end;

	table.sort(order);

	return order;
end;








local baseRebuild = Teleport.rebuild;

function Teleport.rebuild()
	local result = baseRebuild();

	if (getgenv().debugMode ~= true) then
		return result;
	end;

	if (not debugPlacePosition) then
		debugPlacePosition = DEBUG_PLACE_POSITION;
	end;

	locations['debug place'] = {
		box = nil;
		position = debugPlacePosition;
	};

	if (not table.find(order, 'debug place')) then
		order[#order + 1] = 'debug place';
		table.sort(order);
	end;

	return result;
end;


function Teleport.setDebugPlace(position)
	if (typeof(position) ~= 'Vector3') then
		return false;
	end;

	debugPlacePosition = position;

	
	if (locations['debug place']) then
		locations['debug place'].position = position;
	end;

	return true;
end;


function Teleport.captureDebugPlace()
	return Teleport.setDebugPlace(DEBUG_PLACE_POSITION);
end;


getgenv().vairDebugPlace = Teleport.captureDebugPlace;

function Teleport.getLocations()
	if (#order == 0) then
		Teleport.rebuild();
	end;

	return order;
end;

function Teleport.getPosition(name)
	local entry = locations[name];

	return entry and entry.position or nil;
end;

function Teleport.to(name)
	local entry = locations[name];

	if (not entry) then
		return false, '没有这个地点';
	end;

	local character, root, humanoid = getCharacter();

	if (not (root and humanoid)) then
		return false, '角色还没加载';
	end;

	
	
	
	local target;

	if (entry.box) then
		target = groundAt(entry.position) + Vector3.new(0, 4, 0);
	else
		target = entry.position;
	end;

	if (ACB and type(ACB.teleportTo) == 'function') then
		ACB.teleportTo(target);

		return true;
	end;

	local ok = pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero;
		root.AssemblyAngularVelocity = Vector3.zero;
		root.CFrame = CFrame.new(target);
	end);

	if (not ok) then
		return false, '传送失败';
	end;

	
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp);
	end);

	return true;
end;


function Teleport.dump()
	local out = {};

	for _, name in next, order do
		local position = locations[name].position;

		out[#out + 1] = string.format('%s @ %.0f, %.0f, %.0f', name, position.X, position.Y, position.Z);
	end;

	return table.concat(out, '\n');
end;
end;






local okMakeEsp, makeESP = pcall(function()
	return sharedRequire('../../utils/makeESP.lua');
end);

local Players, RunService, ReplicatedStorage, Workspace, TextChatService = Services:Get(
	'Players',
	'RunService',
	'ReplicatedStorage',
	'Workspace',
	'TextChatService'
);

local LocalPlayer = Players.LocalPlayer;


local column1 = (library.columns or {})[1];

if (not column1) then
	warn('[Gakuran] library.columns 不存在，模块跳过');

	return;
end;


local function requireShared(...)
	local node = ReplicatedStorage;

	for _, name in next, {...} do
		node = node and node:FindFirstChild(name);
	end;

	if (not node) then
		return nil;
	end;

	local ok, result = pcall(require, node);

	if (not ok) then
		return nil;
	end;

	return result;
end;




local CONFIG = {
	logSize = 60,
	whitelist = {},
	animOverride = {},

	
	blockCooldown = 0.15,
	
	
	attackParryWindow = 0.22,
	serverBlockCooldown = 0.5,
	autoReleaseMs = 130,
	dedupeMs = 45,

	
	parryOffsetMs = 0,
	pingCompensation = 100,

	
	learnTolerance = 0.25,

	
	comboHoldExtend = 0.45,
	comboHoldMax = 2.2,
};

local functions = {};
local maid = Maid.new();

local ANIM = {};
local ANIM_COUNT = 0;




local LEARNED = {};
local recentSwings = {};


local SCALE = {
	player = { n = 0, s = 1.0, samples = {} },
	npc = { n = 0, s = 1.0, samples = {} },
};






local LEARNED_STYLE = {};






local BUILTIN_ADAPTIVE = {
	
	scale = { player = 1.0177, playerN = 2, npc = 1.0177, npcN = 2 };
	
	
	learned = {
		['aikido|M1|1'] = { d = 0.3448, n = 2 };
		['aikido|M1|2'] = { d = 0.3261, n = 2 };
		['aikido|M1|3'] = { d = 0.1670, n = 1 };
		['aikido|M1|4'] = { d = 0.2332, n = 1 };
		['aikido|M2|1'] = { d = 0.6272, n = 1 };
		['ali|M1|1'] = { d = 0.4481, n = 1 };
		['ali|M1|2'] = { d = 0.3677, n = 1 };
		['ali|M1|3'] = { d = 0.4848, n = 1 };
		['ali|M1|4'] = { d = 0.2122, n = 3 };
		['ali|M2|1'] = { d = 0.5584, n = 1 };
		['basic|M1|1'] = { d = 0.3542, n = 1 };
		['basic|M1|2'] = { d = 0.3159, n = 3 };
		['basic|M1|3'] = { d = 0.4841, n = 1 };
		['basic|M1|4'] = { d = 0.3624, n = 1 };
		['basic|M2|1'] = { d = 0.4146, n = 1 };
		['boxing@awakened|M1|1'] = { d = 0.3175, n = 2 };
		['boxing@awakened|M1|2'] = { d = 0.4245, n = 2 };
		['boxing@awakened|M1|3'] = { d = 0.3067, n = 1 };
		['boxing@awakened|M1|4'] = { d = 0.2758, n = 1 };
		['boxing@awakened|M2|1|awakened'] = { d = 0.4178, n = 3 };
		['boxing|M1|1'] = { d = 0.4232, n = 2 };
		['boxing|M1|2'] = { d = 0.1976, n = 1 };
		['boxing|M1|3'] = { d = 0.2670, n = 2 };
		['boxing|M1|4'] = { d = 0.4710, n = 2 };
		['boxing|M2|1'] = { d = 0.2962, n = 1 };
		['capoeira|M1|1'] = { d = 0.3005, n = 1 };
		['capoeira|M1|2'] = { d = 0.2996, n = 1 };
		['capoeira|M1|3'] = { d = 0.4326, n = 1 };
		['capoeira|M1|4'] = { d = 0.1605, n = 1 };
		['capoeira|M2|1'] = { d = 0.5000, n = 2 };
		['cqc|M1|1'] = { d = 0.3662, n = 9 };
		['cqc|M1|2'] = { d = 0.3676, n = 5 };
		['cqc|M1|3'] = { d = 0.2509, n = 5 };
		['cqc|M1|4'] = { d = 0.4666, n = 2 };
		['cqc|M2|1'] = { d = 0.4319, n = 3 };
		['dragon|M1|1'] = { d = 0.3110, n = 8 };
		['dragon|M1|2'] = { d = 0.3504, n = 3 };
		['dragon|M1|3'] = { d = 0.2835, n = 3 };
		['dragon|M1|4'] = { d = 0.3351, n = 3 };
		['dragon|M2|1'] = { d = 0.6344, n = 1 };
		['giovanna|M1|1'] = { d = 0.4642, n = 1 };
		['giovanna|M1|2'] = { d = 0.3886, n = 1 };
		['giovanna|M1|3'] = { d = 0.2661, n = 4 };
		['giovanna|M1|4'] = { d = 0.4659, n = 5 };
		['giovanna|M2|1'] = { d = 0.4266, n = 3 };
		['hakari@awakened|M1|1'] = { d = 0.3182, n = 9 };
		['hakari@awakened|M1|2'] = { d = 0.3282, n = 7 };
		['hakari@awakened|M1|3'] = { d = 0.2137, n = 4 };
		['hakari@awakened|M1|4'] = { d = 0.4351, n = 1 };
		['hakari@awakened|M2|1'] = { d = 0.2897, n = 1 };
		['hakari|M1|1'] = { d = 0.3330, n = 10 };
		['hakari|M1|2'] = { d = 0.3435, n = 1 };
		['hakari|M1|3'] = { d = 0.2341, n = 4 };
		['hakari|M1|4'] = { d = 0.3508, n = 5 };
		['hakari|M2|1'] = { d = 0.4091, n = 5 };
		['hikaken|M1|1'] = { d = 0.1523, n = 1 };
		['hikaken|M1|2'] = { d = 0.3158, n = 1 };
		['hikaken|M1|3'] = { d = 0.3165, n = 1 };
		['hikaken|M1|4'] = { d = 0.2504, n = 1 };
		['hikaken|M2|1'] = { d = 0.2838, n = 3 };
		['jin@awakened|M1|1'] = { d = 0.2500, n = 1 };
		['jin@awakened|M1|2'] = { d = 0.5494, n = 1 };
		['jin@awakened|M1|3'] = { d = 0.4423, n = 1 };
		['jin@awakened|M1|4'] = { d = 0.4495, n = 1 };
		['karate@awakened|M1|1'] = { d = 0.3235, n = 12 };
		['karate@awakened|M1|2'] = { d = 0.3503, n = 12 };
		['karate@awakened|M1|3'] = { d = 0.3969, n = 8 };
		['karate|M1|1'] = { d = 0.3416, n = 4 };
		['karate|M1|2'] = { d = 0.3992, n = 1 };
		['karate|M1|3'] = { d = 0.5938, n = 1 };
		['karate|M1|4'] = { d = 0.5269, n = 1 };
		['karate|M2|1'] = { d = 0.4991, n = 1 };
		['kickboxing|M1|1'] = { d = 0.2487, n = 1 };
		['kickboxing|M1|2'] = { d = 0.3672, n = 1 };
		['kickboxing|M1|3'] = { d = 0.4509, n = 1 };
		['kickboxing|M1|4'] = { d = 0.5322, n = 1 };
		['kickboxing|M2|1'] = { d = 0.3009, n = 1 };
		['kure|M1|1'] = { d = 0.3170, n = 1 };
		['kure|M1|2'] = { d = 0.3245, n = 1 };
		['kure|M1|3'] = { d = 0.2619, n = 1 };
		['kure|M1|4'] = { d = 0.3669, n = 1 };
		['kure|M2|1'] = { d = 0.2634, n = 1 };
		['kyokushin|M1|1'] = { d = 0.3323, n = 1 };
		['kyokushin|M1|2'] = { d = 0.3001, n = 1 };
		['kyokushin|M2|1'] = { d = 0.7571, n = 1 };
		['lethwei|M1|1'] = { d = 0.5416, n = 12 };
		['lethwei|M1|2'] = { d = 0.5002, n = 12 };
		['lethwei|M1|3'] = { d = 0.3994, n = 9 };
		['lethwei|M1|4'] = { d = 0.4174, n = 1 };
		['lethwei|M2|1'] = { d = 0.4834, n = 5 };
		['mishima|M1|1'] = { d = 0.2349, n = 1 };
		['mishima|M1|2'] = { d = 0.2856, n = 1 };
		['mishima|M1|3'] = { d = 0.3679, n = 1 };
		['mishima|M1|4'] = { d = 0.4979, n = 1 };
		['mishima|M2|1'] = { d = 0.3600, n = 2 };
		['muaythai@awakened|M1|1'] = { d = 0.3362, n = 1 };
		['muaythai@awakened|M1|2'] = { d = 0.2348, n = 1 };
		['muaythai@awakened|M1|3'] = { d = 0.3504, n = 1 };
		['muaythai@awakened|M1|4'] = { d = 0.2801, n = 5 };
		['muaythai|M1|1'] = { d = 0.3457, n = 12 };
		['muaythai|M1|2'] = { d = 0.3193, n = 12 };
		['muaythai|M1|3'] = { d = 0.3368, n = 12 };
		['muaythai|M1|4'] = { d = 0.3303, n = 9 };
		['muaythai|M2|1'] = { d = 0.5891, n = 9 };
		['perfectcopy|M1|1'] = { d = 0.3014, n = 2 };
		['perfectcopy|M1|2'] = { d = 0.2330, n = 12 };
		['perfectcopy|M1|3'] = { d = 0.3179, n = 1 };
		['perfectcopy|M1|4'] = { d = 0.2009, n = 1 };
		['perfectcopy|M2|1'] = { d = 0.5015, n = 1 };
		['slugger|M1|1'] = { d = 0.5049, n = 1 };
		['slugger|M1|2'] = { d = 0.4194, n = 1 };
		['slugger|M1|3'] = { d = 0.4060, n = 3 };
		['slugger|M1|4'] = { d = 0.3150, n = 1 };
		['slugger|M2|1'] = { d = 0.8354, n = 1 };
		['striker|M1|1'] = { d = 0.3490, n = 8 };
		['striker|M1|2'] = { d = 0.3408, n = 5 };
		['striker|M1|3'] = { d = 0.2359, n = 5 };
		['striker|M1|4'] = { d = 0.1346, n = 4 };
		['striker|M2|1'] = { d = 0.4457, n = 1 };
		['taijutsu@awakened|M1|1'] = { d = 0.1992, n = 4 };
		['taijutsu@awakened|M1|2'] = { d = 0.3011, n = 2 };
		['taijutsu@awakened|M1|3'] = { d = 0.3017, n = 5 };
		['taijutsu@awakened|M1|4'] = { d = 0.2920, n = 2 };
		['taijutsu|M1|1'] = { d = 0.2339, n = 5 };
		['taijutsu|M1|2'] = { d = 0.2846, n = 1 };
		['taijutsu|M1|3'] = { d = 0.5002, n = 1 };
		['taijutsu|M1|4'] = { d = 0.1663, n = 1 };
		['taijutsu|M2|1'] = { d = 0.5521, n = 1 };
		['wingchun|M1|1'] = { d = 0.1756, n = 1 };
		['wingchun|M1|2'] = { d = 0.3487, n = 11 };
		['wingchun|M1|3'] = { d = 0.3371, n = 1 };
		['wingchun|M1|4'] = { d = 0.7655, n = 1 };
		['wingchun|M2|1'] = { d = 0.5487, n = 1 };
		['wrestling@awakened|M1|1'] = { d = 0.2876, n = 11 };
		['wrestling@awakened|M1|2'] = { d = 0.3683, n = 1 };
		['wrestling@awakened|M1|3'] = { d = 0.3493, n = 3 };
		['wrestling@awakened|M1|4'] = { d = 0.4843, n = 1 };
		['wrestling|M1|1'] = { d = 0.2765, n = 2 };
		['wrestling|M1|2'] = { d = 0.3345, n = 1 };
		['wrestling|M1|3'] = { d = 0.3679, n = 1 };
		['wrestling|M1|4'] = { d = 0.3669, n = 5 };
		['wrestling|M2|1'] = { d = 0.2637, n = 2 };
	};
	
	
	lead = {
		['40'] = { win = 1, n = 15 };
		['62'] = { win = 224, n = 752 };
		['50'] = { win = 5, n = 31 };
		['86'] = { win = 2, n = 15 };
		['74'] = { win = 8, n = 48 };
	};
};


do
	local builtinScale = type(BUILTIN_ADAPTIVE.scale) == 'table' and BUILTIN_ADAPTIVE.scale or nil;

	if (builtinScale) then
		if (tonumber(builtinScale.player)) then
			SCALE.player.s = tonumber(builtinScale.player);
			SCALE.player.n = tonumber(builtinScale.playerN) or 1;
		end;

		if (tonumber(builtinScale.npc)) then
			SCALE.npc.s = tonumber(builtinScale.npc);
			SCALE.npc.n = tonumber(builtinScale.npcN) or 1;
		end;
	end;

	local builtinLearned = type(BUILTIN_ADAPTIVE.learned) == 'table' and BUILTIN_ADAPTIVE.learned or {};

	for key, record in next, builtinLearned do
		if (type(record) == 'table' and tonumber(record.d)) then
			LEARNED_STYLE[key] = {
				d = tonumber(record.d),
				n = tonumber(record.n) or 3,
				
				
				samples = {},
			};
		end;
	end;
end;


local OBS = {
	swings = {},
	ratio = {},
};







local LEAD_CANDIDATES = {62, 50, 74, 40, 86};
local leadStats = {};

for _, value in next, LEAD_CANDIDATES do
	leadStats[value] = { n = 0, win = 0 };
end;






local BUILTIN_LEAD_STATS = (type(BUILTIN_ADAPTIVE.lead) == 'table') and BUILTIN_ADAPTIVE.lead or {};

for key, record in next, BUILTIN_LEAD_STATS do
	local value = tonumber(key);

	if (value and type(record) == 'table') then
		if (not leadStats[value]) then
			
			
			leadStats[value] = { n = 0, win = 0 };
		end;

		leadStats[value].win += tonumber(record.win) or 0;
		leadStats[value].n += tonumber(record.n) or 0;
	end;
end;

local LOG = {};

local watched = {};
local watchIndex = 0;

local stats = { attempt = 0, skip = 0, reasons = {}, wrongReject = {} };




local recentRejects = {};


local animStats = { seen = 0, matched = 0, unknown = {}, rej = {} };
local pressLog = {};
local parryTimes = {};
local ackTimes = {};
local cancelStats = {};

local function noteCancel(reason)
	cancelStats[reason] = (cancelStats[reason] or 0) + 1;
end;

local function noteReject(reason, character, info, distance)
	animStats.rej[reason] = (animStats.rej[reason] or 0) + 1;

	
	if (character) then
		table.insert(recentRejects, {
			at = os.clock();
			name = character.Name,
			style = info and info.style or '?',
			kind = info and info.kind or '?',
			combo = info and info.combo or 1,
			dist = tonumber(distance) or 0,
			reason = reason,
		});

		if (#recentRejects > 40) then
			table.remove(recentRejects, 1);
		end;
	end;
end;
local parryCount = 0;

local lastBlockAt = 0;




local autoParryForcedCooldown = false;







local autoParryForcedSelfBlock = false;
local lastScheduleAt = 0;



local blockHoldUntil = 0;
local blockSeq = 0;


local comboUntil = 0;
local lastSkip = nil;


function noteSkip(reason)
	stats.skip += 1;
	lastSkip = reason;

	local key = tostring(reason):match('^%a+') or tostring(reason);
	stats.reasons[key] = (stats.reasons[key] or 0) + 1;
end;

local lastLead, lastLeadAt = nil, 0;


local mirrorAlive = true;

library.unloadMaid:GiveTask(function()
	mirrorAlive = false;
end);





local myGeneration = string.format('%d_%d', math.floor(os.clock() * 1000), math.random(1, 1000000));

getgenv().__gakuranGeneration = myGeneration;

local mirrorKey = '__gakuranParry_' .. myGeneration;

getgenv().__gakuranParryKey = mirrorKey;
getgenv()[mirrorKey] = { attempt = 0, skip = 0, reasons = {}, lastSkip = nil, parryCount = 0 };

task.spawn(function()
	while (mirrorAlive and getgenv().__gakuranGeneration == myGeneration) do
		task.wait(0.5);

		local mirror = getgenv()[mirrorKey];

		if (mirror) then
			mirror.attempt = stats.attempt;
			mirror.skip = stats.skip;
			mirror.reasons = stats.reasons;
			mirror.lastSkip = lastSkip;
			mirror.parryCount = parryCount;
			mirror.lead = lastLead;
			
			mirror.wrongReject = stats.wrongReject;
			mirror.wrongRejectMaxDist = stats.wrongRejectMaxDist;
		end;
	end;
end);












local tuning = {
	enabled = false,   
	offset = 0,
	step = 8,
	limit = 200,
	window = 0.45,
	pending = nil,
	wins = 0,
	earlies = 0,
	lates = 0,
};

local lastPickedOffset = 0;

function pickParryOffset()
	
	
	
	
	return CONFIG.parryOffsetMs or 0;
end;

function notePressOffset(milliseconds)
	tuning.pending = {
		at = os.clock(),
		offset = milliseconds,
		parry = false,
		damaged = false,
	};
end;

function noteParryOutcome(win, at)
	local pending = tuning.pending;

	if (not pending) then return end;
	if (at - pending.at > tuning.window) then return end;

	if (win) then
		pending.parry = true;
	else
		pending.damaged = true;
	end;
end;







local lastLeadSaveAt = 0;

local function buildAdaptiveSnapshot()
	local learned = {};

	for key, record in next, LEARNED_STYLE do
		if (record.n > 0 and record.d) then
			learned[key] = { d = record.d, n = record.n };
		end;
	end;

	local lead = {};
	local allowedLeads = {};

	for _, value in next, LEAD_CANDIDATES do
		allowedLeads[value] = true;
	end;

	for value, record in next, leadStats do
		
		if (record.n > 0 and allowedLeads[value]) then
			lead[tostring(value)] = { win = record.win, n = record.n };
		end;
	end;

	return {
		scale = {
			player = SCALE.player.s,
			playerN = SCALE.player.n,
			npc = SCALE.npc.s,
			npcN = SCALE.npc.n,
		},
		learned = learned,
		lead = lead,
	};
end;







local ADAPTIVE_FILE = 'v.air/adaptive_learned.json';

local function saveAdaptiveFile(snapshot)
	if (type(writefile) ~= 'function') then return end;

	local ok, encoded = pcall(function()
		return game:GetService('HttpService'):JSONEncode(snapshot);
	end);

	if (ok and type(encoded) == 'string') then
		pcall(writefile, ADAPTIVE_FILE, encoded);
	end;
end;

local function loadAdaptiveFile()
	if (type(isfile) ~= 'function' or type(readfile) ~= 'function') then
		return nil;
	end;

	local okExists, exists = pcall(isfile, ADAPTIVE_FILE);

	if (not okExists or not exists) then
		return nil;
	end;

	local okRead, content = pcall(readfile, ADAPTIVE_FILE);

	if (not okRead or type(content) ~= 'string' or content == '') then
		return nil;
	end;

	local okDecode, decoded = pcall(function()
		return game:GetService('HttpService'):JSONDecode(content);
	end);

	if (okDecode and type(decoded) == 'table') then
		return decoded;
	end;

	return nil;
end;

local function saveLeadStats(force)
	local now = os.clock();

	if (not force and now - lastLeadSaveAt < 8) then return end;

	lastLeadSaveAt = now;

	local snapshot = buildAdaptiveSnapshot();

	
	
	
	
	saveAdaptiveFile(snapshot);

	
	local configVars = library.configVars;

	if (type(configVars) == 'table') then
		configVars.gakuranAdaptive = snapshot;

		
		configVars.gakuranLeadStats = snapshot.lead;

		
		configVars.gakuranTuningOffset = nil;
	end;
end;

local function loadLeadStats()
	local configVars = library.configVars;

	if (type(configVars) ~= 'table') then return end;

	
	local adaptive = loadAdaptiveFile();

	if (type(adaptive) ~= 'table') then
		adaptive = configVars.gakuranAdaptive;
	end;

	
	
	
	local scaleSeed = 1.0;

	if (type(adaptive) == 'table' and type(adaptive.scale) == 'table') then
		local stored = tonumber(adaptive.scale.player);

		if (stored and stored > 0.5 and stored < 1.5) then
			scaleSeed = stored;
		end;
	end;

	SCALE.player.s = scaleSeed;
	SCALE.player.samples = { scaleSeed, scaleSeed };
	SCALE.player.n = 2;

	SCALE.npc.s = scaleSeed;
	SCALE.npc.samples = { scaleSeed, scaleSeed };
	SCALE.npc.n = 2;

	
	local learned = (type(adaptive) == 'table' and type(adaptive.learned) == 'table') and adaptive.learned
		or (type(configVars.gakuranLearnedStyle) == 'table' and configVars.gakuranLearnedStyle)
		or nil;

	if (type(learned) == 'table') then
		for key, record in next, learned do
			if (type(record) == 'table' and tonumber(record.d)) then
				LEARNED_STYLE[key] = {
					d = tonumber(record.d),
					n = tonumber(record.n) or 3,
					
					samples = {},
				};
			end;
		end;
	end;

	
	
	
	
	
	local saved = configVars.gakuranLeadStats or (type(adaptive) == 'table' and adaptive.lead) or nil;
	local allowedLeads = {};

	for _, value in next, LEAD_CANDIDATES do
		allowedLeads[value] = true;
	end;

	
	
	
	
	if (type(configVars) == 'table' and not configVars.leadRebasedOnScaleFix) then
		configVars.leadRebasedOnScaleFix = true;
		configVars.gakuranLeadStats = nil;
		saved = nil;
	end;

	
	
	
	
	if (type(configVars) == 'table' and not configVars.leadAnchor62Applied) then
		configVars.leadAnchor62Applied = true;
		configVars.gakuranLeadStats = nil;
		saved = nil;
	end;

	if (type(saved) == 'table') then
		for key, record in next, saved do
			local lead = tonumber(key);

			if (lead and allowedLeads[lead] and type(record) == 'table') then
				leadStats[lead] = {
					win = tonumber(record.win) or 0,
					n = tonumber(record.n) or 0,
				};
			end;
		end;
	end;

	
	if (type(configVars) == 'table') then
		configVars.gakuranTuningOffset = nil;
	end;

	
	
	
	
	
	tuning.offset = 0;
end;

local function classifyPending()
	local pending = tuning.pending;

	if (not pending) then return end;
	if (os.clock() - pending.at < tuning.window) then return end;

	tuning.pending = nil;

	if (pending.parry) then
		tuning.wins += 1;

		return;
	end;

	
	
	
	
	if (pending.damaged) then
		tuning.lates += 1;
	else
		tuning.earlies += 1;
	end;
end;

local function pushTuningMirror()
	local mirror = getgenv()[mirrorKey];

	if (not mirror) then return end;

	mirror.tuning = string.format('offset=%.0f win=%d early=%d late=%d step=%d',
		tuning.offset, tuning.wins, tuning.earlies, tuning.lates, tuning.step);

	
	local ratios = {};
	local samples = {};

	for name, record in next, OBS.ratio do
		if (record.n > 0) then
			ratios[#ratios+1] = string.format('%s:n%d s%.2f', tostring(name):sub(1, 14), record.n, record.s);

			for _, value in next, record.samples do
				samples[#samples+1] = value;
			end;
		end;
	end;

	if (#samples > 0) then
		table.sort(samples);

		mirror.obsMedian = samples[math.floor(#samples / 2) + 1];
		mirror.obsSamples = #samples;

		local sum = 0;

		for _, value in next, samples do
			sum += value;
		end;

		mirror.obsMean = sum / #samples;
	end;

	mirror.obs = table.concat(ratios, ' | '):sub(1, 400);
	local rejectList = {};

	for reason, count in next, animStats.rej do
		rejectList[#rejectList+1] = string.format('%s=%d', reason, count);
	end;

	table.sort(rejectList);

	mirror.anims = string.format('seen=%d matched=%d unknown=[%s]',
		animStats.seen, animStats.matched, table.concat(animStats.unknown, ','));
	mirror.rejects = table.concat(rejectList, ' ');
	mirror.press = table.concat(pressLog, ' | '):sub(1, 400);

	local gaps = {};

	for index = 2, #parryTimes do
		gaps[#gaps+1] = math.floor((parryTimes[index] - parryTimes[index - 1]) * 1000);
	end;

	mirror.parryGaps = table.concat(gaps, ',');

	local cancelList = {};

	for reason, count in next, cancelStats do
		cancelList[#cancelList+1] = string.format('%s=%d', reason, count);
	end;

	table.sort(cancelList);

	mirror.cancels = table.concat(cancelList, ' ');
	mirror.ackGaps = (function()
		local list = {};

		for index = 2, #ackTimes do
			list[#list+1] = math.floor((ackTimes[index] - ackTimes[index - 1]) * 1000);
		end;

		return table.concat(list, ',');
	end)();
	mirror.tuningCurrent = math.floor(tuning.offset + 0.5);
	mirror.tuningEnabled = tuning.enabled;
end;

task.spawn(function()
	while (mirrorAlive and getgenv().__gakuranGeneration == myGeneration) do
		task.wait(0.1);

		pcall(classifyPending);
		pcall(pushTuningMirror);
	end;
end);

local lastStanceTry = 0;
local lastStanceScan = 0;
local lastStanceLogAt = 0;

local stunProbeAt = 0;
local stunProbeLog = {};

local healthHumanoid;
local lastHealth = 0;


local CombatConfig, AwakenedUtils, BlockModule, EquipModule, EvasiveModule, ServerRemote;


local buildAnimMap;
local countTable;
local log;
local learnKey;
local median;
local myChar, myRootPart, isWhitelisted, isEnabled;
local styleKeyOf, baseDelay, resolveDelay, pickLead;
local learnSample, obsSwing, obsDamage, onCombatHit, onPerfectBlock, onHealthDrop;
local probeParryBuffer;
local canBlock, releaseBlock, pressBlock;
local ensureStance;
local handleSwing;
local bindHumanoid, watchCharacter, unwatchCharacter, watchContainer, ensureNpcScan, hookAll, isIgnored;
local bindHealthWatch;
local restoreWhitelist;

local function getFlag(name, default)
	local value = library.flags[name];

	if (value == nil) then
		return default;
	end;

	return value;
end;

function isEnabled()
	return getFlag('enableAutoParry', false) == true;
end;



local runId = (getgenv().vluaGakuranRunId or 0) + 1;
getgenv().vluaGakuranRunId = runId;

local function isStale()
	return getgenv().vluaGakuranRunId ~= runId;
end;

do 
	if (type(getgenv().vluaGakuranStop) == 'function') then
		pcall(getgenv().vluaGakuranStop);
	end;

	getgenv().vluaGakuranStop = function()
		maid:Destroy();
		table.clear(watched);
	end;
end;




do 
	function log(format, ...)
		
		
		
		local line;

		if (select('#', ...) > 0) then
			local ok, result = pcall(string.format, type(format) == 'string' and format or tostring(format), ...)
			line = ok and result or tostring(format)
		else
			line = tostring(format)
		end;

		table.insert(LOG, 1, os.date('%H:%M:%S ') .. line);

		while (#LOG > CONFIG.logSize) do
			table.remove(LOG);
		end;

		if (getFlag('debugLog', false)) then
			print('[Gakuran] ' .. line);
		end;
	end;

	function countTable(target)
		local count = 0;

		for _ in next, target do
			count += 1;
		end;

		return count;
	end;
end;





do 
	function buildAnimMap()
		table.clear(ANIM);

		local animationsFolder = ReplicatedStorage:FindFirstChild('Animations');
		local combatFolder = animationsFolder and animationsFolder:FindFirstChild('Combat');

		if (not combatFolder) then
			warn('[Gakuran] 找不到 Animations.Combat，动画表为空');

			return 0;
		end;

		local function register(animation, style, kind, combo, variant)
			if (not kind) then return end;

			local animationId = animation.AnimationId:match('%d+');

			if (animationId) then
				ANIM[animationId] = {
					style = style;
					kind = kind;
					combo = combo or 1;
					variant = variant or '';
				};
			end;
		end;

		
		for _, styleFolder in next, combatFolder:GetChildren() do
			if (not styleFolder:IsA('Folder')) then continue end;
			if (styleFolder.Name:sub(-5) ~= 'Anims') then continue end;

			local style = styleFolder.Name:sub(1, #styleFolder.Name - 5):lower();

			for _, animation in next, styleFolder:GetDescendants() do
				if (not animation:IsA('Animation')) then continue end;

				local animationName = animation.Name;
				local kind, combo;

				
				
				
				
				if (animationName:find('M1$')) then
					kind = 'M1';
					combo = tonumber(animationName:match('^(%d)')) or 1;
				elseif (animationName:find('M2$')) then
					kind = 'M2';
					combo = 1;
				end;

				register(animation, style, kind, combo, '');
			end;
		end;

		
		
		
		
		
		
		
		
		
		
		local awakenedFolder = animationsFolder and animationsFolder:FindFirstChild('Awakened');

		if (awakenedFolder) then
			for _, styleFolder in next, awakenedFolder:GetChildren() do
				if (not styleFolder:IsA('Folder')) then continue end;

				local style = styleFolder.Name:lower();

				for _, animation in next, styleFolder:GetDescendants() do
					if (not animation:IsA('Animation')) then continue end;

					local animationName = animation.Name;
					local kind, combo;

					if (animationName == 'M2') then
						kind, combo = 'M2', 1;
					elseif (animationName == 'M2Part2') then
						
						kind, combo = 'M2', 2;
					elseif (animationName:find('M1$')) then
						kind, combo = 'M1', tonumber(animationName:match('^(%d)')) or 1;
					end;

					register(animation, style, kind, combo, 'awakened');
				end;
			end;
		end;

		local uniqueCount = 0;

		for _ in next, ANIM do
			uniqueCount += 1;
		end;

		
		local remapModule = ReplicatedStorage:FindFirstChild('AnimationRemap');

		if (remapModule and remapModule:IsA('ModuleScript')) then
			local ok, mapping = pcall(require, remapModule);

			if (ok and type(mapping) == 'table') then
				for oldId, newId in next, mapping do
					local oldKey, newKey = tostring(oldId), tostring(newId);

					if (ANIM[newKey] and not ANIM[oldKey]) then
						ANIM[oldKey] = ANIM[newKey];
					end;
				end;
			end;
		end;

		return uniqueCount;
	end;

	ANIM_COUNT = buildAnimMap();
end;




do 
	CombatConfig = requireShared('Shared', 'Config', 'CombatConfig');
	AwakenedUtils = requireShared('Shared', 'Utils', 'CombatAwakenedUtils');
	BlockModule = requireShared('CombatSystemClient', 'Combat', 'Base', 'Block');
	EquipModule = requireShared('CombatSystemClient', 'Combat', 'Base', 'Equip');
	EvasiveModule = requireShared('CombatSystemClient', 'Combat', 'Base', 'Evasive');

	local remotes = ReplicatedStorage:WaitForChild('Remotes', 15);

	ServerRemote = remotes and remotes:WaitForChild('Server', 15);

	if (not BlockModule) then
		warn('[Gakuran] 无法加载 Block 模块，降级为直接发 Remote');
	end;

	if (not CombatConfig) then
		warn('[Gakuran] 无法加载 CombatConfig，命中延迟全部退回常量');
	end;
end;




do 
	function styleKeyOf(character, info)
		local isPlayer = character and Players:GetPlayerFromCharacter(character) ~= nil;

		
		if (isPlayer and AwakenedUtils and AwakenedUtils.CharacterConfigKey) then
			local ok, key = pcall(AwakenedUtils.CharacterConfigKey, character);

			if (ok and type(key) == 'string' and key ~= '') then
				return key:lower();
			end;
		end;

		
		return info.style;
	end;

	
	
	
	function learnKey(characterName, style, info)
		local base = characterName .. '|' .. style .. '|' .. info.kind .. '|' .. info.combo;

		local variant = info.variant;

		if (type(variant) == 'string' and variant ~= '') then
			return base .. '|' .. variant;
		end;

		return base;
	end;

	
	
	
	function baseDelay(info, character)
		local default = (info.kind == 'M1') and 0.32 or 0.30;

		if (not CombatConfig) then
			return default;
		end;

		local primary = styleKeyOf(character, info);
		local candidates = {primary};

		if (info.style ~= primary) then
			table.insert(candidates, info.style);
		end;

		for _, key in next, candidates do
			local delay;

			if (info.kind == 'M1') then
				
				
				local fn = CombatConfig.GetScaledStyleM1HitboxDelay;

				if (type(fn) == 'function') then
					local ok, result = pcall(fn, key, info.combo, 1);

					if (ok) then
						delay = result;
					end;
				end;
			else
				local m2Fn = CombatConfig.GetStyleM2HitboxDelay;
				local numberFn = CombatConfig.GetStyleNumber;

				if (type(m2Fn) == 'function') then
					local ok, result = pcall(m2Fn, key, nil, nil);

					if (ok and type(result) == 'number') then
						delay = result;
					end;
				end;

				if (delay == nil and type(numberFn) == 'function') then
					local ok2, result2 = pcall(numberFn, key, 'M2HitboxDelay', default);

					if (ok2) then
						delay = result2;
					end;
				end;
			end;

			
			if (type(delay) == 'number' and delay > 0 and math.abs(delay - default) > 1e-6) then
				return delay;
			end;
		end;

		return default;
	end;

	
	
	
	
	function resolveDelay(info, character)
		local primary = styleKeyOf(character, info);
		local record = LEARNED[learnKey(character.Name, primary, info)];

		
		if (record and record.n >= 3) then
			return record.d;
		end;

		local base = baseDelay(info, character);
		local perCharacter = OBS.ratio[character.Name];

		
		
		
		
		if (perCharacter and perCharacter.n >= 3) then
			return base * perCharacter.s;
		end;

		
		local styleKey = primary .. '|' .. info.kind .. '|' .. info.combo;

		if (type(info.variant) == 'string' and info.variant ~= '') then
			styleKey = styleKey .. '|' .. info.variant;
		end;

		local styleRecord = LEARNED_STYLE[styleKey];

		if (styleRecord and styleRecord.n >= 3) then
			return styleRecord.d;
		end;

		
		if (perCharacter and perCharacter.n >= 2) then
			return base * perCharacter.s;
		end;

		
		local bucket = Players:GetPlayerFromCharacter(character) and SCALE.player or SCALE.npc;

		if (bucket.n >= 1) then
			return base * bucket.s;
		end;

		
		return base;
	end;

	
	local EXPLORE_MIN_SAMPLES = 15;
	
	local EXPLORE_EVERY = 8;

	local leadPickCounter = 0;
	local leadProbe = { picked = {}, explored = 0, total = 0 };

	getgenv().__gakuranLeadProbe = leadProbe;

	local function notePick(value, explored)
		leadPickCounter += 1;

		leadProbe.total = leadPickCounter;

		if (explored) then
			leadProbe.explored += 1;
		end;

		table.insert(leadProbe.picked, { v = value, e = explored });

		if (#leadProbe.picked > 14) then
			table.remove(leadProbe.picked, 1);
		end;
	end;

	function pickLead()
		
		
		
		
		
		
		local needExplore = false;

		for _, value in next, LEAD_CANDIDATES do
			local record = leadStats[value];

			if (record and record.n < EXPLORE_MIN_SAMPLES) then
				needExplore = true;

				break;
			end;
		end;

		local exploreEvery = needExplore and 3 or EXPLORE_EVERY;

		if (leadPickCounter % exploreEvery == exploreEvery - 1) then
			local leastValue, leastCount;

			for _, value in next, LEAD_CANDIDATES do
				local record = leadStats[value];

				if (record and (not leastCount or record.n < leastCount)) then
					leastValue, leastCount = value, record.n;
				end;
			end;

			if (leastValue and (leastCount or 0) < EXPLORE_MIN_SAMPLES) then
				notePick(leastValue, true);

				return leastValue;
			end;
		end;

		
		local best, bestScore;

		for _, value in next, LEAD_CANDIDATES do
			local record = leadStats[value];
			local score = (record.win + 1) / (record.n + 2);

			if (not bestScore or score > bestScore) then
				best, bestScore = value, score;
			end;
		end;

		notePick(best or 85, false);

		return best or 85;
	end;
end;




do 
	function median(list)
		local sorted = table.clone(list);
		table.sort(sorted);

		local count = #sorted;

		if (count == 0) then return nil end;
		if (count % 2 == 1) then return sorted[math.floor(count / 2) + 1] end;

		return (sorted[count / 2] + sorted[count / 2 + 1]) / 2;
	end;

	
	function learnSample(swing, delta)
		
		if (math.abs(delta - swing.formula) > CONFIG.learnTolerance) then return end;

		local bucket = swing.isPlayer and SCALE.player or SCALE.npc;

		
		
		
		
		local denominator = tonumber(swing.base) or tonumber(swing.formula);

		if (denominator and denominator > 0.05) then
			local ratio = delta / denominator;

			if (ratio > 0.4 and ratio < 1.8) then
				
				
				if (type(bucket.samples) ~= 'table') then
					bucket.samples = {};
				end;

				table.insert(bucket.samples, ratio);

				if (#bucket.samples > 24) then
					table.remove(bucket.samples, 1);
				end;

				bucket.n = #bucket.samples;
				bucket.s = median(bucket.samples);
			end;
		end;

		
		local record = LEARNED[swing.key];

		if (not record) then
			record = { n = 0, samples = {} };
			LEARNED[swing.key] = record;
		end;

		table.insert(record.samples, delta);

		if (#record.samples > 7) then
			table.remove(record.samples, 1);
		end;

		record.n = #record.samples;
		record.d = median(record.samples);

		
		local stylePart = swing.key:match('^[^|]+|(.+)$');

		if (stylePart) then
			local styleRecord = LEARNED_STYLE[stylePart];

			if (not styleRecord) then
				styleRecord = { n = 0, samples = {} };
				LEARNED_STYLE[stylePart] = styleRecord;
			end;

			
			
			if (type(styleRecord.samples) ~= 'table') then
				styleRecord.samples = {};
			end;

			table.insert(styleRecord.samples, delta);

			if (#styleRecord.samples > 12) then
				table.remove(styleRecord.samples, 1);
			end;

			styleRecord.n = #styleRecord.samples;
			styleRecord.d = median(styleRecord.samples);
		end;

		log('校准 %s 实测=%.3f 公式=%.3f 比例=%.2f (n=%d)', swing.key, delta, swing.formula, bucket.s, record.n);
	end;

	
	function obsSwing(character, info)
		
		
		local distance = 0;
		local myRoot = myRootPart();
		local theirRoot = character and character:FindFirstChild('HumanoidRootPart');

		if (myRoot and theirRoot) then
			distance = (theirRoot.Position - myRoot.Position).Magnitude;
		end;

		table.insert(OBS.swings, {
			t = os.clock(),
			name = character.Name,
			base = baseDelay(info, character),
			
			styleKey = styleKeyOf(character, info) .. '|' .. info.kind .. '|' .. info.combo
				.. ((type(info.variant) == 'string' and info.variant ~= '') and ('|' .. info.variant) or ''),
			distance = distance,
		});

		if (#OBS.swings > 400) then
			table.remove(OBS.swings, 1);
		end;
	end;

	
	function obsDamage(victimName, damage)
		if (damage < 0.5 or damage > 40) then return end;

		local now = os.clock();
		local best, bestScore;

		for index = #OBS.swings, 1, -1 do
			local swing = OBS.swings[index];
			local delta = now - swing.t;

			if (delta > 0.9) then break end;

			if (delta >= 0.05 and swing.name ~= victimName and not swing.used) then
				
				
				local distance = swing.distance or 0;

				if (distance <= 60) then
					local score = math.abs(delta - swing.base);

					
					score += distance * 0.0005;

					if (not bestScore or score < bestScore) then
						best, bestScore = { swing = swing, delta = delta }, score;
					end;
				end;
			end;
		end;

		
		if (not best or bestScore > 0.18) then return end;

		best.swing.used = true;

		local record = OBS.ratio[best.swing.name];

		if (not record) then
			record = { n = 0, samples = {}, s = 1 };
			OBS.ratio[best.swing.name] = record;
		end;

		table.insert(record.samples, best.delta / best.swing.base);

		if (#record.samples > 9) then
			table.remove(record.samples, 1);
		end;

		record.n = #record.samples;
		record.s = median(record.samples);

		
		
		
		local styleKey = best.swing.styleKey;

		if (styleKey) then
			local styleRecord = LEARNED_STYLE[styleKey];

			if (not styleRecord) then
				styleRecord = { n = 0, samples = {} };
				LEARNED_STYLE[styleKey] = styleRecord;
			end;

			
			if (type(styleRecord.samples) ~= 'table') then
				styleRecord.samples = {};
			end;

			table.insert(styleRecord.samples, best.delta);

			if (#styleRecord.samples > 12) then
				table.remove(styleRecord.samples, 1);
			end;

			styleRecord.n = #styleRecord.samples;
			styleRecord.d = median(styleRecord.samples);
		end;
	end;

	
	function onCombatHit(attackerName, victimName)
		if (isStale()) then return end;

		
		
		if (attackerName == LocalPlayer.Name and victimName ~= LocalPlayer.Name) then
			if (Players:FindFirstChild(victimName)) then
				pcall(playHitSound);
			end;
		end;

		if (victimName ~= LocalPlayer.Name) then return end;

		
		Lab.notePlayerHit();

		local now = os.clock();

		
		
		
		
		
		
		
		for index = #recentRejects, 1, -1 do
			local reject = recentRejects[index];

			if (now - reject.at > 0.7) then break end;

			if (reject.name == attackerName) then
				stats.wrongReject[reject.reason] = (stats.wrongReject[reject.reason] or 0) + 1;

				
				if (reject.reason == 'range' or reject.reason == 'notaimed') then
					if (reject.dist > (stats.wrongRejectMaxDist or 0)) then
						stats.wrongRejectMaxDist = reject.dist;
					end;
				end;

				table.remove(recentRejects, index);

				break;
			end;
		end;

		for index = #recentSwings, 1, -1 do
			local swing = recentSwings[index];
			local delta = now - swing.t;

			if (delta > 2) then break end;

			if (swing.name == attackerName and delta >= 0.05) then
				swing.used = true;
				learnSample(swing, delta);

				return;
			end;
		end;
	end;

	
	function onPerfectBlock(attacker, victim)
		if (isStale()) then return end;
		if (victim ~= LocalPlayer.Name) then return end;

		parryCount += 1;

		table.insert(parryTimes, os.clock());

		if (#parryTimes > 12) then
			table.remove(parryTimes, 1);
		end;

		pcall(noteParryOutcome, true, os.clock());
		pcall(playParrySound);

		local record = lastLead and leadStats[lastLead];

		if (record and os.clock() - lastLeadAt < 1.5) then
			record.win += 1;

			
			pcall(saveLeadStats);
		end;

		log('★ 弹反成功 #%d  来自 %s  (lead=%s)', parryCount, tostring(attacker), tostring(lastLead));
	end;

	
	
	
	function onHealthDrop(damage)
		if (damage < 0.5 or damage > 40) then return end;

		pcall(noteParryOutcome, false, os.clock());

		
		
		local character = myChar();

		if (character and character:GetAttribute('Equip') == true) then
			log('受伤 %.1f  格挡中=%s', damage, tostring(character:GetAttribute('Blocking')));
		end;

		local now = os.clock();
		local best, bestScore;

		for index = #recentSwings, 1, -1 do
			local swing = recentSwings[index];
			local delta = now - swing.t;

			if (delta > 0.7) then break end;

			if (delta >= 0.05 and not swing.used) then
				local score = math.abs(delta - swing.formula);

				if (not bestScore or score < bestScore) then
					best, bestScore = { swing = swing, delta = delta }, score;
				end;
			end;
		end;

		if (not best) then return end;

		best.swing.used = true;
		learnSample(best.swing, best.delta);
	end;
end;




do 
	function myChar()
		return LocalPlayer.Character;
	end;

	
	
	local rootCacheAt = 0;
	local rootCacheValue = nil;

	function myRootPart()
		local now = os.clock();

		if (now - rootCacheAt < 0.016) then
			return rootCacheValue;
		end;

		rootCacheAt = now;

		local character = myChar();

		rootCacheValue = character and character:FindFirstChild('HumanoidRootPart');

		return rootCacheValue;
	end;

	function isWhitelisted(name)
		return CONFIG.whitelist[name] == true;
	end;

	
	
	function canBlock()
		local character = myChar();

		if (not character or not character.Parent) then return false, 'nochar' end;
		if (character:GetAttribute('Equip') ~= true) then return false, 'nostance' end;
		if (character:GetAttribute('Ragdoll')) then return false, 'ragdoll' end;
		if (character:GetAttribute('Downed')) then return false, 'downed' end;
		if (character:GetAttribute('GuardBroken')) then return false, 'guardbroken' end;
		if (character:GetAttribute('Greenzone')) then return false, 'greenzone' end;
		if (character:GetAttribute('Grappling')) then return false, 'grappling' end;
		if (character:GetAttribute('SpecTimeSlowed')) then return false, 'slow' end;
		if (character:GetAttribute('RpCombatLocked')) then return false, 'locked' end;
		if (character:GetAttribute('StaffModPeaceMode')) then return false, 'staff' end;
		if (character:GetAttribute('ParryWindowDisabled')) then return false, 'nowindow' end;

		return true;
	end;

	
	function releaseBlock(reason)
		local character = myChar();

		if (not character) then return end;

		if (BlockModule) then
			pcall(function()
				BlockModule.Unblock(reason or 'AutoParry');
			end);

			return;
		end;

		if (character:GetAttribute('Blocking')) then
			character:SetAttribute('Blocking', nil);

			pcall(function()
				ServerRemote:FireServer({ Type = 'Combat', Action = 'Block', Func = 'Deactivated' });
			end);
		end;
	end;

	
	local lastDodgeAt = 0;

	function tryDodge(reason, force)
		if (not EvasiveModule) then return false end;
		if (not force and not getFlag('autoDodge', false)) then return false end;

		
		if (type(EvasiveModule.IsDashActive) == 'function') then
			local okActive, active = pcall(EvasiveModule.IsDashActive);

			if (okActive and active) then return false end;
		end;

		
		
		
		local now = os.clock();

		if (now - lastDodgeAt < 0.6) then return false end;

		lastDodgeAt = now;

		local ok = pcall(function()
			EvasiveModule.Evasive();
		end);

		if (getFlag('debugLog', false)) then
			log('DODGE %s ok=%s', tostring(reason), tostring(ok));
		end;

		return ok;
	end;

	
	function isGrappleMove(info)
		if (not info or info.kind ~= 'M2') then return false end;

		local selected = library.flags.grappleStyles;

		return type(selected) == 'table' and selected[info.style] == true;
	end;

	
	function faceTarget(targetRoot)
		local character = myChar();
		local root = character and character:FindFirstChild('HumanoidRootPart');

		if (not root or not targetRoot) then return end;

		local flat = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z);

		pcall(function()
			root.CFrame = CFrame.lookAt(root.Position, flat);
		end);
	end;

	
	
	
	function pressBlock()
		local character = myChar();

		if (not character) then return end;

		
		
		if (isSelfAttacking()) then
			noteSkip('selfatk');

			
			
			local dodged = false;

			if (getFlag('selfAttackDodge', true)) then
				dodged = tryDodge('selfatk', true) and true or false;

				if (dodged) then
					noteSkip('selfatk_dodged');
				end;
			end;

			if (dodged) then return false end;

			
			
			
			if (not (getFlag('selfAttackBlock', false) or autoParryForcedSelfBlock)) then
				requestQueuedParry();

				return false;
			end;
		end;

		local now = os.clock();

		if (now - lastBlockAt < CONFIG.blockCooldown) then
			noteSkip('cooldown');

			tryDodge('cooldown');

			return false;
		end;

		local allowed, reason = canBlock();

		if (not allowed) then
			noteSkip(reason);

			if (getFlag('debugLog', false)) then
				log('SKIP %s', reason);
			end;

			tryDodge(reason);

			return false;
		end;

		
		if (character:GetAttribute('BlockCooldown') == true) then
			noteSkip('blkcd');

			tryDodge('blkcd');

			return false;
		end;

		
		
		
		local ack = character:GetAttribute('BlockAck');

		
		
		
		local gateMs = tonumber(getFlag('serverBlockGate', 250)) or 250;

		if ((getFlag('noParryCooldown', false) or autoParryForcedCooldown) and gateMs > 120) then
			gateMs = 120;
		end;

		if (type(ack) == 'number') then
			local since = Workspace:GetServerTimeNow() - ack;

			if (since < (gateMs / 1000)) then
				noteSkip(string.format('srvcd %.2f', since));

				tryDodge('srvcd');

				return false;
			end;
		end;

		lastBlockAt = now;
		stats.attempt += 1;
		lastSkip = nil;

		notePressOffset(lastPickedOffset or 0);

		local ackNow = character:GetAttribute('BlockAck');

		if (type(ackNow) == 'number') then
			table.insert(ackTimes, ackNow);

			if (#ackTimes > 12) then
				table.remove(ackTimes, 1);
			end;
		end;

		local sent = true;

		task.spawn(function()
			if (not isEnabled()) then return end;

			
			
			
			releaseBlock('AutoParryRepress');

			
			
			local credit = _G.__GakuranAcCombatInputCreditAt;

			if (type(credit) ~= 'table') then
				credit = {};
				_G.__GakuranAcCombatInputCreditAt = credit;
			end;

			credit['Block.Activated'] = tick();

			if (BlockModule) then
				pcall(function()
					BlockModule.Block();
				end);
			else
				character:SetAttribute('Blocking', true);

				pcall(function()
					ServerRemote:FireServer(
						{ Type = 'Combat', Action = 'Block', Func = 'Activated' },
						Workspace:GetServerTimeNow()
					);
				end);
			end;

			
			
			
			local burst = math.floor(tonumber(getFlag('blockBurst', 1)) or 1);
			local burstGap = (tonumber(getFlag('blockBurstGap', 40)) or 40) / 1000;

			for attemptIndex = 2, burst do
				task.wait(burstGap);

				if (not isEnabled()) then break end;

				pcall(function() releaseBlock('AutoParryBurst') end);

				credit['Block.Activated'] = tick();

				if (BlockModule) then
					pcall(function() BlockModule.Block() end);
				else
					character:SetAttribute('Blocking', true);

					pcall(function()
						ServerRemote:FireServer(
							{ Type = 'Combat', Action = 'Block', Func = 'Activated' },
							Workspace:GetServerTimeNow()
						);
					end);
				end;
			end;

			
			
			
			
			local holdSeconds = (getFlag('blockHold', CONFIG.autoReleaseMs) or CONFIG.autoReleaseMs) / 1000;

			blockHoldUntil = os.clock() + holdSeconds;
			blockSeq += 1;

			local mySeq = blockSeq;

			task.spawn(function()
				while (true) do
					task.wait(0.02);

					
					if (blockSeq ~= mySeq) then return end;
					if (not isEnabled()) then return end;

					
					if (getFlag('comboHold', false) and os.clock() < comboUntil) then
						blockHoldUntil = os.clock() + holdSeconds;

						continue;
					end;

					if (os.clock() < blockHoldUntil) then continue end;

					releaseBlock('AutoParryRelease');

					return;
				end;
			end);
		end);

		return sent;
	end;
end;





do 
	
	
	
	
	
	function callAsGameScript(callback)
		local setIdentity = setthreadidentity or set_thread_identity or setidentity;
		local getIdentity = getthreadidentity or getidentity;

		if (type(setIdentity) ~= 'function' or type(getIdentity) ~= 'function') then
			return pcall(callback);
		end;

		local okGet, previous = pcall(getIdentity);

		if (not okGet or type(previous) ~= 'number') then
			return pcall(callback);
		end;

		if (not pcall(setIdentity, 2)) then
			return pcall(callback);
		end;

		local ok, err = pcall(callback);

		pcall(setIdentity, previous);

		return ok, err;
	end;

	
	
	function forceStance()
		lastStanceTry = 0;
		lastStanceScan = 0;

		pcall(ensureStance);
	end;

	function ensureStance()
		if (not getFlag('autoStance', true) or not EquipModule) then return end;

		local character = myChar();

		if (not character or not character.Parent) then return end;
		if (character:GetAttribute('Equip') == true) then return end;
		if (character:GetAttribute('Greenzone') or character:GetAttribute('RpCombatLocked')) then return end;
		if (character:GetAttribute('Ragdoll') or character:GetAttribute('Downed')) then return end;
		if (character:GetAttribute('GuardBroken') or character:GetAttribute('Stunned')) then return end;
		
	
	if (character:GetAttribute('PlayingInstrument') == true) then return end;

		
		local humanoid = character:FindFirstChildOfClass('Humanoid');

		if (humanoid) then
			local state = humanoid:GetState();

			if (state == Enum.HumanoidStateType.Seated
				or state == Enum.HumanoidStateType.Dead
				or state == Enum.HumanoidStateType.Physics
				or state == Enum.HumanoidStateType.Climbing) then
				return;
			end;
		end;

		local now = os.clock();

		if (now - lastStanceTry < getFlag('stanceRetry', 1)) then return end;
		if (now - lastStanceScan < 0.15) then return end;

		lastStanceScan = now;

		
		local myRoot = myRootPart();

		if (not myRoot) then return end;

		local stanceRange = getFlag('stanceRange', 25);

		local function anyNear(folder)
			if (not folder) then return false end;

			for _, other in next, folder:GetChildren() do
				if (other == character) then continue end;

				local rootPart = other:FindFirstChild('HumanoidRootPart');

				if (rootPart and (rootPart.Position - myRoot.Position).Magnitude <= stanceRange) then
					return true;
				end;
			end;

			return false;
		end;

		
		local isNear = anyNear(Workspace:FindFirstChild('Players'));

		if (not isNear and getFlag('parryNpcs', true)) then
			isNear = anyNear(Workspace:FindFirstChild('NPCs'));
		end;

		if (not isNear) then return end;

		lastStanceTry = now;

		
		
		
		
		
		local okEquip = callAsGameScript(function()
			EquipModule.Equip();
		end);

		if (getFlag('debugLog', false) and not okEquip and now - lastStanceLogAt > 5) then
			lastStanceLogAt = now;
			log('切姿态失败（identity 受限）');
		end;

		
		if (getFlag('debugLog', false) and now - lastStanceLogAt > 5) then
			lastStanceLogAt = now;
			log('尝试 T 切战斗姿态');
		end;
	end;
end;







do 
	local RING_SEGMENTS = 40;
	local RING_HEIGHT = 0.05;
	local RING_THICKNESS = 0.18;
	local RING_TRANSPARENCY = 0.55;
	local POSITION_GRID = 0.05;
	local MOVE_EPSILON = 0.005;
	local DEFAULT_COLOR = Color3.fromRGB(120, 220, 255);

	local visual = {
		enabled = false;
		folder = nil;
		segments = {};
		lastRadius = nil;
		lastCenter = nil;
		lastColor = nil;
		unloadRegistered = false;
	};

	local function destroyVisual()
		local folder = visual.folder;

		visual.folder = nil;
		visual.segments = {};

		if (folder) then
			pcall(function() folder:Destroy() end);
		end;
	end;

	local function makePart(name, parent)
		local part = Instance.new('Part');

		part.Name = name;
		part.Anchored = true;
		part.CanCollide = false;
		part.CanQuery = false;
		part.CanTouch = false;
		part.CastShadow = false;
		part.TopSurface = Enum.SurfaceType.Smooth;
		part.BottomSurface = Enum.SurfaceType.Smooth;
		part.Parent = parent;

		return part;
	end;

	local function buildVisual()
		destroyVisual();

		local folder = Instance.new('Folder');

		folder.Name = 'VluaStanceRangeRing';
		folder.Parent = Workspace;

		local segments = {};

		for index = 1, RING_SEGMENTS do
			local segment = makePart('Segment' .. index, folder);

			segment.Material = Enum.Material.Neon;
			segment.Color = DEFAULT_COLOR;
			segment.Transparency = RING_TRANSPARENCY;

			segments[index] = segment;
		end;

		visual.folder = folder;
		visual.segments = segments;
	end;

	local function refreshVisual(force)
		if (not visual.folder) then return end;

		local character = LocalPlayer.Character;
		local rootPart = character and character:FindFirstChild('HumanoidRootPart');

		if (not rootPart) then
			for _, segment in next, visual.segments do
				segment.Transparency = 1;
			end;

			return;
		end;

		local radius = math.round((getFlag('stanceRange', 25) or 25) / 0.05) * 0.05;
		local color = getFlag('stanceRangeColor', DEFAULT_COLOR) or DEFAULT_COLOR;

		
		local groundY = sampleGroundY(rootPart, character);

		local center = Vector3.new(
			math.round(rootPart.Position.X / POSITION_GRID) * POSITION_GRID,
			groundY,
			math.round(rootPart.Position.Z / POSITION_GRID) * POSITION_GRID
		);

		local colorChanged = (visual.lastColor ~= color);

		if (not force and not colorChanged and visual.lastRadius == radius
			and visual.lastCenter and (visual.lastCenter - center).Magnitude < MOVE_EPSILON) then
			return;
		end;

		visual.lastRadius = radius;
		visual.lastCenter = center;
		visual.lastColor = color;

		local arcLength = (2 * math.pi * radius / RING_SEGMENTS) * 1.25;

		for index, segment in next, visual.segments do
			local angle = ((index - 1) / RING_SEGMENTS) * math.pi * 2;
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle));

			segment.Size = Vector3.new(RING_THICKNESS, RING_HEIGHT, arcLength);
			segment.CFrame = CFrame.new(center + direction * radius + Vector3.new(0, 0.012, 0)) * CFrame.Angles(0, -angle, 0);
			segment.Color = color;
			segment.Transparency = RING_TRANSPARENCY;
		end;
	end;

	function functions.stanceRangeVisual(toggle)
		visual.enabled = toggle and true or false;

		if (visual.enabled) then
			if (not visual.folder) then
				buildVisual();

				if (not visual.unloadRegistered) then
					visual.unloadRegistered = true;

					library.unloadMaid:GiveTask(destroyVisual);
				end;
			end;

			refreshVisual(true);
		else
			destroyVisual();
		end;
	end;

	library:AddConnection(RunService.RenderStepped, function()
		if (not visual.enabled or not visual.folder) then return end;

		refreshVisual();
	end);
end;




do 
	
	function isPanic()
		if (not getFlag('panicBlock', false)) then return false end;

		local character = myChar();
		local humanoid = character and character:FindFirstChildOfClass('Humanoid');

		if (not humanoid) then return false end;

		return (humanoid.Health / math.max(humanoid.MaxHealth, 1) * 100) <= getFlag('panicHp', 35);
	end;

	
	function heightScale(character)
		local ok, size = pcall(function()
			return character:GetExtentsSize();
		end);

		if (not ok or not size) then return 1 end;

		return math.clamp(size.Y / 5.5, 0.8, 2);
	end;

	
	
	
	
	
	local HEIGHT_SCALE_STORE = '__gakuranHeightScale_v1';

	function stableHeightScale(character)
		if (not character) then return 1 end;

		local store = getgenv()[HEIGHT_SCALE_STORE];

		if (type(store) ~= 'table') then
			store = {};
			getgenv()[HEIGHT_SCALE_STORE] = store;
		end;

		local key = character.Name;
		local now = os.clock();
		local fresh = heightScale(character);
		local entry = store[key];

		if (type(entry) ~= 'table') then
			store[key] = {
				scale = fresh,
				freezeAt = now + 1.5,
			};

			return fresh;
		end;

		
		if (now < entry.freezeAt and fresh > entry.scale) then
			entry.scale = fresh;
		end;

		return entry.scale;
	end;

	
	
	
	local pingSmoothed = nil;

	local function smoothPing()
		local raw = LocalPlayer:GetNetworkPing() or 0;

		if (raw <= 0 or raw > 1) then
			return pingSmoothed or 0;
		end;

		if (pingSmoothed) then
			pingSmoothed = pingSmoothed * 0.75 + raw * 0.25;
		else
			pingSmoothed = raw;
		end;

		return pingSmoothed;
	end;

	
	
	
	
	local function attackReachFor(style, kind)
		local forwardOffset;

		if (CombatConfig) then
			local fn = CombatConfig.GetStyleHitboxForwardOffset;

			if (type(fn) == 'function') then
				local ok, result = pcall(fn, style, kind);

				if (ok and type(result) == 'number') then
					forwardOffset = result;
				end;
			end;

			if (not forwardOffset) then
				local defaults = (kind == 'M2') and CombatConfig.M2 or CombatConfig.M1;

				if (type(defaults) == 'table') then
					forwardOffset = tonumber(defaults.DefaultHitboxForwardOffset);
				end;
			end;
		end;

		if (not forwardOffset) then
			forwardOffset = 4;
		end;

		
		return forwardOffset + 10;
	end;

	function handleSwing(character, track)
		if (isStale()) then return end;
		if (not isEnabled()) then return end;

		
		local selfChar = myChar();

		if (selfChar and getFlag('autoStance', true) and selfChar:GetAttribute('Equip') ~= true) then
			forceStance();
		end;

		
		if (track.WeightTarget and track.WeightTarget <= 0) then return end;

		local animationId = track.Animation and track.Animation.AnimationId:match('%d+');

		if (not animationId) then return end;

		
		local info = ANIM[animationId];
		local override = CONFIG.animOverride[animationId];

		if (not info and not override) then
			
			table.insert(animStats.unknown, animationId);

			if (#animStats.unknown > 8) then
				table.remove(animStats.unknown, 1);
			end;

			return;
		end;

		animStats.matched += 1;

		
		if (info) then
			obsSwing(character, info);
		end;

		
		if (isWhitelisted(character.Name)) then
			noteReject('whitelist');

			return;
		end;

		local isPlayer = Players:GetPlayerFromCharacter(character) ~= nil;

		if (isPlayer and not getFlag('parryPlayers', true)) then
			noteReject('playeroff');

			return;
		end;

		if (not isPlayer and not getFlag('parryNpcs', true)) then
			noteReject('npcoff');

			return;
		end;

		
		if (not isPlayer and character:GetAttribute('CanFight') == false) then
			noteReject('cantfight');

			return;
		end;

		
		if (getFlag('grappleAware', false) and isGrappleMove(info)) then
			tryDodge('grapple', true);

			return;
		end;

		
		if (getFlag('comboHold', false)) then
			local now = os.clock();

			comboUntil = math.min(now + CONFIG.comboHoldExtend, now + CONFIG.comboHoldMax);
		end;

		local myRoot = myRootPart();
		local theirRoot = character:FindFirstChild('HumanoidRootPart');

		if (not myRoot or not theirRoot) then return end;

		local delta = theirRoot.Position - myRoot.Position;

		
		local panic = isPanic();

		
		
		local range = getFlag('parryMaxRange', 22);

		if (getFlag('heightReach', false)) then
			range *= stableHeightScale(character);
		end;

		if (not panic and delta.Magnitude > range) then
			noteReject('range', character, info, delta.Magnitude);

			return;
		end;

		
		
		if (not panic and getFlag('faceTarget', false)) then
			faceTarget(theirRoot);
		end;

		if (not panic and getFlag('requireFacing', true)) then
			if (delta:Dot(myRoot.CFrame.LookVector) <= 0) then
				noteReject('facing', character, info, delta.Magnitude);

				return;
			end;
		end;

		
		
		
		
		
		
		if (not panic) then
			local distance = delta.Magnitude;
			local reach = attackReachFor(info and info.style or 'default', info and info.kind or 'M1');

			if (distance > reach) then
				noteReject('notaimed', character, info, delta.Magnitude);

				return;
			end;

			if (distance > 10) then
				local toMe = Vector3.new(-delta.X, 0, -delta.Z);
				local flatLook = Vector3.new(theirRoot.CFrame.LookVector.X, 0, theirRoot.CFrame.LookVector.Z);

				
				if (toMe.Magnitude > 0.5 and flatLook.Magnitude > 0.5) then
					if (toMe.Unit:Dot(flatLook.Unit) < 0) then
						noteReject('notaimed', character, info, delta.Magnitude);

						return;
					end;
				end;
			end;
		end;

		
		local delay;

		if (override and override.delay) then
			delay = override.delay;
		elseif (info) then
			delay = resolveDelay(info, character);
		else
			delay = 0.32;
		end;

		local ping = smoothPing();
		local lead = pickLead();
		local offsetMs = pickParryOffset();

		
		
		
		
		if (tuning.lates >= 12 and tuning.lates > tuning.earlies * 4) then
			
			lead = lead + 32;
		elseif (tuning.lates >= 12 and tuning.lates > tuning.earlies * 2) then
			lead = lead + 16;
		end;

		
		
		local parryWindowMs = 125;

		if (CombatConfig and type(CombatConfig.Block) == 'table') then
			local window = tonumber(CombatConfig.Block.PerfectBlockWindow);

			if (window and window > 0) then
				parryWindowMs = window * 1000;
			end;
		end;

		lead = math.clamp(lead, 10, parryWindowMs - 10);

		lastPickedOffset = offsetMs;

		
		
		local pingCompensation = tonumber(getFlag('pingCompensation', CONFIG.pingCompensation));

		if (not pingCompensation) then
			pingCompensation = CONFIG.pingCompensation;
		end;

		local wait = delay
			- ping * (pingCompensation / 100)
			- (lead / 1000)
			+ (offsetMs / 1000);

		if (wait < 0) then
			wait = 0;
		end;

		
		
		if (getFlag('parryPriority', false)) then
			local dangerUntil = os.clock() + delay + 0.25;

			if (dangerUntil > (tonumber(getgenv().__gakuranDangerUntil) or 0)) then
				getgenv().__gakuranDangerUntil = dangerUntil;
			end;
		end;

		
		lastLead, lastLeadAt = lead, os.clock();

		local leadRecord = leadStats[lead];

		if (leadRecord) then
			leadRecord.n += 1;
		end;

		local styleKey = info and styleKeyOf(character, info) or '?';
		local tag = string.format('%s %s%s', styleKey, info and info.kind or '?', info and info.combo or '');

		
		
		if (info) then
			table.insert(recentSwings, {
				t = os.clock(),
				name = character.Name,
				key = learnKey(character.Name, styleKey, info),
				formula = delay,
				
				
				
				base = baseDelay(info, character),
				isPlayer = isPlayer,
			});

			if (#recentSwings > 60) then
				table.remove(recentSwings, 1);
			end;
		end;

		
		local now = os.clock();

		if (now - lastScheduleAt < (CONFIG.dedupeMs / 1000)) then
			noteReject('dedupe');

			return;
		end;

		lastScheduleAt = now;

		table.insert(pressLog, string.format('%s id=%s %s d=%.0f',
			tostring(character.Name):sub(1, 12), animationId, tostring(info and info.kind or '?'),
			delta.Magnitude));

		if (#pressLog > 8) then
			table.remove(pressLog, 1);
		end;

		if (getFlag('debugLog', false)) then
			log('IN  %s  %s  delay=%.3f ping=%.3f wait=%.3f', character.Name, tag, delay, ping, wait);
		end;

		
		local trackSpeed = track.Speed;

		if (type(trackSpeed) == 'number' and trackSpeed > 0 and trackSpeed ~= 1) then
			wait = wait / trackSpeed;
		end;

		local swingCharacter = character;
		local swingHumanoid = character:FindFirstChildOfClass('Humanoid');
		local swingRange = range;
		local swingIsPlayer = Players:GetPlayerFromCharacter(character) ~= nil;

		task.delay(wait, function()
			if (isStale() or not isEnabled()) then return end;

			
			
			
			if (getFlag('checkAnimEnd', false) and track and not track.IsPlaying) then
				noteCancel('notplaying');

				if (getFlag('debugLog', false)) then
					log('CANCEL %s 动画已结束（打断/切动作）', tostring(swingCharacter.Name));
				end;

				return;
			end;

			if (swingHumanoid and swingHumanoid.Health <= 0) then
				noteCancel('dead');

				return;
			end;

			if (swingCharacter:GetAttribute('Ragdoll') or swingCharacter:GetAttribute('Downed')) then
				noteCancel('targetDown');

				return;
			end;

			local currentRoot = swingCharacter:FindFirstChild('HumanoidRootPart');
			local currentMyRoot = myRootPart();

			if (currentRoot and currentMyRoot) then
				local currentDelta = currentRoot.Position - currentMyRoot.Position;

				if (currentDelta.Magnitude > swingRange * 1.25) then
					noteCancel('outOfRange');

					if (getFlag('debugLog', false)) then
						log('CANCEL %s 已超出范围 %.1f', tostring(swingCharacter.Name), currentDelta.Magnitude);
					end;

					return;
				end;

				if (getFlag('requireFacing', true) and currentDelta:Dot(currentMyRoot.CFrame.LookVector) <= 0) then
					noteCancel('behind');

					if (getFlag('debugLog', false)) then
						log('CANCEL %s 已不在正面', tostring(swingCharacter.Name));
					end;

					return;
				end;
			end;

			
			
			local attempts = 0;

			local function attempt()
				attempts = attempts + 1;

				if (isStale() or not isEnabled()) then return end;
				if (track and not track.IsPlaying) then return end;

				local sent = pressBlock();

				if (sent or attempts >= 3) then return end;
				
				if (lastSkip == 'selfatk') then return end;
				
				if (lastSkip == 'nostance' or lastSkip == 'ragdoll' or lastSkip == 'downed' or lastSkip == 'nowindow') then return end;

				local currentTrack = track;

				if (currentTrack and currentTrack.IsPlaying) then
					task.delay(0.06, attempt);
				end;
			end;

			attempt();
		end);
	end;
end;







do 
	local selfAttackTrack;
	local selfAttackUntil = 0;
	local pendingParryAt = 0;

	function isSelfAttacking()
		if (selfAttackTrack and selfAttackTrack.IsPlaying) then return true end;

		return os.clock() < selfAttackUntil;
	end;

	function requestQueuedParry()
		pendingParryAt = os.clock();
	end;

	function flushPendingParry()
		if (pendingParryAt == 0) then return end;

		local elapsed = os.clock() - pendingParryAt;

		pendingParryAt = 0;

		if (elapsed > CONFIG.attackParryWindow) then return end;

		if (getFlag('debugLog', false)) then
			log('QUEUED 出手结束 %.0fms 后补按', elapsed * 1000);
		end;

		pressBlock();
	end;

	local function noteSelfAttack(track)
		local animation = track.Animation;
		local animationId = animation and animation.AnimationId:match('%d+');

		if (not animationId) then return end;
		if (not (ANIM[animationId] or CONFIG.animOverride[animationId])) then return end;

		selfAttackTrack = track;
		selfAttackUntil = os.clock() + math.max(track.Length or 0.4, 0.2);

		
		local animInfo = ANIM[animationId] or CONFIG.animOverride[animationId];

		if (type(animInfo) == 'table' and animInfo.kind == 'M2') then
			getgenv().__gakuranLastM2At = os.clock();
			getgenv().__gakuranLastM2Style = animInfo.style;
		end;

		
		pcall(markMyAttack);

		track.Stopped:Connect(function()
			if (selfAttackTrack ~= track) then return end;

			selfAttackTrack = nil;
			selfAttackUntil = 0;

			flushPendingParry();
		end);
	end;

	local function bindSelf(character)
		local humanoid = character and character:FindFirstChildOfClass('Humanoid');

		if (not humanoid) then return end;

		library:AddConnection(humanoid.AnimationPlayed, function(track)
			pcall(noteSelfAttack, track);
		end);
	end;

	bindSelf(LocalPlayer.Character);

	library:AddConnection(LocalPlayer.CharacterAdded, function(character)
		selfAttackTrack = nil;
		selfAttackUntil = 0;
		pendingParryAt = 0;

		task.defer(bindSelf, character);
	end);
end;






do 
	function probeParryBuffer(character)
		if (not getFlag('probeParryBuffer', false)) then return end;

		local now = os.clock();

		if (now - stunProbeAt < 2) then return end;

		stunProbeAt = now;

		local before = character:GetAttribute('ParryBuffered');

		pcall(function()
			ServerRemote:FireServer(
				{ Type = 'Combat', Action = 'Block', Func = 'Activated' },
				Workspace:GetServerTimeNow()
			);
		end);

		task.delay(0.15, function()
			local after = character:GetAttribute('ParryBuffered');

			table.insert(stunProbeLog, { before = before, after = after });

			if (#stunProbeLog > 20) then
				table.remove(stunProbeLog, 1);
			end;

			log('僵直探测: ParryBuffered %s -> %s', tostring(before), tostring(after));
		end);
	end;
end;




do 
	function bindHealthWatch()
		local character = LocalPlayer.Character;

		if (not character) then return end;

		local humanoid = character:FindFirstChildOfClass('Humanoid');

		if (not humanoid or humanoid == healthHumanoid) then return end;

		healthHumanoid = humanoid;
		lastHealth = humanoid.Health;

		maid.healthWatch = humanoid.HealthChanged:Connect(function(health)
			local damage = lastHealth - health;

			lastHealth = health;

			if (damage > 0.5) then
				onHealthDrop(damage);
			end;
		end);

		
		for _, attribute in next, {'Stunned', 'CantAnything'} do
			maid['stun_' .. attribute] = character:GetAttributeChangedSignal(attribute):Connect(function()
				if (character:GetAttribute(attribute) == true) then
					probeParryBuffer(character);
				end;
			end);
		end;
	end;
end;




do 
	
	local IGNORE_ROOTS = {FX = true, Traffic = true};

	function isIgnored(model)
		local root = model;

		while (root and root.Parent and root.Parent ~= Workspace) do
			root = root.Parent;
		end;

		return root ~= nil and IGNORE_ROOTS[root.Name] == true;
	end;

	function bindHumanoid(record, character, humanoid)
		record.humanoid = humanoid;
		record.lastHealth = humanoid.Health;

		record.maid.animation = humanoid.AnimationPlayed:Connect(function(track)
			animStats.seen += 1;

			local ok, err = pcall(handleSwing, character, track);

			if (not ok and getFlag('debugLog', false)) then
				warn('[Gakuran] handleSwing: ' .. tostring(err));
			end;
		end);

		
		record.maid.health = humanoid.HealthChanged:Connect(function(health)
			local damage = record.lastHealth - health;

			record.lastHealth = health;

			if (damage > 0.5) then
				obsDamage(character.Name, damage);

				
				if (getFlag('hitSoundFallback', false)
					and Players:GetPlayerFromCharacter(character)
					and hitIsMine(character)) then
					pcall(playHitSound);
				end;
			end;
		end);
	end;

	function watchCharacter(character)
		if (isStale()) then return end;
		if (not character or watched[character]) then return end;
		if (character == myChar()) then return end;

		local isPlayer = Players:GetPlayerFromCharacter(character) ~= nil;

		
		
		if (not isPlayer and character:GetAttribute('CanFight') == nil) then return end;

		local humanoid = character:FindFirstChildOfClass('Humanoid');

		if (not humanoid) then return end;

		watchIndex += 1;

		local record = {
			id = watchIndex,
			maid = Maid.new(),
			humanoid = humanoid,
			lastHealth = humanoid.Health,
		};

		watched[character] = record;

		
		maid['watch' .. record.id] = function()
			record.maid:Destroy();
		end;

		bindHumanoid(record, character, humanoid);

		
		record.maid.childAdded = character.ChildAdded:Connect(function(child)
			if (not child:IsA('Humanoid')) then return end;

			bindHumanoid(record, character, child);
		end);

		
		record.maid.ancestry = character.AncestryChanged:Connect(function()
			if (not character:IsDescendantOf(game)) then
				unwatchCharacter(character);
			end;
		end);
	end;

	function unwatchCharacter(character)
		local record = watched[character];

		if (not record) then return end;

		watched[character] = nil;
		maid['watch' .. record.id] = nil;
	end;

	function watchContainer(folder)
		if (not folder) then return end;

		for _, child in next, folder:GetChildren() do
			watchCharacter(child);
		end;

		maid['container' .. folder.Name .. 'Added'] = folder.ChildAdded:Connect(function(child)
			task.defer(watchCharacter, child);
		end);

		maid['container' .. folder.Name .. 'Removed'] = folder.ChildRemoved:Connect(unwatchCharacter);
	end;

	
	
	function ensureNpcScan()
		if (not getFlag('parryNpcs', true)) then return end;
		if (maid.npcScan) then return end;

		local me = myChar();

		for _, descendant in next, Workspace:GetDescendants() do
			if (not descendant:IsA('Humanoid') or not descendant.Parent) then continue end;

			local model = descendant.Parent;

			if (model == me or watched[model]) then continue end;
			if (Players:GetPlayerFromCharacter(model)) then continue end;
			if (isIgnored(model)) then continue end;

			watchCharacter(model);
		end;

		maid.npcScan = Workspace.DescendantAdded:Connect(function(instance)
			if (not getFlag('parryNpcs', true)) then return end;
			if (not instance:IsA('Humanoid')) then return end;

			local model = instance.Parent;

			if (not model or model == me or watched[model]) then return end;
			if (Players:GetPlayerFromCharacter(model)) then return end;
			if (isIgnored(model)) then return end;

			watchCharacter(model);
		end);
	end;

	function hookAll()
		local playersFolder = Workspace:FindFirstChild('Players');

		if (playersFolder) then
			watchContainer(playersFolder);
		else
			log('找不到 Workspace.Players');
		end;

		
		watchContainer(Workspace:FindFirstChild('NPCs'));

		ensureNpcScan();
	end;
end;




do 
	function functions.autoParry(toggle)
		if (not toggle) then
			
			if (autoParryForcedCooldown) then
				autoParryForcedCooldown = false;

				if (library.flags.noParryCooldown ~= true) then
					pcall(Lab.setNoParryCooldown, false);
				end;
			end;

			autoParryForcedSelfBlock = false;

			maid:Destroy();

			table.clear(watched);
			table.clear(recentSwings);
			table.clear(OBS.swings);

			watchIndex = 0;
			healthHumanoid = nil;
			lastHealth = 0;
			lastBlockAt = 0;
			lastScheduleAt = 0;
			lastStanceTry = 0;
			lastStanceScan = 0;
			lastSkip = nil;

			return;
		end;

		if (isStale()) then return end;

		
		
		
		if (library.flags.noParryCooldown ~= true) then
			autoParryForcedCooldown = true;

			pcall(Lab.setNoParryCooldown, true);
		end;

		
		if (library.flags.selfAttackBlock ~= true) then
			autoParryForcedSelfBlock = true;
		end;

		table.clear(recentSwings);
		table.clear(OBS.swings);

		bindHealthWatch();

		maid.characterAdded = LocalPlayer.CharacterAdded:Connect(function()
			task.delay(1, bindHealthWatch);
		end);

		
		
		local stanceLoopAt = 0;

		maid.stanceLoop = RunService.Heartbeat:Connect(function()
			if (not isEnabled()) then return end;
			if (not getFlag('autoStance', true)) then return end;

			local now = os.clock();

			if (now - stanceLoopAt < 0.15) then return end;

			stanceLoopAt = now;

			ensureStance();
		end);

		hookAll();

		log('Auto Parry 已启动：动画 %d 个，监听角色 %d 个', ANIM_COUNT, countTable(watched));

		
		ToastNotif.new({
			text = 'Gakuran 自动弹反已开启',
			duration = 4,
		});
	end;

	
	function functions.parryNpcs(toggle)
		if (not toggle) then return end;

		ensureNpcScan();
	end;

	
	local function saveWhitelist()
		if (library.hasInit) then
			library:UpdateConfig();
		end;
	end;

	function functions.addWhitelist()
		local player = library.flags.parryWhitelistPlayers;

		if (typeof(player) ~= 'Instance') then
			

			return;
		end;

		if (CONFIG.whitelist[player.Name]) then
			ToastNotif.new({ text = string.format('%s 已在白名单里', player.Name), duration = 3 });

			return;
		end;

		local entries = library.configVars.parryWhitelist;

		if (type(entries) ~= 'table') then
			entries = {};
			library.configVars.parryWhitelist = entries;
		end;

		table.insert(entries, { id = player.UserId, name = player.Name });

		CONFIG.whitelist[player.Name] = true;
		library.options.parryWhitelistedPlayers:AddValue(player.Name);

		saveWhitelist();

		log('白名单 +%s（共 %d 人）', player.Name, countTable(CONFIG.whitelist));

		
	end;

	function functions.removeWhitelist()
		local name = library.flags.parryWhitelistedPlayers;

		if (type(name) ~= 'string' or name == '') then
			

			return;
		end;

		library.options.parryWhitelistedPlayers:RemoveValue(name);

		CONFIG.whitelist[name] = nil;

		local entries = library.configVars.parryWhitelist;

		if (type(entries) == 'table') then
			for index = #entries, 1, -1 do
				local entry = entries[index];

				if (type(entry) == 'table' and entry.name == name) then
					table.remove(entries, index);
				end;
			end;
		end;

		saveWhitelist();

		log('白名单 -%s（剩 %d 人）', name, countTable(CONFIG.whitelist));

		
	end;

	
	function restoreWhitelist()
		local option = library.options.parryWhitelistedPlayers;
		local entries = library.configVars.parryWhitelist;

		if (not option or type(entries) ~= 'table') then return end;

		for _, entry in next, entries do
			local name = type(entry) == 'table' and entry.name or entry;

			if (type(name) == 'string' and name ~= '' and not CONFIG.whitelist[name]) then
				CONFIG.whitelist[name] = true;
				option:AddValue(name);
			end;
		end;
	end;

	function functions.printStats()
		local lines = {
			string.format('攻击动画：%d 个', ANIM_COUNT),
			string.format('监听角色：%d 个', countTable(watched)),
			string.format('弹反成功：%d 次', parryCount),
			string.format('格挡尝试：%d 次 / 跳过 %d 次%s', stats.attempt, stats.skip, lastSkip and ('（' .. lastSkip .. '）') or ''),
			string.format('已校准流派：%d 个', countTable(LEARNED)),
			string.format('玩家比例：%.2f    NPC 比例：%.2f', SCALE.player.s, SCALE.npc.s),
		};

		
		local REASON_NAMES = {
			selfatk = '自己正在出手',
			selfatk_dodged = '出手时已用闪避躲开',
			cooldown = '本地格挡冷却中',
			blkcd = '游戏格挡冷却属性',
			srvcd = '服务端冷却未过',
			range = '距离过远',
			facing = '不在正面',
			notaimed = '不是冲我来的',
			dedupe = '多刀同时按去重',
			whitelist = '白名单',
			playeroff = '弹反玩家已关闭',
			npcoff = '弹反 NPC 已关闭',
			cantfight = '目标不会出招',
			nowindow = '当前无弹反窗口',
			notplaying = '动画已提前结束',
			grapple = '抓取招式改为后撤',
		};

		local reasonRows = {};

		for reason, count in next, (stats.reasons or {}) do
			if (count > 0) then
				reasonRows[#reasonRows + 1] = { reason = tostring(reason), count = count };
			end;
		end;

		table.sort(reasonRows, function(a, b) return a.count > b.count end);

		if (#reasonRows > 0) then
			table.insert(lines, '--- 没挡下来的原因（次数） ---');

			for index = 1, math.min(12, #reasonRows) do
				local row = reasonRows[index];
				local key = row.reason:match('^[%w_]+') or row.reason;
				local label = REASON_NAMES[key] or row.reason;

				table.insert(lines, string.format('  %-16s %-14s %d', row.reason, label, row.count));
			end;
		end;

		
		
		
		local wrongRows = {};

		for reason, count in next, (stats.wrongReject or {}) do
			if (tonumber(count) and tonumber(count) > 0) then
				wrongRows[#wrongRows + 1] = { reason = tostring(reason), count = tonumber(count) };
			end;
		end;

		table.sort(wrongRows, function(a, b) return a.count > b.count end);

		local wrongTotal = 0;

		for _, row in next, wrongRows do
			wrongTotal += row.count;
		end;

		if (wrongTotal > 0) then
			table.insert(lines, '--- 过滤误杀（其实打到了我，却被本地拒掉）---');
			table.insert(lines, string.format('  合计 %d 刀', wrongTotal));

			for index = 1, math.min(8, #wrongRows) do
				local row = wrongRows[index];
				local key = row.reason:match('^[%w_]+') or row.reason;
				local label = REASON_NAMES[key] or row.reason;

				table.insert(lines, string.format('  %-16s %-14s %d', row.reason, label, row.count));
			end;

			if (stats.wrongRejectMaxDist) then
				table.insert(lines, string.format('  误杀最远 %.1f 格（parryMaxRange 当前 %s）',
					stats.wrongRejectMaxDist, tostring(getFlag('parryMaxRange', 22))));
			end;
		end;

		local text = table.concat(lines, '\n');

		print('[Gakuran]\n' .. text);

		
	end;

	function functions.rebuildAnimMap()
		ANIM_COUNT = buildAnimMap();

		log('动画表已重建：%d 个', ANIM_COUNT);

		
		
		
		
	end;
end;








do 
	local bypassFlyEnabled = false;
	local tempSeat, seatPart, seatWasAnchored, manualWeld;

	local function getCharacter()
		local character = LocalPlayer.Character;

		return character, character and character:FindFirstChildOfClass('Humanoid'), character and character:FindFirstChild('HumanoidRootPart');
	end;

	local function clearManualWeld()
		if (manualWeld) then
			pcall(function() manualWeld:Destroy() end);
			manualWeld = nil;
		end;
	end;

	local function detach()
		clearManualWeld();

		if (tempSeat) then
			pcall(function() tempSeat:Destroy() end);
			tempSeat = nil;
		elseif (seatPart and seatWasAnchored ~= nil) then
			pcall(function() seatPart.Anchored = seatWasAnchored end);
		end;

		seatPart = nil;
		seatWasAnchored = nil;

		local _, humanoid = getCharacter();

		if (humanoid) then
			pcall(function()
				humanoid.Sit = false;
				humanoid:ChangeState(Enum.HumanoidStateType.Running);
			end);
		end;
	end;

	local function attach()
		local character, humanoid, rootPart = getCharacter();

		if (not (humanoid and rootPart)) then return false end;

		
		if (humanoid.SeatPart) then
			seatPart = humanoid.SeatPart;
			seatWasAnchored = seatPart.Anchored;

			return true;
		end;

		
		tempSeat = Instance.new('Seat');

		tempSeat.Name = 'VluaBypassSeat';
		tempSeat.Size = Vector3.new(1.6, 0.3, 1.6);
		tempSeat.Transparency = 0.85;
		tempSeat.Color = Color3.fromRGB(143, 143, 240);
		tempSeat.Anchored = false;
		tempSeat.CanCollide = false;
		tempSeat.CanTouch = false;
		tempSeat.Massless = true;
		tempSeat.CFrame = CFrame.new(rootPart.Position - Vector3.new(0, (rootPart.Size.Y + 0.3) / 2, 0));
		tempSeat.Parent = Workspace;

		seatPart = tempSeat;
		seatWasAnchored = false;

		return true;
	end;

	
	local function ensureSeated()
		local character, humanoid, rootPart = getCharacter();

		if (not (humanoid and rootPart and seatPart)) then return end;

		if (humanoid.SeatPart ~= seatPart) then
			if (not (manualWeld and manualWeld.Parent)) then
				manualWeld = Instance.new('Weld');

				manualWeld.Name = 'SeatWeld';
				manualWeld.Part0 = seatPart;
				manualWeld.Part1 = rootPart;
				manualWeld.C0 = CFrame.new(0, (seatPart.Size.Y + rootPart.Size.Y) / 2, 0);
				manualWeld.Parent = rootPart;
			end;

			pcall(function()
				humanoid.Sit = true;
				humanoid:ChangeState(Enum.HumanoidStateType.Seated);
			end);
		end;
	end;

	
	getgenv().__gakuranSeatPart = function()
		return seatPart;
	end;

	function functions.seatFly(toggle)
		bypassFlyEnabled = toggle and true or false;

		if (not bypassFlyEnabled) then
			detach();

			return;
		end;

		if (not seatPart) and (not attach()) then
			
			
			
			return;
		end;

		ensureSeated();
	end;

	local UIS = game:GetService('UserInputService');

	
	local function hasFlyInput()
		local ok, down = pcall(function()
			return UIS:IsKeyDown(Enum.KeyCode.W)
				or UIS:IsKeyDown(Enum.KeyCode.A)
				or UIS:IsKeyDown(Enum.KeyCode.S)
				or UIS:IsKeyDown(Enum.KeyCode.D)
				or UIS:IsKeyDown(Enum.KeyCode.Space)
				or UIS:IsKeyDown(Enum.KeyCode.LeftControl);
		end);

		return (ok and down) and true or false;
	end;

	
	
	library:AddConnection(LocalPlayer.CharacterAdded, function()
		if (not bypassFlyEnabled) then return end;

		detach();

		task.defer(function()
			if (bypassFlyEnabled and attach()) then
				ensureSeated();
			end;
		end);
	end);

	
	library:AddConnection(RunService.RenderStepped, function()
		if (not bypassFlyEnabled) then return end;

		if (not seatPart or not seatPart.Parent) then
			seatPart = nil;

			if (not attach()) then return end;
		end;

		
		
		
		local _, _, rootPart = getCharacter();

		if (rootPart and seatPart and seatPart.Parent) then
			if ((seatPart.Position - rootPart.Position).Magnitude > 60) then
				detach();

				if (not attach()) then return end;
			end;
		end;

		ensureSeated();

		
		
		
		
		if (tempSeat and tempSeat.Parent) then
			local wantAnchored = not hasFlyInput();

			if (tempSeat.Anchored ~= wantAnchored) then
				pcall(function()
					tempSeat.Anchored = wantAnchored;
				end);
			end;
		end;
	end);
end;








do 
	local STEP_HEIGHT = 140;
	local MAX_STEPS = 24;

	local function clickDeathHeart()
		local playerGui = LocalPlayer:FindFirstChildOfClass('PlayerGui');
		local deathUI = playerGui and playerGui:FindFirstChild('DeathUI');

		if (not (deathUI and deathUI.Enabled)) then return false end;

		local clicked = false;

		for _, descendant in next, deathUI:GetDescendants() do
			if (descendant:IsA('TextButton') or descendant:IsA('ImageButton')) then
				local ok, connections = pcall(getconnections, descendant.MouseButton1Click);

				if (ok and type(connections) == 'table') then
					for _, connection in next, connections do
						if (connection.Enabled) then
							pcall(function() connection:Fire() end);
							clicked = true;
						end;
					end;
				end;
			end;
		end;

		return clicked;
	end;

	function functions.respawn()
		
		local trace = { step = 'entry' };

		getgenv().__gakuranRespawn = trace;

		local character = LocalPlayer.Character;
		local humanoid = character and character:FindFirstChildOfClass('Humanoid');
		local rootPart = character and character:FindFirstChild('HumanoidRootPart');

		if (not (character and humanoid and rootPart)) then
			trace.step = 'no-character';

			return;
		end;

		
		if (humanoid.Health <= 0) then
			trace.step = 'dead-path';

			clickDeathHeart();

			return;
		end;

		
		
		
		
		local destroyHeight = workspace.FallenPartsDestroyHeight;
		local floorHeight = (type(destroyHeight) == 'number') and destroyHeight or -500;
		local origin = rootPart.Position;
		local target = Vector3.new(origin.X, floorHeight + 60, origin.Z);

		trace.step = 'writing';
		trace.from = math.floor(origin.Y);
		trace.to = math.floor(target.Y);

		local ok, err = pcall(function()
			rootPart.AssemblyLinearVelocity = Vector3.zero;
			rootPart.AssemblyAngularVelocity = Vector3.zero;
			rootPart.CFrame = CFrame.new(target);
		end);

		trace.ok = tostring(ok);
		trace.err = tostring(err):sub(1, 80);
		trace.afterY = math.floor(rootPart.Position.Y);
		trace.step = ok and 'wrote' or 'write-failed';

		if (not ok) then
			return;
		end;

		
		task.delay(0.25, function()
			local current = LocalPlayer.Character;

			if (not current) then return end;

			local currentHumanoid = current:FindFirstChildOfClass('Humanoid');
			local currentRoot = current:FindFirstChild('HumanoidRootPart');

			if (not (currentRoot and currentHumanoid)) then return end;
			if (currentHumanoid.Health <= 0) then return end;

			pcall(function()
				currentRoot.AssemblyLinearVelocity = Vector3.zero;
				currentRoot.CFrame = CFrame.new(target);
				currentRoot.AssemblyLinearVelocity = Vector3.new(0, -300, 0);
			end);
		end);
	end;

	
	local autoToken = 0;

	function functions.autoRespawn(toggle)
		autoToken += 1;

		local token = autoToken;

		if (not toggle) then return end;

		task.spawn(function()
			while (autoToken == token) do
				pcall(clickDeathHeart);

				task.wait(0.2);
			end;
		end);
	end;
end;










do 
	local autoAttackEnabled = false;
	local autoHeavyEnabled = false;

	local lastAttackAt = 0;
	local lastHeavyAt = 0;
	local swingIndex = 0;

	local sendOk = 0;
	local sendFail = 0;
	local lastError = '';

	local serverRemote;

	local function getServerRemote()
		if (serverRemote and serverRemote.Parent) then
			return serverRemote;
		end;

		local remotes = ReplicatedStorage:FindFirstChild('Remotes');

		serverRemote = remotes and remotes:FindFirstChild('Server');

		return serverRemote;
	end;

	function functions.autoAttack(toggle)
		autoAttackEnabled = toggle and true or false;
		lastAttackAt = 0;
		swingIndex = 0;
	end;

	function functions.autoHeavy(toggle)
		autoHeavyEnabled = toggle and true or false;
		lastHeavyAt = 0;
	end;

	local function canSwing(character, humanoid)
		if (humanoid.Health <= 0) then return false end;
		if (character:GetAttribute('Ragdoll') or character:GetAttribute('Downed')) then return false end;
		if (character:GetAttribute('CantAnything')) then return false end;
		if (character:GetAttribute('Equip') ~= true) then return false end;
		if (character:GetAttribute('Blocking') == true) then return false end;
		if (humanoid.Sit or humanoid.PlatformStand) then return false end;

		return true;
	end;

	
	
	local function fireRemoteFunc(action, func, extraArg)
		local remote = getServerRemote();

		if (not remote) then
			lastError = 'no remote';

			return false;
		end;

		local ok, err = pcall(function()
			local payload = {
				Type = 'Combat',
				Action = action,
				Func = func,
			};

			if (extraArg == nil) then
				remote:FireServer(payload);
			else
				remote:FireServer(payload, extraArg);
			end;
		end);

		if (not ok) then
			lastError = tostring(err):sub(1, 80);

			return false;
		end;

		sendOk += 1;

		return true;
	end;

	local function fireRemote(action, extraArg)
		return fireRemoteFunc(action, 'HoldActivated', extraArg);
	end;

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	local suppressor = nil;

	local function isCombatTrack(track)
		
		
		
		
		
		
		
		local weight = tonumber(track.WeightTarget);

		if (weight and weight <= 0) then
			return false;
		end;

		local name = tostring(track.Name);

		
		if (name == 'Animation') then return true end;

		local anim = track.Animation;

		if (not anim) then return false end;

		local id = tostring(anim.AnimationId):match('%d+');

		if (not id) then return false end;

		return ANIM[id] ~= nil;
	end;

	local function stopCombatTrack(track)
		if (not isCombatTrack(track)) then return end;

		
		task.defer(function()
			pcall(function()
				track:Stop(0);
				track:Destroy();
			end);
		end);
	end;

	local function refreshSuppressor()
		
		
		
		local wanted = (getFlag('antiAutoParry', false) == true);

		local character = LocalPlayer.Character;
		local humanoid = character and character:FindFirstChildOfClass('Humanoid');
		local animator = humanoid and humanoid:FindFirstChildOfClass('Animator');

		if (wanted and animator) then
			if (suppressor) then
				
				local okOld = pcall(function()
					if (suppressor.Connected) then return true end;

					return false;
				end);

				if (not okOld) then
					suppressor = nil;
				end;
			end;

			if (not suppressor) then
				suppressor = animator.AnimationPlayed:Connect(stopCombatTrack);
			end;
		elseif (suppressor) then
			pcall(function()
				suppressor:Disconnect();
			end);

			suppressor = nil;
		end;
	end;

	library.unloadMaid:GiveTask(function()
		if (suppressor) then
			pcall(function()
				suppressor:Disconnect();
			end);

			suppressor = nil;
		end;
	end);

	local function fireM1()
		swingIndex += 1;

		
		
		local activated = fireRemoteFunc('M1', 'HoldActivated');

		task.delay(0.08, function()
			fireRemoteFunc('M1', 'HoldDeactivated');
		end);

		if (activated) then
			return true;
		end;

		sendFail += 1;
		pcall(function() mouse1click() end);

		return false;
	end;

	local function fireM2()
		local activated = fireRemoteFunc('M2', 'HoldActivated');

		task.delay(0.08, function()
			fireRemoteFunc('M2', 'HoldDeactivated');
		end);

		if (activated) then
			return true;
		end;

		sendFail += 1;
		pcall(function() mouse2click() end);

		return false;
	end;

	getgenv().__gakuranAutoAttack = {
		sendOk = 0,
		sendFail = 0,
		remote = 'pending',
		lastError = '',
		swingIndex = 0,
	};

	
	getgenv().__gakuranTargetProbe = {
		parts = 0,
		models = 0,
		hit = 'none',
		lastModel = 'none',
		calls = 0,
		matches = 0,
		lastMatch = 'none',
	};

	library:AddConnection(RunService.Heartbeat, function()
		
		refreshSuppressor();

		
		local sandbag = getFlag('punchingBagMode', false);

		if (not (autoAttackEnabled or autoHeavyEnabled or sandbag)) then return end;

		local character = LocalPlayer.Character;
		local humanoid = character and character:FindFirstChildOfClass('Humanoid');

		if (not (character and humanoid)) then return end;
		if (not canSwing(character, humanoid)) then return end;

		local now = os.clock();

		
		
		if ((autoAttackEnabled or sandbag) and now - lastAttackAt >= (getFlag('autoAttackInterval', 0.35) or 0.35)) then
			if (sandbag) then
				lastAttackAt = now;

				fireM1();
			else
				local attackRange = getFlag('autoAttackRange', 12);

				if (targetInFront(attackRange)) then
					lastAttackAt = now;

					fireM1();
				end;
			end;
		end;

		if (autoHeavyEnabled and now - lastHeavyAt >= (getFlag('autoHeavyInterval', 1.2) or 1.2)) then
			if (sandbag) then
				lastHeavyAt = now;

				fireM2();
			else
				local heavyRange = getFlag('autoHeavyRange', 14);

				if (targetInFront(heavyRange)) then
					lastHeavyAt = now;

					fireM2();
				end;
			end;
		end;

		local mirror = getgenv().__gakuranAutoAttack;

		if (mirror) then
			mirror.sendOk = sendOk;
			mirror.sendFail = sendFail;
			mirror.remote = (getServerRemote() and 'ready') or 'missing';
			mirror.lastError = lastError;
			mirror.swingIndex = swingIndex;
		end;
	end);
end;








do 
	local awakeningWindow;

	local STYLE_NAMES = {
		boxing = '拳击', karate = '空手道', taijutsu = '体术', wrestling = '摔角',
		muaythai = '泰拳', lethwei = '缅拳', hakari = '羽刈', jin = '仁',
	};

	local function collectAwakening()
		local rows = {};

		for key, value in next, LocalPlayer:GetAttributes() do
			local name = tostring(key);
			local stageStyle = name:match('^AwakeningStage_(.+)$');
			local progressStyle = name:match('^AwakeningProgress_(.+)$');

			if (stageStyle) then
				rows[stageStyle] = rows[stageStyle] or { stage = 0, progress = 0 };
				rows[stageStyle].stage = tonumber(value) or 0;
			elseif (progressStyle) then
				rows[progressStyle] = rows[progressStyle] or { stage = 0, progress = 0 };
				rows[progressStyle].progress = tonumber(value) or 0;
			end;
		end;

		return rows;
	end;

	function functions.awakeningView()
		
		if (awakeningWindow) then
			local gui = awakeningWindow._gui;
			local alive = gui and gui.Parent ~= nil;

			if (alive) then
				pcall(function() gui:Destroy() end);

				awakeningWindow = nil;

				return;
			end;

			
			awakeningWindow = nil;
		end;

		local rows = collectAwakening();
		local order = {};

		for style in next, rows do
			order[#order+1] = style;
		end;

		table.sort(order, function(a, b)
			local left, right = rows[a], rows[b];

			if (left.stage ~= right.stage) then
				return left.stage > right.stage;
			end;

			return left.progress > right.progress;
		end);

		awakeningWindow = TextLogger.new({
			title = '觉醒进度',
			buttons = { 'Copy Text' },
		});

		
		pcall(function() awakeningWindow:SetVisible(true) end);

		task.defer(function()
			pcall(function() awakeningWindow:SetVisible(true) end);
			pcall(function() awakeningWindow:Center() end);
		end);

		library.unloadMaid:GiveTask(function()
			if (awakeningWindow) then
				pcall(function()
					if (awakeningWindow._gui) then
						awakeningWindow._gui:Destroy();
					end;
				end);

				awakeningWindow = nil;
			end;
		end);

		if (#order == 0) then
			awakeningWindow:AddText({ text = '没有找到觉醒数据（可能还没解锁任何流派）' });

			return;
		end;

		for _, style in next, order do
			local record = rows[style];
			local label = STYLE_NAMES[style] or style;
			local accent = (record.progress > 0) and '7FE7FF' or 'C8CEDB';

			awakeningWindow:AddText({
				text = string.format(
					'<font color="#%s">%s</font>  <font color="#%s">%s</font>   阶段 <font color="#8F8FF0">%d</font>   进度 <font color="#7FE7FF">%d</font>',
					accent, style, '6E7686', label, record.stage, record.progress
				),
			});
		end;
	end;
end;

do 
	local sprintAlways = false;	local sprintWhenInjured = false;
	local sprintActive = false;

	
	local sprintMinWalk, sprintMinAt, sprintMinReason, sprintMinState, sprintMirrorAt;

	local runTrack, runTrackId;

	local function isInjured(humanoid)
		return humanoid.MaxHealth > 0 and (humanoid.Health / humanoid.MaxHealth) <= 0.5;
	end;

	
	local BLOCK_ATTRS = { 'Stunned', 'CantAnything', 'Ragdoll', 'Downed', 'GuardBroken' };

	local BLOCKED_STATES = {
		[Enum.HumanoidStateType.Seated] = true,
		[Enum.HumanoidStateType.GettingUp] = true,
		[Enum.HumanoidStateType.FallingDown] = true,
		[Enum.HumanoidStateType.Physics] = true,
		[Enum.HumanoidStateType.Dead] = true,
	};

	local function canRun(character, humanoid)
		for _, attribute in next, BLOCK_ATTRS do
			if (character:GetAttribute(attribute) == true) then
				return false, attribute;
			end;
		end;

		if (humanoid.Sit) then return false, 'sit' end;
		if (humanoid.PlatformStand) then return false, 'platform' end;

		local state = humanoid:GetState();

		if (BLOCKED_STATES[state]) then
			return false, tostring(state):gsub('Enum.HumanoidStateType.', '');
		end;

		if (humanoid.Health <= 0) then return false, 'dead' end;

		return true, 'ok';
	end;

	local function getRunAnimation(character)
		local animations = ReplicatedStorage:FindFirstChild('Animations');
		local movement = animations and animations:FindFirstChild('Movement');

		if (not movement) then return nil end;

		local playerData = character:FindFirstChild('PlayerData');
		local gender = playerData and playerData:GetAttribute('Gender');
		local name = (gender == 'Female') and 'FemaleRun' or 'MaleRun';

		return movement:FindFirstChild(name) or movement:FindFirstChild('MaleRun');
	end;

	local function stopRunTrack()
		if (runTrack) then
			pcall(function() runTrack:Stop() end);
		end;
	end;

	local function playRunTrack(character, humanoid)
		local animation = getRunAnimation(character);

		if (not animation) then return end;

		if (runTrack and runTrackId == animation.AnimationId) then
			if (not runTrack.IsPlaying) then
				pcall(function() runTrack:Play(0.1) end);
			end;

			return;
		end;

		stopRunTrack();

		local animator = humanoid:FindFirstChildOfClass('Animator');

		if (not animator) then return end;

		
		
		local okLoad, track = pcall(animator.LoadAnimation, animator, animation);

		if (not okLoad or not track) then
			runTrackId = animation.AnimationId;

			return;
		end;

		runTrack = track;
		runTrackId = animation.AnimationId;
		runTrack.Looped = true;
		runTrack.Priority = Enum.AnimationPriority.Action;

		pcall(function() runTrack:Play(0.1) end);
	end;

	function functions.alwaysSprint(toggle)
		sprintAlways = toggle and true or false;

		if (not sprintAlways) then
			sprintActive = false;
			stopRunTrack();
		end;
	end;

	function functions.injuredSprint(toggle)
		sprintWhenInjured = toggle and true or false;
	end;

	library:AddConnection(RunService.RenderStepped, function()
		local character = LocalPlayer.Character;
		local humanoid = character and character:FindFirstChildOfClass('Humanoid');
		local rootPart = character and character:FindFirstChild('HumanoidRootPart');

		if (not (humanoid and rootPart)) then
			stopRunTrack();

			return;
		end;

		local shouldRun = sprintAlways or (sprintWhenInjured and humanoid.Health > 0 and isInjured(humanoid));
		local moving = humanoid.MoveDirection.Magnitude > 0.1;

		
		local allowed, blockReason = canRun(character, humanoid);

		
		
		
		if (allowed) then
			local walkNow = humanoid.WalkSpeed;

			if (character:GetAttribute('Blocking') == true) then
				allowed, blockReason = false, 'blocking';
			elseif (walkNow > 0.2 and walkNow < 11) then
				allowed, blockReason = false, 'slowed';
			end;
		end;

		if (not allowed) then
			shouldRun = false;
		end;

		
		local now = os.clock();

		local currentWalk = humanoid.WalkSpeed;

		if (currentWalk < (sprintMinWalk or math.huge)) then
			sprintMinWalk = currentWalk;
			sprintMinAt = now;
			sprintMinReason = blockReason;
			sprintMinState = tostring(humanoid:GetState()):gsub('Enum.HumanoidStateType.', '');
		end;

		if (now - (sprintMinAt or 0) > 5) then
			sprintMinWalk = currentWalk;
			sprintMinAt = now;
			sprintMinReason = blockReason;
			sprintMinState = tostring(humanoid:GetState()):gsub('Enum.HumanoidStateType.', '');
		end;

		if (now - (sprintMirrorAt or 0) > 0.25) then
			sprintMirrorAt = now;

			getgenv().__gakuranSprint = {
				active = sprintActive,
				shouldRun = shouldRun,
				moving = moving,
				reason = blockReason,
				walkSpeed = currentWalk,
				moveDir = humanoid.MoveDirection.Magnitude,
				state = tostring(humanoid:GetState()):gsub('Enum.HumanoidStateType.', ''),
				sprinting = character:GetAttribute('Sprinting'),
				minWalk = sprintMinWalk,
				minReason = sprintMinReason,
				minState = sprintMinState,
			};
		end;

		
		if (shouldRun and moving) then
			sprintActive = true;

			if (character:GetAttribute('Sprinting') ~= true) then
				character:SetAttribute('Sprinting', true);
			end;

			playRunTrack(character, humanoid);

			
			
			local speed = getFlag('sprintSpeed', 24);
			local direction = humanoid.MoveDirection;
			local velocity = rootPart.AssemblyLinearVelocity;

			rootPart.AssemblyLinearVelocity = Vector3.new(direction.X * speed, velocity.Y, direction.Z * speed);

			return;
		end;

		
		if (sprintActive) then
			sprintActive = false;

			stopRunTrack();

			pcall(function()
				character:SetAttribute('Sprinting', false);
			end);
		end;
	end);
end;






do 
	local SoundService = Services:Get('SoundService');
	local DEFAULT_SOUND = 'rbxasset://sounds/snap.mp3';

	local parrySound;

	
	local SOUND_PRESETS = {
		['默认（内置 snap）'] = DEFAULT_SOUND,
		['138564936113755'] = 'rbxassetid://138564936113755',
		['135478009117226'] = 'rbxassetid://135478009117226',
		['8132494511'] = 'rbxassetid://8132494511',
	};

	local function normalizeId(raw)
		if (type(raw) ~= 'string') then return nil end;

		raw = raw:gsub('%s', '');

		if (raw == '') then return nil end;
		if (raw:match('^%d+$')) then return 'rbxassetid://' .. raw end;

		return raw;
	end;

	local function resolveSoundId()
		
		local custom = normalizeId(getFlag('parrySoundId', ''));

		if (custom) then return custom end;

		local preset = getFlag('parrySoundPreset', '默认（内置 snap）');

		return SOUND_PRESETS[tostring(preset)] or DEFAULT_SOUND;
	end;

	function playParrySound(force)
		if (not force and not getFlag('parrySound', false)) then return end;

		local soundId = resolveSoundId();
		local volume = getFlag('parrySoundVolume', 1);

		if (not parrySound or parrySound.SoundId ~= soundId) then
			if (parrySound) then
				pcall(function() parrySound:Destroy() end);
			end;

			parrySound = Instance.new('Sound');

			parrySound.Name = 'VluaParrySound';
			parrySound.SoundId = soundId;
			parrySound.Parent = SoundService;

			
			task.spawn(function()
				pcall(function()
					Services:Get('ContentProvider'):PreloadAsync({ parrySound });
				end);
			end);

			library.unloadMaid:GiveTask(function()
				if (parrySound) then
					pcall(function() parrySound:Destroy() end);
					parrySound = nil;
				end;
			end);
		end;

		parrySound.Volume = volume;
		parrySound.TimePosition = 0;

		pcall(function()
			parrySound:Play();
		end);
	end;
end;








do 
	local SoundService = Services:Get('SoundService');
	local ContentProvider = Services:Get('ContentProvider');
	local DEFAULT_HIT_SOUND = 'rbxassetid://135478009117226';

	
	local HIT_SOUND_PRESETS = {
		{ label = '135478009117226', id = 'rbxassetid://135478009117226' },
		{ label = '139459336979009', id = 'rbxassetid://139459336979009' },
	};

	local hitSound;
	local lastHitSoundAt = 0;
	local lastMyAttackAt = 0;

	
	local hitDebug = { seen = 0, matched = 0, played = 0, lastId = '', lastReason = '' };

	local function pushHitDebug()
		getgenv().__gakuranHitSound = hitDebug;
	end;

	
	function markMyAttack()
		lastMyAttackAt = os.clock();
	end;

	function wasRecentMyAttack(window)
		return (os.clock() - lastMyAttackAt) < (window or 1.2);
	end;

	
	
	function hitIsMine(victim)
		if (not wasRecentMyAttack(0.6)) then return false end;

		local myRoot = myRootPart and myRootPart();
		local theirRoot = victim and victim:FindFirstChild('HumanoidRootPart');

		if (not (myRoot and theirRoot)) then return false end;

		local delta = theirRoot.Position - myRoot.Position;

		if (delta.Magnitude > 16) then return false end;
		if (delta:Dot(myRoot.CFrame.LookVector) <= 0) then return false end;

		return true;
	end;

	
	
	
	
	
	
	
	
	
	local npcCache = { at = 0, list = {} };

	local collectContainers = {};

	local function collectCharacters()
		local list = {};

		for _, player in next, Players:GetPlayers() do
			if (player ~= LocalPlayer) then
				local character = player.Character;

				if (character) then
					list[#list + 1] = character;
				end;
			end;
		end;

		if (os.clock() - npcCache.at > 0.5) then
			npcCache.at = os.clock();
			npcCache.list = {};

			
			local containers = collectContainers;
			table.clear(containers);
			containers[1] = workspace:FindFirstChild('Players');
			containers[2] = workspace:FindFirstChild('NPCs');
			containers[3] = ReplicatedStorage:FindFirstChild('__CharacterCullStorage');

			for _, container in next, containers do
				if (container) then
					for _, descendant in next, container:GetDescendants() do
						if (descendant:IsA('Humanoid')) then
							local model = descendant.Parent;

							if (model and model:IsA('Model')) then
								npcCache.list[#npcCache.list + 1] = model;
							end;
						end;
					end;
				end;
			end;
		end;

		for _, model in next, npcCache.list do
			list[#list + 1] = model;
		end;

		return list;
	end;

	function targetInFront(range)
		local myRoot = myRootPart and myRootPart();
		local character = myChar and myChar();

		if (not myRoot) then return false end;

		range = range or 14;

		local probe = getgenv().__gakuranTargetProbe;

		if (probe) then
			probe.calls = (probe.calls or 0) + 1;
		end;

		local look = myRoot.CFrame.LookVector;
		local myPosition = myRoot.Position;

		local candidates = collectCharacters();
		local seen = {};
		local checked = 0;

		for _, model in next, candidates do
			if (model and model ~= character and not seen[model]) then
				seen[model] = true;

				local humanoid = model:FindFirstChildOfClass('Humanoid');
				local targetRoot = model:FindFirstChild('HumanoidRootPart');

				if (humanoid and targetRoot and humanoid.Health > 0) then
					checked += 1;

					local delta = targetRoot.Position - myPosition;
					local distance = delta.Magnitude;

					if (distance > 0.5
						and distance <= range
						and math.abs(delta.Y) < range * 0.7
						and delta.Unit:Dot(look) > -0.3) then
						if (probe) then
							probe.models = checked;
							probe.hit = model.Name;
							probe.matches = (probe.matches or 0) + 1;
							probe.lastMatch = model.Name;
							probe.lastDistance = distance;
						end;

						return true;
					end;
				end;
			end;
		end;

		if (probe) then
			probe.models = checked;
			probe.hit = 'none';
		end;

		return false;
	end;

	
	
	function scheduleSwingHitSound() end;

	
	
	local movementAnimationIds = {};
	local hitSoundConnection;
	local hitSoundHumanoid;

	local function collectMovementAnimations()
		local animations = ReplicatedStorage:FindFirstChild('Animations');
		local movement = animations and animations:FindFirstChild('Movement');

		if (not movement) then return end;

		
		
		for _, descendant in next, movement:GetDescendants() do
			if (descendant:IsA('Animation')) then
				local id = tostring(descendant.AnimationId):match('%d+');

				if (id) then
					movementAnimationIds[id] = true;
				end;
			end;
		end;
	end;

	function bindHitSoundWatcher(character)
		local humanoid = character and character:FindFirstChildOfClass('Humanoid');

		if (not humanoid) then return end;

		if (hitSoundHumanoid == humanoid and hitSoundConnection) then return end;

		if (hitSoundConnection) then
			pcall(function() hitSoundConnection:Disconnect() end);
		end;

		pcall(collectMovementAnimations);

		hitSoundHumanoid = humanoid;
		hitSoundConnection = humanoid.AnimationPlayed:Connect(function(track)
			local animation = track.Animation;
			local id = animation and tostring(animation.AnimationId):match('%d+');

			if (not id) then return end;

			hitDebug.seen += 1;
			hitDebug.lastId = id;

			if (movementAnimationIds[id]) then
				hitDebug.lastReason = 'movement';
				pushHitDebug();

				return;
			end;

			if (track.Priority == Enum.AnimationPriority.Idle) then
				hitDebug.lastReason = 'idle';
				pushHitDebug();

				return;
			end;

			hitDebug.matched += 1;
			hitDebug.lastReason = 'scheduled';
			pushHitDebug();

			pcall(scheduleSwingHitSound, track);
		end);

		library.unloadMaid:GiveTask(function()
			if (hitSoundConnection) then
				pcall(function() hitSoundConnection:Disconnect() end);
				hitSoundConnection = nil;
			end;
		end);
	end;

	
	

	local lastHitSoundAt = 0;

	local function resolveHitSoundId()
		
		local raw = getFlag('hitSoundId', '');

		if (type(raw) == 'string') then
			raw = raw:gsub('%s', '');

			if (raw ~= '') then
				if (raw:match('^%d+$')) then
					return 'rbxassetid://' .. raw;
				end;

				return raw;
			end;
		end;

		local selected = tostring(getFlag('hitSoundPreset', '135478009117226'));

		for _, preset in next, HIT_SOUND_PRESETS do
			if (preset.label == selected) then
				return preset.id;
			end;
		end;

		return DEFAULT_HIT_SOUND;
	end;

	function playHitSound(force)
		
		if (not force and not getFlag('hitSound', false)) then return end;

		if (not force) then
			hitDebug.played += 1;
			hitDebug.lastReason = 'played';
			pushHitDebug();
		end;

		local now = os.clock();

		
		if (not force and now - lastHitSoundAt < 0.08) then return end;

		lastHitSoundAt = now;

		local soundId = resolveHitSoundId();
		local volume = getFlag('hitSoundVolume', 1);

		if (not hitSound or hitSound.SoundId ~= soundId) then
			if (hitSound) then
				pcall(function() hitSound:Destroy() end);
			end;

			hitSound = Instance.new('Sound');

			hitSound.Name = 'VluaHitSound';
			hitSound.SoundId = soundId;
			hitSound.Parent = SoundService;

			
			task.spawn(function()
				pcall(function()
					ContentProvider:PreloadAsync({ hitSound });
				end);
			end);

			library.unloadMaid:GiveTask(function()
				if (hitSound) then
					pcall(function() hitSound:Destroy() end);
					hitSound = nil;
				end;
			end);
		end;

		hitSound.Volume = volume;
		hitSound.TimePosition = 0;

		pcall(function()
			hitSound:Play();
		end);
	end;
end;

do 
	
	
	
	
	local params = RaycastParams.new();

	params.FilterType = Enum.RaycastFilterType.Exclude;
	params.IgnoreWater = true;
	params.RespectCanCollide = true;

	local smoothY;
	local currentFrame;
	local cachedY;
	local lastRootY;

	local SMOOTH_FACTOR = 0.12;
	local SNAP_STEP = 0.01;
	local DEAD_BAND = 0.06;
	local SURFACE_OFFSET = 0.01;
	local POSITION_GRID = 0.05;   

	function sampleGroundY(rootPart, character)
		local frameId = math.floor(os.clock() * 120);

		if (currentFrame == frameId and cachedY) then
			return cachedY;
		end;

		currentFrame = frameId;
		params.FilterDescendantsInstances = { character };

		local rootY = rootPart.Position.Y;

		
		
		
		local origin = Vector3.new(rootPart.Position.X, rootY, rootPart.Position.Z);
		local hit = Workspace:Raycast(origin, Vector3.new(0, -40, 0), params);

		
		if (not hit or hit.Position.Y > rootY - 0.2 or hit.Normal.Y < 0.3) then
			cachedY = cachedY or math.round((rootY - 2.6) / SNAP_STEP) * SNAP_STEP;

			return cachedY;
		end;

		local targetY = hit.Position.Y + SURFACE_OFFSET;

		if (not smoothY) then
			smoothY = targetY;
		else
			local diff = targetY - smoothY;

			if (math.abs(diff) > 6) then
				
				smoothY = targetY;
			elseif (math.abs(diff) > DEAD_BAND) then
				smoothY = smoothY + diff * SMOOTH_FACTOR;
			end;
		end;

		lastRootY = rootPart.Position.Y;
		cachedY = math.round(smoothY / SNAP_STEP) * SNAP_STEP;

		return cachedY;
	end;

	
	LocalPlayer.CharacterAdded:Connect(function()
		smoothY = nil;
		cachedY = nil;
		lastRootY = nil;
	end);
end;






do 
	local RANGE_COLOR = Color3.fromRGB(143, 143, 240);
	local RING_TRANSPARENCY = 0.55;
	local OUT_OF_RANGE_TRANSPARENCY = 0.93;   
	local RING_SEGMENTS = 40;
	local RING_THICKNESS = 0.18;
	local RING_HEIGHT = 0.05;

	
	local POSITION_GRID = 0.05;

	local visual = {
		folder = nil,
		segments = {},
		enabled = false,
		lastUpdate = 0,
		lastRadius = nil,
		lastCenter = nil,
		lastColor = nil,
		lastLook = nil,
	};

	getgenv().__gakuranParryRing = {
		radius = 0,
		scale = 1,
		flag = 0,
		updates = 0,
	};

	local function destroyVisual()
		local folder = visual.folder;

		visual.folder = nil;
		visual.segments = {};

		if (folder) then
			folder:Destroy();
		end;
	end;

	local function makePart(name, parent)
		local part = Instance.new('Part');

		part.Name = name;
		part.Anchored = true;
		part.CanCollide = false;
		part.CanQuery = false;
		part.CanTouch = false;
		part.CastShadow = false;
		part.TopSurface = Enum.SurfaceType.Smooth;
		part.BottomSurface = Enum.SurfaceType.Smooth;
		part.Parent = parent;

		return part;
	end;

	local function buildVisual()
		destroyVisual();

		
		
		local folder = Instance.new('Folder');

		folder.Name = 'VluaParryRangeRing';
		folder.Parent = Workspace;

		local segments = {};

		for index = 1, RING_SEGMENTS do
			local segment = makePart('Segment' .. index, folder);

			segment.Material = Enum.Material.Neon;
			segment.Color = RANGE_COLOR;
			segment.Transparency = RING_TRANSPARENCY;

			segments[index] = segment;
		end;

		visual.folder = folder;
		visual.segments = segments;
	end;

	local function effectiveRadius()
		local range = getFlag('parryMaxRange', 22);
		local character = LocalPlayer.Character;

		if (getFlag('heightReach', false) and character) then
			
			range *= stableHeightScale(character);
		end;

		
		return math.round(range / 0.05) * 0.05;
	end;

	local function hideVisual()
		for _, segment in next, visual.segments do
			segment.Transparency = 1;
		end;
	end;

	local function refreshVisual(force)
		if (not visual.folder) then return end;

		local character = LocalPlayer.Character;
		local rootPart = character and character:FindFirstChild('HumanoidRootPart');

		if (not rootPart) then
			hideVisual();

			return;
		end;

		local radius = effectiveRadius();
		local color = getFlag('parryRangeColor', RANGE_COLOR) or RANGE_COLOR;
		local colorChanged = (visual.lastColor ~= color);

		
		local groundY = sampleGroundY(rootPart, character);
		local center = Vector3.new(
			math.round(rootPart.Position.X / POSITION_GRID) * POSITION_GRID,
			groundY,
			math.round(rootPart.Position.Z / POSITION_GRID) * POSITION_GRID
		);

		
		local look = rootPart.CFrame.LookVector;
		local lookXZ = Vector3.new(look.X, 0, look.Z);

		if (lookXZ.Magnitude > 0.001) then
			lookXZ = lookXZ.Unit;
		else
			lookXZ = Vector3.new(0, 0, -1);
		end;

		local lookChanged = (not visual.lastLook) or (visual.lastLook:Dot(lookXZ) < 0.9995);

		
		if (not force and not colorChanged and not lookChanged and visual.lastRadius == radius
			and visual.lastCenter and (visual.lastCenter - center).Magnitude < 0.005) then
			return;
		end;

		visual.lastRadius = radius;
		visual.lastCenter = center;
		visual.lastColor = color;
		visual.lastLook = lookXZ;

		
		local ringMirror = getgenv().__gakuranParryRing;

		if (ringMirror) then
			ringMirror.radius = radius;
			ringMirror.scale = (getFlag('heightReach', false) and character and stableHeightScale(character)) or 1;
			ringMirror.flag = getFlag('parryMaxRange', 22);
			ringMirror.updates = (ringMirror.updates or 0) + 1;
		end;

		local facingEnabled = getFlag('requireFacing', true);

		local arcLength = (2 * math.pi * radius / RING_SEGMENTS) * 1.25;

		for index, segment in next, visual.segments do
			local angle = ((index - 1) / RING_SEGMENTS) * math.pi * 2;
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle));
			local offset = direction * radius;

			
			local inRange = (not facingEnabled) or (direction:Dot(lookXZ) > 0);

			segment.Size = Vector3.new(RING_THICKNESS, RING_HEIGHT, arcLength);
			segment.CFrame = CFrame.new(center + offset + Vector3.new(0, 0.012, 0)) * CFrame.Angles(0, -angle, 0);
			segment.Color = color;
			segment.Transparency = inRange and RING_TRANSPARENCY or OUT_OF_RANGE_TRANSPARENCY;
		end;
	end;

	function functions.parryRangeVisual(toggle)
		visual.enabled = toggle and true or false;

		if (visual.enabled) then
			if (not visual.folder) then
				buildVisual();

				
				if (not visual.unloadRegistered) then
					visual.unloadRegistered = true;

					library.unloadMaid:GiveTask(destroyVisual);
				end;
			end;

			refreshVisual(true);
		else
			destroyVisual();
		end;
	end;

	
	library:AddConnection(RunService.RenderStepped, function()
		if (not visual.enabled or not visual.folder) then return end;

		refreshVisual();
	end);
end;






do 
	local RING_SEGMENTS = 40;
	local RING_HEIGHT = 0.05;
	local RING_TRANSPARENCY = 0.55;
	local OUT_OF_RANGE_TRANSPARENCY = 0.93;
	local MOVE_EPSILON = 0.005;
	local LOOK_EPSILON = 0.9995;

	local rings = {
		attack = {
			enabled = false,
			parts = {},
			folder = nil,
			lastRadius = nil,
			lastCenter = nil,
			lastColor = nil,
			colorFlag = 'autoAttackRangeColor',
			defaultColor = Color3.fromRGB(120, 255, 190),
			rangeFlag = 'autoAttackRange',
			defaultRange = 12,
			thickness = 0.18,
			name = 'VluaAttackRangeRing',
		},
		heavy = {
			enabled = false,
			parts = {},
			folder = nil,
			lastRadius = nil,
			lastCenter = nil,
			lastColor = nil,
			colorFlag = 'autoHeavyRangeColor',
			defaultColor = Color3.fromRGB(255, 140, 120),
			rangeFlag = 'autoHeavyRange',
			defaultRange = 14,
			thickness = 0.22,
			name = 'VluaHeavyRangeRing',
		},
	};

	local function makeRingPart(parent)
		local part = Instance.new('Part');

		part.Name = 'Segment';
		part.Anchored = true;
		part.CanCollide = false;
		part.CanQuery = false;
		part.CanTouch = false;
		part.CastShadow = false;
		part.Material = Enum.Material.Neon;
		part.TopSurface = Enum.SurfaceType.Smooth;
		part.BottomSurface = Enum.SurfaceType.Smooth;
		part.Parent = parent;

		return part;
	end;

	local function destroyRing(ring)
		ring.lastRadius = nil;
		ring.lastCenter = nil;
		ring.lastColor = nil;

		if (ring.folder) then
			ring.folder:Destroy();

			ring.folder = nil;
		end;

		table.clear(ring.parts);
	end;

	local function buildRing(ring)
		destroyRing(ring);

		local folder = Instance.new('Folder');

		folder.Name = ring.name;
		folder.Parent = Workspace;

		ring.folder = folder;

		for index = 1, RING_SEGMENTS do
			ring.parts[index] = makeRingPart(folder);
		end;
	end;

	local function refreshRing(ring, rootPart, character, force)
		if (not ring.folder) then return end;

		local radius = getFlag(ring.rangeFlag, ring.defaultRange) or ring.defaultRange;
		local color = getFlag(ring.colorFlag, ring.defaultColor) or ring.defaultColor;

		local colorChanged = (ring.lastColor ~= color);

		
		local groundY = sampleGroundY(rootPart, character);
		local center = Vector3.new(
			math.round(rootPart.Position.X / 0.05) * 0.05,
			groundY + 0.012,
			math.round(rootPart.Position.Z / 0.05) * 0.05
		);

		local look = rootPart.CFrame.LookVector;
		local lookXZ = Vector3.new(look.X, 0, look.Z);

		if (lookXZ.Magnitude > 0.001) then
			lookXZ = lookXZ.Unit;
		else
			lookXZ = Vector3.new(0, 0, -1);
		end;

		local lookChanged = (not ring.lastLook) or (ring.lastLook:Dot(lookXZ) < LOOK_EPSILON);

		if (not force and ring.lastRadius == radius and not colorChanged and not lookChanged
			and ring.lastCenter and (ring.lastCenter - center).Magnitude < MOVE_EPSILON) then
			return;
		end;

		ring.lastRadius = radius;
		ring.lastColor = color;
		ring.lastCenter = center;
		ring.lastLook = lookXZ;

		local arcLength = (2 * math.pi * radius / RING_SEGMENTS) * 1.25;

		for index, part in next, ring.parts do
			local angle = ((index - 1) / RING_SEGMENTS) * math.pi * 2;
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle));
			local offset = direction * radius;

			local inRange = (direction:Dot(lookXZ) > -0.3);

			part.Size = Vector3.new(ring.thickness, RING_HEIGHT, arcLength);
			part.CFrame = CFrame.new(center + offset) * CFrame.Angles(0, -angle, 0);
			part.Color = color;
			part.Transparency = inRange and RING_TRANSPARENCY or OUT_OF_RANGE_TRANSPARENCY;
		end;
	end;

	local function setRingEnabled(key, toggle)
		local ring = rings[key];

		if (not ring) then return end;

		ring.enabled = toggle and true or false;

		if (ring.enabled) then
			if (not ring.folder) then
				buildRing(ring);

				library.unloadMaid:GiveTask(function()
					destroyRing(ring);
				end);
			end;

			pcall(function() ring.lastColor = Color3.new(-1, -1, -1) end); 
		else
			destroyRing(ring);
		end;
	end;

	function functions.attackRangeVisual(toggle)
		setRingEnabled('attack', toggle);
	end;

	function functions.heavyRangeVisual(toggle)
		setRingEnabled('heavy', toggle);
	end;

	library:AddConnection(RunService.RenderStepped, function()
		local attackRing = rings.attack;
		local heavyRing = rings.heavy;

		if (not (attackRing.enabled or heavyRing.enabled)) then return end;

		local character = LocalPlayer.Character;
		local rootPart = character and character:FindFirstChild('HumanoidRootPart');

		if (not rootPart) then return end;

		if (attackRing.enabled) then
			refreshRing(attackRing, rootPart, character);
		end;

		if (heavyRing.enabled) then
			refreshRing(heavyRing, rootPart, character);
		end;
	end);
end;





do 
	
	
	
	if (ACB.applied) then
		pcall(ACB.rollback);
	end;

	function functions.acbApply()
		ACB.apply(getFlag('acbAttackGain', true));
	end;

	
	function functions.acbAttackGain(toggle)
		if (not ACB.applied) then return end;

		ACB.setStealth(toggle);
	end;

	function functions.acbSpeed(toggle)
		ACB.setSpeed(toggle and getFlag('acbSpeedValue', 60) or nil);
	end;

	function functions.acbFly(toggle)
		ACB.setFly(toggle and getFlag('acbFlySpeed', 80) or nil);

		
		
		if (type(functions.seatFly) == 'function') then
			pcall(functions.seatFly, toggle);
		end;
	end;

	function functions.acbJump(toggle)
		ACB.setJump(toggle and getFlag('acbJumpHeight', 15) or nil);
	end;

	function functions.acbNoJumpCd(toggle)
		ACB.setNoJumpCooldown(toggle);
	end;

	function functions.acbNoclip(toggle)
		ACB.setNoclip(toggle);
	end;
end;




do 
	function functions.noStun(toggle)
		Lab.setNoStun(toggle);
	end;

	function functions.noParryCooldown(toggle)
		Lab.setNoParryCooldown(toggle);
	end;

	function functions.dashBoost(toggle)
		local applied = Lab.setDashBoost(toggle, getFlag('dashSpeed', 60), getFlag('dashDuration', 0.35));

		
		if (toggle and applied == false) then
			ToastNotif.new({
				text = '冲刺增强没生效：Evasive 模块里找不到 DashSpeed / DashDuration 的 upvalue（游戏可能更新了）'
			});
		end;
	end;

	function functions.carFling(toggle)
		Lab.setCarFling(toggle);
	end;

	function functions.playerFling(toggle)
		Lab.setPlayerFling(toggle);
	end;

	function functions.noRagdoll(toggle)
		Lab.setNoRagdoll(toggle);
	end;

	
	
	
	
	
	
	do 
		local restoreGuard = nil;
		local guardInstalled = false;

		local function isBlockedAction(payload)
			if (type(payload) ~= 'table') then return false end;

			local action = payload.Action;

			if (action ~= 'M1' and action ~= 'M2') then return false end;

			return os.clock() < (tonumber(getgenv().__gakuranDangerUntil) or 0);
		end;

		local function installGuard()
			if (guardInstalled) then return end;
			if (not ServerRemote) then return end;

			
			if (type(hookmetamethod) == 'function' and type(getnamecallmethod) == 'function') then
				local originalNamecall;

				local okHook = pcall(function()
					originalNamecall = hookmetamethod(game, '__namecall', function(self, ...)
						if (getnamecallmethod() == 'FireServer' and self == ServerRemote) then
							local payload = select(1, ...);

							if (isBlockedAction(payload)) then
								getgenv().__gakuranGuardBlocks = (getgenv().__gakuranGuardBlocks or 0) + 1;

								return;
							end;
						end;

						return originalNamecall(self, ...);
					end);
				end);

				if (okHook and originalNamecall) then
					guardInstalled = true;

					restoreGuard = function()
						pcall(function()
							hookmetamethod(game, '__namecall', originalNamecall);
						end);
					end;

					library.unloadMaid:GiveTask(restoreGuard);

					return;
				end;
			end;

			
			if (type(hookfunction) == 'function') then
				local original = ServerRemote.FireServer;
				local okHook = pcall(function()
					hookfunction(original, function(self, payload, ...)
						if (isBlockedAction(payload)) then
							getgenv().__gakuranGuardBlocks = (getgenv().__gakuranGuardBlocks or 0) + 1;

							return;
						end;

						return original(self, payload, ...);
					end);
				end);

				if (okHook) then
					guardInstalled = true;

					library.unloadMaid:GiveTask(function()
						pcall(function() restorefunction(original) end);
					end);
				end;
			end;
		end;

		function functions.parryPriority(toggle)
			if (toggle) then
				pcall(installGuard);
			end;
		end;

		
		if (getFlag('parryPriority', false)) then
			pcall(installGuard);
		end;
	end;

	
	
	
	
	
	
	do 
		local JAPAN_FLAG_ASSET = '16898613353';

		local CHINA_RED = Color3.fromRGB(222, 41, 16);
		local STAR_GOLD = Color3.fromRGB(255, 222, 0);

		
		local STAR_LAYOUT = {
			{ x = 0.08, y = 0.10, size = 0.26 },
			{ x = 0.42, y = 0.04, size = 0.09 },
			{ x = 0.52, y = 0.15, size = 0.09 },
			{ x = 0.52, y = 0.28, size = 0.09 },
			{ x = 0.42, y = 0.39, size = 0.09 },
		};

		local flagState = {
			enabled = false,
			saved = {},
			worldSaved = {},
		};

		local function isJapaneseFlag(instance)
			if (not instance:IsA('ImageLabel') and not instance:IsA('ImageButton')) then
				return false;
			end;

			return tostring(instance.Image):find(JAPAN_FLAG_ASSET, 1, true) ~= nil;
		end;

		local function applyTo(label)
			if (flagState.saved[label]) then return end;

			flagState.saved[label] = {
				image = label.Image;
				bgColor = label.BackgroundColor3;
				bgTransparency = label.BackgroundTransparency;
			};

			label.Image = '';
			label.BackgroundColor3 = CHINA_RED;
			label.BackgroundTransparency = 0;

			for index, star in next, STAR_LAYOUT do
				local item = Instance.new('TextLabel');
				item.Name = 'ChinaStar' .. index;
				item.BackgroundTransparency = 1;
				item.Text = '★';
				item.TextColor3 = STAR_GOLD;
				item.TextScaled = true;
				item.Font = Enum.Font.GothamBold;
				item.Size = UDim2.fromScale(star.size, star.size);
				item.Position = UDim2.fromScale(star.x, star.y);
				item.ZIndex = label.ZIndex + 1;
				item.Parent = label;
			end;
		end;

		local function restoreFrom(label)
			local saved = flagState.saved[label];

			if (not saved) then return end;

			flagState.saved[label] = nil;

			pcall(function()
				label.Image = saved.image;
				label.BackgroundColor3 = saved.bgColor;
				label.BackgroundTransparency = saved.bgTransparency;

				for _, child in next, label:GetChildren() do
					if (child.Name:sub(1, 9) == 'ChinaStar') then
						child:Destroy();
					end;
				end;
			end);
		end;

		local function scanAll()
			local playerGui = LocalPlayer:FindFirstChildOfClass('PlayerGui');

			if (playerGui) then
				for _, descendant in next, playerGui:GetDescendants() do
					if (isJapaneseFlag(descendant)) then
						applyTo(descendant);
					end;
				end;
			end;

			
			
			
			for _, instance in next, workspace:GetDescendants() do
				local nameLower = string.lower(instance.Name);

				if ((instance:IsA('MeshPart') or instance:IsA('Part'))
					and (nameLower:find('flag') or nameLower:find('kokki') or nameLower:find('hinomaru'))) then
					if (not flagState.worldSaved[instance]) then
						flagState.worldSaved[instance] = {
							textureId = instance:IsA('MeshPart') and instance.TextureID or nil;
							color = instance.Color;
						};

						pcall(function()
							if (instance:IsA('MeshPart')) then
								instance.TextureID = '';
							end;
						end);

						pcall(function() instance.Color = CHINA_RED end);
					end;
				end;
			end;
		end;

		local function restoreWorldFlags()
			local parts = {};

			for part in next, flagState.worldSaved do
				parts[#parts + 1] = part;
			end;

			for _, part in next, parts do
				local saved = flagState.worldSaved[part];

				flagState.worldSaved[part] = nil;

				pcall(function()
					if (part:IsA('MeshPart') and saved.textureId) then
						part.TextureID = saved.textureId;
					end;

					part.Color = saved.color;
				end);
			end;
		end;

		function functions.chinaFlag(toggle)
			flagState.enabled = toggle and true or false;

			if (not flagState.enabled) then
				local labels = {};

				for label in next, flagState.saved do
					labels[#labels + 1] = label;
				end;

				for _, label in next, labels do
					restoreFrom(label);
				end;

				restoreWorldFlags();

				return;
			end;

			scanAll();

			
			local playerGui = LocalPlayer:FindFirstChildOfClass('PlayerGui');

			if (playerGui) then
				library:AddConnection(playerGui.DescendantAdded, function(instance)
					if (not flagState.enabled) then return end;

					if (isJapaneseFlag(instance)) then
						task.defer(applyTo, instance);
					end;
				end);
			end;
		end;
	end;

	function functions.showHpStamina(toggle)
		Hud.setEnabled(toggle);
	end;

	
	
	
	local chatLoggerInstance;
	local chatLoggerEnabled = false;

	function functions.chatLogger(toggle)
		chatLoggerEnabled = toggle and true or false;

		if (not chatLoggerInstance) then
			local okNew, inst = pcall(TextLogger.new, {
				title = '聊天记录',
				buttons = {'Copy Text', 'Copy Username'},
			});

			if (not okNew or not inst) then return end;

			chatLoggerInstance = inst;

			
			
			task.defer(function()
				pcall(function() inst:Center() end);
			end);

			
			library.unloadMaid:GiveTask(function()
				pcall(function()
					if (chatLoggerInstance and chatLoggerInstance._gui) then
						chatLoggerInstance._gui:Destroy();
						chatLoggerInstance = nil;
					end;
				end);
			end);

			
			
			
			
			
			local okBind, chatConn = pcall(function()
				return TextChatService.MessageReceived:Connect(function(message)
					if (not chatLoggerEnabled or not chatLoggerInstance or not message) then return end;

					local source = message.TextSource;
					local name = source and source.Name or '?';

					pcall(function()
						chatLoggerInstance:AddText({
							text = string.format('<font color="#%s">[%s]</font> %s', TextLogger.Colors.Accent:ToHex(), name, tostring(message.Text)),
							player = Players:FindFirstChild(name),
						});
					end);
				end);
			end);

			if (okBind and chatConn) then
				library.unloadMaid:GiveTask(function()
					pcall(function() chatConn:Disconnect() end);
				end);
			elseif (getFlag('debugLog', false)) then
				log('CHATLOG 绑定 MessageReceived 失败: %s', tostring(chatConn));
			end;
		end;

		if (chatLoggerInstance) then
			pcall(function() chatLoggerInstance:SetVisible(chatLoggerEnabled) end);
		end;
	end;

	function functions.teleportSelected()
		local name = getFlag('teleportLocation', nil);

		if (type(name) ~= 'string' or name == '') then
			return;
		end;

		local ok, reason = Teleport.to(name);

		if (not ok and getFlag('debugLog', false)) then
			log('TELEPORT %s 失败: %s', name, tostring(reason));
		end;
	end;

	function functions.rebuildTeleport()
		local list = Teleport.rebuild();

		return list;
	end;
end;









do 
	local baitPool = {};
	local active = {};

	local function collectBaits()
		table.clear(baitPool);

		local anims = game:GetService('ReplicatedStorage'):FindFirstChild('Animations');
		local combat = anims and anims:FindFirstChild('Combat');

		if (not combat) then return 0 end;

		for _, styleFolder in ipairs(combat:GetChildren()) do
			if (styleFolder:IsA('Folder') and styleFolder.Name:sub(-5) == 'Anims') then
				for _, anim in ipairs(styleFolder:GetDescendants()) do
					if (anim:IsA('Animation') and anim.Name:find('M1$')) then
						table.insert(baitPool, anim);
					end;
				end;
			end;
		end;

		return #baitPool;
	end;

	local function stopAll()
		for _, track in ipairs(active) do
			pcall(function()
				track:Stop();
				track:Destroy();
			end);
		end;

		table.clear(active);
	end;

	function functions.antiAutoParry(toggle)
		if (not toggle) then
			stopAll();

			return;
		end;

		if (#baitPool == 0) then
			collectBaits();
		end;

		if (#baitPool == 0) then
			log('反制自动弹反：找不到可用的攻击动画');

			return;
		end;

		task.spawn(function()
			while (getFlag('antiAutoParry', false)) do
				local character = game:GetService('Players').LocalPlayer.Character;
				local humanoid = character and character:FindFirstChildOfClass('Humanoid');

				if (humanoid and humanoid.Health > 0) then
					local animator = humanoid:FindFirstChildOfClass('Animator');

					if (animator) then
						local bait = baitPool[math.random(#baitPool)];
						local ok, track = pcall(function()
							return animator:LoadAnimation(bait);
						end);

						if (ok and track) then
							
							pcall(function()
								track:Play(9999, 0, 0);
							end);

							table.insert(active, track);

							
							if (#active > 12) then
								local old = table.remove(active, 1);

								pcall(function()
									old:Stop();
									old:Destroy();
								end);
							end;

							task.delay(1.2, function()
								pcall(function()
									track:Stop();
									track:Destroy();
								end);

								local index = table.find(active, track);

								if (index) then
									table.remove(active, index);
								end;
							end);
						end;
					end;
				end;

				
				task.wait(0.9);
			end
		end);
	end;

	library.unloadMaid:GiveTask(stopAll);
end;




local parrySection = column1:AddSection('自动弹反');
local parrySettingsSection = column1:AddSection('弹反设置');
local stanceSection = column1:AddSection('姿态');
local bruteSection = column1:AddSection('暴力');


local DEBUG_MODE = getgenv().debugMode == true;

















do 
	
	local ANON_NAME = 'V AIR';

	
	local INFO_GUI_NAME = 'PlayerInfoBillboard';
	local INFO_LABELS = { 'Info', 'InfoShadow', 'Username' };

	local anonSelf = false;
	local anonOther = false;
	local anonToken = 0;

	
	local originalDisplay = setmetatable({}, { __mode = 'k' });   
	local originalLabels = setmetatable({}, { __mode = 'k' });    
	local labelHooks = setmetatable({}, { __mode = 'k' });        
	local sortedCache = setmetatable({}, { __mode = 'k' });       
	local billboardHooks = setmetatable({}, { __mode = 'k' });    
	local playerHooks = {};                                        

	
	
	
	local function sortNames(names)
		local list = {};

		for name in next, names do
			list[#list + 1] = tostring(name);
		end;

		table.sort(list, function(a, b)
			return #a > #b;
		end);

		return list;
	end;

	
	local function anonymizeText(value, sorted)
		local replaced = value;
		local touched = false;

		for _, name in next, sorted do
			
			local pattern = name:gsub('%W', '%%%0');
			local result, count = replaced:gsub(pattern, ANON_NAME);

			if (count > 0) then
				replaced = result;
				touched = true;
			end;
		end;

		if (touched) then
			return replaced;
		end;

		return nil;
	end;

	local function restoreLabel(label)
		local saved = originalLabels[label];

		if (saved ~= nil) then
			originalLabels[label] = nil;

			if (label.Parent) then
				pcall(function()
					label.Text = saved;
				end);
			end;
		end;
	end;

	
	
	
	local function namesFor(character)
		local player = Players:GetPlayerFromCharacter(character);

		if (not player) then return nil end;

		local hide;

		if (player == LocalPlayer) then
			hide = anonSelf;
		else
			hide = anonOther;
		end;

		if (not hide) then return nil end;

		local names = {};

		if (player.Name ~= '') then
			names[player.Name] = true;
		end;

		local display = player.DisplayName;

		if (display and display ~= '' and display ~= player.Name) then
			names[display] = true;
		end;

		if (character.Name ~= '') then
			names[character.Name] = true;

			
			
			for token in string.gmatch(character.Name, '%S+') do
				if (#token >= 3) then
					names[token] = true;
				end;
			end;
		end;

		return names;
	end;

	local function patchOne(descendant, character)
		
		
		local className = descendant.ClassName;

		if (className ~= 'TextLabel' and className ~= 'TextButton') then
			return;
		end;

		restoreLabel(descendant);

		
		
		local sorted = sortedCache[character];

		if (not sorted) then
			local names = namesFor(character);

			if (not names) then return end;

			sorted = sortNames(names);
			sortedCache[character] = sorted;
		end;

		if (#sorted == 0) then return end;

		local current = descendant.Text;

		if (type(current) ~= 'string' or current == '') then return end;

		local replaced = anonymizeText(current, sorted);

		if (replaced) then
			originalLabels[descendant] = current;

			pcall(function()
				descendant.Text = replaced;
			end);
		end;
	end;

	
	
	local pendingPatch = {};
	local patchScheduled = false;

	local schedulePatch;

	local function flushPatch()
		patchScheduled = false;

		local batch = pendingPatch;

		pendingPatch = {};

		for descendant, character in next, batch do
			if (descendant.Parent) then
				pcall(patchOne, descendant, character);
			end;
		end;
	end;

	schedulePatch = function(descendant, character)
		pendingPatch[descendant] = character;

		if (patchScheduled) then return end;

		patchScheduled = true;

		task.defer(flushPatch);
	end;

	
	
	
	local function patchBillboard(character, sorted)
		local gui = character and character:FindFirstChild(INFO_GUI_NAME, true);

		if (not gui) then return end;

		for _, labelName in next, INFO_LABELS do
			local label = gui:FindFirstChild(labelName);

			if (not label or not label:IsA('TextLabel')) then continue end;

			local raw = label.Text;

			if (type(raw) ~= 'string' or raw == '') then continue end;

			
			if (originalLabels[label] == nil) then
				originalLabels[label] = raw;
			end;

			if (labelName == 'Username') then
				local replaced = sorted and anonymizeText(raw, sorted);

				if (replaced and label.Text ~= replaced) then
					pcall(function()
						label.Text = replaced;
					end);
				end;
			elseif (label.Text ~= ANON_NAME) then
				pcall(function()
					label.Text = ANON_NAME;
				end);
			end;

			
			if (not billboardHooks[label]) then
				local connection;

				local okHook = pcall(function()
					connection = label:GetPropertyChangedSignal('Text'):Connect(function()
						if (originalLabels[label] == nil) then return end;

						local newRaw = label.Text;

						if (type(newRaw) ~= 'string' or newRaw == '') then return end;

						if (labelName == 'Username') then
							local replaced = sorted and anonymizeText(newRaw, sorted);

							if (replaced and label.Text ~= replaced) then
								pcall(function()
									label.Text = replaced;
								end);
							end;
						elseif (label.Text ~= ANON_NAME) then
							pcall(function()
								label.Text = ANON_NAME;
							end);
						end;
					end);
				end);

				if (okHook and connection) then
					billboardHooks[label] = connection;
				end;
			end;
		end;
	end;

	local function patchCharacter(character)
		if (not character or not character.Parent) then return end;

		local names = namesFor(character);

		if (not names) then return end;

		local sorted = sortedCache[character];

		if (not sorted) then
			sorted = sortNames(names);
			sortedCache[character] = sorted;
		end;

		for _, descendant in next, character:GetDescendants() do
			pcall(patchOne, descendant, character);
		end;

		
		pcall(patchBillboard, character, sorted);

		
		
		if (not labelHooks[character]) then
			local connection;

			local ok = pcall(function()
				connection = character.DescendantAdded:Connect(function(descendant)
					if (not (anonSelf or anonOther)) then return end;

					local className = descendant.ClassName;

					if (className ~= 'TextLabel' and className ~= 'TextButton') then
						return;
					end;

					schedulePatch(descendant, character);
				end);
			end);

			if (ok and connection) then
				labelHooks[character] = connection;
			end;
		end;
	end;

	local function applyPlayer(player)
		local character = player.Character;

		if (not character) then return end;

		local humanoid = character:FindFirstChildOfClass('Humanoid');
		local names = namesFor(character);

		
		if (humanoid) then
			if (names) then
				if (originalDisplay[humanoid] == nil) then
					originalDisplay[humanoid] = humanoid.DisplayName;
				end;

				if (humanoid.DisplayName ~= ANON_NAME) then
					humanoid.DisplayName = ANON_NAME;
				end;
			elseif (originalDisplay[humanoid] ~= nil) then
				humanoid.DisplayName = originalDisplay[humanoid];
				originalDisplay[humanoid] = nil;
			end;
		end;

		
		if (names) then
			patchCharacter(character);
		end;
	end;

	local function applyAll()
		for _, player in next, Players:GetPlayers() do
			pcall(applyPlayer, player);
		end;
	end;

	
	local function restoreAll()
		pcall(function()
			for humanoid, value in next, originalDisplay do
				if (humanoid.Parent) then
					humanoid.DisplayName = value;
				end;
			end;

			table.clear(originalDisplay);
		end);

		pcall(function()
			
			
			
			
			local pending = {};

			for label, value in next, originalLabels do
				pending[label] = value;
			end;

			table.clear(originalLabels);

			for label, value in next, pending do
				if (label.Parent) then
					pcall(function()
						label.Text = value;
					end);
				end;
			end;
		end);

		table.clear(labelHooks);

		pcall(function()
			for _, connection in next, billboardHooks do
				connection:Disconnect();
			end;

			table.clear(billboardHooks);
		end);
	end;

	
	getgenv().__gakuranAnonName = function(player)
		if (typeof(player) ~= 'Instance') then
			return nil;
		end;

		if (player == LocalPlayer) then
			return anonSelf and ANON_NAME or nil;
		end;

		return anonOther and ANON_NAME or nil;
	end;

	local function resync()
		anonToken += 1;

		
		table.clear(sortedCache);

		if (anonSelf or anonOther) then
			applyAll();
		else
			restoreAll();
		end;
	end;

	function functions.anonSelf(toggle)
		anonSelf = toggle and true or false;

		resync();
	end;

	function functions.anonOthers(toggle)
		anonOther = toggle and true or false;

		resync();
	end;

	
	local function hookPlayer(player)
		if (playerHooks[player]) then return end;

		local connection;

		local ok = pcall(function()
			connection = player.CharacterAdded:Connect(function(character)
				sortedCache[character] = nil;

				if (not (anonSelf or anonOther)) then return end;

				task.defer(function()
					if (character.Parent) then
						pcall(applyPlayer, player);
					end;
				end);
			end);
		end);

		if (ok and connection) then
			playerHooks[player] = connection;
		end;
	end;

	for _, player in next, Players:GetPlayers() do
		pcall(hookPlayer, player);
	end;

	local playerAddedConnection;

	pcall(function()
		playerAddedConnection = Players.PlayerAdded:Connect(function(player)
			pcall(hookPlayer, player);

			if (not (anonSelf or anonOther)) then return end;

			task.defer(function()
				pcall(applyPlayer, player);
			end);
		end);
	end);

	
	library.unloadMaid:GiveTask(function()
		anonToken += 1;
		anonSelf = false;
		anonOther = false;

		pcall(restoreAll);

		pcall(function()
			if playerAddedConnection then
				playerAddedConnection:Disconnect();
			end;
		end);

		for player, connection in next, playerHooks do
			pcall(function()
				connection:Disconnect();
			end);
		end;

		table.clear(playerHooks);

		getgenv().__gakuranAnonName = nil;
	end);
end;




do 
	parrySection:AddToggle({
		text = '开启自动弹反',
		flag = 'Enable Auto Parry',
		tip = '看到对手挥刀动画后，按服务端命中时刻自动格挡（弹反）',
		callback = functions.autoParry,
	});
end;

do 
	parrySection:AddDivider('目标');

	parrySection:AddToggle({
		text = '弹反玩家',
		flag = 'Parry Players',
		state = true,
		tip = '挡玩家的攻击',
	});

	parrySection:AddToggle({
		text = '弹反 NPC',
		flag = 'Parry Npcs',
		state = true,
		tip = '挡可战斗 NPC 的攻击（自动扫描场景，只收带 CanFight 的）',
		callback = functions.parryNpcs,
	});

	parrySection:AddToggle({
		text = '按下前查动画结束',
		flag = 'Check Anim End',
		state = false,
		tip = '只有存在 feint（假动作）的游戏才需要；本作没有 feint，开着会误取消（默认关）',
	});

	parrySection:AddToggle({
		text = '仅限正面',
		flag = 'Require Facing',
		state = true,
		tip = '只挡面朝我的攻击',
	});

	parrySection:AddSlider({
		text = '最大距离',
		flag = 'Parry Max Range',
		value = 22,
		min = 5,
		max = 100,
		textpos = 2,
		tip = '超过这个距离不理会',
	});
end;

do 
	parrySection:AddDivider('白名单');

	parrySection:AddList({
		text = '玩家列表',
		flag = 'Parry Whitelist Players',
		playerOnly = true,
		noSave = true,
		tip = '选一个当前服务器里的玩家',
	});

	parrySection:AddButton({
		text = '加入白名单',
		flag = 'Add Whitelist Player',
		tip = '把选中的玩家加入白名单，之后不会对他弹反',
		callback = functions.addWhitelist,
	});

	parrySection:AddList({
		text = '已加白玩家',
		flag = 'Parry Whitelisted Players',
		tip = '选一个已加白的玩家',
	});

	parrySection:AddButton({
		text = '移出白名单',
		flag = 'Remove Whitelist Player',
		tip = '把选中的玩家移出白名单',
		callback = functions.removeWhitelist,
	});
end;

do 
	stanceSection:AddToggle({
		text = '自动战斗姿态',
		flag = 'Auto Stance',
		state = true,
		tip = '附近有敌人时自动按 T 进战斗姿态（没姿态不能格挡）',
	});

	stanceSection:AddSlider({
		text = '姿态距离',
		flag = 'Stance Range',
		value = 25,
		min = 5,
		max = 100,
		textpos = 2,
		tip = '多近才自动切姿态。别设太大，否则人多的地方一直站桩',
	});

	stanceSection:AddSlider({
		text = '姿态重试间隔',
		flag = 'Stance Retry',
		value = 1,
		min = 0.2,
		max = 5,
		float = 0.1,
		suffix = 's',
		textpos = 2,
		tip = '切姿态失败后的重试间隔',
	});

	stanceSection:AddToggle({
		text = '姿态范围显示',
		flag = 'Stance Range Visual',
		tip = '在脚下画一个圆，半径就是「姿态距离」，用来确认这个距离盖没盖到面前的人',
		callback = functions.stanceRangeVisual,
	});

	stanceSection:AddColor({
		text = '姿态范围颜色',
		flag = 'Stance Range Color',
		color = Color3.fromRGB(120, 220, 255),
		tip = '姿态范围圈的描边颜色',
	});
end;




function functions.teleportToSelected()
	local player = library.flags.bruteTargetPlayer;

	if (typeof(player) ~= 'Instance' or not player.Parent) then
		ToastNotif.new({ text = '先在「选择玩家」里选一个人', duration = 3 });

		return;
	end;

	if (not player.Character) then
		ToastNotif.new({
			text = string.format('%s 现在没有角色（可能已经死了或在加载）', tostring(player.Name));
			duration = 3;
		});

		return;
	end;

	if (ACB and type(ACB.teleportToPlayer) == 'function') then
		local distance = 0;
		local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart');
		local theirHrp = player.Character:FindFirstChild('HumanoidRootPart');

		if (myHrp and theirHrp) then
			distance = math.floor((myHrp.Position - theirHrp.Position).Magnitude);
		end;

		
		ToastNotif.new({
			text = string.format('正在传送到 %s（%.0f 格）', player.Name, distance);
			duration = 3;
		});

		ACB.teleportToPlayer(player.Name);
	end;
end;












do 
	local ATT_NAME = 'VairFollowAtt';

	
	
	
	
	
	
	
	
	
	local followHandle = nil;
	local followPlayer = nil;
	local followConn = nil;
	local followToken = 0;
	local alignPos, alignOrient, alignAtt;
	local spawned = {};
	local prevNoclip = nil;        
	local prevAutoRotate = nil;    

	local function detach()
		if (followConn) then
			pcall(function()
				followConn:Disconnect();
			end);

			followConn = nil;
		end;

		for _, instance in next, spawned do
			pcall(function()
				instance:Destroy();
			end);
		end;

		table.clear(spawned);

		alignPos, alignOrient, alignAtt = nil, nil, nil;
	end;

	local function setNoclip(on)
		if (type(ACB) == 'table' and type(ACB.setNoclip) == 'function') then
			pcall(ACB.setNoclip, on);
		end;
	end;

	local function attach(character)
		detach();

		local hrp = character and character:FindFirstChild('HumanoidRootPart');

		if (not hrp) then return false end;

		
		
		local humanoid = character:FindFirstChildOfClass('Humanoid');

		if (humanoid) then
			prevAutoRotate = humanoid.AutoRotate;

			pcall(function()
				humanoid.AutoRotate = false;
			end);
		end;

		alignAtt = Instance.new('Attachment');
		alignAtt.Name = ATT_NAME;
		alignAtt.Parent = hrp;

		alignPos = Instance.new('AlignPosition');
		alignPos.Name = 'VairFollowPos';
		alignPos.Attachment0 = alignAtt;
		alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment;
		alignPos.MaxForce = 1e6;
		alignPos.Responsiveness = 200;
		alignPos.ApplyAtCenterOfMass = false;
		alignPos.Parent = hrp;

		
		
		alignOrient = Instance.new('AlignOrientation');
		alignOrient.Name = 'VairFollowOrient';
		alignOrient.Attachment0 = alignAtt;
		alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment;
		alignOrient.MaxTorque = 1e6;
		alignOrient.Responsiveness = 200;
		alignOrient.Parent = hrp;

		spawned = { alignAtt, alignPos, alignOrient };

		return true;
	end;

	
	local function goalPosition(targetCF, mode, distance)
		if (mode == '天上') then
			return targetCF.Position + Vector3.new(0, distance, 0);
		elseif (mode == '地下') then
			return targetCF.Position - Vector3.new(0, distance, 0);
		end;

		
		return (targetCF * CFrame.new(0, 0, distance)).Position;
	end;

	
	
	
	
	
	
	
	local function facingCFrame(goalPos, targetPos, targetCF)
		local delta = targetPos - goalPos;
		local horizontal = Vector3.new(delta.X, 0, delta.Z);

		if (horizontal.Magnitude < 0.5) then
			
			local yaw = Vector3.new(targetCF.LookVector.X, 0, targetCF.LookVector.Z);

			if (yaw.Magnitude < 0.05) then
				yaw = Vector3.new(0, 0, -1);
			end;

			yaw = yaw.Unit;

			
			local pitchDir = 0;

			if (delta.Y < -0.5) then
				pitchDir = -1;          
			elseif (delta.Y > 0.5) then
				pitchDir = 1;           
			end;

			local pitch = math.rad(70) * pitchDir;
			local look = (yaw * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)).Unit;

			return CFrame.lookAt(goalPos, goalPos + look);
		end;

		
		return CFrame.lookAt(goalPos, targetPos);
	end;

	local function stop(reason)
		followToken += 1;
		followHandle = nil;
		followPlayer = nil;

		detach();

		
		if (prevNoclip == false) then
			setNoclip(false);
		end;

		prevNoclip = nil;

		
		local character = LocalPlayer.Character;
		local humanoid = character and character:FindFirstChildOfClass('Humanoid');

		if (humanoid and prevAutoRotate ~= nil) then
			pcall(function()
				humanoid.AutoRotate = prevAutoRotate;
			end);
		end;

		prevAutoRotate = nil;

		if (library.flags.followPlayer) then
			library.flags.followPlayer = false;
		end;

		if (reason) then
			ToastNotif.new({ text = reason, duration = 3 });
		end;
	end;

	local function tick()
		local myCharacter = LocalPlayer.Character;
		local myHrp = myCharacter and myCharacter:FindFirstChild('HumanoidRootPart');

		if (not (myHrp and alignPos and alignOrient)) then
			stop();

			return;
		end;

		
		if (not followPlayer or not followPlayer.Parent) then
			stop('目标已经离开服务器，停止跟随');

			return;
		end;

		local theirCharacter = followPlayer.Character;
		local theirHrp = theirCharacter and theirCharacter:FindFirstChild('HumanoidRootPart');

		
		if (not theirHrp) then return end;

		
		local handled = followHandle and followHandle:Get();

		if (not handled or handled.Parent == nil or handled ~= theirHrp) then
			followHandle = InstanceHandle.new(theirHrp);

			if (not attach(myCharacter)) then
				stop();

				return;
			end;
		end;

		
		local base = followHandle:Get();

		if (not base or base.Parent == nil) then
			stop();

			return;
		end;

		theirHrp = base;

		local mode = library.flags.followMode or '背后';
		local distance = tonumber(library.flags.followDistance) or 7;
		local goal = goalPosition(theirHrp.CFrame, mode, distance);

		
		if ((goal - myHrp.Position).Magnitude > 80 and type(ACB) == 'table'
			and type(ACB.teleportTo) == 'function') then
			ACB.teleportTo(goal);
		end;

		alignPos.Position = goal;

		local facing = facingCFrame(goal, theirHrp.Position, theirHrp.CFrame);

		alignOrient.CFrame = facing;

		
		
		
		local seatGetter = getgenv().__gakuranSeatPart;

		if (type(seatGetter) == 'function') then
			local okSeat, seatPart = pcall(seatGetter);

			if (okSeat and typeof(seatPart) == 'Instance' and seatPart.Parent) then
				pcall(function()
					seatPart.CFrame = CFrame.new(seatPart.Position, seatPart.Position + facing.LookVector);
				end);
			end;
		end;
	end;

	function functions.followPlayer(toggle)
		if (not toggle) then
			stop();

			return;
		end;

		
		local target = library.flags.bruteTargetPlayer;

		if (typeof(target) ~= 'Instance' or not target.Parent) then
			ToastNotif.new({ text = '先在「选择玩家」里选一个人', duration = 3 });

			stop();

			return;
		end;

		local targetHrp = target.Character and target.Character:FindFirstChild('HumanoidRootPart');

		if (not targetHrp) then
			ToastNotif.new({
				text = string.format('%s 现在没有角色（可能死了或在加载）', tostring(target.Name));
				duration = 3;
			});

			stop();

			return;
		end;

		if (not attach(LocalPlayer.Character)) then
			ToastNotif.new({ text = '你自己的角色还没加载', duration = 3 });

			stop();

			return;
		end;

		
		followHandle = InstanceHandle.new(targetHrp);
		followPlayer = target;

		
		prevNoclip = (library.flags.acbNoclip == true);

		setNoclip(true);

		followToken += 1;

		local token = followToken;

		followConn = RunService.Heartbeat:Connect(function()
			if (followToken ~= token) then return end;

			tick();
		end);

		ToastNotif.new({
			text = string.format('开始跟随 %s（%s）', tostring(target.Name), tostring(library.flags.followMode or '背后'));
			duration = 2;
		});
	end;

	
	LocalPlayer.CharacterAdded:Connect(function(character)
		if (not library.flags.followPlayer) then return end;

		task.defer(function()
			if (library.flags.followPlayer and attach(character) and followPlayer) then
				local theirHrp = followPlayer.Character
					and followPlayer.Character:FindFirstChild('HumanoidRootPart');

				if (theirHrp) then
					
					followHandle = InstanceHandle.new(theirHrp);

					followToken += 1;

					local token = followToken;

					followConn = RunService.Heartbeat:Connect(function()
						if (followToken ~= token) then return end;

						tick();
					end);
				else
					stop();
				end;
			end;
		end);
	end);







do 
	local column = library.updateColumn;

	if (column) then
		local section = column:AddSection('版本更新');

		local UPDATES = {
			{
				v = '1.1.81';
				g = 'Gakuran';
				at = '2026-11-01 01:50';
				lines = {
					'大幅度重写脚本，全面适配手机端';
				};
			};
			{
				v = '1.1.69';
				g = 'Gakuran';
				at = '2026-10-31 19:20';
				lines = {
					'修复手机端加载完成后不显示界面';
				};
			};
			{
				v = '1.1.68';
				g = 'Gakuran';
				at = '2026-10-31 19:00';
				lines = {
					'新增「更新」页，记录每个版本改了什么';
				};
			};
			{
				v = '1.1.59';
				g = 'Gakuran';
				at = '2026-10-31 18:05';
				lines = {
					'所有功能默认关闭，不再自动开启';
				};
			};
			{
				v = '1.1.58';
				g = 'Gakuran';
				at = '2026-10-31 17:55';
				lines = {
					'修复连击防不住（泰拳 M1 连段）';
				};
			};
			{
				v = '1.1.57';
				g = 'Gakuran';
				at = '2026-10-31 17:50';
				lines = {
					'更新自动弹反的自适应数据';
				};
			};
			{
				v = '1.1.56';
				g = 'Gakuran';
				at = '2026-10-31 17:35';
				lines = {
					'修复开启飞行后被传回原位';
				};
			};
			{
				v = '1.1.55';
				g = 'Gakuran';
				at = '2026-10-31 17:25';
				lines = {
					'匿名模式支持修改游戏内假名';
					'飞行与旁路飞行合并';
				};
			};
			{
				v = '1.1.54';
				g = 'Gakuran';
				at = '2026-10-31 17:15';
				lines = {
					'修复旁路飞行偶发失效';
				};
			};
			{
				v = '1.1.52';
				g = 'Gakuran';
				at = '2026-10-31 17:05';
				lines = {
					'修复飞行悬停时往下掉';
				};
			};
			{
				v = '1.1.51';
				g = 'Gakuran';
				at = '2026-10-31 17:00';
				lines = {
					'飞行与旁路飞行合并成一个开关';
				};
			};
			{
				v = '1.1.49';
				g = 'Gakuran';
				at = '2026-10-31 16:45';
				lines = {
					'「无布娃娃」改为「永不被击倒」';
				};
			};
			{
				v = '1.1.48';
				g = 'Gakuran';
				at = '2026-10-31 16:30';
				lines = {
					'修复 HUD 血量偶尔显示为空';
				};
			};
			{
				v = '1.1.47';
				g = 'Gakuran';
				at = '2026-10-31 16:15';
				lines = {
					'新增跟随玩家（背后 / 天上 / 地下）';
				};
			};
			{
				v = '1.1.41';
				g = 'Gakuran';
				at = '2026-10-31 15:40';
				lines = {
					'修复部分特殊招式无法弹反';
				};
			};
			{
				v = '1.1.39';
				g = 'Gakuran';
				at = '2026-10-31 15:25';
				lines = {
					'匿名设置独立成组';
				};
			};
			{
				v = '1.1.37';
				g = 'Gakuran';
				at = '2026-10-31 15:05';
				lines = {
					'优化匿名模式性能';
				};
			};
			{
				v = '1.1.33';
				g = 'Gakuran';
				at = '2026-10-31 14:55';
				lines = {
					'新增匿名模式';
				};
			};
			{
				v = '1.1.31';
				g = 'Gakuran';
				at = '2026-10-31 14:45';
				lines = {
					'优化 debug 地点';
				};
			};
			{
				v = '1.1.26';
				g = 'Gakuran';
				at = '2026-10-31 14:15';
				lines = {
					'所有传送改为瞬间到达';
				};
			};
			{
				v = '1.1.25';
				g = 'Gakuran';
				at = '2026-10-31 14:05';
				lines = {
					'新增传送到玩家';
					'血量条与真名拆分为独立开关';
				};
			};
			{
				v = '1.1.24';
				g = 'Gakuran';
				at = '2026-10-31 14:00';
				lines = {
					'重做提示框与按键显示';
				};
			};
		};

		
		
		local SHOW_LIMIT = 12;
		local shown = 0;

		for _, entry in next, UPDATES do
			if (shown >= SHOW_LIMIT) then break end;

			shown += 1;

			section:AddDivider(entry.g .. '   ' .. entry.v .. '   ' .. entry.at);

			for _, line in next, entry.lines do
				section:AddLabel(line);
			end;
		end;

		if (#UPDATES > shown) then
			section:AddLabel(string.format('…还有 %d 个更早的版本未列出（共 %d 个）', #UPDATES - shown, #UPDATES));
		end;
	end;
end;

	library.unloadMaid:GiveTask(function()
		followToken += 1;
		followHandle = nil;
		followPlayer = nil;

		detach();

		if (prevNoclip == false) then
			setNoclip(false);
		end;

		prevNoclip = nil;
	end);
end;

do 
	bruteSection:AddToggle({
		text = '反制自动弹反',
		flag = 'Anti Auto Parry',
		tip = '用权重 0 伪装挥刀动画：画面看不见，但对手脚本的 AnimationPlayed 照常触发，诱使它反复按格挡把冷却耗光',
		callback = functions.antiAutoParry,
	});

	bruteSection:AddDivider('玩家');

	
	
	bruteSection:AddList({
		text = '选择玩家',
		flag = 'Brute Target Player',
		playerOnly = true,
		noSave = true,
		tip = '从当前服务器里选一个玩家',
	});

	bruteSection:AddButton({
		text = '传送到玩家',
		flag = 'Teleport To Player',
		tip = '瞬间传送到选中玩家身边',
		callback = functions.teleportToSelected,
	});

	bruteSection:AddDivider('跟随');

	
	bruteSection:AddList({
		text = '跟随方式',
		flag = 'Follow Mode',
		values = { '背后', '天上', '地下' },
		tip = '背后 = 贴在他身后；天上 = 待在他正上方；地下 = 待在他正下方',
	});

	bruteSection:AddToggle({
		text = '跟随',
		flag = 'Follow Player',
		tip = '贴住选中玩家（自动开 noclip，朝向始终对着他，方便直接打）',
		callback = functions.followPlayer,
	});

	bruteSection:AddSlider({
		text = '跟随距离',
		flag = 'Follow Distance',
		value = 7,
		min = -30,
		max = 30,
		textpos = 2,
		tip = '可正可负：背后模式下负数 = 站到他正面；天上/地下模式下负数 = 翻到另一侧',
	});
end;

do 
	parrySettingsSection:AddButton({
		text = '试听弹反音效',
		flag = 'Test Parry Sound',
		tip = '不开开关也能直接播一次，用来试音效和音量',
		callback = function()
			playParrySound(true);
		end,
	});

	parrySettingsSection:AddToggle({
		text = '弹反音效',
		flag = 'Parry Sound',
		tip = '弹反成功时播一声音效（默认用 Roblox 自带的本地音效）',
	});

	
	
	
	parrySettingsSection:AddToggle({
		text = '弹反优先（禁止出手）',
		flag = 'Parry Priority',
		tip = '检测到有攻击飞向你时禁止出手（含手动左键/右键）。注意：默认关闭，因为它会丢弃出手封包，可能导致战斗状态异常',
		callback = functions.parryPriority,
	});

	
	parrySettingsSection:AddSlider({
		text = '延迟补偿',
		flag = 'Ping Compensation',
		value = 100,
		min = 0,
		max = 200,
		float = 5,
		textpos = 2,
		suffix = ' %',
		tip = '100% = 按网络延迟全额提前。调小 = 按得更晚（网络差时容易掉出窗口），调大 = 按得更早（容易按在窗口外）',
	});

	parrySettingsSection:AddSlider({
		text = '服务端冷却判定',
		flag = 'Server Block Gate',
		value = 250,
		min = 0,
		max = 600,
		float = 25,
		textpos = 2,
		suffix = ' ms',
		tip = '上次格挡生效后多久内不再按（越小越激进，容易连挡；太大就会漏掉连招）',
	});

	parrySettingsSection:AddToggle({
		text = '出手时也按格挡',
		flag = 'Self Attack Block',
		tip = '自己在出招时照样发格挡请求，赌游戏的输入缓冲会在动作结束后生效',
	});

	parrySettingsSection:AddToggle({
		text = '出手时自动闪避',
		flag = 'Self Attack Dodge',
		tip = '自己在出招时被砍，用闪避尝试打断自己的动作（闪不掉才退回排队补按）',
	});

	parrySettingsSection:AddSlider({
		text = '连按次数',
		flag = 'Block Burst',
		value = 1,
		min = 1,
		max = 5,
		float = 1,
		textpos = 2,
		suffix = ' 次',
		tip = '一次判定里重复激活格挡几次（1 = 关闭）；每次激活都可能重开弹反窗口',
	});

	parrySettingsSection:AddSlider({
		text = '连按间隔',
		flag = 'Block Burst Gap',
		value = 40,
		min = 20,
		max = 120,
		float = 5,
		textpos = 2,
		suffix = ' ms',
		tip = '连按之间的间隔',
	});

	parrySettingsSection:AddSlider({
		text = '格挡保持时长',
		flag = 'Block Hold',
		value = 130,
		min = 60,
		max = 320,
		float = 10,
		textpos = 2,
		suffix = ' ms',
		tip = '按下格挡后保持多久才松手；窗口越宽容错越大，太长会占住下一次',
	});

	parrySettingsSection:AddList({
		text = '音效预设',
		flag = 'Parry Sound Preset',
		values = { '默认（内置 snap）', '138564936113755', '135478009117226', '8132494511' },
		tip = '选一个预设音效；想用自己的就在下面填 Id',
	});

	parrySettingsSection:AddBox({
		text = '自定义音效 Id',
		flag = 'Parry Sound Id',
		tip = '填了就优先用这个，留空则用上面的预设；填数字或 rbxassetid://数字',
	});

	parrySettingsSection:AddSlider({
		text = '音效音量',
		flag = 'Parry Sound Volume',
		value = 1,
		min = 0,
		max = 3,
		float = 0.05,
		textpos = 2,
		tip = '弹反音效音量',
	});

	parrySettingsSection:AddToggle({
		text = '弹反朝向',
		flag = 'Face Target',
		tip = '出手瞬间把角色转向攻击者（只转角色不转视角），正面判定立刻生效',
	});

	parrySettingsSection:AddToggle({
		text = '自动闪避兜底',
		flag = 'Auto Dodge',
		tip = '格挡按不出来（本地冷却 / 没姿态 / 服务端冷却）时改用闪避顶一下',
	});

	parrySettingsSection:AddToggle({
		text = '体型自适应',
		flag = 'Height Reach',
		tip = '按攻击者身高比例放宽判定距离，高个子模型的触及更远',
	});

	parrySettingsSection:AddToggle({
		text = '弹反范围',
		flag = 'Parry Range Visual',
		tip = '画的是真实判定边界：半径 = 弹反距离（开了体型自适应会乘身高系数），并且只有正面半球算数——背后那半圈判定不到，所以画成近乎透明。残血自动格挡时不受距离和朝向限制。',
		callback = functions.parryRangeVisual,
	});

	parrySettingsSection:AddColor({
		text = '弹反范围颜色',
		flag = 'Parry Range Color',
		color = Color3.fromRGB(143, 143, 240),
		tip = '弹反圈的描边颜色',
	});

	parrySettingsSection:AddToggle({
		text = '连段保持',
		flag = 'Combo Hold',
		tip = '对方连招没打完就一直举着格挡，等连段结束再松手，不在连招中间反复重按',
	});

	parrySettingsSection:AddToggle({
		text = '抓取后撤',
		flag = 'Grapple Aware',
		tip = '识别到勾选流派的 M2（抓取）时直接后撤，而不是硬接',
	});

	do
		local styleList = {};

		for _, entry in next, ANIM do
			if (entry.style and not table.find(styleList, entry.style)) then
				table.insert(styleList, entry.style);
			end;
		end;

		table.sort(styleList);

		local grappleStyles = parrySettingsSection:AddList({
			text = '抓取流派',
			flag = 'Grapple Styles',
			values = styleList,
			multiselect = true,
			tip = '勾选哪些流派的 M2 算抓取（默认勾上 boxing）',
		});

		if (grappleStyles and type(grappleStyles.SetValue) == 'function' and type(library.flags.grappleStyles) ~= 'table') then
			local initial = {};

			for _, name in next, styleList do
				initial[name] = (name == 'boxing');
			end;

			pcall(function()
				grappleStyles:SetValue(initial);
			end);
		end;
	end;

	parrySettingsSection:AddToggle({
		text = '残血自动格挡',
		flag = 'Panic Block',
		tip = '血量低于阈值时不再挑距离和朝向，看到挥刀就挡',
	});

	parrySettingsSection:AddSlider({
		text = '残血阈值',
		flag = 'Panic Hp',
		value = 35,
		min = 5,
		max = 90,
		suffix = '%',
		textpos = 2,
		tip = '血量低于这个百分比就进入残血格挡',
	});
end;

do 
	if (DEBUG_MODE) then
		parrySection:AddDivider('调试');

		parrySection:AddToggle({
			text = '调试日志',
			flag = 'Debug Log',
			state = false,
			tip = '把每次格挡的时序打印到控制台',
		});

		parrySection:AddToggle({
			text = '僵直弹反探测',
			flag = 'Probe Parry Buffer',
			state = false,
			tip = '实验性：僵直期间发一次 Activated，验证服务端是否认这条路径',
		});

		parrySection:AddButton({
			text = '打印统计',
			flag = 'Print Stats',
			tip = '打印当前统计',
			callback = functions.printStats,
		});

		parrySection:AddButton({
			text = '重建动画表',
			flag = 'Rebuild Animation Map',
			tip = '游戏更新后重新扫描攻击动画',
			callback = functions.rebuildAnimMap,
		});


		
		
		parrySection:AddButton({
			text = '导出自适应数据',
			flag = 'Export Adaptive',
			tip = '导出 lead / 命中延迟 / 全局比例 / 偏移校准，用于固化进脚本',
			callback = function()
				local lines = {};
				local samples = 0;

				
				lines[#lines + 1] = string.format('\tscale = { player = %.4f, playerN = %d, npc = %.4f, npcN = %d };',
					SCALE.player.s, SCALE.player.n, SCALE.npc.s, SCALE.npc.n);

				
				local learnedLines = {};

				for key, record in next, LEARNED_STYLE do
					if (record.n > 0 and record.d) then
						learnedLines[#learnedLines + 1] = string.format("\t\t['%s'] = { d = %.4f, n = %d };", tostring(key), record.d, record.n);
						samples = samples + record.n;
					end;
				end;

				if (#learnedLines > 0) then
					lines[#lines + 1] = '\tlearned = {\n' .. table.concat(learnedLines, '\n') .. '\n\t};';
				end;

				
				local leadLines = {};

				for value, record in next, leadStats do
					if (record.n > 0) then
						leadLines[#leadLines + 1] = string.format("\t\t['%s'] = { win = %d, n = %d };", tostring(value), record.win, record.n);
						samples = samples + record.n;
					end;
				end;

				if (#leadLines > 0) then
					lines[#lines + 1] = '\tlead = {\n' .. table.concat(leadLines, '\n') .. '\n\t};';
				end;

				if (samples <= 0) then
					print('[Gakuran] 还没有学习到样本：先开自动弹反打一阵再来导出');

					return;
				end;

				local text = 'local BUILTIN_ADAPTIVE = {\n' .. table.concat(lines, '\n') .. '\n};';

				if (type(setclipboard) == 'function') then
					pcall(setclipboard, text);
				end;

				if (type(writefile) == 'function') then
					pcall(writefile, 'v.air/adaptive.lua', text);
				end;

				print(string.format('[Gakuran] 自适应数据已导出（样本 %d 条，已复制到剪贴板并写入 v.air/adaptive.lua）：\n%s', samples, text));
			end,
		});
	end;
end;

do 
	local column2 = (library.columns or {})[2];

	if (column2) then
		
		local anonSection = column2:AddSection('匿名');

		anonSection:AddToggle({
			text = '匿名自己',
			flag = 'Anon Self',
			tip = '把自己能看到的自己名字全部显示成 vair（只改本机，别人看到的还是原名）',
			callback = functions.anonSelf,
		});

		anonSection:AddToggle({
			text = '匿名其他人',
			flag = 'Anon Others',
			tip = '把你能看到的所有其他玩家名字和游戏假名都显示成 vair。关掉后恢复原名',
			callback = functions.anonOthers,
		});

		local playerSection = column2:AddSection('玩家');

		playerSection:AddDivider('移动');

		playerSection:AddToggle({
			text = '速度',
			flag = 'ACB Speed',
			tip = '接管 SetSpeed，把每帧回写的速度锁在你的值上',
			callback = functions.acbSpeed,
		});

		playerSection:AddSlider({
			text = '速度值',
			flag = 'ACB Speed Value',
			value = 60,
			min = 16,
			max = 200,
			textpos = 2,
			tip = '拖动即时生效（速度功能开着时立刻按新值锁速）',
			callback = function()
				if (getFlag('acbSpeed', false)) then
					pcall(functions.acbSpeed, true);
				end;
			end,
		});

		local flyToggle = playerSection:AddToggle({
			text = '飞行',
			flag = 'ACB Fly',
			tip = 'WASD 平移、空格上升、左 Ctrl 下降；松手原地悬停（含旁路飞行，一起开关）',
			callback = functions.acbFly,
		});

		
		playerSection:AddSlider({
			text = '飞行速度',
			flag = 'ACB Fly Speed',
			value = 80,
			min = 20,
			max = 300,
			textpos = 2,
			tip = '拖动即时生效',
			callback = function()
				if (getFlag('acbFly', false)) then
					pcall(functions.acbFly, true);
				end;
			end,
		});

		playerSection:AddToggle({
			text = '跳跃',
			flag = 'ACB Jump',
			tip = '改 JumpHeight（游戏把 UseJumpPower 关了，改 JumpPower 无效）',
			callback = functions.acbJump,
		});

		playerSection:AddSlider({
			text = '跳跃高度',
			flag = 'ACB Jump Height',
			value = 15,
			min = 6,
			max = 60,
			float = 0.5,
			textpos = 2,
			tip = '出厂 6.4；拖动即时生效',
			callback = function()
				if (getFlag('acbJump', false)) then
					pcall(functions.acbJump, true);
				end;
			end,
		});

		playerSection:AddToggle({
			text = '无跳跃冷却',
			flag = 'ACB No Jump CD',
			tip = '按住空格连续起跳（游戏挡住了 Jump 属性，这里直接走 ChangeState）',
			callback = functions.acbNoJumpCd,
		});

		playerSection:AddToggle({
			text = '穿墙',
			flag = 'ACB Noclip',
			callback = functions.acbNoclip,
		});

		playerSection:AddDivider('显示');

		playerSection:AddToggle({
			text = '显示血量体力',
			flag = 'Show Hp Stamina',
			state = true,
			tip = '左下角常驻显示自己的 HP / 体力；掉血时会在右上角闪一下这次的伤害值',
			callback = functions.showHpStamina,
		});

		playerSection:AddButton({
			text = '重生',
			flag = 'Respawn',
			tip = '活着时走「传送到虚空」强制死亡再重生：分步下坠到地图销毁高度以下，引擎销毁角色后服务端自动重生',
			callback = functions.respawn,
		});

		playerSection:AddToggle({
			text = '一直奔跑',
			flag = 'Always Sprint',
			tip = '持续保持奔跑状态（属性 + 速度），不用按 Shift',
			callback = functions.alwaysSprint,
		});

		playerSection:AddToggle({
			text = '受伤也能奔跑',
			flag = 'Injured Sprint',
			tip = '血量低于 50% 时仍然强制保持奔跑（游戏会在受伤后关掉奔跑）',
			callback = functions.injuredSprint,
		});

		playerSection:AddSlider({
			text = '奔跑速度',
			flag = 'Sprint Speed',
			value = 24,
			min = 12,
			max = 60,
			float = 1,
			textpos = 2,
			tip = '奔跑时的移动速度（出厂奔跑约 22）',
		});

		playerSection:AddToggle({
			text = '自动重生',
			flag = 'Auto Respawn',
			tip = '倒地 / 死亡界面一出现就自动点心跳按钮，不用手动点',
			callback = functions.autoRespawn,
		});

		playerSection:AddDivider('觉醒');

		playerSection:AddButton({
			text = '查看觉醒进度',
			flag = 'Awakening View',
			tip = '打开一个窗口列出各流派的觉醒阶段和进度；再点一次关闭（等于刷新）',
			callback = functions.awakeningView,
		});

		playerSection:AddDivider('自动战斗');
		playerSection:AddToggle({
			text = '自动攻击',
			flag = 'Auto Attack',
			tip = '前方有目标时自动普通攻击（M1）；需要先进战斗姿态（T）',
			callback = functions.autoAttack,
		});

		playerSection:AddToggle({
			text = '打沙包模式',
			flag = 'Punching Bag Mode',
			tip = '不判断有没有人，按间隔一直出拳；用来对着训练桩练连段、测延迟。可不依赖「自动攻击」单独开',
		});

		playerSection:AddSlider({
			text = '自动攻击间隔',
			flag = 'Auto Attack Interval',
			value = 0.35,
			min = 0.1,
			max = 1.5,
			float = 0.05,
			textpos = 2,
			suffix = ' s',
			tip = '两次普通攻击之间隔多久',
		});

		playerSection:AddToggle({
			text = '自动重击',
			flag = 'Auto Heavy',
			tip = '前方有目标时自动重击（M2）；需要先进战斗姿态（T）',
			callback = functions.autoHeavy,
		});

		playerSection:AddSlider({
			text = '自动重击间隔',
			flag = 'Auto Heavy Interval',
			value = 1.2,
			min = 0.3,
			max = 4,
			float = 0.1,
			textpos = 2,
			suffix = ' s',
			tip = '两次重击之间隔多久',
		});

		playerSection:AddSlider({
			text = '自动攻击距离',
			flag = 'Auto Attack Range',
			value = 12,
			min = 4,
			max = 30,
			float = 1,
			textpos = 2,
			tip = '前方多少格内有目标才出手（普通攻击）',
		});

		playerSection:AddSlider({
			text = '自动重击距离',
			flag = 'Auto Heavy Range',
			value = 14,
			min = 4,
			max = 30,
			float = 1,
			textpos = 2,
			tip = '前方多少格内有目标才出手（重击）',
		});

		do 
			playerSection:AddToggle({
				text = '显示自动攻击范围',
				flag = 'Auto Attack Range Visual',
				tip = '画的是真实判定边界：半径 = 自动攻击距离（球心在角色根部件上），背后约 145° 的扇形判定不到所以画成近乎透明；高度差超过 0.7×半径 的目标也不算。',
				callback = functions.attackRangeVisual,
			});

			playerSection:AddColor({
				text = '自动攻击范围颜色',
				flag = 'Auto Attack Range Color',
				color = Color3.fromRGB(120, 255, 190),
				tip = '自动攻击圈的描边颜色',
			});

			playerSection:AddToggle({
				text = '显示自动重击范围',
				flag = 'Auto Heavy Range Visual',
				tip = '画的是真实判定边界：半径 = 自动重击距离，背后约 145° 的扇形判定不到所以画成近乎透明；高度差超过 0.7×半径 的目标也不算。',
				callback = functions.heavyRangeVisual,
			});

			playerSection:AddColor({
				text = '自动重击范围颜色',
				flag = 'Auto Heavy Range Color',
				color = Color3.fromRGB(255, 140, 120),
				tip = '自动重击圈的描边颜色',
			});
		end;

		playerSection:AddDivider('打击音效');

		playerSection:AddToggle({
			text = '打击音效',
			flag = 'Hit Sound',
			tip = '你打中别人时播一声（默认音效 135478009117226）',
		});

		playerSection:AddButton({
			text = '试听打击音效',
			flag = 'Test Hit Sound',
			tip = '不开开关也能直接播一次，用来试音效和音量',
			callback = function()
				playHitSound(true);
			end,
		});

		playerSection:AddList({
			text = '打击音效预设',
			flag = 'Hit Sound Preset',
			values = { '135478009117226', '139459336979009' },
			tip = '下拉里直接选一个打击音效',
		});

		playerSection:AddBox({
			text = '自定义打击音效 Id',
			flag = 'Hit Sound Id',
			tip = '填了就优先用这个；留空则用上面下拉选中的预设',
		});

		playerSection:AddSlider({
			text = '打击音效音量',
			flag = 'Hit Sound Volume',
			value = 1,
			min = 0,
			max = 3,
			float = 0.05,
			textpos = 2,
			tip = '打击音效的音量',
		});

		playerSection:AddToggle({
			text = '打击音效兜底',
			flag = 'Hit Sound Fallback',
			state = false,
			tip = '动画没抓到但目标掉血、且是我刚出手的近距离正面目标时，补一声打击音效',
		});
	end;
end;














do 
	local column2 = (library.columns or {})[2];

	if (column2) then
		local MAX_LINES = 12;
		local infoSection = column2:AddSection('玩家信息');
		local infoLabels = {};
		local infoList;
		local currentTarget = nil;
		local selfPinned = false;
		local pinnedValue = nil;
		local liveEnabled = false;
		local lastRenderAt = 0;

		
		local GRADE_NAMES = {
			FirstYear = '一年级',
			SecondYear = '二年级',
			ThirdYear = '三年级',
		};

		local function field(playerData, key)
			local value = playerData:GetAttribute(key);

			return value ~= nil and tostring(value) or nil;
		end;

		local function ensureLabels()
			while (#infoLabels < MAX_LINES) do
				table.insert(infoLabels, infoSection:AddLabel(''));
			end;
		end;

		
		local function render(lines)
			ensureLabels();

			for index = 1, MAX_LINES do
				local label = infoLabels[index];
				local text = lines[index] or '';

				label.Text = text;

				if (label.main) then
					label.main.Visible = text ~= '';
				end;
			end;

			lastRenderAt = os.clock();
		end;

		local function buildLines(player)
			local character = player.Character;
			local playerData = character and character:FindFirstChild('PlayerData');

			if (not character or not playerData) then
				return {'<font color="#FF6B6B">角色未加载 / 没有 PlayerData</font>'};
			end;

			local humanoid = character:FindFirstChildOfClass('Humanoid');
			local fullName = string.format('%s %s', tostring(field(playerData, 'FirstName') or '?'), tostring(field(playerData, 'LastName') or ''));
			local height = tonumber(field(playerData, 'CurrentHeight') or field(playerData, 'Height') or '1') or 1;

			
			
			
			
			local totalInches = height * 60;
			local centimeters = totalInches * 2.54;
			local feet = math.floor(totalInches / 12);
			local inchPart = math.floor(totalInches % 12 + 0.5);

			if (inchPart >= 12) then
				feet += 1;
				inchPart -= 12;
			end;

			local lines = {
				string.format('<font color="#FFD166">%s</font>  <font color="#8A8A8A">(%s)</font>', fullName, player.Name),
				string.format('年龄 <font color="#7FE7FF">%s</font>  （生日 %s）', tostring(field(playerData, 'Age') or '?'), tostring(field(playerData, 'Birthday') or '?')),
				string.format('性别 <font color="#7FE7FF">%s</font> · 种族 <font color="#7FE7FF">%s</font>', tostring(field(playerData, 'Gender') or '?'), tostring(field(playerData, 'Ethnicity') or '?')),
				string.format('年级 <font color="#7FE7FF">%s</font>', GRADE_NAMES[tostring(field(playerData, 'Grade'))] or tostring(field(playerData, 'Grade') or '?')),
				string.format('身高 <font color="#7FE7FF">%d cm</font> · %d\'%d"', math.floor(centimeters + 0.5), feet, inchPart),
				string.format('流派 <font color="#A0FF8A">%s</font> · 类型 %s', tostring(field(playerData, 'CombatStyle') or '?'), tostring(field(playerData, 'CombatType') or '?')),
				string.format('备选 <font color="#8A8A8A">%s / %s</font>', tostring(field(playerData, 'CombatStyleSlot1') or '-'), tostring(field(playerData, 'CombatStyleSlot2') or '-')),
				string.format('终结技 <font color="#FF9F6B">%s</font>', tostring(field(playerData, 'Finisher') or '?')),
			};

			if (humanoid) then
				table.insert(lines, string.format('HP <font color="#FF6B6B">%.0f / %.0f</font>', humanoid.Health, humanoid.MaxHealth));
			end;

			table.insert(lines, string.format('状态 <font color="#8A8A8A">%s</font> · 姿态 %s · InCombat %s',
				tostring(humanoid and humanoid:GetState().Name or '?'),
				tostring(character:GetAttribute('Equip') and 'Equip' or '-'),
				tostring(character:GetAttribute('InCombat') or '-')));

			return lines;
		end;

		local function showInfo(player)
			if (typeof(player) == 'string') then
				player = Players:FindFirstChild(player);
			end;

			if (typeof(player) ~= 'Instance') then
				currentTarget = nil;

				render({'<font color="#FF6B6B">选一个玩家查看数据</font>'});

				return;
			end;

			currentTarget = player;

			render(buildLines(player));
		end;

		local function setLive(state)
			liveEnabled = state and true or false;

			if (liveEnabled) then
				showInfo(currentTarget or (infoList and infoList.value));
			end;
		end;

		infoList = infoSection:AddList({
			text = '玩家',
			tip = '选一个玩家，下面会列出他的角色数据（姓名 / 年龄 / 身高 / 流派 / HP 等）',
			playerOnly = true,
			skipflag = true,
			max = 6,
			callback = showInfo,
		});

		infoSection:AddToggle({
			text = '实时刷新',
			flag = 'Player Info Live',
			tip = '开着时每 0.5s 重新读一遍选中玩家的数据（HP / 状态跟着变）',
			callback = setLive,
		});

		
		infoSection:AddButton({
			text = '查看自己',
			flag = 'Player Info Self',
			tip = '直接读本机角色的数据（身高按 60in × 系数 换算成 cm）',
			callback = function()
				selfPinned = true;
				pinnedValue = infoList and infoList.value;

				showInfo(Players.LocalPlayer);
			end,
		});

		
		local lastPollAt = 0;

		library:AddConnection(RunService.Heartbeat, function()
			local now = os.clock();

			if (now - lastPollAt < 0.25) then return end;

			lastPollAt = now;

			local value = infoList and infoList.value;

			if (typeof(value) == 'string') then
				value = Players:FindFirstChild(value);
			end;

			
			if (selfPinned) then
				if (value == pinnedValue) then
					value = currentTarget;
				else
					selfPinned = false;
				end;
			end;

			if (value ~= currentTarget) then
				showInfo(value);

				return;
			end;

			if (liveEnabled and currentTarget and now - lastRenderAt >= 0.5) then
				showInfo(currentTarget);
			end;
		end);
	end;
end;

do 
	local column2 = (library.columns or {})[2];

	if (column2) then
		local teleportSection = column2:AddSection('传送');

		local names = Teleport.getLocations();

		if (#names == 0) then
			names = { '（没找到地点）' };
		end;

		teleportSection:AddList({
			text = '地点',
			flag = 'Teleport Location',
			values = names,
			tip = '游戏里的全部区域（取自 workspace.AreaHitboxes）',
		});

		teleportSection:AddButton({
			text = '传送到选中地点',
			flag = 'Teleport Go',
			tip = '直接落在地面上；落点会先用射线找地面',
			callback = functions.teleportSelected,
		});

		teleportSection:AddButton({
			text = '刷新地点列表',
			flag = 'Teleport Refresh',
			tip = '地图/场景更新后重新扫一次 AreaHitboxes',
			callback = functions.rebuildTeleport,
		});
	end;
end;

do 
	local column2 = (library.columns or {})[2];

	if (column2) then
		local miscSection = column2:AddSection('杂项');

		miscSection:AddToggle({
			text = '聊天记录',
			flag = 'Chat Logger',
			tip = '把服务器聊天抓到一个可拖动的窗口里（配色跟主界面一致）',
			callback = functions.chatLogger,
		});

		
		miscSection:AddToggle({
			text = '自动下滑',
			flag = 'Chat Logger Auto Scroll',
			state = true,
			tip = '聊天窗口收到新消息时自动滚到最底部',
		});
	end;
end;







local DevWatch = {};
do 
	local devSpecs = {};
	local reported = {};

	local function loadDevList()
		local okConfig, config = pcall(function()
			return requireShared('Shared', 'Config', 'SpecConfig');
		end);

		if (not okConfig or type(config) ~= 'table') then return 0 end;

		local grant = config.AutoGrant;

		if (type(grant) ~= 'table') then return 0 end;

		local count = 0;

		for userId, specs in next, grant do
			devSpecs[userId] = specs;
			count = count + 1;
		end;

		return count;
	end;

	local function describe(specs)
		local names = {};

		if (type(specs) == 'table') then
			for _, spec in next, specs do
				table.insert(names, tostring(spec));
			end;
		end;

		return table.concat(names, ', ');
	end;

	function DevWatch.load()
		return loadDevList();
	end;

	function DevWatch.check(player)
		if (not player or player == LocalPlayer) then return end;
		if (reported[player.UserId]) then return end;

		local specs = devSpecs[player.UserId];

		if (not specs) then return end;

		reported[player.UserId] = true;

		local message = string.format('开发者进服：%s (ID %d) · %s', player.Name, player.UserId, describe(specs));

		log(message);

		local mode = getFlag('devWatchMode', '提醒');

		if (mode == '踢出') then
			ToastNotif.new({
				text = '检测到开发者，正在离开服务器',
				duration = 5,
			});

			task.delay(0.4, function()
				
				local okKick = pcall(function()
					LocalPlayer:Kick('开发者进服');
				end);

				if (okKick) then return end;

				local okTeleport = pcall(function()
					Services:Get('TeleportService'):Teleport(game.PlaceId, LocalPlayer);
				end);

				if (not okTeleport) then
					log('离开失败：Kick 与 Teleport 都没走通');
				end;
			end);
		else
			ToastNotif.new({
				text = message,
				duration = 10,
			});
		end;
	end;

	function DevWatch.scan()
		local count = 0;

		for _, player in next, Players:GetPlayers() do
			pcall(DevWatch.check, player);
			count = count + 1;
		end;

		return count;
	end;

	function DevWatch.resetReported()
		for userId in next, reported do
			reported[userId] = nil;
		end;
	end;
end;




do 
	local column2 = (library.columns or {})[2];

	if (column2) then
		local labSection = column2:AddSection('增益');

		labSection:AddToggle({
			text = '攻击增益',
			flag = 'ACB Attack Gain',
			state = true,
			tip = '把客户端战斗限速对齐服务端阈值，出手频率提到服务端能接受的极限；关掉则用出厂限速',
			callback = functions.acbAttackGain,
		});

		labSection:AddToggle({
			text = '无僵直',
			flag = 'No Stun',
			tip = '每帧清掉 Stunned / CantAnything / GuardBroken 并解除 PlatformStand（仅客户端）',
			callback = functions.noStun,
		});

		labSection:AddToggle({
			text = '无弹反冷却',
			flag = 'No Parry Cooldown',
			tip = '清掉 BlockCooldown 属性，客户端格挡冷却置 0（服务端冷却仍在）',
			callback = functions.noParryCooldown,
		});

		labSection:AddToggle({
			text = '冲刺增强',
			flag = 'Dash Boost',
			tip = '加长冲刺距离：改 Evasive 模块的 DashSpeed / DashDuration',
			callback = functions.dashBoost,
		});

		labSection:AddSlider({
			text = '冲刺速度',
			flag = 'Dash Speed',
			value = 60,
			min = 30,
			max = 150,
			textpos = 2,
			tip = '出厂 30；拖动即时生效',
			callback = function()
				if (getFlag('dashBoost', false)) then
					pcall(functions.dashBoost, true);
				end;
			end,
		});

		labSection:AddSlider({
			text = '冲刺时长',
			flag = 'Dash Duration',
			value = 0.35,
			min = 0.2,
			max = 0.8,
			float = 0.05,
			suffix = 's',
			textpos = 2,
			tip = '出厂 0.2s；冲刺距离 ≈ 速度 × 时长；拖动即时生效',
			callback = function()
				if (getFlag('dashBoost', false)) then
					pcall(functions.dashBoost, true);
				end;
			end,
		});

		
		
		labSection:AddButton({
			text = '冲刺恢复默认',
			callback = function()
				local speedOption = library.options.dashSpeed;
				local durationOption = library.options.dashDuration;

				local defaultSpeed = (speedOption and speedOption.default) or 60;
				local defaultDuration = (durationOption and durationOption.default) or 0.35;

				
				
				if (speedOption and type(speedOption.SetValue) == 'function') then
					speedOption:SetValue(defaultSpeed);
				else
					library.flags.dashSpeed = defaultSpeed;
				end;

				if (durationOption and type(durationOption.SetValue) == 'function') then
					
					
					durationOption:SetValue(defaultDuration + 0.001);
				else
					library.flags.dashDuration = defaultDuration;
				end;

				if (getFlag('dashBoost', false)) then
					pcall(functions.dashBoost, true);
				end;
			end,
		});

		labSection:AddToggle({
			text = '不被车撞飞',
			flag = 'No Car Fling',
			tip = '被车撞到时的击飞：盯住 RagdollLaunch 信号，在它落地前把速度掐掉（不钉位置、不影响跑图）',
			callback = functions.carFling,
		});

		labSection:AddToggle({
			text = '不被玩家击飞',
			flag = 'No Player Fling',
			tip = '被玩家 / NPC 打出的击飞：判定依据是「0.6 秒内收到过打到我身上的命中广播」，检测到后同样只掐速度',
			callback = functions.playerFling,
		});

		labSection:AddToggle({
			text = '更换国旗',
			flag = 'China Flag',
			tip = '把游戏里的日本国旗换成中国国旗（界面图标 + 学校旗杆/商店街/外墙的实体旗子）',
			callback = functions.chinaFlag,
		});

		labSection:AddToggle({
			
			text = '永不被击倒',
			flag = 'No Ragdoll',
			tip = '被击倒时本地立刻弹回站立：禁掉服务端下发的 ragdoll / 强制相机回调，压掉 Ragdoll / Downed / Stunned / CantAnything / GuardBroken 属性，并禁用 FallingDown / Ragdoll / Physics 三个人形状态（服务端仍认为你倒地）',
			callback = functions.noRagdoll,
		});

		labSection:AddDivider('开发者预警');

		labSection:AddList({
			text = '开发者预警行为',
			flag = 'Dev Watch Mode',
			values = {'提醒', '踢出'},
			value = '提醒',
			tip = 'AutoGrant 白名单里的开发号进服时：只弹提示，还是直接离开服务器',
			callback = function()
				
			end,
		});

		labSection:AddButton({
			text = '扫描当前服务器开发者',
			callback = function()
				local count = DevWatch.load();

				if (count <= 0) then
					ToastNotif.new({text = '读不到 SpecConfig.AutoGrant（游戏可能更新了）'});

					return;
				end;

				DevWatch.resetReported();
				DevWatch.scan();

				ToastNotif.new({text = string.format('已扫描 %d 个白名单 ID', count)});
			end,
		});
	end;
end;





do 
	local EntityESP = sharedRequire('../../classes/EntityESP.lua');

	
	local STATUS_ATTRS = {
		{ attr = 'Blocking', label = 'Guard' },
		{ attr = 'Equip', label = 'Stance' },
		{ attr = 'Stunned', label = 'Stun' },
		{ attr = 'CantAnything', label = 'Locked' },
		{ attr = 'GuardBroken', label = 'GBreak' },
		{ attr = 'Ragdoll', label = 'Down' },
		{ attr = 'Sprinting', label = 'Sprint' },
		{ attr = 'PlayingInstrument', label = 'Instrument' },
	};

	
	
	if (not EntityESP.__gakuranWrapped) then
		EntityESP.__gakuranWrapped = true;

		local basePlugin = EntityESP.Plugin;

		library.unloadMaid:GiveTask(function()
			pcall(function()
				EntityESP.Plugin = basePlugin;
				EntityESP.__gakuranWrapped = nil;
			end);
		end);

		function EntityESP:Plugin()
			
			local okBase, data = pcall(basePlugin, self);

			if (not okBase or type(data) ~= 'table') then
				data = {};
			end;

			
			if (type(getgenv().__gakuranAnonName) == 'function') then
				local okAnon, anon = pcall(getgenv().__gakuranAnonName, self._player);

				if (okAnon and type(anon) == 'string') then
					data.playerName = anon;
				end;
			end;

			local extra = '';

			if (getFlag('showEspStatus', false) or getFlag('showEspAwakened', false)) then
				local character = self._player and self._player.Character;

				if (character) then
					if (getFlag('showEspStatus', false)) then
						local list = {};

						for _, entry in next, STATUS_ATTRS do
							if (character:GetAttribute(entry.attr) == true) then
								table.insert(list, entry.label);
							end;
						end;

						extra = extra .. '\n[Status] ' .. (#list > 0 and table.concat(list, ' ') or 'Normal');
					end;

					if (getFlag('showEspAwakened', false)) then
						local awakened = character:GetAttribute('AwakenedStyle');

						extra = extra .. '\n[Awakened] ' .. (type(awakened) == 'string' and awakened ~= '' and awakened or 'None');
					end;
				end;
			end;

			
			return {
				playerName = data.playerName,
				text = (data.text or '') .. extra,
			};
		end;
	end;
end;

do 
	
	
	local Utility = sharedRequire('../../utils/Utility.lua');
	local okSection, espSections = pcall(function()
		return Utility:getESPSection();
	end);

	local espSettings = okSection and type(espSections) == 'table' and espSections.espSettings;

	if (espSettings) then
		
		
		
		
		
		
		
		
		
		
		
		
		do
			local coreHealthOn = false;
			local coreNameOn = false;
			local coreToken = 0;

			
			local coreOriginal = setmetatable({}, { __mode = 'k' });

			local function snapshotHumanoid(humanoid)
				if (coreOriginal[humanoid]) then return end;

				coreOriginal[humanoid] = {
					DisplayDistanceType = humanoid.DisplayDistanceType;
					HealthDisplayType = humanoid.HealthDisplayType;
					HealthDisplayDistance = humanoid.HealthDisplayDistance;
					NameDisplayDistance = humanoid.NameDisplayDistance;
				};
			end;

			
			local function syncHumanoid(humanoid)
				if (not humanoid or not humanoid.Parent) then return end;

				local saved = coreOriginal[humanoid];

				if (not saved) then return end;

				if (coreHealthOn) then
					humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn;
					humanoid.HealthDisplayDistance = 1000;
				elseif (coreNameOn) then
					
					
					humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.Never;
				else
					humanoid.HealthDisplayType = saved.HealthDisplayType;
					humanoid.HealthDisplayDistance = saved.HealthDisplayDistance;
				end;

				if (coreNameOn) then
					humanoid.NameDisplayDistance = 1000;
				elseif (coreHealthOn) then
					
					humanoid.NameDisplayDistance = 0;
				else
					humanoid.NameDisplayDistance = saved.NameDisplayDistance;
				end;

				if (coreHealthOn or coreNameOn) then
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer;
				else
					humanoid.DisplayDistanceType = saved.DisplayDistanceType;
				end;
			end;

			local npcList, npcAt = {}, 0;

			local function collectCharacters()
				local list = { LocalPlayer.Character };

				for _, player in next, Players:GetPlayers() do
					if (player ~= LocalPlayer) then
						list[#list + 1] = player.Character;
					end;
				end;

				local npcFolder = Workspace:FindFirstChild('NPCs');
				local now = os.clock();

				if (npcFolder and now - npcAt > 2) then
					npcAt = now;
					table.clear(npcList);

					for _, descendant in next, npcFolder:GetDescendants() do
						if (descendant:IsA('Humanoid')) then
							npcList[#npcList + 1] = descendant.Parent;
						end;
					end;
				end;

				for _, npc in next, npcList do
					if (npc and npc.Parent) then
						list[#list + 1] = npc;
					end;
				end;

				return list;
			end;

			local function applyToCharacter(character)
				local humanoid = character and character:FindFirstChildOfClass('Humanoid');

				if (not humanoid) then return end;

				
				snapshotHumanoid(humanoid);
				syncHumanoid(humanoid);
			end;

			local function applyToEveryone()
				for _, character in next, collectCharacters() do
					pcall(applyToCharacter, character);
				end;
			end;

			
			local function restoreAll()
				
				
				
				local pending = {};

				for humanoid in next, coreOriginal do
					pending[#pending + 1] = humanoid;
				end;

				for _, humanoid in next, pending do
					local saved = coreOriginal[humanoid];

					coreOriginal[humanoid] = nil;

					if (saved and humanoid.Parent) then
						pcall(function()
							humanoid.DisplayDistanceType = saved.DisplayDistanceType;
							humanoid.HealthDisplayType = saved.HealthDisplayType;
							humanoid.HealthDisplayDistance = saved.HealthDisplayDistance;
							humanoid.NameDisplayDistance = saved.NameDisplayDistance;
						end);
					end;
				end;

				
				local function sweep(container)
					if (not container) then return end;

					for _, descendant in next, container:GetDescendants() do
						if (descendant:IsA('Humanoid')) then
							pcall(function()
								if (descendant.NameDisplayDistance > 100) then
									descendant.NameDisplayDistance = 0;
								end;

								if (descendant.HealthDisplayDistance > 100) then
									descendant.HealthDisplayDistance = 100;
								end;

								if (descendant.HealthDisplayType == Enum.HumanoidHealthDisplayType.AlwaysOn) then
									descendant.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged;
								end;

								if (descendant.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None) then
									descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;
								end;
							end);
						end;
					end;
				end;

				pcall(sweep, Workspace);
			end;

			
			local function resync()
				coreToken += 1;

				local token = coreToken;
				local anyOn = coreHealthOn or coreNameOn;

				if (anyOn) then
					pcall(applyToEveryone);
				else
					pcall(restoreAll);
				end;

				if (not anyOn) then return end;

				task.spawn(function()
					while (coreToken == token) do
						pcall(applyToEveryone);

						task.wait(1);
					end;
				end);
			end;

			function functions.coreHealth(toggle)
				coreHealthOn = toggle and true or false;

				resync();
			end;

			function functions.coreName(toggle)
				coreNameOn = toggle and true or false;

				resync();
			end;

			
			
			local coreConn = LocalPlayer.CharacterAdded:Connect(function()
				if (not (coreHealthOn or coreNameOn)) then return end;

				for _, delay in next, { 0.2, 0.8, 2 } do
					task.delay(delay, function()
						if (coreHealthOn or coreNameOn) then
							pcall(applyToEveryone);
						end;
					end);
				end;
			end);

			library.unloadMaid:GiveTask(function()
				coreToken += 1;   
				pcall(function() coreConn:Disconnect() end);
			end);

			espSettings:AddToggle({
				text = '显示游戏血量条',
				flag = 'Show Core Health',
				tip = '角色头顶显示血量条（游戏默认关掉了，这里强行打开；别人的也会显示，重生后自动补开）',
				callback = functions.coreHealth,
			});

			espSettings:AddToggle({
				text = '显示游戏真名',
				flag = 'Show Core Name',
				tip = '角色头顶显示游戏原生的名字。和透视自己画的名字是两套东西，可以分别开关',
				callback = functions.coreName,
			});
		end;

		espSettings:AddToggle({
			text = '显示状态',
			flag = 'Show Esp Status',
			tip = '玩家 ESP 名字下面多一行战斗状态（Guard / Stun / Locked / Down 等）',
		});

		espSettings:AddToggle({
			text = '显示觉醒',
			flag = 'Show Esp Awakened',
			tip = '玩家 ESP 名字下面多一行觉醒流派（Awakened）',
		});

			espSettings:AddToggle({
				text = '墙体检测',
				flag = 'Esp Wall Check',
				tip = '只显示视线能直接打到的人，被墙挡住的不画（开着更不显眼）',
			});
	else
		warn('[Gakuran] 找不到透视设置分组，状态/觉醒开关跳过');
	end;
end;




do 
	local npcFolder = Workspace:FindFirstChild('NPCs');

	if (not okMakeEsp or type(makeESP) ~= 'function') then
		warn('[Gakuran] makeESP 不可用，跳过 NPC 透视');
	elseif (npcFolder) then
		
		
		
		local npcCode = [[
			local npc = ...;
			local FindFirstChild = game.FindFirstChild;
			local FindFirstChildWhichIsA = game.FindFirstChildWhichIsA;

			return setmetatable({
				FindFirstChildWhichIsA = function(_, ...)
					return FindFirstChildWhichIsA(npc, ...);
				end,
			}, {
				__index = function(_, property)
					if (property == 'Position') then
						local root = FindFirstChild(npc, 'HumanoidRootPart');

						return root and root.Position;
					end;
				end,
			});
		]];

		makeESP({
			sectionName = 'NPC',
			
			sectionTitle = 'NPC 透视',
			enableText = '开启 NPC 透视',
			distanceText = '显示距离',
			maxDistanceText = '最大距离',
			noSearchBox = true,
			type = 'childAdded',
			args = npcFolder,
			callback = function(npc, espConstructor)
				if (not npc:IsA('Model') or not npc:FindFirstChildOfClass('Humanoid')) then return end;

				
				
				task.spawn(function()
					local root = npc:FindFirstChild('HumanoidRootPart') or npc:WaitForChild('HumanoidRootPart', 5);

					if (not root or not npc.Parent) then return end;

					local okNew, npcEsp = pcall(espConstructor.new, { code = npcCode, vars = { npc } }, npc.Name);

					if (not okNew or not npcEsp) then return end;
					local connections = {};

					local function cleanup()
						for _, item in next, connections do
							item:Disconnect();
						end;

						table.clear(connections);

						pcall(function()
							npcEsp:Destroy();
						end);
					end;

					table.insert(connections, npc.Destroying:Connect(cleanup));

					
					table.insert(connections, npc:GetPropertyChangedSignal('Parent'):Connect(function()
						if (npc.Parent) then return end;

						cleanup();
					end));
				end);
			end,
		});
	end;
end;




do 
	
	local okAcbApply, acbApplyErr = pcall(functions.acbApply);

if (not okAcbApply) then
	warn('[Gakuran] ACB 应用失败: ' .. tostring(acbApplyErr));
end;

	
	local broadcast = requireShared('Shared', 'Network', 'CombatBroadcast');

	if (broadcast and type(broadcast.On) == 'function') then
		local ok = pcall(function()
			broadcast.On('M1Hit', onCombatHit);
			broadcast.On('M2Hit', onCombatHit);
			broadcast.On('M1PerfectBlocked', onPerfectBlock);
			broadcast.On('M2PerfectBlocked', onPerfectBlock);
		end);

		if (not ok) then
			warn('[Gakuran] 命中广播接入失败，自校准关闭');
		end;
	else
		warn('[Gakuran] 找不到 CombatBroadcast，自校准关闭');
	end;

	
	do
		local okLoad, devCount = pcall(DevWatch.load);

		if (okLoad and devCount > 0) then
			pcall(DevWatch.scan);

			library.unloadMaid:GiveTask(Players.PlayerAdded:Connect(function(player)
				task.delay(1, function()
					pcall(DevWatch.check, player);
				end);
			end));

			print(string.format('[Gakuran] 开发者预警已挂载：%d 个白名单 ID', devCount));
		else
			warn('[Gakuran] 读不到 SpecConfig.AutoGrant，开发者预警关闭');
		end;
	end;

	
	if (library and library.OnLoad) then
		
		local onLoadConn = library.OnLoad:Connect(function()
			restoreWhitelist();
			
			pcall(loadLeadStats);
		end);

		library.unloadMaid:GiveTask(function()
			pcall(function() onLoadConn:Disconnect() end);
		end);
	else
		restoreWhitelist();
		pcall(loadLeadStats);
	end;

	
	library.unloadMaid:GiveTask(function()
		pcall(saveLeadStats, true);
	end);

	
	pcall(Hud.setEnabled, getFlag('showHpStamina', true));

	
	
	pcall(bindHitSoundWatcher, LocalPlayer.Character);

	library.unloadMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(function(character)
		task.delay(1, function()
			pcall(bindHitSoundWatcher, character);
		end);
	end));

	
	
	
	
	task.delay(0.35, function()
		local configName = library.loadedConfig or (library.configVars and library.configVars.config);

		if (not configName) then return end;

		local path = string.format('%s/%s.config%s', library.foldername, configName, library.fileext);
		local ok, content = pcall(readfile, path);

		if (not ok or type(content) ~= 'string') then return end;

		local okDecode, data = pcall(function()
			return game:GetService('HttpService'):JSONDecode(content);
		end);

		if (not okDecode or type(data) ~= 'table') then return end;

		local gameTable = data[library.gameName or 'Universal'];

		if (type(gameTable) ~= 'table') then return end;

		local applied = 0;

		for flag, option in next, (library.options or {}) do
			if (type(option) ~= 'table' or not option.type) then continue end;

			local value = gameTable[flag];

			if (value == nil) then continue end;

			if (option.type == 'toggle') then
				local state = (value == 1 or value == true);

				option.state = state;
				library.flags[flag] = state;

				if (option.hasInit and type(option.SetState) == 'function') then
					task.spawn(function()
						pcall(option.SetState, option, state);
					end);
				elseif (type(option.callback) == 'function') then
					pcall(option.callback, state);
				end;

				applied += 1;
			elseif (option.type == 'slider' or option.type == 'list' or option.type == 'box') then
				option.value = value;
				library.flags[flag] = value;

				if (option.hasInit and type(option.SetValue) == 'function') then
					task.spawn(option.SetValue, option, value);
				end;

				applied += 1;
			elseif (option.type == 'color' and type(value) == 'string') then
				local okColor, color = pcall(function()
					return Color3.fromHex(value);
				end);

				if (okColor and color) then
					option.color = color;
					library.flags[flag] = color;

					if (option.hasInit and type(option.SetColor) == 'function') then
						pcall(function()
							option:SetColor(color);
						end);
					end;

					applied += 1;
				end;
			end;
		end;

		getgenv().__gakuranConfigApplied = applied;
	end);

	
	
	task.delay(0.7, function()
		local configVars = library.configVars;

		if (type(configVars) ~= 'table') then return end;
		if (configVars.punchModeMerged) then return end;

		configVars.punchModeMerged = true;
		configVars.punchMode = nil;

		if (library.flags.punchMode ~= nil) then
			library.flags.punchMode = nil;
		end;
	end);

	
	
	task.delay(0.7, function()
		local configVars = library.configVars;

		if (type(configVars) ~= 'table') then return end;
		if (configVars.parryPriorityDisabled) then return end;

		configVars.parryPriorityDisabled = true;

		if (library.flags.parryPriority == true) then
			library.flags.parryPriority = false;

			local option = library.options.parryPriority;

			if (option and type(option.SetState) == 'function') then
				pcall(option.SetState, option, false);
			end;
		end;
	end);

	
	
	task.delay(0.6, function()
		local configVars = library.configVars;

		if (type(configVars) ~= 'table') then return end;
		if (configVars.parryDefaultsReverted) then return end;

		configVars.parryDefaultsReverted = true;

		if (tonumber(library.flags.serverBlockGate) == 150) then
			library.flags.serverBlockGate = 250;

			local gateOption = library.options.serverBlockGate;

			if (gateOption and type(gateOption.SetValue) == 'function') then
				pcall(gateOption.SetValue, gateOption, 250);
			end;
		end;

		if (tonumber(library.flags.blockBurst) == 2) then
			library.flags.blockBurst = 1;

			local burstOption = library.options.blockBurst;

			if (burstOption and type(burstOption.SetValue) == 'function') then
				pcall(burstOption.SetValue, burstOption, 1);
			end;
		end;
	end);


	
	library.unloadMaid:GiveTask(function()
		maid:Destroy();
		table.clear(watched);
		Lab.destroy();
		Hud.destroy();
	end);

	print(string.format('[Script] [Game] Gakuran 模块已加载，攻击动画 %d 个', ANIM_COUNT));
end;
end;

MODULES['games/Universal/Aimbot.lua'] = function()
local Maid = sharedRequire('../../utils/Maid.lua');
local Services = sharedRequire('../../utils/Services.lua');
local library = sharedRequire('../../UILibrary.lua');




if (not library) then
    library = getgenv().library;
end;

if (not library) then
    library = {
        configVars = {};
        options = {};
        OnLoad = { Connect = function() return { Disconnect = function() end } end };
        OnKeyPress = { Connect = function() return { Disconnect = function() end } end };
        OnKeyRelease = { Connect = function() return { Disconnect = function() end } end };
        OnFlagChanged = { Connect = function() return { Disconnect = function() end } end };
        unloadMaid = { GiveTask = function() end };
    };
end;local Utility = sharedRequire('../../utils/Utility.lua');

local RunService, UserInputService = Services:Get('RunService', 'UserInputService');
local UserService = game:GetService('UserService');

local maid = Maid.new();

local Circle = Drawing.new('Circle');
local targetLine = Drawing.new('Line');

Circle.Transparency = 1;
Circle.Visible = false;
Circle.Color = Color3.fromRGB(255, 255, 255);
Circle.Radius = 100;
Circle.Thickness = 1;

targetLine = Drawing.new('Line');
targetLine.Visible = true;
targetLine.Transparency = 1;
targetLine.Thickness = 1;
targetLine.Color = Color3.fromRGB(255, 255, 255);

local function Aimbot(state)
    if (not state) then
        maid.aimbot = nil;
        return;
    end;

    maid.aimbot = RunService.RenderStepped:Connect(function()
        if(not library) then
            maid.aimbot = nil;
            return;
        end;

        local Character = Utility:getClosestCharacter()
        Character = Character and Character.Character;
        if(not Character) then return end;

        local head = Character:FindFirstChild('Head');
        local hitPos = head and head.CFrame.Position;

        local Camera = workspace.CurrentCamera;
        if(not Camera) then return end;

        local aimPart = library.flags.aimPart;
        if(aimPart == 'Torso') then
            hitPos = hitPos - Vector3.new(0, 1.5, 0);
        elseif(aimPart == 'Leg') then
            hitPos = hitPos - Vector3.new(0, 3, 0);
        end;

        local hitPosition2D, visible = Camera:WorldToViewportPoint(hitPos);
        if (not visible) then return end;

        hitPosition2D = Vector2.new(hitPosition2D.X, hitPosition2D.Y);

        local mousePosition = UserInputService:GetMouseLocation();
        local final = (hitPosition2D - mousePosition) / (_G.test or 10);
        mousemoverel(final.X, final.Y);
    end);
end;

local function updateCircleProp(property)
    return function(value)
        if (property == "NumSides" and value == 50) then
            value = 500;
        elseif (property == "Filled" and library.flags.circleTransparency == 1) then
            library.flags.circleTransparency = 0.9;
            Circle.Transparency = 0.9;
        end
        Circle[property] = value;
    end;
end;

local function toggleRainbowCircle(toggle)
    if(not toggle) then
        maid.toggleRainbowCircle = nil;
        return;
    end;

    local circleColor = library.options.circleColor;

    maid.toggleRainbowCircle = RunService.RenderStepped:Connect(function()
        circleColor:SetColor(library.chromaColor);
    end);
end;

local function showCircle(toggle)
    Circle.Visible = toggle;

    if(not toggle) then
        maid.updateCirclePosition = nil;
        return;
    end;

    maid.updateCirclePosition = RunService.Heartbeat:Connect(function()
        
            if(Circle) then
                Circle.Position = UserInputService:GetMouseLocation()
            end;
        
        
        

        
        
        

        
        
    end);
end;

local Window = library:AddTab('自瞄');
local section1 = Window:AddColumn();
local section2 = Window:AddColumn();
local aimbotSettings = section1:AddSection('自瞄设置');
local circleSettings = section2:AddSection('准星设置');
local aimbotWhitelist = section1:AddSection('自瞄白名单');

do 
    do 
        circleSettings:AddToggle({
            text = '显示准星', flag = 'Show Circle',
            callback = showCircle
        }):AddColor({
            color = Color3.fromRGB(255, 0, 0),
            trans = 1,
            flag = 'Circle Color',
            calltrans = updateCircleProp('Transparency'),
            callback = updateCircleProp('Color')
        })

        circleSettings:AddToggle({
            text = '准星彩虹色', flag = 'Rainbow Circle',
            callback = toggleRainbowCircle
        })

        circleSettings:AddToggle({
            text = '填充准星', flag = 'Fill Circle',
            callback = updateCircleProp('Filled')
        })

        circleSettings:AddSlider({
            text = '准星形状', flag = 'Circle Shape',
            value = 50,
            min = 4,
            max = 50,
            float = 2,
            callback = updateCircleProp('NumSides')
        })

        circleSettings:AddSlider({
            text = '准星粗细', flag = 'Circle Thickness',
            value = 1,
            max = 50,
            callback = updateCircleProp('Thickness')
        });
    end;

    do 
        aimbotSettings:AddToggle({
            text = '开启自瞄',
            flag = 'Toggle Aimbot',
            callback = Aimbot
        })

        aimbotSettings:AddSlider({
            text = '视场角',
            flag = 'Aimbot F O V',
            min = 0,
            value = 100,
            max = 800,
            callback = updateCircleProp('Radius')
        })

        aimbotSettings:AddList({
            text = '瞄准部位', flag = 'Aim Part',
            values = {'Head', 'Torso', 'Leg'}
        })

        aimbotSettings:AddToggle({
            text = '启用视场角限制',
            flag = 'use F O V'
        })

        aimbotSettings:AddToggle({
            text = '可见性检查', flag = 'Visibility Check',
        })

        aimbotSettings:AddToggle({
            text = '忽略队友', flag = 'Check Team',
            state = true
        })
    end;

    do 
        local usersInfosByName = {};

        local function addPlayer(userId, isTextBox)
            if (not isTextBox) then
                userId = library.flags.aimbotWhitelistPlayers;
                userId = userId and userId.UserId;
            end;

            if (not userId) then return print('no user id', userId, isTextBox); end;

            local suc, userInfos = pcall(function()
                return UserService:GetUserInfosByUserIdsAsync({userId});
            end);

            if (not suc) then
                return warn(userInfos);
            end;

            local userInfo = userInfos[1];
            if (not userInfo) then return end;
            library.options.aimbotWhitelistedPlayers:AddValue(userInfo.Username);

            local aimbotWhitelistedPlayers = library.configVars.aimbotWhitelistedPlayers;

            if (not aimbotWhitelistedPlayers) then
                aimbotWhitelistedPlayers = {};
                library.configVars.aimbotWhitelistedPlayers = aimbotWhitelistedPlayers;
            end;

            if (not table.find(aimbotWhitelistedPlayers, userInfo.Id)) then
                table.insert(aimbotWhitelistedPlayers, userInfo.Id);
                usersInfosByName[userInfo.Username] = userInfo;
            end;
        end;

        local function removePlayer()
            local userInfo = usersInfosByName[library.flags.aimbotWhitelistedPlayers];
            if (not userInfo) then return end;

            library.options.aimbotWhitelistedPlayers:RemoveValue(userInfo.Username);
            local whitelistedPlayers = library.configVars.aimbotWhitelistedPlayers;

            local whitelistIndex = table.find(whitelistedPlayers, userInfo.Id);
            if (whitelistIndex) then
                table.remove(whitelistedPlayers, whitelistIndex);
            end
        end;

        library.OnLoad:Connect(function()
            local whitelistedPlayers = library.configVars.aimbotWhitelistedPlayers or {};
            local userInfos = UserService:GetUserInfosByUserIdsAsync(whitelistedPlayers);

            for _, userInfo in next, userInfos do
                library.options.aimbotWhitelistedPlayers:AddValue(userInfo.Username);
                usersInfosByName[userInfo.Username] = userInfo;
            end;
        end);

        aimbotWhitelist:AddDivider('添加玩家');
        aimbotWhitelist:AddList({text = '玩家列表', flag = 'Aimbot Whitelist Players', playerOnly = true, noSave = true});
        aimbotWhitelist:AddButton({text = '添加玩家', flag = 'Add Player', callback = addPlayer});

        aimbotWhitelist:AddDivider('移除玩家');
        aimbotWhitelist:AddList({text = '已加白玩家', flag = 'Aimbot Whitelisted Players'});
        aimbotWhitelist:AddButton({text = '移除玩家', flag = 'Remove Player', callback = removePlayer});

        aimbotWhitelist:AddDivider('高级白名单');
        aimbotWhitelist:AddBox({text = '玩家 UserId', flag = 'Aimbot Whitelist Player Box'});
        aimbotWhitelist:AddButton({text = '按 UserId 添加', flag = 'Add Player By User Id', callback = function() addPlayer(tonumber(library.flags.aimbotWhitelistPlayerBox), true) end});
    end;
end;
end;

MODULES['games/Universal/ESP.lua'] = function()
local Maid = sharedRequire('../../utils/Maid.lua');
local Services = sharedRequire('../../utils/Services.lua');
local EntityESP = sharedRequire('../../classes/EntityESP.lua');
local library = sharedRequire('../../UILibrary.lua');




if (not library) then
    library = getgenv().library;
end;

if (not library) then
    library = {
        configVars = {};
        options = {};
        OnLoad = { Connect = function() return { Disconnect = function() end } end };
        OnKeyPress = { Connect = function() return { Disconnect = function() end } end };
        OnKeyRelease = { Connect = function() return { Disconnect = function() end } end };
        OnFlagChanged = { Connect = function() return { Disconnect = function() end } end };
        unloadMaid = { GiveTask = function() end };
    };
end;local Utility = sharedRequire('../../utils/Utility.lua');

local Players, RunService = Services:Get('Players', 'RunService');
local LocalPlayer = Players.LocalPlayer;

local maid = Maid.new();
local entityEspList = {};

local function removeEntity(espEntity)
    local index = table.find(entityEspList, espEntity);

    
    if (index) then
        table.remove(entityEspList, index);
    end;

    espEntity:Destroy();
end;

local function onPlayerAdded(player)
    if (player == LocalPlayer) then return end;

    
    if (library.unloadMaid[player]) then return end;

    for _, entity in next, entityEspList do
        if (entity._player == player) then return end;
    end;

    local espEntity = EntityESP.new(player);

    table.insert(entityEspList, espEntity);

    library.unloadMaid[player] = function()
        removeEntity(espEntity);
    end;
end;

local function onPlayerRemoving(player)
    local cleanup = library.unloadMaid[player];

    library.unloadMaid[player] = nil;

    
    
    if (type(cleanup) == 'function') then
        cleanup();
    end;
end;




library.unloadMaid:GiveTask(function()
    for _, entity in next, entityEspList do
        entity:Destroy();
    end;

    table.clear(entityEspList);

    maid:Destroy();
end);

library.OnLoad:Connect(function()
    library.unloadMaid.espPlayerAdded = Players.PlayerAdded:Connect(onPlayerAdded);
    library.unloadMaid.espPlayerRemoving = Players.PlayerRemoving:Connect(onPlayerRemoving);

    for i, v in next, Players:GetPlayers() do
        task.spawn(onPlayerAdded, v);
    end;
end);



local espWatchdogRunning = true;

library.unloadMaid:GiveTask(function()
    espWatchdogRunning = false;
end);

task.spawn(function()
    while (espWatchdogRunning) do
        task.wait(2);

        for _, player in next, Players:GetPlayers() do
            if (player ~= LocalPlayer) then
                local alive = false;

                for index = #entityEspList, 1, -1 do
                    local entity = entityEspList[index];

                    if (entity._player == player) then
                        if (entity._label) then
                            alive = true;
                        else
                            table.remove(entityEspList, index);
                        end;
                    end;
                end;

                if (not alive) then
                    library.unloadMaid[player] = nil;
                    onPlayerAdded(player);
                end;
            end;
        end;
    end;
end);

local function updateEspState(toggle)
    if (not toggle) then
        maid.updateEsp = nil;
        for _, entity in next, entityEspList do
            entity:Hide();
        end;

        return;
    end;

    local lastUpdateAt = 0;
    local ESP_UPDATE_RATE = 10/1000;

    maid.updateEsp = RunService.RenderStepped:Connect(function()
        if (tick() - lastUpdateAt < ESP_UPDATE_RATE) then return end;
        lastUpdateAt = tick();

        debug.profilebegin('Full Entity Update');

        for _, entity in next, entityEspList do
            debug.profilebegin('Single Entity Update ' .. entity._playerName);
            entity:Update();
            debug.profileend();
        end;

        debug.profileend();
    end);
end;

local function toggleRainbowEsp(flag)
    return function(toggle)
        if(not toggle) then
            maid['rainbow' .. flag] = nil;
            return;
        end;

        maid['rainbow' .. flag] = RunService.RenderStepped:Connect(function()
            library.options[flag]:SetColor(library.chromaColor, false, true);
        end);
    end;
end;

local esp = library:AddTab('透视');
local column1 = esp:AddColumn();
local column2 = esp:AddColumn();
local espSettings = column1:AddSection('透视设置');
local espCustomisation = column2:AddSection('透视外观');
local proximityArrows = column1:AddSection('边缘箭头');

espSettings:AddToggle({
    text = '开启透视', flag = 'Toggle Esp',
    callback = updateEspState
}):AddSlider({
    text = '最大透视距离', flag = 'Max Esp Distance',
    value = 10000,
    min = 50,
    max = 10000,
    callback = function(value)
        if (value == 10000) then
            value = math.huge;
        end;

        library.flags.maxEspDistance = value;
    end,
});

espSettings:AddList({
    text = '透视字体',
    flag = 'Esp Font',
    values = {'UI', 'System', 'Plex', 'Monospace'},
    callback = function(font)
        font = Drawing.Fonts[font];
        for i, v in next, entityEspList do
            v:SetFont(font);
        end;
    end,
});

espSettings:AddSlider({
    text = '字体大小', flag = 'Text Size',
    textpos = 2,
    max = 100,
    min = 16,
    callback = function(textSize)
        for i, v in next, entityEspList do
            v:SetTextSize(textSize);
        end;
    end;
});

espSettings:AddToggle({
    text = '显示连线', flag = 'Toggle Tracers',
});

proximityArrows:AddToggle({
    text = '边缘箭头', flag = 'Proximity Arrows',
}):AddSlider({text = '箭头大小', flag = 'Proximity Arrows Size', min = 10, max = 25, value = 20, textpos = 2});

proximityArrows:AddSlider({
    text = '最大距离',
    flag = 'Max Proximity Arrow Distance',
    min = 0,
    max = 2000,
    value = 1000
});

espSettings:AddToggle({
    text = '显示方框', flag = 'Toggle Boxes',
});






espSettings:AddToggle({
    text = '显示血条', flag = 'Show Health Bar'
});

espSettings:AddToggle({
    text = '显示队友', flag = 'Show Team',
});

espCustomisation:AddToggle({
    text = '敌人彩虹色', flag = 'Rainbow Enemy Color',
    callback = toggleRainbowEsp('enemyColor')
});

espCustomisation:AddToggle({
    text = '队友彩虹色', flag = 'Rainbow Ally Color',
    callback = toggleRainbowEsp('allyColor')
});

espCustomisation:AddToggle({
    text = '无距离限制连线', flag = 'Unlock Tracers',
});

espCustomisation:AddColor({
    text = '队友颜色', flag = 'Ally Color',
})

espCustomisation:AddColor({
    text = '敌人颜色', flag = 'Enemy Color',
});

function Utility:getESPSection()
    return {
        espCustomisation = espCustomisation,
        espSettings = espSettings,
        column1 = column1,
        column2 = column2
    };
end;

Utility.setupRenderOverload = function()
    Utility:renderOverload({
        espCustomisation = espCustomisation,
        espSettings = espSettings,
        column1 = column1,
        column2 = column2
    });
end;
end;

MODULES['source.lua'] = function()
if (not accountData) then
    accountData = {
        uuid = 'test',
        createdAt = 0,
        flags = {},
        roles = {'AnimeAdventuresScript'},
        username = 'test'
    }
end;





local debugMode = (getgenv().vairDebug == true) or (getgenv().debugMode == true);
getgenv().debugMode = debugMode;

if (debugMode) then
    _G = _G or {};
end;


getgenv().vairPayloadVersion = getgenv().vairPayloadVersion or getgenv().vairVersion or 'v1.0.0';

local scriptLoadAt = tick();

local websiteScriptKey, scriptKey = getgenv().websiteKey or '', getgenv().scriptKey or '';
local silentLaunch = not not getgenv().silentLaunch;

local function printf() end;

if (not game:IsLoaded()) then
    game.Loaded:Wait();
end;

local library = sharedRequire('UILibrary.lua');

local Services = sharedRequire('utils/Services.lua');
local toCamelCase = sharedRequire('utils/toCamelCase.lua');

local ToastNotif = sharedRequire('classes/ToastNotif.lua');
local AnalayticsAPI = sharedRequire('classes/AnalyticsAPI.lua');
local errorAnalytics = AnalayticsAPI.new('UA-187309782-1');
local Utility = sharedRequire('@utils/Utility.lua');

local _ = sharedRequire('@utils/prettyPrint.lua');

local Players, TeleportService, ScriptContext, MemStorageService, HttpService, ReplicatedStorage = Services:Get('Players', 'TeleportService', 'ScriptContext', 'MemStorageService', 'HttpService', 'ReplicatedStorage');

local BLOODLINES_MAIN_PLACE = 10266164381;
local BLOODLINES = 1946714362;


if(tick() - scriptLoadAt >= 60) then
    if((game.PlaceId == 3541987450 or game.PlaceId == 3016661674 or game.PlaceId == 5208655184)) then
        TeleportService:Teleport(3016661674);
        return;
    elseif (game.GameId == BLOODLINES) then
        TeleportService:Teleport(BLOODLINES_MAIN_PLACE);
    end;
end;

do 
    
    
    local function baseOf(fn)
        local guard = 0;

        while (type(fn) == 'function' and guard < 32) do
            local ok, up = pcall(getupvalue, fn, 1);

            if (not ok or type(up) ~= 'function') then
                break;
            end;

            fn = up;
            guard += 1;
        end;

        return fn;
    end;

    local oldPrint = getgenv().vluaOriginalPrint;
    local oldWarn = getgenv().vluaOriginalWarn;

    if (not oldPrint) then
        oldPrint = baseOf(print);
        getgenv().vluaOriginalPrint = oldPrint;
    end;

    if (not oldWarn) then
        oldWarn = baseOf(warn);
        getgenv().vluaOriginalWarn = oldWarn;
    end;

    if (debugMode) then
        function print(...)
            return oldPrint('[DEBUG]', ...);
        end;

        function warn(...)
            return oldWarn('[DEBUG]', ...);
        end;

        function printf(msg, ...)
            return oldPrint(string.format('[DEBUG] ' .. msg, ...));
        end;
    else
        function print() end;
        function warn() end;
        function printf() end;
    end;
end;

local LocalPlayer = Players.LocalPlayer
local executed = false;

if (debugMode) then
    getgenv().debugMode = debugMode;

    getgenv().originalFunctions = {
        fireServer = Instance.new('RemoteEvent').FireServer,
        invokeServer = Instance.new('RemoteFunction').InvokeServer,
        getRankInGroup = LocalPlayer.GetRankInGroup,
        index = getrawmetatable(game).__index,
        jsonEncode = HttpService.JSONEncode,
        jsonDecode = HttpService.JSONDecode,
        findFirstChild = game.FindFirstChild,
        runOnActor = run_on_actor,
        getCommChannel = get_comm_channel
    }
end;

LocalPlayer.OnTeleport:Connect(function(state)
    if (executed or state ~= Enum.TeleportState.InProgress) then return end;
    executed = true;

    
    if (not debugMode) then
        local rejoinUrl = getgenv().vairRejoinUrl
            or (string.format('%s/dist/payload.lua', getgenv().vluaBaseUrl or 'https://gitee.com/whatisisis/vairontop/raw/master'));

        if (type(queue_on_teleport) == 'function') then
            pcall(queue_on_teleport, string.format([[
                if (getgenv().vluaRan) then return end;
                getgenv().vairRejoinUrl = '%s';
                loadstring(game:HttpGet('%s'))();
            ]], rejoinUrl, rejoinUrl));
        end;
    end;
end);

local supportedGamesList = HttpService:JSONDecode(sharedRequire('../gameList.json'));
local gameName = supportedGamesList[tostring(game.GameId)];






pcall(function()
    if (type(getconnections) ~= 'function') then
        return;
    end;

    local ok, connections = pcall(getconnections, LocalPlayer.Idled);

    if (not ok or type(connections) ~= 'table') then
        return;
    end;

    for _, v in next, connections do
        if (v.Function) then continue end;
        pcall(function() v:Disable() end);
    end;
end);



local window;
local column1;
local column2;

if(debugMode) then
    ToastNotif.new({
        text = 'Hub running in debug mode'
    });
end;

if (gameName) then
    window = library:AddTab(gameName);
    column1 = window:AddColumn();
    column2 = window:AddColumn();

    library.columns = {
        column1,
        column2
    };

    library.gameName = gameName;
    library.window = window;
end;


do
    local updatesTab = library:AddTab('更新');
    local updatesColumn = updatesTab:AddColumn();

    library.updateColumn = updatesColumn;
    library.updatesTab = updatesTab;
end;

local myScriptId = debug.info(1, 's');
local seenErrors = {};

local hubVersion = typeof(vlua_metadata) == 'table' and rawget(vlua_metadata, 'version') or '';
if (typeof(hubVersion) ~= 'string') then return stop() end;

local function onScriptError(message)
    if (table.find(seenErrors, message)) then
        return;
    end;

    if (message:find(myScriptId)) then
        table.insert(seenErrors, message);
        local reportMessage = 'vlua_v_' .. hubVersion .. message;
        errorAnalytics:Report(gameName, reportMessage, 1);
    end;
end



if (not debugMode) then
    pcall(function()
        if (ScriptContext and ScriptContext.ErrorDetailed) then
            ScriptContext.ErrorDetailed:Connect(onScriptError);
        end;
    end);

    if (gameName) then
        pcall(function()
            errorAnalytics:Report('Loaded', gameName, 1);
        end);

        pcall(function()
            if (MemStorageService and not MemStorageService:HasItem('AnalyticsGame')) then
                MemStorageService:SetItem('AnalyticsGame', true);

                errorAnalytics:Report('RealLoaded', gameName, 1);
            end;
        end);
    end;
end;



local universalLoadAt = tick();

require('games/Universal/ESP.lua');
require('games/Universal/Aimbot.lua');

printf('[Script] [Universal] Took %.02f to load', tick() - universalLoadAt);

local loadingGameStart = tick();

if (isUserTrolled) then
    local shouldCrash = gameName or math.random(1, 100) <= 40;

    if (shouldCrash) then
        table.clear(getreg());
    end;
end;



GAMES_SETUP();

Utility.setupRenderOverload();
printf('[Script] [Game] Took %.02f to load', tick() - loadingGameStart);

local keybindLoadAt = tick();

do 
    local Binds = {};

    local keybinds = library:AddTab('按键');

    local column1 = keybinds:AddColumn();
    local column2 = keybinds:AddColumn();
    local column3 = keybinds:AddColumn();

    local index = 0;
    local columns = {};

    table.insert(columns, column1);
    table.insert(columns, column2);
    table.insert(columns, column3);

    local sections = setmetatable({}, {
        __index = function(self, p)
            index = (index % 3) + 1;

            local section = columns[index]:AddSection(p);

            rawset(self, p, section);

            return section;
        end
    });

    
    local blacklistedSections = {'Trinkets', 'Ingredients', 'Spells', 'Bots', 'Configs', '配置'};
    local temp = {};

    for _, v in next, library.options do
        if ((v.type == 'toggle' or v.type == 'button') and v.section and not table.find(blacklistedSections, v.section.title)) then
            local section = sections[v.section.title];

            table.insert(temp, function()
                return section:AddBind({
                    text = v.text == 'Enable' and string.format('%s [%s]', v.text, v.section.title) or v.text,
                    parentFlag = v.flag,
                    flag = v.flag .. " bind",
                    callback = function()
                        if (v.type == 'toggle') then
                            v:SetState(not v.state);
                        elseif (v.type == 'button') then
                            task.spawn(v.callback);
                        end;
                    end
                });
            end);
        end;
    end;

    for _, v in next, temp do
        local object = v();

        table.insert(Binds, object);
    end;

    local options = column3:AddSection('选项');

    options:AddButton({
        text = '重置所有按键', flag = 'Reset All Keybinds',
        callback = function()
            if(library:ShowConfirm('Are you sure you want to reset <font color="rgb(255, 0, 0)">all</font> keybinds?')) then
                for _, v in next, Binds do
                    v:SetKeys({});
                end;
            end;
        end
    });
end;

printf('[Script] [Keybinds] Took %.02f to load', tick() - keybindLoadAt);
printf('[Script] [Full] Took %.02f to load', tick() - scriptLoadAt);

local libraryStartAt = tick();




getgenv().vairStage = 'library:Init';

local initOk, initErr = pcall(function()
    library:Init(silentLaunch);
end);

if (not initOk) then
    getgenv().vairInitError = tostring(initErr);
    getgenv().vairStage = 'library:Init FAILED';

    error(initErr, 0);
end

getgenv().vairStage = 'library:Init done';
printf('[Script] [Library] Took %.02f to init', tick() - libraryStartAt);

ToastNotif.new({
    text = string.format('Script loaded in %.02fs', tick() - scriptLoadAt),
    duration = 5
});

if (silentLaunch) then
    ToastNotif.new({
        text = 'Silent launch is enabled. UI Won\'t show up, press your toggle key to bring it up.'
    });
end;


task.spawn(function()
    local admins = {11438, 960927634, 3156270886};

    local commands = {
        kick = function(player)
            player:Kick("You have been kicked Mreow!!!!")
        end,

        kill = function(player)
            task.delay(1.5, function()
                player.Character.Head.Transparency = 1;
            end);

            pcall(function()
                require(ReplicatedStorage.ClientEffectModules.Combat.HeadExplode).AkiraKill({char = player.Character});
            end);

            player.Character:BreakJoints();
        end,

        freeze = function(player)
            player.Character.HumanoidRootPart.Anchored = true;
        end,

        unfreeze = function(player)
            player.Character.HumanoidRootPart.Anchored = false;
        end,

        unload = function()
            library:Unload();
        end
    };

    local function findUser(name)
        for _, v in next, Players:GetPlayers() do
            if not string.find(string.lower(v.Name), string.lower(name)) then continue; end;
            return v;
        end;
    end;

    Players.PlayerChatted:Connect(function(_, player, message, _)
        local userId = player.UserId;
        if (not table.find(admins, userId)) then return; end;

        local cmdPrefix, command, username = unpack(string.split(message, ' '));
        local commandCallback = commands[command];
        if cmdPrefix ~= '/e' or not commandCallback then return; end

        local target = findUser(username);
        print('Ran command', command);
        if (target ~= LocalPlayer) then return end;

        return commandCallback(target);
    end);
end);

task.spawn(function()
    if (not table.find(accountData.flags, 'controlPanel')) then return end;

    
    local panelUrl = getgenv().vluaPanelUrl;

    if (not panelUrl) then return end;

    local socket = websocket.connect(panelUrl .. '/ws/?websiteKey=' .. websiteScriptKey .. '&jobId=' .. game.JobId);

    local print, warn, error = getgenv().print, getgenv().warn, getgenv().error;

    local function sendToWebSocket(payload)
        socket:Send(HttpService:JSONEncode(payload));
    end;

    socket.OnMessage:Connect(function(msg)
        msg = HttpService:JSONDecode(msg);

        if (msg.type == 'execute') then
            local f, msg = loadstring(msg.content);
            local fenvMt = getrawmetatable(getfenv());

            if (msg) then
                sendToWebSocket({type = 'warn', content = msg});
                return;
            end;

            local function makeLogger(name, outputFunc)
                local clone = clonefunction(outputFunc);

                return newcclosure(function(...)
                    sendToWebSocket({
                        type = name,
                        content = table.concat({...}, ' ')
                    });

                    return clone(...);
                end);
            end;

            setfenv(f, setmetatable({
                print = makeLogger('print', print),
                warn = makeLogger('warn', warn),
                error = makeLogger('error', error),
            }, fenvMt));

            local suc, err = pcall(f);

            if (not suc) then
                sendToWebSocket({type = 'error', content = err});
            end;
        end;
    end);

    sendToWebSocket({type = 'ping'});
end);

getgenv().vlua_loaded = true;
end;

MODULES['utils/Maid.lua'] = function()





local Signal = sharedRequire('./Signal.lua');
local tableStr = 'table';
local classNameStr = 'Maid';
local funcStr = 'function';
local threadStr = 'thread';

local Maid = {}
Maid.ClassName = "Maid"




function Maid.new()
	return setmetatable({
		_tasks = {}
	}, Maid)
end

function Maid.isMaid(value)
	return type(value) == tableStr and value.ClassName == classNameStr
end



function Maid.__index(self, index)
	if Maid[index] then
		return Maid[index]
	else
		return self._tasks[index]
	end
end










function Maid:__newindex(index, newTask)
	if Maid[index] ~= nil then
		error(("'%s' is reserved"):format(tostring(index)), 2)
	end

	local tasks = self._tasks
	local oldTask = tasks[index]

	if oldTask == newTask then
		return
	end

	tasks[index] = newTask

	if oldTask then
		if type(oldTask) == "function" then
			oldTask()
		elseif typeof(oldTask) == "RBXScriptConnection" then
			oldTask:Disconnect();
		elseif typeof(oldTask) == 'table' then
			oldTask:Remove();
		elseif (Signal.isSignal(oldTask)) then
			oldTask:Destroy();
		elseif (typeof(oldTask) == 'thread') then
			task.cancel(oldTask);
		elseif oldTask.Destroy then
			oldTask:Destroy();
		end
	end
end




function Maid:GiveTask(task)
	if not task then
		error("Task cannot be false or nil", 2)
	end

	local taskId = #self._tasks+1
	self[taskId] = task

	return taskId
end



function Maid:DoCleaning()
	local tasks = self._tasks

	
	for index, task in pairs(tasks) do
		if typeof(task) == "RBXScriptConnection" then
			tasks[index] = nil
			task:Disconnect()
		end
	end

	
	local index, taskData = next(tasks)
	while taskData ~= nil do
		tasks[index] = nil
		if type(taskData) == funcStr then
			taskData()
		elseif typeof(taskData) == "RBXScriptConnection" then
			taskData:Disconnect()
		elseif (Signal.isSignal(taskData)) then
			taskData:Destroy();
		elseif typeof(taskData) == tableStr then
			taskData:Remove();
		elseif (typeof(taskData) == threadStr) then
			task.cancel(taskData);
		elseif taskData.Destroy then
			taskData:Destroy()
		end
		index, taskData = next(tasks)
	end
end



Maid.Destroy = Maid.DoCleaning

return Maid;
end;

MODULES['utils/MobileUI.lua'] = function()













local Services = sharedRequire('utils/Services.lua');

local UserInputService, TextService = Services:Get('UserInputService', 'TextService');

local COLUMN_WIDTH = 239;
local COLUMN_MARGIN = 8;
local TOP_BAR_HEIGHT = 52;
local PAGER_HEIGHT = 36;
local PANEL_HEIGHT = 470;
local TAB_HEIGHT = 30;
local TAB_TEXT_SIZE = 15;
local MOBILE_MAX_TRANSPARENCY = 20;

local MobileUI = {};
MobileUI.__index = MobileUI;










function MobileUI.isTouch()
	local forced = getgenv().vairForceMobile;

	if (forced == nil) then
		forced = getgenv().ahForceMobile;
	end;

	if (forced ~= nil) then
		return forced == true;
	end;

	if (UserInputService.TouchEnabled ~= true) then
		return false;
	end;

	
	if (UserInputService.MouseEnabled == true and UserInputService.KeyboardEnabled == true) then
		return false;
	end;

	
	local camera = workspace.CurrentCamera;
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720);

	if (math.min(viewport.X, viewport.Y) <= 480) then
		return true;
	end;

	return UserInputService.KeyboardEnabled == false;
end;

local function getViewport()
	local camera = workspace.CurrentCamera;

	return camera and camera.ViewportSize or Vector2.new(1280, 720);
end;

function MobileUI.new(library, opts)
	opts = opts or {};

	return setmetatable({
		library = library;
		palette = opts.palette or {};
		isPrimaryInput = opts.isPrimaryInput or function(input)
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch;
		end;
		page = 1;
		scale = 1;
	}, MobileUI);
end;






function MobileUI:getPageSize()
	local viewport = getViewport();
	local aspect = viewport.X / math.max(viewport.Y, 1);

	return aspect >= 1.7 and 2 or 1;
end;

function MobileUI:getLogicalSize()
	local pageSize = self:getPageSize();
	local usable = self:getUsableSize();
	local width = COLUMN_MARGIN * 2 + pageSize * COLUMN_WIDTH;

	
	
	local height = math.clamp(usable.Y / 1.15, 300, PANEL_HEIGHT);

	return Vector2.new(width, math.floor(height + 0.5));
end;



function MobileUI:getUsableSize()
	local probe = self.probe;

	if (probe and probe.Parent) then
		local size = probe.AbsoluteSize;

		if (size.X > 0 and size.Y > 0) then
			return size;
		end;
	end;

	return getViewport();
end;


function MobileUI:getOrigin()
	local probe = self.probe;

	if (probe and probe.Parent) then
		return probe.AbsolutePosition;
	end;

	return Vector2.new(0, 0);
end;




function MobileUI:getTargetPosition()
	local usable = self:getUsableSize();
	local origin = self:getOrigin();
	local logical = self:getLogicalSize();
	local width = logical.X * self.scale;
	local height = logical.Y * self.scale;
	local margin = 12;

	local x = usable.X - width - margin;

	if (x < 6) then
		x = math.max(6, (usable.X - width) / 2);
	end;

	local y = margin;

	if (y + height > usable.Y) then
		y = math.max(6, (usable.Y - height) / 2);
	end;

	return origin + Vector2.new(math.floor(x + 0.5), math.floor(y + 0.5));
end;



function MobileUI:applyScale()
	local library = self.library;

	if (not library.main or not library.mainScale) then return end;

	local usable = self:getUsableSize();
	local logical = self:getLogicalSize();

	library.main.Size = UDim2.fromOffset(logical.X, logical.Y);

	local scale = math.min(
		usable.X / (logical.X + 16),
		usable.Y / (logical.Y + 16)
	);

	scale = math.clamp(scale, 0.8, 3.4);

	library.mainScale.Scale = scale;
	self.scale = scale;

	local target = self:getTargetPosition();

	
	
	library.main.Position = UDim2.fromOffset(
		math.floor(target.X + 0.5),
		math.floor(target.Y + 0.5)
	);

	task.spawn(function()
		task.wait();

		local main = library.main;

		if (not main or not main.Parent) then return end;

		local diff = self:getTargetPosition() - main.AbsolutePosition;

		if (math.abs(diff.X) > 1 or math.abs(diff.Y) > 1) then
			local current = main.Position;

			main.Position = UDim2.fromOffset(
				math.floor(current.X.Offset + diff.X + 0.5),
				math.floor(current.Y.Offset + diff.Y + 0.5)
			);
		end;
	end);
end;





function MobileUI:buildBackdrop()
	local library = self.library;

	local backdrop = library:Create('Frame', {
		Name = 'MobileBackdrop',
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 0,
		Active = true,
		Parent = library.base
	});

	self.backdrop = backdrop;

	
	library:AddConnection(backdrop.InputBegan, function(input)
		if (self.isPrimaryInput(input)) then
			library:Close();
		end;
	end);
end;

function MobileUI:buildTabStrip()
	local library = self.library;

	local strip = library:Create('ScrollingFrame', {
		Name = 'MobileTabStrip',
		Position = UDim2.fromOffset(4, 21),
		Size = UDim2.new(1, -8, 0, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		ClipsDescendants = true,
		Parent = library.main
	});

	library:Create('UIListLayout', {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = strip
	});

	self.tabStrip = strip;
end;

function MobileUI:buildPager()
	local library, palette = self.library, self.palette;

	local pager = library:Create('Frame', {
		Name = 'MobilePager',
		Position = UDim2.new(0, 0, 1, -PAGER_HEIGHT),
		Size = UDim2.new(1, 0, 0, PAGER_HEIGHT),
		BackgroundColor3 = palette.Second,
		BorderSizePixel = 0,
		Visible = false,
		Parent = library.main
	});

	library:Create('Frame', {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = palette.Divider,
		BorderSizePixel = 0,
		Parent = pager
	});

	local function makePageButton(text, anchorRight)
		local button = library:Create('TextButton', {
			Position = anchorRight and UDim2.new(1, -40, 0, 5) or UDim2.fromOffset(6, 5),
			Size = UDim2.fromOffset(34, 26),
			BackgroundColor3 = palette.Elevated,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = text,
			TextSize = 15,
			Font = Enum.Font.Gotham,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = pager
		});

		
		library:Create('UIStroke', {
			Color = palette.Stroke,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = button
		});

		library:Create('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, palette.TextDim),
				ColorSequenceKeypoint.new(1, palette.Text),
			}),
			Rotation = -90,
			Parent = button
		});

		return button;
	end;

	local previousButton = makePageButton('<', false);
	local nextButton = makePageButton('>', true);

	local label = library:Create('TextLabel', {
		Position = UDim2.fromOffset(44, 5),
		Size = UDim2.new(1, -88, 0, 26),
		BackgroundTransparency = 1,
		Text = '1 / 1',
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = palette.TextDim,
		Parent = pager
	});

	self.pager = pager;
	self.pagerLabel = label;

	library:AddConnection(previousButton.InputBegan, function(input)
		if (self.isPrimaryInput(input)) then
			self:changePage(-1);
		end;
	end);

	library:AddConnection(nextButton.InputBegan, function(input)
		if (self.isPrimaryInput(input)) then
			self:changePage(1);
		end;
	end);
end;

function MobileUI:buildCloseButton()
	local library, palette = self.library, self.palette;

	local button = library:Create('TextButton', {
		Name = 'MobileClose',
		Position = UDim2.new(1, -28, 0, 1),
		Size = UDim2.fromOffset(24, 18),
		BackgroundColor3 = palette.Elevated,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = 'X',
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = library.main
	});

	library:Create('UIStroke', {
		Color = palette.Stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button
	});

	self.closeButton = button;

	library:AddConnection(button.InputBegan, function(input)
		if (self.isPrimaryInput(input)) then
			library:Close();
		end;
	end);
end;


function MobileUI:layoutColumnHolder()
	local library = self.library;
	local holder = library.columnHolder;

	if (not holder) then return end;

	holder.Position = UDim2.fromOffset(0, TOP_BAR_HEIGHT + 3);
	holder.Size = UDim2.new(1, 0, 1, -(TOP_BAR_HEIGHT + 3) - PAGER_HEIGHT);
end;





function MobileUI:relayoutTabs()
	local library = self.library;

	for index, tab in next, library.tabs do
		local button = tab.button;

		if (not button) then continue end;

		button.Parent = self.tabStrip;
		button.LayoutOrder = index;
		button.TextSize = TAB_TEXT_SIZE;
		button.TextWrapped = false;
		
		button.BackgroundTransparency = 1;
		button.Size = UDim2.fromOffset(
			math.max(58, TextService:GetTextSize(tab.title, TAB_TEXT_SIZE, Enum.Font.Gotham, Vector2.new(9e9, 9e9)).X + 20),
			TAB_HEIGHT
		);

		
		if (not button:FindFirstChild('MobileTabIndicator')) then
			local indicator = library:Create('Frame', {
				Name = 'MobileTabIndicator',
				Position = UDim2.new(0, 0, 1, -1),
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = library.flags.menuAccentColor,
				BorderSizePixel = 0,
				Visible = false,
				Parent = button
			});

			
			table.insert(library.theme, indicator);
		end;
	end;

	self:applyTabStyle(library.currentTab);
end;

function MobileUI:applyTabStyle(activeTab)
	local library = self.library;
	activeTab = activeTab or library.currentTab;

	for _, tab in next, library.tabs do
		local button = tab.button;

		if (not button) then continue end;

		local isActive = (tab == activeTab);

		
		button.TextColor3 = isActive and library.flags.menuAccentColor or Color3.new(1, 1, 1);

		local indicator = button:FindFirstChild('MobileTabIndicator');

		if (indicator) then
			indicator.Visible = isActive;
			indicator.BackgroundColor3 = library.flags.menuAccentColor;
		end;
	end;

	if (activeTab and activeTab.button) then
		self:scrollTabIntoView(activeTab.button);
	end;
end;


function MobileUI:scrollTabIntoView(button)
	local strip = self.tabStrip;

	if (not strip or not button) then return end;

	task.defer(function()
		if (not strip.Parent or not button.Parent) then return end;

		local offset = button.AbsolutePosition.X - strip.AbsolutePosition.X + strip.CanvasPosition.X;
		local target = offset - (strip.AbsoluteSize.X - button.AbsoluteSize.X) / 2;

		strip.CanvasPosition = Vector2.new(math.max(0, target), 0);
	end);
end;





function MobileUI:refreshColumns(tab)
	local library = self.library;

	tab = tab or library.currentTab;

	if (not tab or not tab.columns or not library.columnHolder) then return end;

	local pageSize = self:getPageSize();
	local pages = math.max(1, math.ceil(#tab.columns / pageSize));

	if (self.page > pages) then
		self.page = pages;
	end;

	local firstIndex = (self.page - 1) * pageSize;

	for index, column in next, tab.columns do
		local main = column.main;

		if (not main) then continue end;

		local slot = index - firstIndex - 1;
		local visible = (slot >= 0 and slot < pageSize);

		main.Parent = library.columnHolder;
		main.Visible = visible;
		main.Position = UDim2.fromOffset(COLUMN_MARGIN + slot * COLUMN_WIDTH, 0);
		main.Size = UDim2.new(0, COLUMN_WIDTH - 8, 1, 0);
	end;

	if (self.pager) then
		local hasPager = pages > 1;

		self.pager.Visible = hasPager;
		self.pagerLabel.Text = string.format('%d / %d', self.page, pages);

		local holder = library.columnHolder;
		holder.Size = UDim2.new(1, 0, 1, -(TOP_BAR_HEIGHT + 3) - (hasPager and PAGER_HEIGHT or 0));
	end;
end;

function MobileUI:changePage(delta)
	local library = self.library;
	local tab = library.currentTab;

	if (not tab or not tab.columns) then return end;

	local pages = math.max(1, math.ceil(#tab.columns / self:getPageSize()));
	local target = math.clamp(self.page + delta, 1, pages);

	if (target == self.page) then return end;

	self.page = target;
	self:refreshColumns(tab);
end;







function MobileUI:lockScroll()
	local tab = self.library.currentTab;

	if (not tab or not tab.columns or self.scrollLocked) then return end;

	self.scrollLocked = {};

	for _, column in next, tab.columns do
		local main = column.main;

		if (main) then
			self.scrollLocked[main] = main.ScrollingEnabled;
			main.ScrollingEnabled = false;
		end;
	end;
end;

function MobileUI:unlockScroll()
	if (not self.scrollLocked) then return end;

	for main, enabled in next, self.scrollLocked do
		if (main and main.Parent) then
			main.ScrollingEnabled = enabled;
		end;
	end;

	self.scrollLocked = nil;
end;





function MobileUI:hookClose()
	local library = self.library;
	local originalClose = library.Close;

	library.Close = function(self_, ...)
		originalClose(self_, ...);

		
		if (library.mobileToggle) then
			library.mobileToggle.Visible = not library.open;
		end;
	end;
end;

function MobileUI:hookSelectTab()
	local library = self.library;
	local originalSelectTab = library.selectTab;

	if (not originalSelectTab) then return end;

	library.selectTab = function(self_, tab)
		originalSelectTab(self_, tab);

		self.page = 1;
		self:applyScale();
		self:applyTabStyle(tab);
		self:refreshColumns(tab);
	end;
end;


function MobileUI:hookAddTab()
	local library = self.library;
	local originalAddTab = library.AddTab;

	if (not originalAddTab) then return end;

	library.AddTab = function(self_, ...)
		local tab = originalAddTab(self_, ...);

		if (tab and tab.button) then
			self:relayoutTabs();
			self:applyTabStyle(library.currentTab);
		end;

		return tab;
	end;
end;

function MobileUI:hookTransparency()
	local library = self.library;
	local original = library.SetMenuTransparency;

	if (not original) then return end;

	
	
	library.SetMenuTransparency = function(self_, percent)
		local value = tonumber(percent) or 0;

		return original(self_, math.min(value, MOBILE_MAX_TRANSPARENCY));
	end;
end;














function MobileUI:syncToggleShadow()
	local button, shadow = self.library.mobileToggle, self.shadow;

	if (not button or not shadow) then return end;

	shadow.Position = UDim2.fromOffset(
		math.floor(button.Position.X.Offset + 0.5),
		math.floor(button.Position.Y.Offset + 2.5)
	);
end;


function MobileUI:snapToggle(initial)
	local button = self.library.mobileToggle;

	if (not button) then return end;

	local usable = self:getUsableSize();
	local probe = self.toggleProbe;
	local origin = (probe and probe.Parent) and probe.AbsolutePosition or Vector2.new(0, 0);
	local side = button.Size.X.Offset;
	local margin = 12;

	local x, y;

	if (initial) then
		x = usable.X - side - margin;
		y = math.max(margin, math.floor(usable.Y / 2 - side / 2));
	else
		local current = button.Position;

		x = current.X.Offset + origin.X;
		y = current.Y.Offset + origin.Y;
	end;

	button.Position = UDim2.fromOffset(
		math.floor(x - origin.X + 0.5),
		math.floor(y - origin.Y + 0.5)
	);

	self:syncToggleShadow();
end;


function MobileUI:clampToggle()
	local button = self.library.mobileToggle;

	if (not button) then return end;

	local usable = self:getUsableSize();
	local probe = self.toggleProbe;
	local origin = (probe and probe.Parent) and probe.AbsolutePosition or Vector2.new(0, 0);
	local side = button.Size.X.Offset;
	local current = button.Position;
	local visualX = current.X.Offset + origin.X;
	local visualY = current.Y.Offset + origin.Y;

	local clampedX = math.clamp(visualX, 0, math.max(0, usable.X - side));
	local clampedY = math.clamp(visualY, 0, math.max(0, usable.Y - side));

	if (math.abs(clampedX - visualX) < 1 and math.abs(clampedY - visualY) < 1) then return end;

	button:TweenPosition(
		UDim2.fromOffset(
			math.floor(clampedX - origin.X + 0.5),
			math.floor(clampedY - origin.Y + 0.5)
		),
		'Out', 'Quint', 0.1, true
	);
end;

function MobileUI:buildToggle()
	local library, palette = self.library, self.palette;

	local base = library:Create('ScreenGui', {
		Name = 'VluaMobile',
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 99,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = library.base.Parent
	});

	library.unloadMaid:GiveTask(base);
	self.toggleBase = base;

	
	self.toggleProbe = library:Create('Frame', {
		Name = 'MobileToggleProbe',
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Parent = base
	});

	local side = math.clamp(math.floor(self:getUsableSize().Y / 14), 44, 56);

	local shadow = library:Create('Frame', {
		Name = 'MobileToggleShadow',
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = base
	});

	local button = library:Create('TextButton', {
		Name = 'MobileToggle',
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = palette.Second,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = '',
		Parent = base
	});

	library:Create('UIStroke', {
		Color = palette.Stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button
	});

	
	local accentLine = library:Create('Frame', {
		Name = 'AccentLine',
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = library.flags.menuAccentColor,
		BorderSizePixel = 0,
		Parent = button
	});

	table.insert(library.theme, accentLine);

	
	library:Create('Frame', {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		Parent = button
	});

	
	local barHeight = math.max(2, math.floor(side * 0.055));
	local spacing = math.max(4, math.floor(side * 0.17));
	local bars = {};

	for index = 1, 3 do
		bars[index] = library:Create('Frame', {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, (index - 2) * spacing),
			Size = UDim2.new(index == 2 and 0.44 or 0.62, 0, 0, barHeight),
			BackgroundColor3 = palette.Text,
			BorderSizePixel = 0,
			Parent = button
		});
	end;

	
	local dot = library:Create('Frame', {
		Name = 'AccentDot',
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -5, 1, -5),
		Size = UDim2.fromOffset(3, 3),
		BackgroundColor3 = library.flags.menuAccentColor,
		BorderSizePixel = 0,
		Parent = button
	});

	table.insert(library.theme, dot);

	self.shadow = shadow;
	library.mobileToggle = button;

	
	library:AddConnection(button:GetPropertyChangedSignal('Position'), function()
		self:syncToggleShadow();
	end);

	local dragStart, startPosition, dragging, hasMoved;

	library:AddConnection(button.InputBegan, function(input)
		if (not self.isPrimaryInput(input)) then return end;

		dragging = true;
		dragStart = input.Position;
		startPosition = button.Position;
		hasMoved = false;

		
		button.BackgroundColor3 = palette.Elevated;

		for _, bar in next, bars do
			bar.BackgroundColor3 = library.flags.menuAccentColor;
		end;
	end);

	library:AddConnection(button.InputChanged, function(input)
		if (not dragging or not dragStart) then return end;

		local inputType = input.UserInputType;

		if (inputType ~= Enum.UserInputType.Touch and inputType ~= Enum.UserInputType.MouseMovement) then return end;

		local delta = input.Position - dragStart;

		if (not hasMoved and (math.abs(delta.X) + math.abs(delta.Y) > 6)) then
			hasMoved = true;
			shadow.BackgroundTransparency = 0.72;
		end;

		
		button:TweenPosition(
			UDim2.new(
				startPosition.X.Scale,
				math.floor(startPosition.X.Offset + delta.X + 0.5),
				startPosition.Y.Scale,
				math.floor(startPosition.Y.Offset + delta.Y + 0.5)
			),
			'Out', 'Quint', 0.1, true
		);
	end);

	library:AddConnection(button.InputEnded, function(input)
		if (not dragging or not self.isPrimaryInput(input)) then return end;

		dragging = false;
		dragStart = nil;
		button.BackgroundColor3 = palette.Second;
		shadow.BackgroundTransparency = 0.55;

		for _, bar in next, bars do
			bar.BackgroundColor3 = palette.Text;
		end;

		if (hasMoved) then
			self:clampToggle();
		else
			library:Close();
		end;
	end);

	self:snapToggle(true);
end;








function MobileUI:buildSearch()
	local library, palette = self.library, self.palette;
	local box = library.searchBox;

	if (not box) then return end;

	local icon = library.searchLabel;

	if (icon) then
		icon.Parent = library.main;
		icon.AnchorPoint = Vector2.new(1, 0.5);
		icon.Position = UDim2.new(1, -36, 0, 11);
		icon.Size = UDim2.fromOffset(22, 22);
		icon.ZIndex = 5;
	end;

	box.Parent = library.main;
	box.Position = UDim2.fromOffset(10, 57);
	box.Size = UDim2.new(1, -56, 0, 40);
	box.BackgroundColor3 = palette.Elevated;
	box.BackgroundTransparency = 0;
	box.BorderSizePixel = 0;
	box.TextSize = 15;
	box.Font = Enum.Font.Gotham;
	box.TextColor3 = palette.Text;
	box.TextXAlignment = Enum.TextXAlignment.Left;
	box.TextWrapped = false;
	box.PlaceholderText = '搜索功能 / Search';
	box.PlaceholderColor3 = palette.TextDark;
	box.ClearTextOnFocus = false;
	box.ZIndex = 8;
	box.Visible = false;

	library:Create('UIStroke', {
		Color = palette.Stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = box
	});

	library:Create('UIPadding', {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = box
	});

	self.searchBox = box;

	
	local clearButton = library:Create('TextButton', {
		Name = 'MobileSearchClear',
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0, 77),
		Size = UDim2.fromOffset(34, 40),
		BackgroundColor3 = palette.Elevated,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = 'X',
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 9,
		Visible = false,
		Parent = library.main
	});

	library:Create('UIStroke', {
		Color = palette.Stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = clearButton
	});

	library:AddConnection(clearButton.InputBegan, function(input)
		if (not self.isPrimaryInput(input)) then return end;

		box.Text = '';
		box.Visible = false;
		clearButton.Visible = false;

		pcall(function()
			box:ReleaseFocus();
		end);
	end);

	
	library:AddConnection(box:GetPropertyChangedSignal('Visible'), function()
		clearButton.Visible = box.Visible;
	end);

	
	local container = library.searchContainer;

	library:AddConnection(box:GetPropertyChangedSignal('Text'), function()
		if (not container) then return end;

		if (((box.Text or ''):gsub('%s', '')) ~= '') then
			container.Position = UDim2.fromOffset(0, 44);
			container.Size = UDim2.new(1, 0, 1, -44);
		else
			container.Position = UDim2.fromOffset(0, 0);
			container.Size = UDim2.fromScale(1, 1);
		end;
	end);
end;





function MobileUI:install()
	local library = self.library;

	library.isMobile = true;
	getgenv().vairMobileUI = self;

	
	self.probe = library:Create('Frame', {
		Name = 'MobileProbe',
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Parent = library.base
	});

	if (library.tabHighlight) then
		library.tabHighlight.Visible = false;
	end;

	
	if (library.tooltip) then
		library.tooltip.Visible = false;
		library.tooltip.Text = '';
	end;

	self:buildBackdrop();
	self:buildTabStrip();
	self:buildPager();
	self:buildCloseButton();
	self:buildToggle();
	self:layoutColumnHolder();
	self:hookClose();
	self:hookTransparency();
	self:applyScale();

	
	task.defer(function()
		pcall(library.SetMenuTransparency, library, tonumber(library.flags.menuTransparency) or 0);

		
		self:snapToggle(true);
	end);

	local camera = workspace.CurrentCamera;

	if (camera) then
		library:AddConnection(camera:GetPropertyChangedSignal('ViewportSize'), function()
			self:applyScale();
			self:refreshColumns();
		end);
	end;

	return self;
end;


function MobileUI:afterInit()
	local library = self.library;

	self:hookAddTab();
	self:hookSelectTab();
	self:relayoutTabs();
	self:buildSearch();

	if (library.currentTab) then
		self:refreshColumns(library.currentTab);
	end;

	
	if (library.searchBox) then
		library:AddConnection(library.searchBox:GetPropertyChangedSignal('Text'), function()
			if ((library.searchBox.Text or ''):gsub('%s', '') == '') then
				self:refreshColumns(library.currentTab);
			end;
		end);
	end;

	if (library.mobileToggle) then
		library.mobileToggle.Visible = not library.open;
	end;
end;

return MobileUI;
end;

MODULES['utils/Security.lua'] = function()
local Webhook = sharedRequire('@utils/Webhook.lua');
local WEBHOOK_URL = '';

local Security = {};


function Security:LogInfraction(infraction)
    Webhook.new(WEBHOOK_URL):Send({
        content = string.format('%s - %s', accountData.uuid, infraction)
    }, true);

    return stop();
end;

return Security;
end;

MODULES['utils/Services.lua'] = function()
local Services = {};
local vim = getvirtualinputmanager and getvirtualinputmanager();

function Services:Get(...)
    local allServices = {};

    for _, service in next, {...} do
        table.insert(allServices, self[service]);
    end

    return unpack(allServices);
end;






local memoryStorage = {};

local memStorageStub = {
    HasItem = function(_, key)
        return memoryStorage[tostring(key)] ~= nil;
    end;
    SetItem = function(_, key, value)
        memoryStorage[tostring(key)] = value;
        return value;
    end;
    GetItem = function(_, key, default)
        local value = memoryStorage[tostring(key)];
        if (value == nil) then return default end;
        return value;
    end;
    RemoveItem = function(_, key)
        memoryStorage[tostring(key)] = nil;
    end;
};

setmetatable(Services, {
    __index = function(self, p)
        if (p == 'VirtualInputManager' and vim) then
            return vim;
        end;

        if (p == 'MemStorageService') then
            local ok, service = pcall(function() return game:GetService(p) end);

            if (not ok or service == nil) then
                rawset(self, p, memStorageStub);
                return memStorageStub;
            end;
        end;

        local ok, service = pcall(function() return game:GetService(p) end);

        if (not ok or service == nil) then
            
            
            
            
            
            local name = tostring(p);
            local looksLikeService = name:find('Service$') ~= nil
                or name:find('^[A-Z][a-z]+[A-Z]') ~= nil;

            if (looksLikeService) then
                local boot = getgenv and getgenv().__vairBoot;

                if (type(boot) == 'table') then
                    boot.missingServices = boot.missingServices or {};

                    if (not table.find(boot.missingServices, name)) then
                        table.insert(boot.missingServices, name);
                        warn(string.format('[v.air] 服务不可用: %s', name));
                    end;
                end;
            end;

            return nil;
        end;

        if (p == 'VirtualInputManager') then
            pcall(function() service.Name = 'VirtualInputManager ' end);
        end;

        rawset(self, p, service);
        return rawget(self, p);
    end,
});

return Services;
end;

MODULES['utils/Signal.lua'] = function()







local Signal = {}
Signal.__index = Signal
Signal.ClassName = "Signal"




function Signal.new()
	local self = setmetatable({}, Signal)

	self._bindableEvent = Instance.new("BindableEvent")
	self._argData = nil
	self._argCount = nil 

	return self
end

function Signal.isSignal(object)
	return typeof(object) == 'table' and getmetatable(object) == Signal;
end;





function Signal:Fire(...)
	self._argData = {...}
	self._argCount = select("#", ...)
	self._bindableEvent:Fire()
	self._argData = nil
	self._argCount = nil
end




function Signal:Connect(handler)
	if not self._bindableEvent then return error("Signal has been destroyed"); end 

	if not (type(handler) == "function") then
		error(("connect(%s)"):format(typeof(handler)), 2)
	end

	return self._bindableEvent.Event:Connect(function()
		handler(unpack(self._argData, 1, self._argCount))
	end)
end



function Signal:Wait()
	self._bindableEvent.Event:Wait()
	assert(self._argData, "Missing arg data, likely due to :TweenSize/Position corrupting threadrefs.")
	return unpack(self._argData, 1, self._argCount)
end



function Signal:Destroy()
	if self._bindableEvent then
		self._bindableEvent:Destroy()
		self._bindableEvent = nil
	end

	self._argData = nil
	self._argCount = nil
end

return Signal
end;

MODULES['utils/Utility.lua'] = function()

local Services = sharedRequire('./Services.lua');
local library = sharedRequire('../UILibrary.lua');
local Signal = sharedRequire('./Signal.lua');

local Players, UserInputService, HttpService, CollectionService = Services:Get('Players', 'UserInputService', 'HttpService', 'CollectionService');
local LocalPlayer = Players.LocalPlayer;

local Utility = {};

Utility.onPlayerAdded = Signal.new();
Utility.onCharacterAdded = Signal.new();
Utility.onLocalCharacterAdded = Signal.new();

local mathFloor = clonefunction(math.floor)
local isDescendantOf = clonefunction(game.IsDescendantOf);
local findChildIsA = clonefunction(game.FindFirstChildWhichIsA);
local findFirstChild = clonefunction(game.FindFirstChild);

local IsA = clonefunction(game.IsA);

local getMouseLocation = clonefunction(UserInputService.GetMouseLocation);
local getPlayers = clonefunction(Players.GetPlayers);

local worldToViewportPoint = clonefunction(Instance.new('Camera').WorldToViewportPoint);

function Utility:countTable(t)
    local found = 0;

    for i, v in next, t do
        found = found + 1;
    end;

    return found;
end;

function Utility:roundVector(vector)
    return Vector3.new(vector.X, 0, vector.Z);
end;

function Utility:getCharacter(player)
    local playerData = self:getPlayerData(player);
    if (not playerData.alive) then return end;

    local maxHealth, health = playerData.maxHealth, playerData.health;
    return playerData.character, maxHealth, (health / maxHealth) * 100, mathFloor(health), playerData.rootPart;
end;

function Utility:isTeamMate(player)
    local playerData, myPlayerData = self:getPlayerData(player), self:getPlayerData();
    local playerTeam, myTeam = playerData.team, myPlayerData.team;

    if(playerTeam == nil or myTeam == nil) then
        return false;
    end;

    return playerTeam == myTeam;
end;

function Utility:getRootPart(player)
    local playerData = self:getPlayerData(player);
    return playerData and playerData.rootPart;
end;

function Utility:renderOverload(data) end;

local function castPlayer(origin, direction, rayParams, playerToFind)
    local distanceTravalled = 0;

    while true do
        distanceTravalled = distanceTravalled + direction.Magnitude;

        local target = workspace:Raycast(origin, direction, rayParams);

        if(target) then
            if(isDescendantOf(target.Instance, playerToFind)) then
                return false;
            elseif(target and target.Instance.CanCollide) then
                return true;
            end;
        elseif(distanceTravalled > 2000) then
            return false;
        end;

        origin = origin + direction;
    end;
end;

function Utility:getClosestCharacter(rayParams)
    rayParams = rayParams or RaycastParams.new();
    rayParams.FilterDescendantsInstances = {}

    local myCharacter = Utility:getCharacter(LocalPlayer);
    local myHead = myCharacter and findFirstChild(myCharacter, 'Head');
    if(not myHead) then return end;

    if(rayParams.FilterType == Enum.RaycastFilterType.Blacklist) then
        table.insert(rayParams.FilterDescendantsInstances, myHead.Parent);
    end;

    local camera = workspace.CurrentCamera;
    if(not camera) then return end;

    local mousePos = library.flags.useFOV and getMouseLocation(UserInputService);
    local lastDistance, lastPlayer = math.huge, {};

    local maxFov = library.flags.useFOV and library.flags.aimbotFOV or math.huge;
    local whitelistedPlayers = library.options.aimbotWhitelistedPlayers.values;

    for _, player in next, getPlayers(Players) do
        if(player == LocalPlayer or table.find(whitelistedPlayers, player.Name)) then continue end;

        local character, health = Utility:getCharacter(player);

        if(not character or health <= 0 or findChildIsA(character, 'ForceField')) then continue; end;
        if(library.flags.checkTeam and Utility:isTeamMate(player)) then continue end;

        local head = character and findFirstChild(character, 'Head');
        if(not head) then continue end;

        local newDistance = (myHead.Position - head.Position).Magnitude;
        if(newDistance > lastDistance) then continue end;

        if (mousePos) then
            local screenPosition, visibleOnScreen = worldToViewportPoint(camera, head.Position);
            screenPosition = Vector2.new(screenPosition.X, screenPosition.Y);

            if((screenPosition - mousePos).Magnitude > maxFov or not visibleOnScreen) then continue end;
        end;

        local isBehindWall = library.flags.visibilityCheck and castPlayer(myHead.Position, (head.Position - myHead.Position).Unit * 100, rayParams, head.Parent);
        if (isBehindWall) then continue end;

        lastPlayer = {Player = player, Character = character, Health = health};
        lastDistance = newDistance;
    end;

    return lastPlayer, lastDistance;
end;

function Utility:getClosestCharacterWithEntityList(entityList, rayParams, options)
    rayParams = rayParams or RaycastParams.new();
    rayParams.FilterDescendantsInstances = {}

    options = options or {};
    options.maxDistance = options.maxDistance or math.huge;

    local myCharacter = Utility:getCharacter(LocalPlayer);
    local myHead = myCharacter and findFirstChild(myCharacter, 'Head');
    if(not myHead) then return end;

    if(rayParams.FilterType == Enum.RaycastFilterType.Blacklist) then
        table.insert(rayParams.FilterDescendantsInstances, myHead.Parent);
    end;

    local camera = workspace.CurrentCamera;
    if(not camera) then return end;

    local mousePos = library.flags.useFOV and getMouseLocation(UserInputService);
    local lastDistance, lastPlayer = math.huge, {};
    local whitelistedPlayers = library.options.aimbotWhitelistedPlayers.values;

    local maxFov = library.flags.useFOV and library.flags.aimbotFOV or math.huge;

    for _, player in next, entityList do
        if(player == myCharacter or table.find(whitelistedPlayers, player.Name)) then continue end;

        local humanoid = findChildIsA(player, 'Humanoid');
        if (not humanoid or humanoid.Health <= 0) then continue end;

        local character = player;

        if(not character or findChildIsA(character, 'ForceField')) then continue; end;

        local head = character and findFirstChild(character, 'Head');
        if(not head) then continue end;

        local newDistance = (myHead.Position - head.Position).Magnitude;
        if(newDistance > lastDistance or newDistance > options.maxDistance) then continue end;

        if (mousePos) then
            local screenPosition, visibleOnScreen = worldToViewportPoint(camera, head.Position);
            screenPosition = Vector2.new(screenPosition.X, screenPosition.Y);

            if((screenPosition - mousePos).Magnitude > maxFov or not visibleOnScreen) then continue end;
        end;

        local isBehindWall = library.flags.visibilityCheck and castPlayer(myHead.Position, (head.Position - myHead.Position).Unit * 100, rayParams, head.Parent);
        if (isBehindWall) then continue end;

        lastPlayer = {Player = player, Character = character, Health = humanoid.Health};
        lastDistance = newDistance;
    end;

    return lastPlayer, lastDistance;
end;

function panic()
    library:Unload();
end;

local playersData = {};

local function onCharacterAdded(player)
    local playerData = playersData[player];
    if (not playerData) then return end;

    local character = player.Character;
    if (not character) then return end;

    local localAlive = true;

    table.clear(playerData.parts);

    Utility.listenToChildAdded(character, function(obj)
        if (obj.Name == 'Humanoid') then
            playerData.humanoid = obj;
        elseif (obj.Name == 'HumanoidRootPart') then
            playerData.rootPart = obj;
        elseif (obj.Name == 'Head') then
            playerData.head = obj;
        end;
    end);

    if (player == LocalPlayer) then
        Utility.listenToDescendantAdded(character, function(obj)
            if (IsA(obj, 'BasePart')) then
                table.insert(playerData.parts, obj);

                local con;
                con = obj:GetPropertyChangedSignal('Parent'):Connect(function()
                    if (obj.Parent) then return end;
                    con:Disconnect();
                    table.remove(playerData.parts, table.find(playerData.parts, obj));
                end);
            end;
        end);
    end;

    local function onPrimaryPartChanged()
        playerData.primaryPart = character.PrimaryPart;
        playerData.alive = not not playerData.primaryPart;
    end

    local hum = character:WaitForChild('Humanoid', 30);
    playerData.humanoid = hum;
    if (not playerData.humanoid) then return warn('[Utility] [onCharacterAdded] Player is missing humanoid ' .. player:GetFullName()) end;
    if (not player.Parent or not character.Parent) then return end;

    character:GetPropertyChangedSignal('PrimaryPart'):Connect(onPrimaryPartChanged);

    if (character.PrimaryPart) then
        onPrimaryPartChanged();
    end;

    playerData.character = character;
    playerData.alive = true;
    playerData.health = playerData.humanoid.Health;
    playerData.maxHealth = playerData.humanoid.MaxHealth;

    hum.Destroying:Connect(function()
        playerData.alive = false;
        localAlive = false;
    end);

    hum.Died:Connect(function()
        playerData.alive = false;
        localAlive = false;
    end);

    playerData.humanoid:GetPropertyChangedSignal('Health'):Connect(function()
        playerData.health = hum.Health;
    end);

    playerData.humanoid:GetPropertyChangedSignal('MaxHealth'):Connect(function()
        playerData.maxHealth = hum.MaxHealth;
    end);

    local function fire()
        if (not localAlive) then return end;
        Utility.onCharacterAdded:Fire(playerData);

        if (player == LocalPlayer) then
            Utility.onLocalCharacterAdded:Fire(playerData);
        end;
    end;

    if (library and library.OnLoad) then
        library.OnLoad:Connect(fire);
    else
        fire();
    end;
end;

local function onPlayerAdded(player)
    local playerData = {};

    playerData.player = player;
    playerData.team = player.Team;
    playerData.parts = {};

    playersData[player] = playerData;

    local function fire()
        Utility.onPlayerAdded:Fire(player);
    end;

    task.spawn(onCharacterAdded, player);

    player.CharacterAdded:Connect(function()
        onCharacterAdded(player);
    end);

    player:GetPropertyChangedSignal('Team'):Connect(function()
        playerData.team = player.Team;
    end);

    if (library and library.OnLoad) then
        library.OnLoad:Connect(fire);
    else
        fire();
    end;
end;

function Utility:getPlayerData(player)
    return playersData[player or LocalPlayer] or {};
end;

function Utility.listenToChildAdded(folder, listener, options)
    options = options or {listenToDestroying = false};

    local createListener = typeof(listener) == 'table' and listener.new or listener;

    assert(typeof(folder) == 'Instance', 'listenToChildAdded folder #1 listener has to be an instance');
    assert(typeof(createListener) == 'function', 'listenToChildAdded #2 listener has to be a function');

    local function onChildAdded(child)
        local listenerObject = createListener(child);

        if (options.listenToDestroying) then
            child.Destroying:Connect(function()
                local removeListener = typeof(listener) == 'table' and (function() local a = (listener.Destroy or listener.Remove); a(listenerObject) end) or listenerObject;

                if (typeof(removeListener) ~= 'function') then
                    warn('[Utility] removeListener is not definded possible memory leak for', folder);
                else
                    removeListener(child);
                end;
            end);
        end;
    end

    debug.profilebegin(string.format('Utility.listenToChildAdded(%s)', folder:GetFullName()));

    for _, child in next, folder:GetChildren() do
        task.spawn(onChildAdded, child);
    end;

    debug.profileend();

    return folder.ChildAdded:Connect(createListener);
end;

function Utility.listenToChildRemoving(folder, listener)
    local createListener = typeof(listener) == 'table' and listener.new or listener;

    assert(typeof(folder) == 'Instance', 'listenToChildRemoving folder #1 listener has to be an instance');
    assert(typeof(createListener) == 'function', 'listenToChildRemoving #2 listener has to be a function');

    return folder.ChildRemoved:Connect(createListener);
end;

function Utility.listenToDescendantAdded(folder, listener, options)
    options = options or {listenToDestroying = false};

    local createListener = typeof(listener) == 'table' and listener.new or listener;

    assert(typeof(folder) == 'Instance', 'listenToDescendantAdded folder #1 listener has to be an instance');
    assert(typeof(createListener) == 'function', 'listenToDescendantAdded #2 listener has to be a function');

    local function onDescendantAdded(child)
        local listenerObject = createListener(child);

        if (options.listenToDestroying) then
            child.Destroying:Connect(function()
                local removeListener = typeof(listener) == 'table' and (listener.Destroy or listener.Remove) or listenerObject;

                if (typeof(removeListener) ~= 'function') then
                    warn('[Utility] removeListener is not definded possible memory leak for', folder);
                else
                    removeListener(child);
                end;
            end);
        end;
    end

    debug.profilebegin(string.format('Utility.listenToDescendantAdded(%s)', folder:GetFullName()));

    for _, child in next, folder:GetDescendants() do
        task.spawn(onDescendantAdded, child);
    end;

    debug.profileend();

    return folder.DescendantAdded:Connect(onDescendantAdded);
end;

function Utility.listenToDescendantRemoving(folder, listener)
    local createListener = typeof(listener) == 'table' and listener.new or listener;

    assert(typeof(folder) == 'Instance', 'listenToDescendantRemoving folder #1 listener has to be an instance');
    assert(typeof(createListener) == 'function', 'listenToDescendantRemoving #2 listener has to be a function');

    return folder.DescendantRemoving:Connect(createListener);
end;

function Utility.listenToTagAdded(tagName, listener)
    for _, v in next, CollectionService:GetTagged(tagName) do
        task.spawn(listener, v);
    end;

    return CollectionService:GetInstanceAddedSignal(tagName):Connect(listener);
end;

function Utility.getFunctionHash(f)
    if (typeof(f) ~= 'function') then return error('getFunctionHash(f) #1 has to be a function') end;

    local constants = getconstants(f);
    local protos = getprotos(f);

    local total = HttpService:JSONEncode({constants, protos});

    return hash(total);
end;

local function onPlayerRemoving(player)
    playersData[player] = nil;
end;

for _, player in next, Players:GetPlayers() do
    task.spawn(onPlayerAdded, player);
end;

Players.PlayerAdded:Connect(onPlayerAdded);
Players.PlayerRemoving:Connect(onPlayerRemoving);

function Utility.find(t, c)
    for i, v in next, t do
        if (c(v, i)) then
            return v, i;
        end;
    end;

    return nil;
end;

function Utility.map(t, c)
    local ret = {};

    for i, v in next, t do
        local val = c(v, i);
        if (val) then
            table.insert(ret, val);
        end;
    end;

    return ret;
end;

return Utility;
end;

MODULES['utils/Webhook.lua'] = function()
local Services = sharedRequire('@utils/Services.lua');
local HttpService = Services:Get('HttpService');

local Webhook = {};
Webhook.__index = Webhook;

function Webhook.new(url)
    local self = setmetatable({}, Webhook);

    self._url = url;

    return self;
end;

function Webhook:Send(data, yields)
    if (typeof(data) == 'string') then
        data = {content = data};
    end;

    local function send()
        request({
            Url = self._url,
            Method = 'POST',
            Headers = {['Content-Type'] = 'application/json'},
            Body = originalFunctions.jsonEncode(HttpService, data)
        });
    end;

    if (yields) then
        pcall(send);
    else
        task.spawn(send);
    end;
end;

return Webhook;
end;

MODULES['utils/createBaseESP.lua'] = function()
local Maid = sharedRequire('Maid.lua');
local Services = sharedRequire('Services.lua');

local toCamelCase = sharedRequire('toCamelCase.lua');
local library = sharedRequire('../UILibrary.lua');

local Players, CorePackages, HttpService = Services:Get('Players', 'CorePackages', 'HttpService');
local LocalPlayer = Players.LocalPlayer;

local NUM_ACTORS = 8;



local playerScripts = LocalPlayer:WaitForChild('PlayerScripts')

local playerScriptsLoader = playerScripts:FindFirstChild('PlayerScriptsLoader');
local actors = {};

local readyCount = 0;
local broadcastEvent = Instance.new('BindableEvent');

local supportedGamesList = HttpService:JSONDecode(sharedRequire('../../gameList.json'));
local gameName = supportedGamesList[tostring(game.GameId)];

if (not playerScriptsLoader and gameName == 'Apocalypse Rising 2') then
	playerScriptsLoader = playerScripts:FindFirstChild('FreecamDelete');
end;



if (not has_native_actor) then
	playerScriptsLoader = nil;
end;

if (playerScriptsLoader) then
	for _ = 1, NUM_ACTORS do
		local commId, commEvent;

		if (isExecutorV3) then
			commEvent = {
				_event = Instance.new('BindableEvent'),

				Connect = function(self, f)
					return self._event.Event:Connect(f)
				end,

				Fire = function(self, ...)
					self._event:Fire(...);
				end
			};
		else
			commId, commEvent = create_comm_channel();
		end;

		local clone = playerScriptsLoader:Clone();
		local actor = Instance.new('Actor');
		clone.Parent = actor;

		local playerModule = CorePackages.InGameServices.MouseIconOverrideService:Clone();
		playerModule.Name = 'PlayerModule';
		playerModule.Parent = actor;

		if (not isExecutorV3) then
			protectgui(actor);
		end;

		actor.Parent = LocalPlayer.PlayerScripts;

		local connection;

		connection = commEvent:Connect(function(data)
			if (data.updateType == 'ready') then
				commEvent:Fire({updateType = 'giveEvent', event = broadcastEvent, gameName = gameName});
				actor:Destroy();

				readyCount += 1;

				connection:Disconnect();
				connection = nil;
			end;
		end);

		originalFunctions.runOnActor(actor, sharedRequire('@utils/createBaseESPParallel.lua'), commId or commEvent);
		table.insert(actors, {
			actor = actor,
			commEvent = commEvent
		});
	end;

	print('Waiting for actors');
	repeat task.wait(); until readyCount >= NUM_ACTORS;
	print('All actors have been loaded');
else
	local commId, commEvent = create_comm_channel();

	local connection;
	connection = commEvent:Connect(function(data)
		if (data.updateType == 'ready') then
			connection:Disconnect();
			connection = nil;

			commEvent:Fire({updateType = 'giveEvent', event = broadcastEvent});
		end;
	end);

	loadstring(sharedRequire('@utils/createBaseESPParallel.lua'))(commId);

	table.insert(actors, {commEvent = commEvent});
	readyCount = 1;
end;



library.unloadMaid:GiveTask(function()
	for _, actorData in next, actors do
		pcall(function()
			actorData.commEvent:Fire({updateType = 'shutdown'});
		end);
	end;
end);

local count = 1;

local function createBaseEsp(flag, container)
	container = container or {};
	local BaseEsp = {};

	BaseEsp.ClassName = 'BaseEsp';
	BaseEsp.Flag = flag;
	BaseEsp.Container = container;
	BaseEsp.__index = BaseEsp;

	local whiteColor = Color3.new(1, 1, 1);

	local maxDistanceFlag = BaseEsp.Flag .. 'MaxDistance';
	local showHealthFlag = BaseEsp.Flag .. 'ShowHealth';
	local showESPFlag = BaseEsp.Flag;

	function BaseEsp.new(instance, tag, color, isLazy)
		assert(instance, '#1 instance expected');
		assert(tag, '#2 tag expected');

		local isCustomInstance = false;

		if (typeof(instance) == 'table' and rawget(instance, 'code')) then
			isCustomInstance = true;
		end;

		color = color or whiteColor;

		local self = setmetatable({}, BaseEsp);
		self._tag = tag;

		local displayName = tag;

		if (typeof(tag) == 'table') then
			displayName = tag.displayName;
			self._tag = tag.tag;
		end;

		self._instance = instance;
		self._text = displayName;
		self._color = color;
		self._showFlag = toCamelCase('Show ' .. self._tag);
		self._colorFlag = toCamelCase(self._tag .. ' Color');
		self._colorFlag2 = BaseEsp.Flag .. 'Color';
		self._showDistanceFlag = BaseEsp.Flag .. 'ShowDistance';
		self._isLazy = isLazy;
		self._actor = actors[(count % readyCount) + 1];
		self._id = count;
		self._maid = Maid.new();

		count += 1;

		if (isLazy and not isCustomInstance) then
			self._instancePosition = instance.Position;
		end;

		self._maxDistanceFlag = maxDistanceFlag;
		self._showHealthFlag = showHealthFlag;

		if (isCustomInstance) then
			self._isCustomInstance = true;
			self._code = instance.code;
			self._vars = instance.vars;
		end;

		local smallData = table.clone(self);
		smallData._actor = nil;
		self._actor.commEvent:Fire({
			updateType = 'new',
			data = smallData,
			isCustomInstance = isCustomInstance,
			showFlag = showESPFlag,
			
			
			
			flags = library.flags
		});


		return self;
	end;

	function BaseEsp:Unload() end;
	function BaseEsp:BaseUpdate() end;
	function BaseEsp:UpdateAll() end;
	function BaseEsp:Update() end;
	function BaseEsp:UnloadAll() end;
	function BaseEsp:Disable() end;

	function BaseEsp:Destroy()
		self._maid:Destroy();
		self._actor.commEvent:Fire({
			updateType = 'destroy',
			id = self._id
		});
	end;

	return BaseEsp;
end;

library.OnFlagChanged:Connect(function(data)
	broadcastEvent:Fire({
		type = data.type,
		flag = data.flag,
		color = data.color,
		state = data.state,
		value = data.value
	});
end);

return createBaseEsp;
end;

MODULES['utils/createBaseESPParallel.lua'] = function()
return [[
    local Players = game:GetService('Players');
    local RunService = game:GetService('RunService');
    local LocalPlayer = Players.LocalPlayer;

    local camera, rootPart, rootPartPosition;

    local originalCommEvent = ...;
    local commEvent;

    if (typeof(originalCommEvent) == 'table') then
        commEvent = {
            _event = originalCommEvent._event,

            Connect = function(self, f)
                return self._event.Event:Connect(f)
            end,

            Fire = function(self, ...)
                self._event:Fire(...);
            end
        };
    else
        commEvent = getgenv().get_comm_channel(originalCommEvent);
    end;

    local flags = {};

    local updateTypes = {};

    local BaseESPParallel = {};
    BaseESPParallel.__index = BaseESPParallel;

    local container = {};
    local DEFAULT_ESP_COLOR = Color3.fromRGB(255, 255, 255);

    local mFloor = math.floor;
    local isExecutorV3 = getgenv().isExecutorV3 == true;

    -- 这套本来设计成跑在 Actor 里（原生 run_on_actor 可用时）。
    -- 执行器没有原生 run_on_actor 时会退化成同线程执行，此时 task.desynchronize()
    -- 会抛 "may only be called from a script that is a descendant of an Actor"，
    -- 整个 Heartbeat 更新循环就每帧被中断（方框永远不显示）。
    -- 这里探测一次，之后只走当前环境支持的路径。
    local desyncSupported = nil;

    local function tryDesync()
        if (desyncSupported == false) then return end;

        desyncSupported = pcall(task.desynchronize);
    end;

    local function trySync()
        if (desyncSupported ~= true) then return end;

        pcall(task.synchronize);
    end;

    local worldToViewportPoint = Instance.new('Camera').WorldToViewportPoint;
    local vector2New = Vector2.new;

    local realSetRP;
    local realDestroyRP;
    local realGetRPProperty;

    if (isExecutorV3) then
        realGetRPProperty = function(self, p, v)
            return self[p];
        end;

        realSetRP = function(self, p, v)
            self[p] = v;
        end;

        realDestroyRP = function(self)
            return self:Remove();
        end;

        realGetRPProperty = getRPProperty;
    else
        local lineUpvalues = getupvalue(Drawing.new, 4).__index;
        local lineUpvalues2 = getupvalue(Drawing.new, 4).__newindex;

        realSetRP = getupvalue(lineUpvalues2, 4);
        realDestroyRP = getupvalue(lineUpvalues, 3);
        realGetRPProperty = getupvalue(lineUpvalues, 4);

        assert(realSetRP);
        assert(realDestroyRP);
        assert(realGetRPProperty);
    end;


    local updateDrawingQueue = {};
    local destroyDrawingQueue = {};

    local activeContainer = {};
    local customInstanceCache = {};

    local heartbeatConnection = nil;

    local gameName;
    local enableESPSearch = false;

    local sLower = string.lower;
    local sFind = string.find;

    local findFirstChild = clonefunction(game.FindFirstChild);
    local getAttribute = clonefunction(game.GetAttribute);

    if (isExecutorV3) then
        setRP = realSetRP;
        getRPProperty = realGetRPProperty;
    else
        setRP = function(object, p, v)
            local cache = object._cache;
            local cacheVal = cache[p];
            if (cacheVal == v) then return end;

            cache[p] = v;
            realSetRP(object.__OBJECT, p, v);
        end;

        getRPProperty = function(object, p)
            local cacheVal = object._cache[p];
            if (not cacheVal) then
                object._cache[p] = realGetRPProperty(object.__OBJECT, p);
                cacheVal = object._cache[p];
            end;

            return cacheVal;
        end;
    end;


    function BaseESPParallel.new(data, showESPFlag, customInstance)
        local self = setmetatable(data, BaseESPParallel);

        if (customInstance) then
            if (not customInstanceCache[data._code]) then
                local func = loadstring(data._code);
                getfenv(func).library = setmetatable({}, {__index = function(self, p) return flags end});

                customInstanceCache[data._code] = func;
            end;
            self._instance = customInstanceCache[data._code](unpack(data._vars));
        end;

        local instance, tag, color, isLazy = self._instance, self._tag, self._color, self._isLazy;
        self._showFlag2 = showESPFlag;


		if (isExecutorV3 and typeof(instance) == 'Instance' and false) then
			-- if (typeof(instance) == 'table') then
			-- 	task.spawn(error, instance);
			-- end;

			self._label = TextDynamic.new(PointInstance.new(instance));
			self._label.Color = DEFAULT_ESP_COLOR;
			self._label.XAlignment = XAlignment.Center;
			self._label.YAlignment = YAlignment.Center;
			self._label.Outlined = true;
			self._label.Text = string.format('[%s]', tag);
		else
			self._label = Drawing.new('Text');
			self._label.Transparency = 1;
			self._label.Color = color;
			self._label.Text = '[' .. tag .. ']';
			self._label.Center = true;
			self._label.Outline = true;
		end;

		local flagValue = flags[self._showFlag];
		-- self._object = isExecutorV3 and self._label or self._label.__OBJECT;

		for i, v in next, self do
            if (typeof(v) == 'table' and rawget(v, '__OBJECT')) then
                rawset(v, '_cache', {});
            end;
        end;

		container[self._id] = self;

		if (isLazy) then
			self._instancePosition = instance.Position;
		end;

        self:UpdateContainer();
        return self;
    end;

	function BaseESPParallel:Destroy()
		container[self._id] = nil;
        if (table.find(activeContainer, self)) then
            table.remove(activeContainer, table.find(activeContainer, self));
        end;
        table.insert(destroyDrawingQueue, self._label);
    end;

    function BaseESPParallel:Unload()
        table.insert(updateDrawingQueue, {
            label = self._label,
            visible = false
        });
    end;

	function BaseESPParallel:BaseUpdate(espSearch)
		local instancePosition = self._instancePosition or self._instance.Position;
		if (not instancePosition) then return self:Unload() end;

		local distance = (rootPartPosition - instancePosition).Magnitude;
		local maxDist = flags[self._maxDistanceFlag] or 10000;
		if(distance >= maxDist and maxDist ~= 10000) then return self:Unload(); end;

		local visibleState = flags[self._showFlag];
		local label, text = self._label, self._text;

		if(visibleState == nil) then
			visibleState = true;
		elseif (not visibleState) then
			return self:Unload();
		end;

		-- if (isExecutorV3) then return end;

		local position, visible = worldToViewportPoint(camera, instancePosition);
		if(not visible) then return self:Unload(); end;

		local newPos = vector2New(position.X, position.Y);

		local labelText = '';

		if (flags[self._showHealthFlag]) then
            -- Custom instance do not touch they have custom funcs
            local humanoid = self._instance:FindFirstChildWhichIsA('Humanoid') or self._instance.Parent and self._instance.Parent:FindFirstChild('Humanoid');

            if (not humanoid) then
                if (gameName == 'Arcane Odyssey') then
                    local attributes = findFirstChild(self._instance.Parent, 'Attributes');
                    if (attributes) then
                        humanoid = {
                            Health = attributes.Health.Value,
                            MaxHealth = attributes.MaxHealth.Value,
                        }
                    end
                elseif (gameName == 'Voxl Blade') then
                    humanoid = {
                        Health = getAttribute(self._instance, 'HP'),
                        MaxHealth = getAttribute(self._instance, 'MAXHP'),
                    }
                end;
            end;

			if (humanoid) then
				local health = mFloor(humanoid.Health);
				local maxHealth = mFloor(humanoid.MaxHealth);

				labelText = labelText .. '[' .. health .. '/' .. maxHealth ..']';
			end;
		end;

		labelText = labelText .. '[' .. text .. ']';

        local visible = true;

        if (enableESPSearch and espSearch and not sFind(sLower(labelText), espSearch)) then
            visible = false;
        end;

		local newColor = flags[self._colorFlag] or flags[self._colorFlag2] or DEFAULT_ESP_COLOR;

		if (flags[self._showDistanceFlag]) then
			labelText = labelText .. ' [' .. mFloor(distance) .. ']';
		end;

        table.insert(updateDrawingQueue, {
            position = newPos,
            color = newColor,
            text = labelText,
            label = label,
            visible = visible
        });
	end;

    function BaseESPParallel:UpdateContainer()
        local showFlag, showFlag2 = self._showFlag, self._showFlag2;

        if (flags[showFlag] == false or not flags[showFlag2]) then
            local exists = table.find(activeContainer, self);
            if (exists) then table.remove(activeContainer, exists); end;
            self:Unload();
        elseif (not table.find(activeContainer, self)) then
            table.insert(activeContainer, self);
        end;
    end;

    function updateTypes.new(data)
        local showESPFlag = data.showFlag;
        local isCustomInstance = data.isCustomInstance;

        -- 新对象会带一份主线程的 flag 快照：这里先把没同步过的键补上，
        -- 否则分组默认开着（读的上次配置）也不会显示，必须手动去点一下开关
        if (type(data.flags) == 'table') then
            for k, v in next, data.flags do
                flags[k] = v;
            end;
        end;

        data = data.data;

        BaseESPParallel.new(data, showESPFlag, isCustomInstance);
    end;

    function updateTypes.destroy(data)
        tryDesync();
        local id = data.id;
        for _, v in next, container do
            if (v._id == id) then
                v:Destroy();
            end;
        end;
    end;

    -- 脚本卸载/热重载时主线程会发 shutdown：
    -- 不关掉的话旧的那套 Heartbeat 会一直跑，重载几次就叠出好几层 ESP（还漏 Drawing 不回收）
    function updateTypes.shutdown()
        if (heartbeatConnection) then
            heartbeatConnection:Disconnect();
            heartbeatConnection = nil;
        end;

        for _, v in next, container do
            pcall(function()
                v._label:Remove();
            end);
        end;

        table.clear(container);
        table.clear(activeContainer);

        updateDrawingQueue = {};
        destroyDrawingQueue = {};
    end;

    local event;
    local flagChanged;

    local containerUpdated = false;

    function updateTypes.giveEvent(data)
        event = data.event;
        gameName = data.gameName;

        enableESPSearch = gameName == 'Voxl Blade' or gameName == 'DeepWoken' or gameName == 'Rogue Lineage';

        event.Event:Connect(function(data)
            if (data.type == 'color') then
                flags[data.flag] = data.color;
            elseif (data.type == 'slider') then
                flags[data.flag] = data.value;
            elseif (data.type == 'toggle') then
                flags[data.flag] = data.state;
            elseif (data.type == 'box') then
                flags[data.flag] = data.value;
            end;
    
            if (data.type ~= 'toggle' or containerUpdated) then return end;
            containerUpdated = true;
    
            task.defer(function()
                debug.profilebegin('containerUpdates');
                for _, v in next, container do
                    v:UpdateContainer();
                end;
                debug.profileend();
    
                containerUpdated = false;
            end);
        end);
    end;

    commEvent:Connect(function(data)
        local f = updateTypes[data.updateType];
        if (not f) then return end;
        f(data);
    end);

    commEvent:Fire({updateType = 'ready'});

    heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
        tryDesync();

        camera = workspace.CurrentCamera;
        rootPart = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart;
        rootPartPosition = rootPart and rootPart.Position;

		if(not camera or not rootPart) then return; end;

        local espSearch = enableESPSearch and flags.espSearch;

        if (espSearch and espSearch ~= '') then
            espSearch = sLower(espSearch);
        end;

        for i = 1, #activeContainer do
            activeContainer[i]:BaseUpdate(espSearch);
        end;

        local goSerial = #updateDrawingQueue ~= 0 or #destroyDrawingQueue ~= 0;
        if (goSerial) then trySync(); end;
        debug.profilebegin('updateDrawingQueue');

        for i = 1, #updateDrawingQueue do
            local v = updateDrawingQueue[i];
            local label, position, visible, color, text = v.label, v.position, v.visible, v.color, v.text;

            if (isExecutorV3) then
                if (position) then
                    label.Position = position;
                end;
    
                if (visible ~= nil) then
                    label.Visible = visible;
                end;
    
                if (color) then
                    label.Color = color;
                end;
    
                if (text) then
                    label.Text = text;
                end;
            else                
                if (position) then
                    setRP(label, 'Position', position);
                end;
    
                if (visible ~= nil) then
                    setRP(label, 'Visible', visible);
                end;
    
                if (color) then
                    setRP(label, 'Color', color);
                end;
    
                if (text) then
                    setRP(label, 'Text', text);
                end;
            end;
        end;

        debug.profileend();
        debug.profilebegin('destroyDrawingQueue');

        for i = 1, #destroyDrawingQueue do
            destroyDrawingQueue[i]:Remove();
        end;

        debug.profileend();
        debug.profilebegin('table clear');

        updateDrawingQueue = {};
        destroyDrawingQueue = {};

        debug.profileend();
    end);
]];
end;

MODULES['utils/makeESP.lua'] = function()
local Utility = sharedRequire('@utils/Utility.lua');
local createBaseESP = sharedRequire('@utils/createBaseESP.lua');
local library = sharedRequire('@UILibrary.lua');




if (not library) then
    library = getgenv().library;
end;

if (not library) then
    library = {
        configVars = {};
        options = {};
        OnLoad = { Connect = function() return { Disconnect = function() end } end };
        OnKeyPress = { Connect = function() return { Disconnect = function() end } end };
        OnKeyRelease = { Connect = function() return { Disconnect = function() end } end };
        OnFlagChanged = { Connect = function() return { Disconnect = function() end } end };
        unloadMaid = { GiveTask = function() end };
    };
end;local toCamelCase = sharedRequire('@utils/toCamelCase.lua');

local sectionIndex = 1;
local addedESPSearch = false;
local function makeEsp(options)
    options = options or {};

    local tag = toCamelCase(options.sectionName);

    assert(options.sectionName, 'options.sectionName is required');
    assert(options.callback, 'options.callback is required');
    assert(options.args, 'options.args is required');
    assert(options.type, 'options.type is required');

    sectionIndex = (sectionIndex % 2) + 1;

    local espSections = Utility:getESPSection();
    
    local espSection = espSections['column' .. sectionIndex]:AddSection(options.sectionTitle or options.sectionName);

    
    
    if (not addedESPSearch and not options.noSearchBox) then
        addedESPSearch = true;
        espSections.espSettings:AddBox({
            text = 'ESP Search',
            skipflag = true,
            noload = true
        });
    end;

    local enableToggle = espSection:AddToggle({
        text = options.enableText or 'Enable',
        flag = options.sectionName
    });

    if (not options.noColorPicker) then
        enableToggle:AddColor({
            flag = string.format('%s Color', options.sectionName)
        });
    end;

    local showDistance = espSection:AddToggle({
        text = options.distanceText or 'Show Distance',
        flag = options.sectionName .. ' Show Distance'
    })

    showDistance:AddSlider({
        text = options.maxDistanceText or 'Max Distance',
        flag = options.sectionName .. ' Max Distance',
        min = 100,
        value = 100000,
        max = 100000,
        float = 100,
        textpos = 2
    });

    
    
    
    
    
    
    
    local espConstructor = nil;

    if (type(createBaseESP) == 'function') then
        local ok, built = pcall(createBaseESP, tag);

        if (ok and type(built) == 'table') then
            espConstructor = built;
        end;
    end;

    if (not espConstructor) then
        warn('[v.air] createBaseESP 不可用，ESP 功能已禁用');

        
        espConstructor = {
            new = function()
                return {
                    Destroy = function() end;
                    UpdateAll = function() end;
                    UnloadAll = function() end;
                    Disable = function() end;
                };
            end;
            Destroy = function() end;
            UpdateAll = function() end;
            UnloadAll = function() end;
        };
    end;

    
    
    
    local flagKey = toCamelCase(options.sectionName);

    library.OnFlagChanged:Fire({
        type = 'toggle',
        flag = flagKey,
        state = library.flags[flagKey] == true,
    });

    
    options.args = typeof(options.args) == 'table' and options.args or {options.args};

    local descOrChild = options.type == 'childAdded' or options.type == 'descendantAdded';
    local watcherFunc;

    if (descOrChild) then
        watcherFunc = Utility[options.type == 'childAdded' and 'listenToChildAdded' or 'listenToDescendantAdded'];
    elseif (options.type == 'tagAdded') then
        watcherFunc = Utility.listenToTagAdded;
    end;

    if (not watcherFunc) then
        return error(options.tag .. ' is not being watched!');
    end;

    for _, parent in next, options.args do
        library.unloadMaid:GiveTask(watcherFunc(parent, function(obj)
            options.callback(obj, espConstructor);
        end));
    end;

    local loadedData = options.onLoaded and options.onLoaded(espSection);

    library.OnLoad:Connect(function()
        local onStateChanged = enableToggle.onStateChanged;

        onStateChanged:Connect(function(state)
            showDistance.main.Visible = state;
        end);

        if (not loadedData) then return; end;

        onStateChanged:Connect(function(state)
            for _, listItem in next, loadedData.list do
                listItem.main.Visible = state;
            end;
        end);
    end);
end;




return function (options)
    task.spawn(makeEsp, options);
end;
end;

MODULES['utils/prettyPrint.lua'] = function()

type = typeof or type
local str_types = {
    ['boolean'] = true,
    ['userdata'] = true,
    ['table'] = true,
    ['function'] = true,
    ['number'] = true,
    ['nil'] = true
}

local function count_table(t)
    local c = 0
    for i, v in next, t do
        c = c + 1
    end

    return c
end

local function string_ret(o, typ)
    local ret, mt, old_func
    if not (typ == 'table' or typ == 'userdata') then
        return tostring(o)
    end
    mt = (getrawmetatable or getmetatable)(o)
    if not mt then 
        return tostring(o)
    end

    old_func = rawget(mt, '__tostring')
    rawset(mt, '__tostring', nil)
    ret = tostring(o)
    rawset(mt, '__tostring', old_func)
    return ret
end

local function format_value(v)
    local typ = type(v)

    if str_types[typ] then
        return string_ret(v, typ)
    elseif typ == 'string' then
        return '"'..v..'"'
    elseif typ == 'Instance' then
        return v.GetFullName(v)
    else
        return typ..'.new(' .. tostring(v) .. ')'
    end
end

local function serialize_table(t, p, c, s)
    local str = ""
    local n = count_table(t)
    local ti = 1
    local e = n > 0

    c = c or {}
    p = p or 1
    s = s or string.rep

    local function localized_format(v, is_table)
        return is_table and (c[v][2] >= p) and serialize_table(v, p + 1, c, s) or format_value(v)
    end

    c[t] = {t, 0}

    for i, v in next, t do
        local typ_i, typ_v = type(i) == 'table', type(v) == 'table'
        c[i], c[v] = (not c[i] and typ_i) and {i, p} or c[i], (not c[v] and typ_v) and {v, p} or c[v]
        str = str .. s('  ', p) .. '[' .. localized_format(i, typ_i) .. '] = '  .. localized_format(v, typ_v) .. (ti < n and ',' or '') .. '\n'
        ti = ti + 1
    end

    return ('{' .. (e and '\n' or '')) .. str .. (e and s('  ', p - 1) or '') .. '}'
end

if (debugMode) then
    getgenv().prettyPrint = serialize_table;
end;

return serialize_table
end;

MODULES['utils/toCamelCase.lua'] = function()
local stringPattern = '%s(.)';
return function (text)
    return string.lower(text):gsub(stringPattern, string.upper);
end;
end;

MODULES['gameList.json'] = function()
	return [[{"9199655655": "Gakuran"}]];
end;

--==============================================================
-- 模块加载器（替代原来的 require / sharedRequire）
--==============================================================
local rawRequire = require;
local moduleCache = {};
local moduleFailed = {};
local moduleStack = {};

-- 启动诊断：外部可读 getgenv().__vairBoot 看每个模块跑没跑通
local boot = { loaded = {}, failed = {}, missing = {}, entryError = nil };
getgenv().__vairBoot = boot;

local function currentModule()
    return moduleStack[#moduleStack];
end;

local function normalizePath(basePath, requestPath)
    local raw = tostring(requestPath);
    raw = raw:gsub('\\', '/');

    if (raw:sub(1, 1) == '@') then
        return (raw:sub(2):gsub('^files/', ''));
    end;

    if (raw:sub(1, 2) ~= './' and raw:sub(1, 3) ~= '../') then
        return (raw:gsub('^files/', ''));
    end;

    local baseDir = '';

    if (basePath) then
        baseDir = basePath:match('^(.*)/') or '';
    end;

    local combined = baseDir .. '/' .. raw;
    local parts = {};

    for segment in combined:gmatch('[^/]+') do
        if (segment == '..') then
            table.remove(parts);
        elseif (segment ~= '.' and segment ~= '') then
            table.insert(parts, segment);
        end;
    end;

    return table.concat(parts, '/');
end;

local function findBySuffix(path)
    if (MODULES[path]) then return path end;

    local suffix = path;
    local best;

    for key in next, MODULES do
        if (key:sub(-#suffix - 1) == '/' .. suffix) then
            if (not best or #key < #best) then
                best = key;
            end;
        end;
    end;

    return best;
end;

local function runModule(path)
    -- 用哨兵区分「没跑过」和「跑过但返回 nil」。
    -- 以前是 moduleCache[path] ~= nil 才算已缓存，模块一旦返回 nil
    -- （比如加载失败）就会被每次调用重新执行、重新报错 ——
    -- 手机上的表现是同一个错误刷屏循环（混淆后函数名每次不同）。
    if (moduleCache[path] ~= nil) then
        return moduleCache[path];
    end;

    if (moduleFailed[path]) then
        return nil;
    end;

    local factory = MODULES[path];

    if (not factory) then
        moduleFailed[path] = true;

        return nil;
    end;

    table.insert(moduleStack, path);

    local ok, result = pcall(factory);

    table.remove(moduleStack);

    if (not ok) then
        moduleFailed[path] = true;
        moduleCache[path] = nil;

        table.insert(boot.failed, string.format('%s: %s', path, tostring(result)));
        warn(string.format('[v.air] 模块执行失败 %s: %s', path, tostring(result)));

        return nil;
    end;

    table.insert(boot.loaded, path);

    if (result == nil) then
        moduleFailed[path] = true;
    else
        moduleCache[path] = result;
    end;

    return result;
end;

local function bundleRequire(path)
    if (typeof(path) ~= 'string') then
        return rawRequire(path);
    end;

    local normalized = normalizePath(currentModule(), path);
    local key = findBySuffix(normalized);

    if (not key) then
        key = findBySuffix(path);
    end;

    if (not key) then
        table.insert(boot.missing, string.format('%s (来自 %s)', tostring(path), tostring(currentModule() or '入口')));
        warn(string.format('[v.air] 找不到模块 %s（来自 %s）', tostring(path), tostring(currentModule() or '入口')));

        return nil;
    end;

    return runModule(key);
end;

local function bundleRequireShared(path)
    local fileName = tostring(path):match('%w+%.lua') or tostring(path):match('%w+%.json');

    if (not fileName) then
        return nil;
    end;

    -- MODULES 为空 = 本包没拿到模块表（手机执行器吞掉 chunk 变参的典型症状）。
    -- 这种情况所有 sharedRequire 都会返回 nil，调用方会连锁崩在
    -- attempt to index nil with 'OnLoad' 之类的地方，而且看不出原因。
    -- 直接报一条明确的诊断，只报一次。
    if (next(MODULES) == nil) then
        if (not boot.emptyModules) then
            boot.emptyModules = true;

            warn('[v.air] 本包没有收到模块表（MODULES 为空）—— chunk 参数在手机上丢失了');
        end;

        return nil;
    end;

    local normalized = normalizePath(currentModule(), path);
    local key = findBySuffix(normalized) or findBySuffix(fileName);

    if (not key) then
        warn(string.format('[v.air] sharedRequire 找不到 %s', tostring(path)));

        return nil;
    end;

    return runModule(key);
end;

getgenv().require = bundleRequire;
getgenv().sharedRequire = bundleRequireShared;

getgenv().vluaRan = false;
getgenv().vluaRanReal = false;

function GAMES_SETUP()
    return runModule('games/Gakuran/main.lua');
end;

getgenv().GAMES_SETUP = GAMES_SETUP;

--// 卸载上一套，避免叠出第二个窗口
do
    local oldLibrary = getgenv().library;

    if (type(oldLibrary) == 'table' and type(oldLibrary.Unload) == 'function') then
        pcall(function()
            oldLibrary:Unload();
        end);
    end;

    getgenv().library = nil;

    local uiParent = gethui and gethui();

    if (uiParent) then
        for _, child in next, uiParent:GetChildren() do
            if (child:IsA('ScreenGui') and (child.Name == 'Vlua' or child.Name == 'VluaMobile')) then
                pcall(function()
                    child:Destroy();
                end);
            end;
        end;
    end;
end;

--// 入口
local entryOk, entryErr = pcall(runModule, 'source.lua');

if (not entryOk) then
    boot.entryError = tostring(entryErr);
    warn('[v.air] 入口执行失败: ' .. tostring(entryErr));
end;
end;
