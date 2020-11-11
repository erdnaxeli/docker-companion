# docker-companion

A bad reimplementation of docker-compose that manages your docker services and
warns you about images updates over Matrix.

> Insert here an awesome gif of some containers being controlled by speaking
> to a Matrix bot.

## Installation

You need to have Crystal installed, see
[instructions](https://crystal-lang.org/install/).

Clone the following repository, go into the folder, then type `make`.

## Usage

You need a file named `config.yaml` in the folder you will run your companion.

```
matrix:
  homeserver: the url of your homeserver
  access_token: an access token for the bot's account
  notification_room: the id of a room where to receive updates notification
  users:
    - a list of
    - users allowed
    - to talk to the bot
    - in the form @username:server.net
```

Then you can run `/path/to/docker-companion/bin/docker-companion`.

Upon start it will scan the current directory.
For any directory containing a `docker-compose.yaml` file, it will read it,
**drop any running containers** for this project, and start new ones.

> :warning: If your project is already running with docker-compose, you probably
> want to stop it first to avoid having many instance of the same services running.
>
> See below the naming part for more details.

The companion will then try to pull new images every hours, and if there are
any it will warn you.
You can then restart the services with their new images with the command
`update` (see below).

## Features

This project tries to mimic docker-compose, so it will:
* create a network for each project
* attach the containers to the project network
* resolve relative paths in volumes to absolutes ones

You can invite the bot and interact with it.
The currently available commands are:
* `images`: list local docker images
* `networks`: list docker networks
* `projects`: list loaded projects
* `update PROJECT [SERVICES]`: update a project services by dropping and recreating them
* and of course `help`

Docker-compose features supported:
* specifying the container's name
* mapping ports
* restart policy
* binds-mounts (aka volumes with a path as source)
* environment vars
* labels

Major docker-compose features not supported:
* command and entrypoint
* creating networks (other than the default one)
* build an image from a Dockerfile
* named volumes (not bind mounts)
* scaling and all docker swarm related things
* and a lot more

Specific points:
* labels must use the dictionnary form
* read-only mode for bind mounts is not supported
* networks other than "default" are not created and must exist

### Naming

The naming is a bit different from the docker-compose's one:
  * for containers (if `container_name` is not provided):
    `${project_name}_${serivce_name}`
  * for the default network: `${project_name}_network`
  * the project name is the folder's name, like docker-compose does

This means the companion will not recognize containers created with docker-compose
for the same project, and so will not destroy them.
It is up to you to manage them.

You probably want to use either docker-compose or this project but not both at
the same time with the same project.

## Todo

* offer a command to rollback a container to a previous (local) image
* commands to restart a container or show its logs
* support building a docker image
* warn when a container fails

Maybe after that:
* support cloning a git repository, watch for new commits, and build the image
* do not destroy containers at boot, but warn the user for diffs
* add projets directly from Matrix
* edit projects from Matrix

## Development

Install the depencies with `shards install`.

`make test` runs the tests, and `make lint` runs the formater plus a linter.
`make run` runs the code, `make` builds a binary.

## Contributing

1. Fork it (<https://github.com/erdnaxeli/docker-companion/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [erdnaxeli](https://github.com/erdnaxeli) - creator and maintainer
