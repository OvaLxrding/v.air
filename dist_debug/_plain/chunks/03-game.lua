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

	for _, obj in ipairs(gcObjects) do
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

	for _, obj in ipairs(gcObjects) do
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
end;
