.PHONY: build test run clean

build:
	swift build

test:
	swift test

run:
	swift run DriftMap

clean:
	swift package clean
