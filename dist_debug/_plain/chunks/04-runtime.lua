do
local MODULES = getgenv().__vairModules;

if (type(MODULES) ~= 'table') then
    MODULES = {};
    getgenv().__vairModules = MODULES;
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
