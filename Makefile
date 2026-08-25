SHELL := /bin/bash

.PHONY: check lint syntax test

check: syntax lint test

syntax:
	bash -n vpsbuddy install.sh VPS_buddy.sh lib/*.sh tests/*.sh

lint:
	shellcheck -x vpsbuddy install.sh VPS_buddy.sh lib/*.sh tests/*.sh

test:
	bash tests/manifest.sh
	bash tests/unit.sh
	bash tests/smoke.sh
