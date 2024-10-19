import gleam/bit_array
import gleam/bytes_builder
import gleam/io
import gleam/string

import gleam/erlang/process
import gleam/option.{type Option, None}
import gleam/otp/actor.{type Next}
import glisten.{type Connection, type Message, Packet}

type Command {
  PING
}

pub fn main() {
  let assert Ok(_) =
    glisten.handler(fn(_connection) { #(Nil, None) }, response_handler)
    |> glisten.serve(6379)

  process.sleep_forever()
}

fn parse_message(message: Message(a)) -> Option(Command) {
  let message = case message {
    Packet(message) ->
      message
      |> bit_array.to_string
      |> option.from_result
    _ -> option.None
  }

  case message {
    option.None -> option.None
    option.Some(message) ->
      case string.trim(message) {
        "*1\r\n$4\r\nPING" -> option.Some(PING)
        _ -> option.None
      }
  }
}

fn choose_response(command: Command) -> String {
  case command {
    PING -> "PONG"
  }
}

fn response_handler(
  message: Message(a),
  state: Nil,
  connection: Connection(a),
) -> Next(Message(a), Nil) {
  io.println("Received message!")

  let message =
    message
    |> parse_message

  let response = case message {
    option.None -> "UKNOWN_COMMAND"
    option.Some(command) ->
      command
      |> choose_response
  }

  let assert Ok(_) =
    connection
    |> glisten.send(bytes_builder.from_string("+" <> response <> "\r\n"))

  actor.continue(state)
}
