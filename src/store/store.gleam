import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import gleam/otp/actor

const timeout: Int = 5000

pub type Message {
  Get(client: Subject(Option(String)), key: String)
  Set(key: String, value: String)

  Shutdown
}

fn get_item(store: Dict(String, String), key: String) -> Option(String) {
  store
  |> dict.get(key)
  |> option.from_result
}

fn handle_message(
  message: Message,
  store: Dict(String, String),
) -> actor.Next(Message, Dict(String, String)) {
  case message {
    Shutdown -> actor.Stop(process.Normal)

    Get(client, key) -> {
      process.send(client, get_item(store, key))

      actor.continue(store)
    }

    Set(key, value) -> {
      actor.continue(dict.insert(store, key, value))
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

pub fn set(store: Subject(Message), key: String, value: String) -> Nil {
  actor.send(store, Set(key, value))
}
