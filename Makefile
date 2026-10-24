.PHONY: build run test check-shader app clean

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

clean:
	rm -rf .build build
