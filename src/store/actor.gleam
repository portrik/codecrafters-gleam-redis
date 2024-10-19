import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import gleam/otp/actor

import store/store.{type Record}

const timeout: Int = 5000

pub type Message {
  Get(client: Subject(Option(String)), key: String)
  Set(key: String, value: String, expiration: Option(Int))

  Shutdown
}

fn handle_message(
  message: Message,
  store: Dict(String, Record),
) -> actor.Next(Message, Dict(String, Record)) {
  case message {
    Shutdown -> actor.Stop(process.Normal)

    Get(client, key) -> {
      let #(store, value) = store.get_item(store, key)
      process.send(client, value)

      actor.continue(store)
    }

    Set(key, value, expiration) -> {
      let store =
        store
        |> store.set_item(key, value, expiration)

      actor.continue(store)
    }
  }
}

pub fn new() -> Result(Subject(Message), actor.StartError) {
  actor.start(dict.new(), handle_message)
}

pub fn close(store: Subject(Message)) -> Nil {
  actor.send(store, Shutdown)
}

pub fn get(store: Subject(Message), key: String) -> Option(String) {
  actor.call(store, Get(_, key), timeout)
}

pub fn set(
  store: Subject(Message),
  key: String,
  value: String,
  expiration: Option(Int),
) -> Nil {
  actor.send(store, Set(key, value, expiration))
}
