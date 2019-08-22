![cenit_io](https://user-images.githubusercontent.com/4213488/40578188-bcbf8a58-60c4-11e8-96d7-19842c348c5e.png)

[![Code Climate](https://codeclimate.com/github/openjaf/cenit/badges/gpa.svg)](https://codeclimate.com/github/openjaf/cenit)
[![codebeat](https://codebeat.co/badges/1b596784-b6c1-4ce7-b739-c91b873e4b5d)](https://codebeat.co/projects/github-com-cenit-io-cenit)
[![license](https://img.shields.io/packagist/l/doctrine/orm.svg)]()

[![OpenAPIs in collection][numApis-image]][apisDir-link]
[![OpenAPI specs][numSpecs-image]][apisDir-link]
[![Endpoints][endpoints-image]][apisDir-link]

[![Follow on Twitter][twitterFollow-image]][twitterFollow-link]

* [Cenit IO](https://cenit.io)  [(https://cenit.io)](https://cenit.io)
* [Join our Slack][join-slack-link]
[(cenitio.slack.com)][join-slack-link]
* [Shared Collections](https://cenit.io/setup~shared_collection)
* [Wiki](https://github.com/cenit-io/cenit/wiki)
* support@cenit.io

[Cenit](https://cenit.io) is a 100% open integration Platform (iPaaS) that's modern, powerful, yet hackable to the core, ready to use in the cloud https://cenit.io or on-premises. It is designed to solve unique integrations needs, orchestrate data flows that may involve types of protocols and data formats, and provide API management capabilities. All of which can support wide range of integration use cases. Is particular valuable to embrace a pervasive integration approach.

**Why**

The insatiable need for integration driven by social networks, open APIs, mobile apps, cloud services and, increasingly, the IoT is fertile ground for the growth in adoption of integration platforms.

Many are familiar with services such as Zapier and IFTTT, which addresses common integration problems but have limited capabilities to adapt to particular needs and to reflect business flows that are not simple. iPaaS platforms are designed to handle this issue, being in recent years in the state of the art for applications and data integration technologies used by large organizations, and gaining increasing interest in the general public.

The proliferation and growing importance of decentralized integration tasks driven by business and IT trends are forcing to rethink organizational models and technology platforms to an approach to pervasive integration.

None of the vendor leaders in the market really offers a completely open and transparent solution, with the freedom to use, customize or modified without restriction, we believe that is one of the keys to a wide adoption, and relevant to making the decision to use on-premise.

**Mission**

Enable everyone to contribute and benefit from the use of a modern Integration Platform (iPaaS).

**Value proposition**

Cenit makes possible that benefits of a modern iPaaS should be accessible to the small and midsize organizations, particularly valuable to embrace as a strategic component of a pervasive integration approach that allows a complete automation of all operational processes. As well as adding value quickly and continuously, essential to be competitive in the actual economy.

**How**

* Developing a 100% open source integration Platform (iPaaS).
* Provide options to use in the cloud https://cenit.io or on-premise server.
* Include open catalogs for formal API specs.
* Options to share integrations at different openness levels: inside a tenant, to specific tenants, or for everyone.
* Ensure that anyone can create, use and share integrations.
* Be ready for enterprise environments.


**Goals**

* Be the most open integration platform on the market.
* Become one of the most popular iPaaS solutions.
* Be a viable option for enterprises.


**Capabilities**

* **Backendless**: After creating a new Data Type using a JSON Schema is generated on the fly a complete REST API and a CRUD UI to manage the data. Useful for mobile backend and API services.

* **Routing and orchestration**: Integration flow development, monitoring, and lifecycle management tools. Enables multi-step integration flows by compose atomic functionality (such as connection, transformation, data event, schedule, webhook).

* **Data integration**: Data validation, transformation, mapping, and data quality. Exchange support for multiple formats (JSON, XML, ASN), standards (EDIFACT, X12, UBL) and protocol connectors (HTTP(S), FTP, SFTP, SCP).

* **Third party service integrations**: Directory for OpenAPI Spec (Swagger) and Shared Collections - social feature to share integration settings - to connect services as ERP / Fulfilment / Marketing / Communication.


**Data Pipelines between APIs**

It allows the creation of custom data pipelines to process, storage and move data between APIs. The flows could be trigger by data events or be scheduled.

There are now over 200 pre-built integration collections shared out the box to connect with online internet services,
fulfillment solutions, accounting, communications, ERP, multi-channels, etc.

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
* Use the rabbitmq addon: `heroku addons:create "cloudamqp:lemur"`
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

## Frameworks and Tools

* Ruby on Rails
* MongoDB
* Mongoid and Mongoff as Object Document Mapper (ODM)
* rails_admin, for build admin panel.
* RabbitMQ for internal pipeline messages.


## Create your own Cenit IO local server.

Clone the [GitHub cenit-io/cenit repo](https://github.com/cenit-io/cenit) and move to the **cenit** folder.

```
$ git clone https://github.com/cenit-io/cenit.git
$ cd cenit
```

Move to the development branch.

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

It uses Figaro gem to manage app configuration using ENV. Any of this variable is required to run a local server but maybe you consider some of them to run in the production environment

Then add to `config/application.yml` app configuration as reference review `config/application.example.yml`  

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

### Install Ruby 2.5.5 with rbenv  (alternative RVM)

```
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
exec $SHELL
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
exec $SHELL
rbenv install 2.5.5
rbenv global 2.5.5
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

First, you need to create one translator that let you import all collections and data. So, go to Transformations/Parser and select New.

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

1. Export Basic collection. In Cenit.io search Basic cross collection and select the Export option. In translator select JSON Portable Exporter [Shared].

2. Import Basic collection. In your local Cenit, go to Collections/Shared Collections/All and select Import option. There select the translator you have just created and import the collection. You can see it on Collections/Shared Collections/All.


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

### To the Community

Since the challenge is great, we have to build the solution in community. We believe that a successful open source project provides confidence, facilitates creating a broad community, where everyone can share answers to questions, suggestions, and improvements to the platform.

We encourage the community to join the initiative and contribute to the dissemination of the project, sharing integration experiences, collaborating in the detection and resolution of errors or contributing to the development of the project. We hope that those who join us enjoy the collaborative work and the challenge of achieving something innovative and useful that can potentially serve many others.


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

### Screenshots

![dashboard](https://user-images.githubusercontent.com/4213488/40578423-8b132dc6-60c8-11e8-8754-e3d4f3fa95df.png)

![flows](https://user-images.githubusercontent.com/4213488/40578271-dad7e700-60c5-11e8-9eb3-0d1b75c69461.png)

![swagger](https://user-images.githubusercontent.com/4213488/40578290-4ca8697c-60c6-11e8-979f-b953d5dfb30c.png)

![open_api_directory](https://user-images.githubusercontent.com/4213488/40578339-41b5f844-60c7-11e8-8676-26a4ee494582.png)

[numApis-image]: https://api.apis.guru/badges/apis_in_collection.svg
[numSpecs-image]: https://api.apis.guru/badges/openapi_specs.svg
[endpoints-image]: https://api.apis.guru/badges/endpoints.svg
[apisDir-link]: https://github.com/APIs-guru/openapi-directory/tree/master/APIs
[twitterFollow-image]: https://img.shields.io/twitter/follow/cenit_io.svg?style=social
[twitterFollow-link]: https://twitter.com/intent/follow?screen_name=cenit_io
[join-slack-link]:
https://join.slack.com/t/cenitio/shared_invite/enQtNzI4MDUxMTM0NzUzLTJjMWRlNmRkMzUwYTQ1NTVhOTIyZTZjODI5MGFjZjU2NTA2ZDUzOWExMjY4NDUzOTA0OGUwM2JhMTNlNWQ0ZjU
