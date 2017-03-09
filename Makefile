ELM_FILES = $(wildcard src/*.elm) $(wildcard src/**/*.elm) $(wildcard src/**/*.js)

documentation.json: ${ELM_FILES}
	elm make --yes --docs=$@

elm-ops-tooling:
	git clone https://github.com/NoRedInk/elm-ops-tooling

tests/elm-stuff: elm-ops-tooling
	cd tests; ../elm-ops-tooling/with_retry.rb elm package install --yes

tests/elm-stuff/packages/BrianHicks/elm-benchmark: tests/elm-stuff ${ELM_FILES}
	./elm-ops-tooling/elm_self_publish.py . tests

examples/elm-stuff: elm-ops-tooling
	cd examples; ../elm-ops-tooling/with_retry.rb elm package install --yes

examples/elm-stuff/packages/BrianHicks/elm-benchmark: examples/elm-stuff ${ELM_FILES}
	./elm-ops-tooling/elm_self_publish.py . examples

.PHONY: test
test: tests/elm-stuff/packages/BrianHicks/elm-benchmark
	elm-test

examples/%.html: examples/% examples/elm-stuff/packages/BrianHicks/elm-benchmark
	cd examples; elm make --yes --output $(shell basename $@) $(shell basename $<)
