import gleam/option.{type Option}

pub type Command {
  PING
  ECHO(content: String)
  SET(key: String, value: String, expiration: Option(Int))
  GET(key: String)
}
