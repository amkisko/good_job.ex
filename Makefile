.DEFAULT_GOAL := help

.PHONY: help setup deps format lint test ci dialyzer docs bench hex.build clean release test.setup test.reset

help:
	@echo "good_job.ex Makefile"
	@echo ""
	@echo "  make setup       deps.get + test DB setup"
	@echo "  make deps        mix deps.get"
	@echo "  make format      mix format"
	@echo "  make lint        format check + credo --strict"
	@echo "  make test        mix test (no lint gate)"
	@echo "  make ci          mix test.ci (format, unused deps, credo, test, dialyzer)"
	@echo "  make dialyzer    mix dialyzer"
	@echo "  make docs        mix docs"
	@echo "  make bench       MIX_ENV=dev mix bench.load"
	@echo "  make hex.build   mix hex.build"
	@echo "  make test.setup  create + migrate test DB"
	@echo "  make test.reset  drop + recreate test DB"
	@echo "  make clean       remove build, cover, docs, tarballs"
	@echo "  make release     elixir usr/bin/release.exs"
	@echo ""
	@echo "Bench knobs: JOBS THREADS LOCK SCENARIO BULK PRESERVE POOL_SIZE"

setup: deps test.setup

deps:
	mix deps.get

format:
	mix format

lint:
	mix format --check-formatted
	mix credo --strict

test:
	mix test

ci:
	mix test.ci

dialyzer:
	mix dialyzer

docs:
	mix docs

bench:
	MIX_ENV=dev mix bench.load

hex.build:
	mix hex.build

test.setup:
	mix test.setup

test.reset:
	mix test.reset

clean:
	rm -rf _build cover deps doc .elixir_ls
	rm -f erl_crash.dump good_job-*.tar

release:
	elixir usr/bin/release.exs
