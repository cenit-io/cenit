![best_user_pictures_3](https://user-images.githubusercontent.com/4213488/27266266-718722d0-5454-11e7-987f-1f951610673d.png)

[![Code Climate](https://codeclimate.com/github/openjaf/cenit/badges/gpa.svg)](https://codeclimate.com/github/openjaf/cenit)
[![codebeat](https://codebeat.co/badges/1b596784-b6c1-4ce7-b739-c91b873e4b5d)](https://codebeat.co/projects/github-com-cenit-io-cenit)
[![license](https://img.shields.io/packagist/l/doctrine/orm.svg)]()
[![Slack Status](http://cenit-slack.herokuapp.com/badge.svg)](http://cenitio.slack.com)

[![OpenAPIs in collection][numApis-image]][apisDir-link]
[![OpenAPI specs][numSpecs-image]][apisDir-link]
[![Endpoints][endpoints-image]][apisDir-link]

[![Follow on Twitter][twitterFollow-image]][twitterFollow-link]

* [Cenit IO](https://cenit.io)  [(https://cenit.io)](https://cenit.io)
* [Join our Slack][join-slack-link]
[(cenitio.slack.com)][join-slack-link]
* [Shared Collections](https://cenit.io/setup~shared_collection)
* [Cenit IO - 101 Intro](https://cenit-io.github.io/cenit-slides/#cover)
* [Documentation](https://cenit-io.github.io/docs/)
* support@cenit.io


[Cenit IO](https://cenit.io)  [(https://cenit.io)](https://cenit.io) is an Open Platform for Data and Business Integration (iPaaS). It is designed to orchestrate data flows that may involve several kinds of endpoints (APIs, Datasets, EDI). It makes possible a complete business automation of all operational processes in a company, connecting between organization's on-premises infrastructure and cloud provider services.

**Backenless**

When is created a new Data Type using a JSON Schema, is generated on the fly a complete REST API and a CRUD UI to manage the data. It is useful in different use cases, for example as the backend for a mobile application.

[see this video for more details](https://youtu.be/DsFicrI6cDg)

![mwjajn](https://user-images.githubusercontent.com/4213488/27265759-ec78001e-544e-11e7-9265-d6e5cc7559da.gif)

**Data Pipelines between APIs**

It allows the creation of custom data pipelines for process, storage and data movement between APIs. The flows could be trigger by data events or be scheduled.

There are now over 200 pre-built integration collections shared out the box to connect with online internet services,
fulfilment solutions, accounting, communications, ERP, multi-channels, etc.

[see this video for more details](https://youtu.be/IOEbTtEv8MQ)

An example of integration data flow (Fancy <=> Shipstation):

* Every 20 minutes Cenit trigger a flow to get orders from Fancy Marketplace.

* New or updated orders are received and persisted in Cenit.

* After the new or updated orders are saved, is trigger a Flow to send a shipment to Shipstation.

* The flow requires transforming the Fancy Order into a valid shipment on Shipstation.

* Each 20 minutes Cenit trigger a flow to fetch Shipped shipments from Shipstation.

* After the shipments are updated in Cenit, is trigger a Flow to send the tracking update to Fancy.


## Deploy your own server

### With the Heroku Button

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

### Without It

* Clone the repo and change directory to it
* Log in with the Heroku Toolbelt and create an app: `heroku create`
* Use the mLab addon: `heroku addons:create mongolab:sandbox`
* Use the rabbitmq addon: `heroku addons:create rabbitmq-bigwig:pipkin`
* Deploy it with: `git push heroku master`
* Open in the browser: `heroku open`

###  With Docker compose.

After [install docker compose](https://docs.docker.com/compose/install)

Then run docker compose:

```batch
docker-compose build
docker-compose up
```

and visit the browser: `localhost:3000`

## General Features

* 100% Open source integration platform and community friendly.
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
  + **Schemas & Validators** - XML Schema, EDI Grammars, Regular Expression, etc
  + **Data Types** - Include Object Type defined and a Json Schema and File Type

* Connectors
  + **API Specs** - Allow upload an Open API Spec (Swagger 2.0).
  + **Connections** - Are representation of endpoints.
  + **Resources** - Element that manages a kind of data and a state and provides processing on this kind
  + **Operations** - An operation is a unit of a REST API that you can call
  + **Webhooks** - The webhook are the final step in a flow, implemented like a request HTTP to an endpoint, for sent or receive data

* Compute
  + **Snippets** - Small region of re-usable code
  + **Algorithms**
  + **Applications** - Associate path with algorithms to process the request and render the response.

* Transformations
  + **Renderers** - Exporting data outside Cenit.
  + **Parsers** - Importing outside data into Cenit.
  + **Converters** - Converting data already stored in Cenit.
  + **Updaters** - Updating data already stored in Cenit.

* Workflows
  + **Flows** - Defines how data is processed by the execution of one or more actions.
  + **Data Events** - Creation of new objects or changes in objects will result in events.
  + **Schedulers** - Are events triggered on a certain moment and can be optionally recurrent.

* Security
  + **OAuth Clients**
  + **Providers** - Authentication Providers.
  + **OAuth 2.0 Scopes**
  + **Authorizations** - Integrations authorizations.
  + **Access Grants**

* Monitors
  + **Notifications** - Provide detailed trail of tenant activity.
  + **Tasks** -  Asynchronous executions of flows.
  + **Storages** - Info about the used space.

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

Browse *http://localhost:3000*. If you have any trouble please check that *mongodb* server is running.
You should also have a working installation of [RabbitMQ](http://www.rabbitmq.com), see below the guide to install
RabbitMQ.

If RabbitMQ is correctly installed when you run the rails server you should see:

```
 [*] Waiting for messages. To exit press CTRL+C
```

It uses Figaro gem to manage app configuration using ENV. Any of this variable is required to run a local server but maybe you consider some of then to run in production environment

Then add to `config/application.yml` app configuration:  

```
# config/application.yml

SHOW_SLACK_BADGE: "true"
JUPYTER_NOTEBOOKS: "true"
JUPYTER_NOTEBOOKS_URL: "//{your-cenit-jupyter-notebooks}.herokuapp.com"
GITHUB_OAUTH_TOKEN: "{GITHUB_OAUTH_TOKEN}"
DB_PROD: "{DB_PROD}"
OAUTH_TOKEN_END_POINT: "embedded"
RELIC_LICENSE_KEY: "{RELIC_LICENSE_KEY}"
GOOGLE_ANALYTIC_ID: "{GOOGLE_ANALYTIC_ID}"
PORTAL_URL: 'https://cenit-portal.herokuapp.com'
DOCS_URL: 'https://cenit-io.github.io'
API_DOC_URL: 'https://cenit-io.github.io'
OPEN_ID_CLIENT_ID: "{OPEN_ID_CLIENT_ID}"
OPEN_ID_CLIENT_SECRET: "{OPEN_ID_CLIENT_SECRET}"
OPEN_ID_AUTH_URL: "https://cenit.io/app/open_id/sign_in"
OPEN_ID_REDIRECT_URI: "https://cenit.io/users/sign_in"
OPEN_ID_TOKEN_URL: "https://cenit.io/app/open_id/sign_in/token"
EXCLUDED_ACTIONS: simple_share bulk_share simple_cross_share bulk_cross_share build_gem bulk_pull
RABBITMQ_BIGWIG_TX_URL: "{RABBITMQ_BIGWIG_TX_URL}"
NOTIFIER_EMAIL: "{NOTIFIER_EMAIL}"
EXCEPTION_RECIPIENTS: "{List of emails}"
RABBIT_MQ_USER: "{RABBIT_MQ_USER}"
RABBIT_MQ_PASSWORD: "{RABBIT_MQ_PASSWORD}"

# AMAZON SIMPLE STORAGE SERVICE.
AWS_ACCESS_KEY_ID: "{AWSS3 Access ID}"
AWS_SECRET_ACCESS_KEY: "{AWSS3 Access Key}"
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

## How to install on Ubuntu server 16.04

### Update OS

```
sudo apt update
sudo apt dist-upgrade
sudo apt autoremove
reboot
```

### Install additional required packages

```
sudo apt install mongodb rabbitmq-server zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev python-software-properties libffi-dev nodejs git imagemagick libmagickwand-dev
```

### Install Ruby 2.2.1 with rbenv

```
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
exec $SHELL
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
exec $SHELL
rbenv install 2.2.1
rbenv global 2.2.1
exec $SHELL
```

### Confirm Ruby version

```
ruby -v
gem install bundler
exec $SHELL
```

### Install Cenit

```
git clone https://github.com/cenit-io/cenit.git
cd cenit
git checkout -b develop origin/develop
```

Confirm repository branch `> *develop`

```
git branch
```

Update development branch

```
git pull origin develop
```

### Install Cenit requirements

```
bundle install
```

### Create Cenit admin user and run Cenit

```
exec $SHELL
rake admin:create
rails s -p 3000 -b # The IP address of Ubuntu machine
```

### Importing first cross collection on Cenit local:

Once you have Cenit running in local you can start importing collections.

First you need to create one translator that let you import all collections and data. So, go to Transformations/Parser and select New.

Write a namespace and a name for it. In style select Ruby.

In code write this:

```Ruby
if (parsed_data = JSON.parse(data)).is_a?(Array)
  parsed_data.each { |item| target_data_type.create_from_json!(item) }
else   
  target_data_type.create_from_json!(parsed_data)
end
```

Then save it.

Now you can import collections using the translator you have already created.

Example: Importing Basic collections

1. Export Basic collection. In Cenit.io search Basic cross collection and select Export option. In translator select JSON Portable Exporter [Shared].

2. Import Basic collection. In your cenit in local, go to Collections/Shared Collections/All and selectImport option. There select the translator you have just created and import the collection. You can see it on Collections/Shared Collections/All.


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
* [Yoandry Pacheco](https://github.com/yoandrypa)
* [Maria E. Guirola](https://github.com/maryguirola)
* [Asnioby Hernandez](https://github.com/Asnioby)
* [Daniel H. Bahr](https://github.com/dhbahr)
* [Cesar Lage](https://github.com/kaerdsar)
* [Aneli Valdés](https://github.com/avaldesa)
* [José A. Cruz](https://github.com/jalbertcruz)

[numApis-image]: https://api.apis.guru/badges/apis_in_collection.svg
[numSpecs-image]: https://api.apis.guru/badges/openapi_specs.svg
[endpoints-image]: https://api.apis.guru/badges/endpoints.svg
[apisDir-link]: https://github.com/APIs-guru/openapi-directory/tree/master/APIs
[twitterFollow-image]: https://img.shields.io/twitter/follow/cenit_io.svg?style=social
[twitterFollow-link]: https://twitter.com/intent/follow?screen_name=cenit_io
[join-slack-link]: https://join.slack.com/t/cenitio/shared_invite/MjI4MDE5MjM3Nzc2LTE1MDMwNzY0NDUtY2FjMGJjNWQzNA
