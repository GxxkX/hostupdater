-- Copyright (c) 2025 Gxxkx
module("luci.controller.hostupdater", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/hostupdater") then
		return
	end

	local page = entry({"admin", "services", "hostupdater"}, template("admin/services/hostupdater"), _("Host Updater"), 60)
	page.dependent = true
	page.acl_depends = { "hostupdater" }

	-- actions
	entry({"admin", "services", "hostupdater", "status"}, call("action_status")).leaf = true
	entry({"admin", "services", "hostupdater", "update"}, call("action_update")).leaf = true
	entry({"admin", "services", "hostupdater", "restore"}, call("action_restore")).leaf = true
	entry({"admin", "services", "hostupdater", "config"}, call("action_config")).leaf = true
	entry({"admin", "services", "hostupdater", "log"}, call("action_log")).leaf = true
	entry({"admin", "services", "hostupdater", "hosts"}, call("action_hosts")).leaf = true

	entry({"admin", "services", "hostupdater", "source", "toggle"}, call("action_source_toggle")).leaf = true
	entry({"admin", "services", "hostupdater", "source", "update"}, call("action_source_update")).leaf = true
	entry({"admin", "services", "hostupdater", "source", "delete"}, call("action_source_delete")).leaf = true
	-- generic sources collection (GET list / POST create)
	entry({"admin", "services", "hostupdater", "sources"}, call("action_sources"))
end

local SOURCES_FILE = "/etc/hostupdater/sources.conf"
local LOG_FILE = "/var/log/hostupdater.log"

local function read_sources()
	local list = {}
	local f = io.open(SOURCES_FILE, "r")
	if not f then return list end
	for line in f:lines() do
		if not line:match("^%s*#") and line:match("%S") then
			local name, url, enabled = line:match("^([^|]+)|([^|]+)|([01])%s*$")
			if name and url and enabled then
				list[#list+1] = { id = name, name = name, url = url, enabled = (enabled == "1") }
			end
		end
	end
	f:close()
	return list
end

local function write_sources(list)
	nixio.fs.mkdirr("/etc/hostupdater")
	local f = io.open(SOURCES_FILE, "w+")
	if not f then return false, "cannot open sources file" end
	for _, s in ipairs(list) do
		local en = s.enabled and "1" or "0"
		f:write(string.format("%s|%s|%s\n", s.name, s.url, en))
	end
	f:close()
	return true
end

function action_status()
	local sys = require "luci.sys"
	local http = require "luci.http"
	local status = {
		service = sys.process.list()["hostupdater"] ~= nil,
		config = nixio.fs.access("/etc/config/hostupdater"),
		sources = nixio.fs.access(SOURCES_FILE),
		hosts = nixio.fs.access("/etc/hosts"),
		backup = nixio.fs.access("/etc/hostupdater/backup/hosts.original"),
		log = nixio.fs.access(LOG_FILE)
	}
	http.prepare_content("application/json")
	http.write_json(status)
end

function action_update()
	local sys = require "luci.sys"
	local http = require "luci.http"
	local result = sys.exec("/usr/bin/hostupdater update")
	http.prepare_content("text/plain")
	http.write(result)
end

function action_restore()
	local sys = require "luci.sys"
	local http = require "luci.http"
	local result = sys.exec("/usr/bin/hostupdater restore")
	http.prepare_content("text/plain")
	http.write(result)
end

function action_config()
	local sys = require "luci.sys"
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()
	local method = http.getenv("REQUEST_METHOD")
	if method == "POST" then
		local json = require "luci.jsonc"
		local body = http.content() or "{}"
		local data = json.parse(body) or {}
		if next(data) == nil then
			local fe = http.formvalue("enabled")
			data.enabled = (fe == "1" or fe == "true")
			data.interval = http.formvalue("interval")
		end
		local enabled = data.enabled and "1" or "0"
		local interval = tostring(data.interval or "6")
		uci:set("hostupdater", "main", "enabled", enabled)
		uci:set("hostupdater", "main", "interval", interval)
		uci:commit("hostupdater")
		if enabled == "1" then
			sys.exec("/etc/init.d/hostupdater enable >/dev/null 2>&1")
			sys.exec("/etc/init.d/hostupdater restart >/dev/null 2>&1")
		else
			sys.exec("/etc/init.d/hostupdater stop >/dev/null 2>&1")
			sys.exec("/etc/init.d/hostupdater disable >/dev/null 2>&1")
		end
		http.prepare_content("application/json")
		http.write_json({ success = true })
	else
		local enabled = (uci:get("hostupdater", "main", "enabled") == "1")
		local interval = uci:get("hostupdater", "main", "interval") or "6"
		http.prepare_content("application/json")
		http.write_json({ enabled = enabled, interval = interval })
	end
end

function action_sources()
	local http = require "luci.http"
	local method = http.getenv("REQUEST_METHOD")
	if method == "GET" then
		http.prepare_content("application/json")
		http.write_json(read_sources())
		return
	end
	if method == "POST" then
		local json = require "luci.jsonc"
		local body = http.content() or "{}"
		local data = json.parse(body) or {}
		if not data.name or not data.url then
			data.name = data.name or http.formvalue("name")
			data.url = data.url or http.formvalue("url")
			local en = http.formvalue("enabled")
			if en ~= nil then data.enabled = (en == "1" or en == "true") end
		end
		if not data.name or not data.url then
			http.prepare_content("application/json")
			http.write_json({ success = false, error = "missing name or url" })
			return
		end
		local list = read_sources()
		for _, s in ipairs(list) do
			if s.name == data.name then
				http.prepare_content("application/json")
				http.write_json({ success = false, error = "source exists" })
				return
			end
		end
		list[#list+1] = { name = data.name, url = data.url, enabled = (data.enabled ~= false) }
		local ok, err = write_sources(list)
		http.prepare_content("application/json")
		http.write_json({ success = ok, error = err })
		return
	end
	http.status(405, "Method Not Allowed")
end

function action_source_toggle(name)
	local http = require "luci.http"
	if not name or name == "" then
		name = http.formvalue("name") or http.formvalue("id") or http.formvalue("source")
	end
	if not name or name == "" then
		http.prepare_content("application/json")
		http.write_json({ success = false, error = "missing name" })
		return
	end
	local list = read_sources()
	local found = false
	for _, s in ipairs(list) do
		if s.name == name then
			s.enabled = not s.enabled
			found = true
			break
		end
	end
	local ok, err = write_sources(list)
	http.prepare_content("application/json")
	http.write_json({ success = found and ok or false, error = (found and err or "not found") })
end

function action_source_delete(name)
	local http = require "luci.http"
	local method = http.getenv("REQUEST_METHOD")
	if not name or name == "" then
		name = http.formvalue("name") or http.formvalue("id") or http.formvalue("source")
	end
	if not name or name == "" then
		http.prepare_content("application/json")
		http.write_json({ success = false, error = "missing name" })
		return
	end

	local list = read_sources()
	local newlist = {}
	local removed = false
	for _, s in ipairs(list) do
		if s.name ~= name then
			newlist[#newlist+1] = s
		else
			removed = true
		end
	end
	local ok, err = write_sources(newlist)
	http.prepare_content("application/json")
	http.write_json({ success = removed and ok or false, error = (removed and err or "not found") })
end

function action_source_update(name)
	local sys = require "luci.sys"
	local http = require "luci.http"
	if not name or name == "" then
		name = http.formvalue("name") or http.formvalue("id") or http.formvalue("source")
	end
	if not name or name == "" then
		http.status(400, "Bad Request")
		http.write("missing name")
		return
	end
	local exists = false
	for _, s in ipairs(read_sources()) do
		if s.name == name then exists = true break end
	end
	if not exists then
		http.status(404, "Not Found")
		http.write("source not found")
		return
	end
	local cmd = string.format("/usr/bin/hostupdater update-source %q", name)
	local result = sys.exec(cmd)
	http.prepare_content("text/plain")
	http.write(result)
end

function action_log()
	local http = require "luci.http"
	local method = http.getenv("REQUEST_METHOD")
	if method == "GET" then
		local lines = tonumber(http.formvalue("lines") or "100") or 100
		local data = ""
		if nixio.fs.access(LOG_FILE) then
			local fp = io.popen(string.format("tail -n %d %s 2>/dev/null", lines, LOG_FILE))
			if fp then
				data = fp:read("*a") or ""
				fp:close()
			end
		end
		http.prepare_content("text/plain")
		http.write(data)
		return
	end
	if method == "DELETE" or (method == "POST" and ((http.formvalue("op") == "delete") or (http.formvalue("_method") == "DELETE"))) then
		if nixio.fs.access(LOG_FILE) then
			nixio.fs.remove(LOG_FILE)
		end
		http.prepare_content("application/json")
		http.write_json({ success = true })
		return
	end
	http.status(405, "Method Not Allowed")
end

function action_hosts()
	local http = require "luci.http"
	local data = ""
	local f = io.open("/etc/hosts", "r")
	if f then
		data = f:read("*a") or ""
		f:close()
	end
	http.prepare_content("text/plain")
	http.write(data)
end 