include $(TOPDIR)/rules.mk

PKG_NAME:=hostupdater
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Gxxkx <anjiejayjo@gmail.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Host Updater
  DEPENDS:=+curl +ca-bundle +luci-base +luci-compat
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  A hosts subscription source manager for OpenWrt that supports multiple hosts sources,
  scheduled and manual fetching, and updates to /etc/hosts file.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/hostupdater
/etc/hostupdater/
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/hostupdater $(1)/usr/bin/
	
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/etc/config/hostupdater $(1)/etc/config/
	
	$(INSTALL_DIR) $(1)/etc/hostupdater
	$(INSTALL_DATA) ./files/etc/hostupdater/sources.conf $(1)/etc/hostupdater/
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/hostupdater $(1)/etc/init.d/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/luci/controller/hostupdater.lua $(1)/usr/lib/lua/luci/controller/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/luci/model/cbi/hostupdater.lua $(1)/usr/lib/lua/luci/model/cbi/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/admin/services
	$(INSTALL_DATA) ./luasrc/luci/view/admin/services/hostupdater.htm $(1)/usr/lib/lua/luci/view/admin/services/
	
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/usr/share/rpcd/acl.d/luci-hostupdater.json $(1)/usr/share/rpcd/acl.d/
	
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./files/usr/share/luci/menu.d/luci-hostupdater.json $(1)/usr/share/luci/menu.d/
	
	$(INSTALL_DIR) $(1)/usr/share/luci/applications.d
	$(INSTALL_DATA) ./files/usr/share/luci/applications.d/luci-app-hostupdater.json $(1)/usr/share/luci/applications.d/
	
	$(INSTALL_DIR) $(1)/usr/share/luci/icons
	$(INSTALL_DATA) ./files/usr/share/luci/icons/hostupdater.svg $(1)/usr/share/luci/icons/
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
# Create backup directory
mkdir -p /etc/hostupdater/backup

# Backup original hosts file if not exists
if [ ! -f /etc/hostupdater/backup/hosts.original ]; then
    cp /etc/hosts /etc/hostupdater/backup/hosts.original
fi

# Set permissions
chmod 755 /usr/bin/hostupdater
chmod 644 /etc/config/hostupdater
chmod 644 /etc/hostupdater/sources.conf

# Enable service
/etc/init.d/hostupdater enable

# Reload LuCI menu
/etc/init.d/rpcd restart >/dev/null 2>&1
/etc/init.d/uhttpd restart >/dev/null 2>&1

exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
# Stop and disable service
/etc/init.d/hostupdater stop >/dev/null 2>&1
/etc/init.d/hostupdater disable >/dev/null 2>&1

# Restore original hosts file
if [ -f /etc/hostupdater/backup/hosts.original ]; then
    cp /etc/hostupdater/backup/hosts.original /etc/hosts
fi

# Remove package files
rm -rf /etc/hostupdater
rm -f /etc/config/hostupdater

# Reload LuCI menu
/etc/init.d/rpcd restart >/dev/null 2>&1
/etc/init.d/uhttpd restart >/dev/null 2>&1

exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME))) 