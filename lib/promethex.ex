defmodule Promethex do
  use GenServer

  def start_link(prefix) do
    GenServer.start_link(__MODULE__, prefix, name: __MODULE__)
  end

  @impl true
  def init(prefix) do
    spawn_link(__MODULE__, :push_metrics, [])
    {:ok, %{prefix: prefix, values: %{}}}
  end

  def inc(name) do
    GenServer.cast(__MODULE__, {:inc, name})
  end

  def inc(name, ctx) when is_list(ctx) do
    GenServer.cast(__MODULE__, {:inc, name, ctx |> Enum.into(%{})})
  end

  def inc(name, ctx) when is_map(ctx) do
    GenServer.cast(__MODULE__, {:inc, name, ctx})
  end

  def handle_cast({:inc, name}, %{values: values} = state) do
    last = Map.get(values, name, 0)
    {:noreply, put_in(state.values, Map.put(values, name, last+1))}
  end

  def handle_cast({:inc, name, ctx}, %{values: values} = state) do
    key_map = Map.put(ctx, :_name, name)
    last = Map.get(values, key_map, 0)
    {:noreply, put_in(state.values, Map.put(values, key_map, last+1))}
  end

  @impl true
  def handle_cast(:push_to_prometheus, %{values: values, prefix: prefix} = state) do
    body =
      values
      |> Enum.map(fn
        {k, v} when is_binary(k) ->
          "#{prefix}_#{k} #{v}"
        {%{_name: name} = k, v} when is_map(k) ->
          params =
            k
            |> Map.delete(:_name)
            |> Enum.map(fn {k, v} -> "#{k}=\"#{v}\"" end)
            |> Enum.join(",")
          "#{prefix}_#{name}{#{params}} #{v}"
      end)
      |> Enum.join("\n")
    body = body <> "\n"
    HTTPoison.post("#{prometheus_url}/metrics/job/#{prefix}", body)
    |> case do
      {:ok, %{status_code: code}} when code >= 300 ->
        IO.puts "ERROR PUSHING TO PROMETHEUS: status-code = #{code}"
      {:error, %{reason: reason}} ->
        IO.puts "ERROR PUSHING TO PROMETHEUS: reason = #{reason}"
      _ ->
        :ok
    end

    {:noreply, state}
  end

  def prometheus_url() do
    System.get_env("PROMETHEUS_URL") || "http://prometheus:9091"
  end

  def push_metrics() do
    :timer.sleep(1000 * 60) # wait 60 seconds
    GenServer.cast(__MODULE__, :push_to_prometheus)
    push_metrics()
  end
end
