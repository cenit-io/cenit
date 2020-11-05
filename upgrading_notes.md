# Upgrading process 2020

Many features have been added to the core of the Cenit project since it started in 2014 but,
most of the underlying libraries had remained tied to specific versions. 

A key underlying library is `rails_admin`, which helped to speed the project in the early beginning
by providing a fast configurable UI, easy to scale (within its own limitations) and to adapt.
However after six years, continue moving on with `rails_admin` has became very heavy and it's very
difficult to develop a user experience that meet the standards of current modern application frameworks
with JavaScript.

Been said that, the upgrading process has been divided in two parts, one is to upgrade all the
core libraries and the other is to replace `rails_admin` by a new modern UI.

## Upgrading core libraries

To understand why the upgrading process have been delayed for so long lets say that some libraries where
tied to versions for breaking features on their first time and it was'nt possible to upgrade one library without upgrading
a significant set of other. In fact by removing the `Gemfile.lock` and executing `bundle install` the bundler
was not able to find a set of compatible gems. But now the fundamental libraries, `rails` and `mongoid`, have moved
forward two major versions and upgrading the bundler itself all the dependencies are well resolved

Particularly with `rails` the project is moving from version `4` to `6` while with `mongoid` the move is from `5` to `7`.
Upgrading `rails` is always soft and two major versions is not a big deal but, the last version of `mongoid` significantly
changes the way of using _persistence options_ which is widely used by Cenit to store and retrieve records from the same
model but persisted across multiple tenants and _collections_. So looking backward it seems to be a good decision to wait
for this change.

## The new Admin App

The main goal is to replace `rails_admin` with a new modern application build on top of a modern JavaScript framework.
This should bring a better experience to users and more flexibility and capabilities for developing. A better performance
is also expected because this new _admin app_ should be deployed as a **Single Page Application** and must consume the Cenit
core only through the **API**.

The main challenge for a new UI is the same reason why `rails_admin` was chosen in the first place, and it is the 
capability to render dynamic forms based on the Cenit data type JSON Schemas. There are several packages to render and
validate forms based on schemas but, Cenit schemas have their own complexity like references between schemas and the
nature of the relations (referenced, embedded). Another complexity based on the prior experience with `rails_admin` is
that models can be recursive or being simply too large to render a complete form with all the data, so it's a requirement
for the new UI to be able to render a progressive form depending on the demanded data.

## Reviewing the upgrading process

To take a look at the the upgrade changes just checkout the upgrading branch at the Cenit main repository:

[https://github.com/cenit-io/cenit/compare/upgrading]()

To run a cenit instance with the latest upgrade changes:

1. Make sure you have a recent MongoDB server running, for instance by executing the following docker command.

    `docker run --name mongo -d -p 27017:27017 mongo:latest`

2. Make sure you have a RabbitMQ server running, for instance by executing the following docker command.

    `docker run --name rabbitmq -d -p 5672:5672 rabbitmq:latest`
    
3. Make sure you have a Redis server running, for instance by executing the following docker command.

    `docker run --name redis -d -p 6379:6379 redis:latest`
    
4. Setup the Cenit repository.

    `git clone https://github.com/cenit-io/cenit.git`
    
    `cd cenit`
    
    `git fetch origin upgrading`
    
    `git checkout upgrading`
    
5. Setup the SDK by making sure the `ruby` version is `2.5.5`. If using `rvm` then execute then execute the fallowing commands.

    `rvm install 2.5.5`
    
    `rvm gemset create @upgrading`
    
    `rvm use 2.5.5@upgrading`
    
    `gem install bundler`
    
    `bundle install`
    
6. Run Cenit

    `rails s`
    
## The new behavior

The main goal of the Cenit platform is to support development on top of an **Integration Platform**.
That been said, the Cenit platform will focus on serverless services while reducing UI to the minimum
required for start customization. The most of UX should be provided by external apps interacting with the platform
through the API.

And that's what the Admin App is, a SPA which uses the platform API to provide a UI for administration proposes.

### The default user

As part of the new upgraded behavior. A _default super admin user_ will be created the first time the platform bootstraps.
By default, the default email is `support@cenit.io` and the password is `password`. To change this just add to the file
`config/application.yml` the following entries.

```yaml
DEFAULT_USER_EMAIL: my_email@example.com
DEFAULT_USER_PASSWORD: my_secret_password
```

**Important note**: The default user creation occurs just one time per data base initialization unless there is no
super admin user when the platform is bootstrapping.