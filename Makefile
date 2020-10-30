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

test:
	crystal spec  --error-trace
