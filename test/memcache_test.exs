defmodule MemcacheTest do
  use ExUnit.Case, async: false
  import TestUtils

  doctest Memcache

  def append_prepend(pid) do
    assert { :ok } = Memcache.flush(pid)
    assert { :ok } == Memcache.set(pid, "hello", "world")
    assert { :ok } == Memcache.append(pid, "hello", "!")
    assert { :ok, "world!" } == Memcache.get(pid, "hello")
    assert { :ok } == Memcache.prepend(pid, "hello", "!")
    assert { :ok, "!world!" } == Memcache.get(pid, "hello")
    cas_error = { :error, "Key exists" }

    assert { :ok, cas } = Memcache.set(pid, "new", "new ", [cas: true])
    assert { :ok } == Memcache.append_cas(pid, "new", "hope", cas)
    assert cas_error == Memcache.append_cas(pid, "new", "hope", cas)
    assert { :ok, _cas } = Memcache.append(pid, "new", "hope", [cas: true])
    assert { :ok, "new hopehope"} == Memcache.get(pid, "new")
    assert { :ok, cas } = Memcache.set(pid, "new", "hope", [cas: true])
    assert { :ok } == Memcache.prepend_cas(pid, "new", "new ", cas)
    assert cas_error == Memcache.prepend_cas(pid, "new", "new ", cas)
    assert { :ok, _cas } = Memcache.prepend(pid, "new", "new ", [cas: true])
    assert { :ok } = Memcache.flush(pid)
  end

  def common(pid) do
    assert { :ok } = Memcache.flush(pid)
    assert { :ok } == Memcache.set(pid, "hello", "world")
    assert { :ok, "world" } == Memcache.get(pid, "hello")
    assert { :error, "Key exists" } == Memcache.add(pid, "hello", "world")
    assert { :ok } == Memcache.replace(pid, "hello", "again")
    assert { :ok } == Memcache.delete(pid, "hello")
    assert { :error, "Key not found" } == Memcache.replace(pid, "hello", "world")
    assert { :error, "Key not found" } == Memcache.get(pid, "hello")
    assert { :error, "Key not found" } == Memcache.delete(pid, "hello")
    assert { :ok } == Memcache.add(pid, "hello", "world")
    assert { :ok, 3 } == Memcache.incr(pid, "count", by: 5, default: 3)
    assert { :ok, 8 } == Memcache.incr(pid, "count", by: 5)
    assert { :ok, 3 } == Memcache.decr(pid, "count", by: 5)
    assert { :ok } == Memcache.delete(pid, "count")
    assert { :ok, 0 } == Memcache.decr(pid, "count", by: 5, default: 0)
    assert { :ok, 5 } == Memcache.incr(pid, "count", by: 5)
    assert { :ok, 4 } == Memcache.decr(pid, "count")
    assert { :ok, 2 } == Memcache.decr(pid, "count", by: 2)
    assert { :ok, _hash } = Memcache.stat(pid)
    assert { :ok, _settings } = Memcache.stat(pid, "settings")
    assert { :ok, _version } = Memcache.version(pid)

    cas_error = { :error, "Key exists" }
    assert { :ok } == Memcache.flush(pid)
    assert { :error, "Key not found" } == Memcache.get(pid, "unknown", [cas: true])
    assert { :ok, cas } = Memcache.set(pid, "hello", "world", [cas: true])
    assert is_integer(cas)
    assert { :ok, cas } = Memcache.set_cas(pid, "hello", "world", cas, [cas: true])
    assert { :ok } == Memcache.set(pid, "hello", "another")
    assert cas_error == Memcache.set_cas(pid, "hello", "world", cas, [cas: true])
    assert { :ok, "another", cas } = Memcache.get(pid, "hello", [cas: true])
    assert { :ok, _cas } = Memcache.set_cas(pid, "hello", "world", cas, [cas: true])
    assert { :ok } == Memcache.set(pid, "hello", "move on")
    assert { :ok, "move on" } == Memcache.get(pid, "hello")
    assert { :ok, cas } = Memcache.add(pid, "add", "world", [cas: true])
    assert { :ok } == Memcache.delete_cas(pid, "add", cas)
    assert { :ok } == Memcache.add(pid, "add", "world")
    assert cas_error == Memcache.delete_cas(pid, "add", cas)
    assert { :ok, cas } = Memcache.replace(pid, "add", "world", [cas: true])
    assert { :ok } == Memcache.replace_cas(pid, "add", "world", cas)
    assert cas_error == Memcache.replace_cas(pid, "add", "world", cas)
    assert cas_error == Memcache.delete_cas(pid, "add", cas)
    assert { :ok, "world", cas } = Memcache.get(pid, "add", [cas: true])
    assert { :ok } == Memcache.delete_cas(pid, "add", cas)
    assert { :ok, 5, cas } = Memcache.incr(pid, "count", [by: 1, default: 5, cas: true])
    assert { :ok, 6 } == Memcache.incr(pid, "count", [by: 1, default: 5])
    assert cas_error == Memcache.incr_cas(pid, "count", cas, [by: 5, default: 1])
    assert { :ok } == Memcache.delete(pid, "count")
    assert { :ok, 5, cas } = Memcache.decr(pid, "count", [by: 1, default: 5, cas: true])
    assert { :ok, 4 } == Memcache.decr_cas(pid, "count", cas, [by: 1, default: 5])
    assert cas_error == Memcache.decr_cas(pid, "count", cas, [by: 6, default: 5])
    assert { :ok } == Memcache.delete(pid, "count")
    assert { :ok } == Memcache.flush(pid)

    assert { :ok } = Memcache.noop(pid)
    assert { :ok } = Memcache.flush(pid)
  end

  def multi(pid) do
    assert { :ok } = Memcache.flush(pid)
    assert { :ok } == Memcache.set(pid, "a", "1")
    assert { :ok } == Memcache.set(pid, "b", "2")
    assert { :ok, %{"a" => "1", "b" => "2"}} == Memcache.multi_get(pid, ["a", "b"])
    assert { :ok, %{"a" => "1", "b" => "2"}} == Memcache.multi_get(pid, ["a", "c", "b"])
    assert { :ok, %{"a" => {"1", _}, "b" => {"2", _}}} = Memcache.multi_get(pid, ["a", "b"], [cas: true])
    assert { :ok, %{"a" => {"1", _}, "b" => {"2", _}}} = Memcache.multi_get(pid, ["a", "c", "b"], [cas: true])
    assert { :ok, %{}} == Memcache.multi_get(pid, ["c"])
    assert { :ok, %{"a" => "1"}} == Memcache.multi_get(pid, ["a"])
  end

  test "commands" do
    assert { :ok, pid } = Memcache.start_link()
    common(pid)
    append_prepend(pid)
    multi(pid)
    assert { :ok } = Memcache.stop(pid)
  end

  test "cas" do
    assert { :ok, pid } = Memcache.start_link()
    assert { :ok } == Memcache.set(pid, "counter", "0")
    increment = fn () ->
      Enum.each(1..100, fn (_) ->
        Memcache.cas(pid, "counter", &(Integer.to_string(String.to_integer(&1) + 1)))
      end)
    end
    task_a = Task.async(increment)
    task_b = Task.async(increment)
    task_c = Task.async(increment)
    Task.await(task_a)
    Task.await(task_b)
    Task.await(task_c)

    assert { :ok, "300" } == Memcache.get(pid, "counter")
    assert { :ok } = Memcache.stop(pid)
  end

  test "expire" do
    assert { :ok, pid } = Memcache.start_link()
    assert { :ok } == Memcache.flush(pid)

    assert { :ok } == Memcache.set(pid, "set", "world", ttl: 1)
    assert { :ok } == Memcache.set(pid, "replace", "world")
    assert { :ok } == Memcache.replace(pid, "replace", "world", ttl: 1)
    assert { :ok } == Memcache.add(pid, "add", "world", ttl: 1)
    assert { :ok, 5 } == Memcache.incr(pid, "incr", default: 5, ttl: 1)
    assert { :ok, 5 } == Memcache.decr(pid, "decr", default: 5, ttl: 1)

    :timer.sleep(2000)

    assert { :error, "Key not found" } == Memcache.get(pid, "set")
    assert { :error, "Key not found" } == Memcache.get(pid, "replace")
    assert { :error, "Key not found" } == Memcache.get(pid, "add")
    assert { :error, "Key not found" } == Memcache.get(pid, "incr")
    assert { :error, "Key not found" } == Memcache.get(pid, "decr")

    assert { :ok } == Memcache.set(pid, "hello", "world")
    assert { :ok } == Memcache.flush(pid, ttl: 2)
    assert { :ok, "world" } == Memcache.get(pid, "hello")

    :timer.sleep(3000)

    assert { :error, "Key not found" } == Memcache.get(pid, "hello")
    assert { :ok } = Memcache.stop(pid)
  end

  test "namespace" do
    assert { :ok, namespaced } = Memcache.start_link([namespace: "app"])
    assert { :ok, pid } = Memcache.start_link()
    assert { :ok } = Memcache.flush(pid)
    assert { :ok } == Memcache.set(namespaced, "hello", "world")
    assert { :error, "Key not found" } == Memcache.get(pid, "hello")
    assert { :ok, "world" } == Memcache.get(namespaced, "hello")
    assert { :ok, "world" } == Memcache.get(pid, "app:hello")
    assert { :ok } == Memcache.delete(namespaced, "hello")
    assert { :error, "Key not found" } == Memcache.get(namespaced, "hello")
    assert { :ok } = Memcache.flush(pid)
    assert { :ok } = Memcache.stop(pid)

    common(namespaced)
    append_prepend(namespaced)
    multi(namespaced)
    assert { :ok } = Memcache.stop(namespaced)
  end

  test "default ttl" do
    assert { :ok, pid } = Memcache.start_link([ttl: 1])
    assert { :ok } == Memcache.flush(pid)

    assert { :ok } == Memcache.set(pid, "set", "world")
    assert { :ok } == Memcache.set(pid, "replace", "world")
    assert { :ok } == Memcache.replace(pid, "replace", "world")
    assert { :ok } == Memcache.add(pid, "add", "world")
    assert { :ok, 5 } == Memcache.incr(pid, "incr", default: 5)
    assert { :ok, 5 } == Memcache.decr(pid, "decr", default: 5)

    :timer.sleep(2000)

    assert { :error, "Key not found" } == Memcache.get(pid, "set")
    assert { :error, "Key not found" } == Memcache.get(pid, "replace")
    assert { :error, "Key not found" } == Memcache.get(pid, "add")
    assert { :error, "Key not found" } == Memcache.get(pid, "incr")
    assert { :error, "Key not found" } == Memcache.get(pid, "decr")

    common(pid)
    assert { :ok } = Memcache.stop(pid)
  end

  test "server and connection are linked" do
    assert_exit(fn ->
      assert { :ok, server } = Memcache.start_link()
      connection = Memcache.connection_pid(server)
      Process.exit(connection, :kill)
    end, :killed)
  end

  test "erlang coder" do
    assert { :ok, pid } = Memcache.start_link([coder: Memcache.Coder.Erlang])
    common(pid)

    assert { :ok } == Memcache.set(pid, "hello", ["list", 1])
    assert { :ok, ["list", 1] } == Memcache.get(pid, "hello")
    assert { :ok, %{"hello" => ["list", 1]} } == Memcache.multi_get(pid, ["hello"])
    assert { :ok } = Memcache.stop(pid)

    assert { :ok, pid } = Memcache.start_link([coder: {Memcache.Coder.Erlang, [compressed: 9]}])
    assert { :ok } == Memcache.set(pid, "hello", ["list", 1])
    assert { :ok, ["list", 1] } == Memcache.get(pid, "hello")
    assert { :ok } = Memcache.stop(pid)
  end

  test "json coder" do
    assert { :ok, pid } = Memcache.start_link([coder: Memcache.Coder.JSON])
    common(pid)

    assert { :ok } == Memcache.set(pid, "hello", ["list", 1])
    assert { :ok, ["list", 1] } == Memcache.get(pid, "hello")
    assert { :ok } == Memcache.set(pid, "hello", %{ "a" => 1 })
    assert { :ok, %{ "a" => 1 } } == Memcache.get(pid, "hello")
    assert { :ok, %{"hello" => %{ "a" => 1 }} } == Memcache.multi_get(pid, ["hello"])
    assert { :ok } = Memcache.stop(pid)

    assert { :ok, pid } = Memcache.start_link([coder: {Memcache.Coder.JSON, [keys: :atoms]}])
    assert { :ok } == Memcache.set(pid, "hello", %{hello: "world"})
    assert { :ok, %{hello: "world"} } == Memcache.get(pid, "hello")
    assert { :ok } = Memcache.stop(pid)
  end

  test "zip coder" do
    assert { :ok, pid } = Memcache.start_link([coder: Memcache.Coder.ZIP])
    common(pid)
    assert { :ok } = Memcache.stop(pid)
  end
end
