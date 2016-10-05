[![Code Climate](https://codeclimate.com/github/openjaf/cenit/badges/gpa.svg)](https://codeclimate.com/github/openjaf/cenit)
[![codebeat](https://codebeat.co/badges/1b596784-b6c1-4ce7-b739-c91b873e4b5d)](https://codebeat.co/projects/github-com-cenit-io-cenit)
[![license](https://img.shields.io/packagist/l/doctrine/orm.svg)]()
[![Slack Status](http://cenit-slack.herokuapp.com/badge.svg)](http://cenitio.slack.com)

* [Cenit IO](https://cenit.io)  [(https://cenit.io)](https://cenit.io)
* [Join our Slack](http://cenit-slack.herokuapp.com/) [(cenitio.slack.com)](http://cenitio.slack.com)
* [Shared Collections](https://cenit.io/setup~shared_collection)
* [Cenit IO - 101 Intro](https://cenit-io.github.io/cenit-slides/#cover)
* [Documentation](https://cenit-io.github.io/docs/)
* support@cenit.io


**Cenit IO** is an open platform for data and business integration. This Integration Platform-as-a-Service (iPaaS) has been designed to orchestrate data flows that may involve several kind of endpoints (APIs, Datasets, EDI). It makes possible the automation of all operational processes in a company, connecting between organization's on-premises infrastructure and cloud provider services.

It allows the creation of custom data pipelines for process, storage and data movement between APIs –either public or 
on premises-. The flows could be trigger by data events or be scheduled by our platform [Cenit IO](https://cenit.io).


## Run your own Cenit
[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)


## General Features

* 100% Open source platform and community friendly. 
* Router Logic for redirecting documents to different endpoints.
* Powerful design with simple abstractions: Data Types, Webhooks, Flows, Events, Connections, Transforms and Validators.
* Exchange support for multiple formats XML, JSON, CSV, EDI(X12, EDIFACT, ..), etc.
* Dynamic load validators: XML Schema, JSON Schema and EDI grammars.
* Powerful transformation tools to translate and convert several formats into others.
* Social networking features to share integration settings, we call them *Shared Collections*.
* Export and import shared collections as a repo on Github and a gem in Rubygems.
* Multi-tenancy.


## Key concepts

* Definitions
  + Schemas & Validators
  + Data Types

* Connectors
  + Connections
  + Connection Roles
  + Webhooks

* Workflows
  + Flows
  + Data Events
  + Schedulers
  + Translators
  + Algoritms

* Security
  + OAuth Clients
  + Providers
  + OAuth 2.0 Scopes
  + Authorizations

* Monitors
  + Notifications
  + Tasks
  + Storages


## Load Schemas & Data Types on the fly

* XSD, JSON Schemas and EDI grammars
* Allows adding new Document types to the Database
* CRUD any data with ease
* Search and filter
* Export data to CSV/JSON/XML
* User action history


## Manage multiple Authentication Protocols

* Basic Auth
* Digest Auth
* OAuth 1.0a
* OAuth 2.0


## Shared Collections

There are now over 200 pre-built integration collections shared out the box to connect with online internet services, 
fulfilment solutions, accounting, communications, ERP, multi-channels, etc.


## Frameworks and Tools

* Ruby on Rails
* MongoDB
* Mongoid and Mongoff as Object Document Mapper (ODM)
* rails_admin, for build admin panel.
* RabbitMQ for internal pipeline messages.


## Create Cenit IO local server.

Clone the [GitHub cenit-io/cenit repo](https://github.com/cenit-io/cenit) and move to the **cenit** folder.

```
$ git clone https://github.com/cenit-io/cenit.git
$ cd cenit
```

Checkout the development branch.

```
$ git checkout -b develop origin/develop
```

If you have previously cloned it ensure that you are in the **develop** branch...

```
$ git branch
> *develop
```

...and that it is updated.

```
$ git pull origin develop
> Already up-to-date.
```

Run the `bundle install` command to set up the required gems on your computer:

```
$ bundle install
```

Since Cenit IO uses Mongodb you don't need run any migrations, simply start the hub on port 3000, or any other of your 
own choosing, just be mindful of that.

```
$ rails s -p 3000
```

If you have some trouble with *secret_key_base* running `rails s`, you can generate a random secret key value:

```
$ rake secret
```	

Then copy this value and paste it in config/initializers/secret_token.rb:

```
Cenit::Application.config.secret_key_base = 'bla' # replace this
```

Browse *http://localhost:3000*. If you have any troublea please check that *mongodb* server is running.
You should also have a working installation of [RabbitMQ](http://www.rabbitmq.com), see below the guide to install 
RabbitMQ.

If RabbitMQ is correctly installed when you run the rails server you should see:

```
 [*] Waiting for messages. To exit press CTRL+C	
```

## Dependencies

Before generating your application, you will need:

* The Ruby language
* The Rails gem
* A working installation of [MongoDB](http://www.mongodb.org)
* A working installation of [RabbitMQ](http://www.rabbitmq.com)


### Installing MongoDB

If you don't have MongoDB installed on your computer, you'll need to install it and set it up to be always running on 
your computer (run at launch).

On Mac OS X, the easiest way to install MongoDB is to install [Homebrew](http://brew.sh) and then run:

```
brew install mongodb
```

Homebrew will provide post-installation instructions to get MongoDB running. The last line of the installation output 
shows you the MongoDB install location (for example, */usr/local/Cellar/mongodb/1.8.0-x86_64*). You'll find the MongoDB 
configuration file there. After an installation using Homebrew, the default data directory will be 
*/usr/local/var/mongodb*.

On the Debian GNU/Linux operating system, as of March 2013, the latest stable version is MongoDB 2.0.0. With MongoDB 
2.0.0, the Mongoid gem must be version 3.0.x. See the 
[Mongoid installation instructions](http://mongoid.org/en/mongoid/docs/installation.html#installation). Change your 
`Gemfile` to use an earlier Mongoid version:

```
gem 'mongoid', github: 'mongoid/mongoid'
gem 'bson_ext', '~> 1.8.6'
```

### Installing RabbitMQ

The [RabbitMQ](http://www.rabbitmq.com) website has a good [installation guide](http://www.rabbitmq.com/download.html) 
that addresses many operating systems. On Mac OS X, the fastest way to install RabbitMQ is with 
[Homebrew](http://brew.sh):

```
brew install rabbitmq
```

then run it:

```
rabbitmq-server
```

On Debian and Ubuntu, you can either [download the RabbitMQ .deb package](http://www.rabbitmq.com/download.html) and 
install it with [dpkg](http://www.debian.org/doc/manuals/debian-faq/ch-pkgtools.en.html) or make use of the 
[apt repository](http://www.rabbitmq.com/install-debian.html) that the RabbitMQ team provides.

For RPM-based distributions like RedHat or CentOS, the RabbitMQ team provides an 
[RPM package](http://www.rabbitmq.com/download.html).

```
Note: The RabbitMQ packages that ship with Ubuntu versions earlier than 11.10 are outdated and will not work with 
Bunny 0.9.0 and later versions (you will need at least RabbitMQ v2.0 to use with this guide).
```

Contributing
----------------------

Cenit IO is an open source project and we encourage contributions. 

In the spirit of [free software](http://www.fsf.org/licensing/essays/free-sw.html), **everyone** is encouraged to help 
improve this project.

Here are some ways **you** can contribute:

* by using prerelease master branch
* by reporting [bugs](https://github.com/cenit-io/cenit/issues/new)
* by writing or editing [documentation](https://github.com/cenit-io/docs)
* by writing [needed code](https://github.com/cenit-io/cenit/labels/feature_request) or [finishing code](https://github.com/cenit-io/cenit/labels/address_feedback)
* by [refactoring code](https://github.com/cenit-io/cenit/labels/address_feedback)
* by reviewing [pull requests](https://github.com/cenit-io/cenit/pulls)

### Contributors

Thank you for your contributions:

* [Maikel Arcia](https://github.com/macarci)
* [Miguel Sancho](https://github.com/sanchojaf)
* [Asnioby Hernandez](https://github.com/Asnioby)
* [Cesar Lage](https://github.com/kaerdsar)
* [Daniel H. Bahr](https://github.com/dhbahr)
* [Maria E. Guirola](https://github.com/maryguirola)
* [José A. Cruz](https://github.com/jalbertcruz)


