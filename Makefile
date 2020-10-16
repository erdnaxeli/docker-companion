init-dev:
	shards install

lint:
	crystal tool format
	./bin/ameba src spec
