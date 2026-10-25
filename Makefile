.PHONY: build run play test check-shader app smoke smoke-game clean

build:
	swift build

run:
	swift run NullmereLauncher

play:
	swift run Nullmere

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

clean:
	rm -rf .build build
