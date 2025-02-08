import gleam/bit_array
import gleam/int
import gleam/result

import mug.{type Socket}

import messaging/format

const timeout = 5000

pub type MasterConnectionError {
  UnableToConnect
  PingFailed
  ConfirmationFailed
}

type MasterSocket(state) {
  MasterSocket(socket: Socket)
}

type MasterSocketPing {
  MasterSocketPing
}

type MasterSocketConfirmation {
  MasterSocketConfirmation
}

type MasterSocketSynchronize {
  MasterSocketSynchronize
}

fn send_ping(
  socket: MasterSocket(MasterSocketPing),
) -> Result(MasterSocket(MasterSocketConfirmation), MasterConnectionError) {
  let ping =
    ["PING"]
    |> format.format_to_resp_array
    |> bit_array.from_string

  use _nil_result <- result.try(
    socket.socket
    |> mug.send(ping)
    |> result.replace_error(UnableToConnect),
  )

  use _ping_response <- result.try(
    socket.socket
    |> mug.receive(timeout)
    |> result.replace_error(UnableToConnect),
  )

  let socket: MasterSocket(MasterSocketConfirmation) =
    MasterSocket(socket.socket)

  Ok(socket)
}

fn send_confirmation(
  socket: MasterSocket(MasterSocketConfirmation),
  listening_port: Int,
) -> Result(MasterSocket(MasterSocketSynchronize), MasterConnectionError) {
  let listening_port_message =
    ["REPLCONF", "listening-port", int.to_string(listening_port)]
    |> format.format_to_resp_array
    |> bit_array.from_string

  use _nil_result <- result.try(
    socket.socket
    |> mug.send(listening_port_message)
    |> result.replace_error(ConfirmationFailed),
  )

  use _port_response <- result.try(
    socket.socket
    |> mug.receive(timeout)
    |> result.replace_error(ConfirmationFailed),
  )

  let capabilities_message =
    ["REPLCONF", "capa", "psync2"]
    |> format.format_to_resp_array
    |> bit_array.from_string

  use _nil_result <- result.try(
    socket.socket
    |> mug.send(capabilities_message)
    |> result.replace_error(ConfirmationFailed),
  )

  use _capabilities_response <- result.try(
    socket.socket
    |> mug.receive(timeout)
    |> result.replace_error(ConfirmationFailed),
  )

  let socket: MasterSocket(MasterSocketSynchronize) =
    MasterSocket(socket.socket)

  Ok(socket)
}

fn send_synchronization(
  _socket: MasterSocket(MasterSocketSynchronize),
) -> Result(Nil, MasterConnectionError) {
  Ok(Nil)
  // TODO
}

pub fn connect_to_master(
  master_hostname: String,
  master_port: Int,
  listening_port: Int,
) -> Result(Nil, MasterConnectionError) {
  let connection_options = mug.new(master_hostname, master_port)
  use ping_socket: MasterSocket(MasterSocketPing) <- result.try(
    connection_options
    |> mug.connect
    |> result.map(MasterSocket)
    |> result.replace_error(UnableToConnect),
  )

  use confirmation_socket <- result.try(send_ping(ping_socket))
  use synchronization_socket <- result.try(send_confirmation(
    confirmation_socket,
    listening_port,
  ))

  send_synchronization(synchronization_socket)
}
