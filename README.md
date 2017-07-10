This is sensu-plugin-signifai, a sensu event handler for submitting your
metrics to SignifAi via the REST API. 

Installation
============

Assuming you have [installed Sensu for your platform]
(https://sensuapp.org/docs/latest/installation/), you should be able
to `git clone git@github.com:SignifAi/sensu-plugin-signifai`. Once
you've pulled the repository, if you elect to use the "embedded" Ruby
that comes with Sensu, you may want to (at least temporarily) add their
Ruby to your PATH:

```
export EMBEDDED_RUBY="true"
export PATH="/opt/sensu/embedded/bin:$PATH"
```

Whether you've done this or not, you will need to install dependencies (note
that you will need the `bundler` gem if you are using your system's native
Ruby):

```
bundle install
```

And it's always a safe bet to run tests:

```
bundle exec rake default
```

If the tests are okay (or you're sure you don't require them to run), you can
build the gem:

```
gem build sensu-plugin-signifai.gemspec
```

And on success, you can install it:

```
sudo -E gem install ./sensu-plugin-signifai-1.0.0.gem
```

`which handler-signifai.rb` should give you a valid path now. 

Configuration
=============

The Signifai event handler is what Sensu calls a 'pipe' handler type, and you
will need to configure it before it will forward events for you.

Write out a file, /etc/sensu/conf.d/signifai.json , that looks like this:

```
{
  "handlers": {
    "signifai": {
      "type": "pipe",
      "filter": "state_change_only",
      "command": "/opt/sensu/embedded/bin/handler-signifai.rb"
    }
  },
  "signifai": {
    "api_key": "YOUR_API_KEY"
  },
  "sensu_plugin": {
    "disable_deprecated_filtering": true
  },
  "filters": {
    "state_change_only": {
      "negate": false,
      "attributes": {
        "occurrences": "eval: value == 1 || ':::action:::' == 'resolve'"
      }
    }
  }
}
```

If you don't want to add the sensu_plugin setting because you are currently
relying on the deprecated filtering ([more information]
(https://blog.sensuapp.org/deprecating-event-filtering-in-sensu-plugin-b60c7c500be3))
you can, instead, set the `"enable_deprecated_filtering": false` per-check. 

For any check whose results you want to forward to signifai, refer to this
example:


```
{
  "checks": {
    "sleep": {
      "command": "/opt/sensu/embedded/bin/check-process.rb -p sleep",
      "subscribers": ["dev-sensu"],
      "handlers": ["signifai"],
      "interval": 60
    }
  }
}
```

You can use either the `handler` attribute with just the string `"signifai"`
or you can use `handlers` with `"signifai"` alongside any other handlers you
may need. 
