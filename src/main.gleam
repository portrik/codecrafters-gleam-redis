import gleam/bytes_builder
import gleam/io

import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor.{type Next}
import glisten.{type Connection, type Message}

pub fn main() {
  let assert Ok(_) =
    glisten.handler(fn(_connection) { #(Nil, None) }, response_handler)
    |> glisten.serve(6379)

  process.sleep_forever()
}

fn response_handler(
  _message: Message(a),
  state: Nil,
  connection: Connection(a),
) -> Next(Message(a), Nil) {
  io.println("Received message!")

  let assert Ok(_) =
    connection
    |> glisten.send(bytes_builder.from_string("+PONG\r\n"))

  actor.continue(state)
}
