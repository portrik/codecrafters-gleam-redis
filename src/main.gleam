import gleam/bytes_builder
import gleam/io

import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor.{type Next}
import glisten.{type Connection, type Message}

import resp/command.{type Command}

pub fn main() {
  let assert Ok(_) =
    glisten.handler(fn(_connection) { #(Nil, None) }, response_handler)
    |> glisten.serve(6379)

  process.sleep_forever()
}

fn choose_response(command: Command) -> String {
  case command {
    command.PING -> "PONG"
    command.ECHO(content) -> content
  }
}

fn response_handler(
  message: Message(a),
  state: Nil,
  connection: Connection(a),
) -> Next(Message(a), Nil) {
  io.println("Received message!")

  let response = case command.parse_bulk_message(message) {
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
