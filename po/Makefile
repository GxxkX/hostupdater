# Makefile for hostupdater translations

# Languages to build
LANGS := zh-cn

# Output directory for .lmo files
LMO_DIR := ../files/usr/lib/lua/luci/i18n

# po2lmo tool (provided by OpenWrt build system)
PO2LMO ?= po2lmo

# Default target
all: $(LANGS)

# Build one language. Expect PO at <lang>/hostupdater.po
$(LANGS): %: %/hostupdater.po
	@echo "Building $@..."
	@mkdir -p $(LMO_DIR)
	@$(PO2LMO) $< $(LMO_DIR)/hostupdater.$@.lmo

# Clean generated files
clean:
	rm -f $(LMO_DIR)/hostupdater.*.lmo

# Update POT file from source (best-effort; LuCI templates may need manual maintenance)
pot: hostupdater.pot

hostupdater.pot: ../luasrc/luci/view/admin/services/hostupdater.htm
	@echo "Extracting strings to POT file..."
	@xgettext --from-code=UTF-8 --language=Python --keyword='<%:' --output=$@ $< || true

# Update PO files from POT
update-po: pot
	@for lang in $(LANGS); do \
	  if [ -f $$lang/hostupdater.po ]; then \
	    echo "Updating $$lang/hostupdater.po..."; \
	    msgmerge --update $$lang/hostupdater.po hostupdater.pot; \
	  fi; \
	done

# Install language files
install: $(LANGS)
	@echo "Installing language files to $(LMO_DIR)..." 

.PHONY: all clean pot update-po install $(LANGS)
