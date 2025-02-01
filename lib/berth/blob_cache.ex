defmodule Berth.BlobCache do
  @moduledoc """
  Blob cache with limited size. Keep data in ETS with fast blobs reads.

  To start cache process use
  ```
  {:ok, _pid} = BlobCache.start_link(max_size: <maximum total memory for all blobs in bytes>)
  ```
  """

  use GenServer

  @ets_table :blob_cache
  @default_max_size 52428800 # 50 MBytes

  @doc """
  Start internal GenServer witch creates ETS table for blobs
  opts:
    :max_size - maximum cache size in bytes, default 50 MBytes
  """
  def start_link(opts \\ []) do
    max_size = Keyword.get(opts, :max_size, @default_max_size)
    GenServer.start_link(__MODULE__, %{max_size: max_size, current_size: 0, counter: 0}, name: __MODULE__)
  end

  @doc """
  Put blob in given bucket with blob's ID.
  If adding this blob overflow cache's data size, most old blobs will be deleted to make a room for a new one.
  Returns:
    :ok - blob was added to cache
    :error - blob is larger than :max_size value given in start_link/1.
  """
  def put(bucket, id, blob) do
    GenServer.call(__MODULE__, {:put, make_key(bucket, id), blob})
  end

  @doc """
  Get blob from given bucket with blob's ID
  """
  def get(bucket, id) do
    key = make_key(bucket, id)
    case :ets.lookup(@ets_table, key) do
      [{^key, blob, _counter, _size}] ->
        GenServer.cast(__MODULE__, {:count, key})
        {:ok, blob}

      _ -> :error
    end
  end

  @doc """
  Delete blob from cache
  """
  def delete(bucket, id) do
    GenServer.call(__MODULE__, {:delete, make_key(bucket, id)})
  end

  # Combine bucket and ID in one string to use one ETS table for different blobs types.
  defp make_key(bucket, id) do
    bucket <> id
  end

  #---- GenServer callbacks

  def init(state) do
    #NOTE: we use named table for simple access to it in get/2 and do not keep table ID in state.
    #      We have much more reads than writes so read_concurrency set to true.
    :ets.new(@ets_table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, state}
  end

  # PUT blob
  def handle_call({:put, key, blob}, _from, state) do
    blob_size = byte_size(blob)

    if blob_size > state.max_size do
      {:reply, :error, state}
    else
      new_state = ensure_space(blob_size, state)
      :ets.insert(@ets_table, {key, blob, new_state.counter, blob_size})
      {:reply, :ok, %{new_state | current_size: new_state.current_size + blob_size, counter: new_state.counter + 1}}
    end
  end

  # DELETE blob
  def handle_call({:delete, key}, _from, state) do
    case :ets.lookup(@ets_table, key) do
      [{^key, _blob, _counter, size}] ->
        :ets.delete(@ets_table, key)
        {:reply, :ok, %{state | current_size: state.current_size - size}}

      _ -> {:reply, :error, state}
    end
  end

  # COUNT -- update blob counter to a fresh one to protect blob from deletion
  def handle_cast({:count, key}, state) do
    new_count = state.counter + 1
    :ets.update_element(@ets_table, key, {3, new_count})  # tuples in Erlang counts from 1, counter's index is 3
    {:noreply, %{state | counter: new_count}}
  end

  # Check if we have enough space for a new blob and delete old blobs to have blob_size room
  defp ensure_space(blob_size, state) do
    if state.current_size + blob_size > state.max_size do
      keys = :ets.tab2list(@ets_table)
             |> Enum.sort_by(fn {_key, _blob, counter, _size} -> counter end)

      free_space(blob_size, keys, state)
    else
      state
    end
  end

  defp free_space(_needed, [], state), do: state

  defp free_space(needed, [{key, _blob, _counter, size} | rest], state) do
    if state.current_size + needed <= state.max_size do
      state
    else
      :ets.delete(@ets_table, key)
      free_space(needed, rest, %{state | current_size: state.current_size - size})
    end
  end

end
