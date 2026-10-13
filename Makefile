BIN := $(HOME)/.luarocks/bin
LUA := luajit

.PHONY: check test lint link data

check: lint test

test:
	$(BIN)/busted

lint:
	$(BIN)/luacheck .

# Symlink this checkout into the game. Usage: make link ADDONS="/path/to/Interface/AddOns"
link:
	@test -n "$(ADDONS)" || (echo "set ADDONS=/path/to/Interface/AddOns" && exit 1)
	ln -sfn "$(CURDIR)" "$(ADDONS)/Altrobe"

# Regenerate Data/Generated from a local All The Things checkout. Usage: make data ATT=/path/to/AllTheThings
data:
	@test -n "$(ATT)" || (echo "set ATT=/path/to/AllTheThings checkout" && exit 1)
	$(LUA) tools/build_data.lua "$(ATT)"
