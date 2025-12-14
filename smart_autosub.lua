-- smart_autosub.lua
-- 用于 mpv 自动匹配 SxxExx 格式的字幕，忽略文件名前后的差异

local utils = require 'mp.utils'
local msg = require 'mp.msg'

-- 支持的字幕后缀
local sub_exts = {
    ["ass"] = true,
    ["srt"] = true,
    ["vtt"] = true,
    ["ssa"] = true,
    ["sub"] = true,
    ["txt"] = true
}

-- 从文件名中提取 季(S) 和 集(E) 的数字
-- 支持格式：S01E04, s1e4, S01.E04, S1_E4, 1x04 等
local function extract_se(filename)
    if not filename then return nil, nil end
    local name = string.lower(filename) -- 转小写处理
    
    -- 模式1: 标准 SxxExx (允许中间有 . _ 或空格)
    -- 例如: S01E04, s1.e4, s01_e04
    local s, e = string.match(name, "s(%d+)[%s%.%_]*e(%d+)")
    if s and e then return tonumber(s), tonumber(e) end

    -- 模式2: 1x04 格式
    s, e = string.match(name, "(%d+)x(%d+)")
    if s and e then return tonumber(s), tonumber(e) end

    return nil, nil
end

-- 获取文件扩展名
local function get_ext(filename)
    return filename:match("^.+(%.[^%.]+)$"):sub(2):lower()
end

local function load_smart_subs()
    local path = mp.get_property("path")
    if not path then return end

    -- 分离目录和文件名
    local dir, filename = utils.split_path(path)
    
    -- 提取当前视频的 S 和 E
    local vid_s, vid_e = extract_se(filename)
    
    -- 如果视频本身没有 SxxExx 标记，则不执行脚本，避免误伤
    if not vid_s or not vid_e then 
        msg.verbose("当前视频未检测到 S/E 编号，跳过智能匹配。")
        return 
    end

    msg.info(string.format("检测到剧集信息: Season %d, Episode %d", vid_s, vid_e))

    -- 读取目录下所有文件
    local files = utils.readdir(dir, "files")
    if not files then return end

    for _, file in ipairs(files) do
        -- 检查是否是字幕文件
        local ext = file:match("^.+(%.[^%.]+)$")
        if ext then
            ext = ext:sub(2):lower()
            if sub_exts[ext] then
                -- 提取字幕文件的 S 和 E
                local sub_s, sub_e = extract_se(file)
                
                -- 如果 S 和 E 都匹配，且不是视频文件本身
                if sub_s == vid_s and sub_e == vid_e and file ~= filename then
                    local sub_path = utils.join_path(dir, file)
                    msg.info("智能匹配成功，加载字幕: " .. file)
                    mp.commandv("sub-add", sub_path)
                end
            end
        end
    end
end

-- 在文件加载时触发
mp.register_event("start-file", load_smart_subs)