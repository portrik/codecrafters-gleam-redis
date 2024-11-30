import gleam/option.{type Option}

import birl.{type Time}
import configuration/configuration.{
  type ConfigurationKeyString, type ConfigurationKeyStringTupleList,
}

pub type ConfigAction {
  ConfigRead
}

pub type Command {
  Ping
  Echo(content: String)
  Set(key: String, value: String, expiration: Option(Time))
  Get(key: String)
  Keys(pattern: String)

  Config(action: ConfigAction, key: ConfigurationKeyString)
  Info(value: ConfigurationKeyStringTupleList)
}
