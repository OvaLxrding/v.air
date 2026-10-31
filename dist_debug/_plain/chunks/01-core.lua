do
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
end;
