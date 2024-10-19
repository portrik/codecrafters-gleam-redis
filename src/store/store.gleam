import birl/duration
import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/order

import birl.{type Time}

pub type Record {
  Record(value: String, created_at: Time, expires_at: Option(Time))
}

pub fn get_item(
  store: Dict(String, Record),
  key: String,
) -> #(Dict(String, Record), Option(String)) {
  let assert option.Some(value) =
    store
    |> dict.get(key)
    |> option.from_result

  case value.expires_at {
    option.None -> #(store, option.Some(value.value))
    option.Some(expires_at) ->
      case birl.compare(birl.now(), expires_at) {
        order.Lt -> #(store, option.Some(value.value))
        _ -> #(dict.delete(store, key), option.None)
      }
  }
}

pub fn set_item(
  store: Dict(String, Record),
  key: String,
  value: String,
  expiration: Option(Int),
) -> Dict(String, Record) {
  let created_at = birl.now()

  let expires_at = case expiration {
    option.None -> option.None
    option.Some(value) ->
      value
      |> duration.milli_seconds
      |> birl.add(created_at, _)
      |> option.Some
  }

  store
  |> dict.insert(key, Record(value, created_at, expires_at))
}
