defmodule PromethexTest do
  use ExUnit.Case
  import Promethex

  test "test it" do
    {:ok, state} = init("test_app")
    assert state == %{prefix: "test_app", values: %{}}
    {:noreply, state} = handle_cast({:inc, "foo"}, state)
    assert state == %{prefix: "test_app", values: %{"foo" => 1}}
    {:noreply, state} = handle_cast({:inc, "bar"}, state)
    assert state == %{prefix: "test_app", values: %{"foo" => 1, "bar" => 1}}
    {:noreply, state} = handle_cast({:inc, "foo"}, state)
    assert state == %{prefix: "test_app", values: %{"foo" => 2, "bar" => 1}}

    me = self()
    :meck.expect(HTTPoison, :post, fn (url, body) ->
      send me, {:post, url, body}
    end)
    {:noreply, _state} = handle_cast(:push_to_prometheus, state)
    assert_receive {:post, url, body}

    assert url == "http://prometheus-push-gw:9091/metrics/job/test_app"
    assert body == "test_app_bar 1\ntest_app_foo 2\n"
  end

  test "test it with ctx" do
    {:ok, state} = init("test_app")
    {:noreply, state} = handle_cast({:inc, "foo", %{code: 200}}, state)
    assert state == %{prefix: "test_app", values: %{%{_name: "foo", code: 200} => 1}}
    {:noreply, state} = handle_cast({:inc, "foo", %{code: 500}}, state)
    assert state == %{prefix: "test_app", values: %{%{_name: "foo", code: 200} => 1, %{_name: "foo", code: 500} => 1}}
    {:noreply, state} = handle_cast({:inc, "foo", %{code: 200}}, state)
    assert state == %{prefix: "test_app", values: %{%{_name: "foo", code: 200} => 2, %{_name: "foo", code: 500} => 1}}

    me = self()
    :meck.expect(HTTPoison, :post, fn (url, body) ->
      send me, {:post, url, body}
    end)
    {:noreply, _state} = handle_cast(:push_to_prometheus, state)
    assert_receive {:post, url, body}

    assert url == "http://prometheus-push-gw:9091/metrics/job/test_app"
    assert body == "test_app_foo{code=\"200\"} 2\ntest_app_foo{code=\"500\"} 1\n"
  end

  test "test put" do
    {:ok, state} = init("test_app")
    assert state == %{prefix: "test_app", values: %{}}
    {:noreply, state} = handle_cast({:put, "foo", 5}, state)
    assert state == %{prefix: "test_app", values: %{"foo" => 5}}
    {:noreply, state} = handle_cast({:put, "bar", 1}, state)

    me = self()
    :meck.expect(HTTPoison, :post, fn (url, body) ->
      send me, {:post, url, body}
    end)
    {:noreply, _state} = handle_cast(:push_to_prometheus, state)
    assert_receive {:post, url, body}

    assert url == "http://prometheus-push-gw:9091/metrics/job/test_app"
    assert body == "test_app_bar 1\ntest_app_foo 5\n"
  end
end
