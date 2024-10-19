import gleam/erlang/process.{type Subject}
import gleam/option

import messaging/command.{type Command}
import messaging/format
import store/actor.{type Message}

pub fn handle_command(store_actor: Subject(Message), command: Command) -> String {
  let message = case command {
    command.PING -> "PONG"
    command.ECHO(content) -> format.format_to_resp_string(content)
    command.GET(key) ->
      actor.get(store_actor, key)
      |> option.map(format.format_to_resp_string)
      |> option.unwrap("-1")
    command.SET(key, value, expiration) -> {
      actor.set(store_actor, key, value, expiration)

      "OK"
    }
  }

  case message {
    "OK" | "PONG" | "UNKOWN_COMMAND" -> "+" <> message <> "\r\n"
    "-1" -> "$-1\r\n"
    _ -> message
  }
}
