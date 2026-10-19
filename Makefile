PREFIX ?= /usr/local

build:
	swiftc remindlist.swift -o remindlist -O

install: build
	install -d $(PREFIX)/bin
	install remindlist $(PREFIX)/bin/remindlist

test: build
	./remindlist "remindlist-smoke-test"
	./remindlist list | grep -q "remindlist-smoke-test"
	@echo "smoke test passed"

clean:
	rm -f remindlist

.PHONY: build install test clean
