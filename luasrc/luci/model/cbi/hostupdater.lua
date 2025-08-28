-- Copyright (c) 2025 Gxxkx
local m, s, o
local uci = luci.model.uci.cursor()

m = Map("hostupdater", translate("Host Updater"), translate("基础设置和快捷操作。高级订阅源管理请前往自定义视图页面。"))

-- 基本设置
s = m:section(TypedSection, "main", translate("基本设置"))
s.anonymous = true

o = s:option(Flag, "enabled", translate("启用服务"))
o.default = 0
o.rmempty = false

o = s:option(ListValue, "interval", translate("更新间隔"))
o:value("1", translate("1小时"))
o:value("2", translate("2小时"))
o:value("3", translate("3小时"))
o:value("6", translate("6小时"))
o:value("12", translate("12小时"))
o:value("24", translate("24小时"))
o.default = "6"
o.rmempty = false

-- 快捷操作
s = m:section(SimpleSection, translate("快捷操作"))
s.anonymous = true

o = s:option(Button, "open_view", translate("打开高级管理页面"))
o.inputtitle = translate("打开页面")
o.inputstyle = "apply"
o.write = function()
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "hostupdater"))
end

o = s:option(Button, "update_all", translate("执行全部更新"))
o.inputtitle = translate("更新全部")
o.inputstyle = "apply"
o.write = function()
	luci.sys.call("/usr/bin/hostupdater update >/dev/null 2>&1")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "hostupdater"))
end

-- 日志操作
s = m:section(SimpleSection, translate("日志操作"))
s.anonymous = true

o = s:option(Button, "view_log", translate("查看日志(最近100行)"))
o.inputtitle = translate("查看日志")
o.inputstyle = "reload"
o.write = function()
	local data = luci.sys.exec("/usr/bin/tail -n 100 /var/log/hostupdater.log 2>/dev/null")
	luci.template.render_string([[<%+header%><h2><%:Host Updater 日志%></h2><pre style="white-space:pre-wrap;word-break:break-all;">]] ..
		luci.util.pcdata(data) .. "</pre>" .. [[<%+footer%>]])
end

o = s:option(Button, "clear_log", translate("清空日志"))
o.inputtitle = translate("清空")
o.inputstyle = "remove"
o.write = function()
	luci.sys.call("rm -f /var/log/hostupdater.log >/dev/null 2>&1")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "hostupdater"))
end

return m 