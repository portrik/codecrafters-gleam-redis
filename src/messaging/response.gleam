import gleam/erlang/process.{type Subject}
import gleam/option

import configuration/configuration.{type Message as ConfigurationMessage}
import messaging/command.{type Command}
import messaging/format
import store/store.{type Message as StoreMessage}

pub fn handle_command(
  store store_subject: Subject(StoreMessage),
  configuration configuration_subject: Subject(ConfigurationMessage),
  command command: Command,
) -> String {
  let message = case command {
    command.Ping -> "PONG"
    command.Echo(content) -> format.format_to_resp_string(content)
    command.Get(key) ->
      store.get(store_subject, key)
      |> option.map(format.format_to_resp_string)
      |> option.unwrap("-1")
    command.Set(key, value, expiration) -> {
      store.set(store_subject, key, value, expiration)

      "OK"
    }
    command.Config(command.ConfigRead, key) -> {
      let value =
        key
        |> configuration.get(configuration_subject, _)
        |> option.unwrap("-1")

      let key = format.configuration_key_to_string(key)

      format.format_to_resp_array([key, value])
    }
  }

  case message {
    "OK" | "PONG" | "UNKNOWN" -> "+" <> message <> "\r\n"
    "-1" -> "$-1\r\n"
    _ -> message
  }
}
