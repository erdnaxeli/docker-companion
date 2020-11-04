all:
	shards build

doc:
	crystal doc

init-dev:
	shards install

lint:
	crystal tool format
	./bin/ameba src spec

run:
	crystal run src/main.cr

static:
	docker run --rm -it -v ${PWD}:/workspace -w /workspace crystallang/crystal:0.35.1-alpine crystal build --static --release src/main.cr

test:
	crystal spec  --error-trace

.PHONY: test
