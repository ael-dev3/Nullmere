.PHONY: build run play test check-shader app smoke smoke-game smoke-menu clean

build:
	swift build

run:
	swift run NullmereLauncher

# Plays in a realm hosted on this Mac.
play:
	NULLMERE_REALM=local swift run NullmereLauncher

test:
	swift test

check-shader:
	scripts/check-shader.sh

app:
	scripts/build-app.sh

smoke: app
	scripts/smoke-test-app.sh

smoke-game: build
	scripts/smoke-test-game.sh

smoke-menu: build
	scripts/smoke-test-launcher-menu.sh

clean:
	rm -rf .build build
