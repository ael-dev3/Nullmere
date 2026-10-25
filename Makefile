.PHONY: build run test check-shader app smoke clean

build:
	swift build

run:
	swift run NullmereLauncher

test:
	swift test

check-shader:
	scripts/check-shader.sh

app:
	scripts/build-app.sh

smoke: app
	scripts/smoke-test-app.sh

clean:
	rm -rf .build build
