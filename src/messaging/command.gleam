import gleam/option.{type Option}

import configuration/configuration.{type ConfigurationKey}

pub type ConfigAction {
  ConfigRead
}

pub type Command {
  Ping
  Echo(content: String)
  Set(key: String, value: String, expiration: Option(Int))
  Get(key: String)

  Config(action: ConfigAction, key: ConfigurationKey)
}
