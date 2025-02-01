defmodule Berth.BlobCacheTest do
  use ExUnit.Case

  alias Berth.BlobCache
  import Bitwise

  @moduletag :capture_log

  setup do
    # start our own BlobCache process with custom test opts
    {:ok, _pid} = BlobCache.start_link(max_size: 10000)
    :ok
  end

  defp make_bytes(size) do
    for i <- 1..size, into: <<>>, do: <<i &&& 0xFF>>
  end

  test "put and get blob" do
    blob = make_bytes(1000)

    assert :ok == BlobCache.put("b1", "key1", blob)
    assert {:ok, ^blob} = BlobCache.get("b1", "key1")
  end

  test "delete blob" do
    blob = make_bytes(500)

    assert :ok == BlobCache.put("b2", "key2", blob)
    assert {:ok, ^blob} = BlobCache.get("b2", "key2")

    assert :ok == BlobCache.delete("b2", "key2")
    assert :error == BlobCache.get("b2", "key2")
  end

  test "delete old blobs, no free space" do
    small_blob = make_bytes(3000)
    big_blob = make_bytes(8000)  # will replace small_blob

    assert :ok == BlobCache.put("b1", "small", small_blob)
    assert :ok == BlobCache.put("b1", "big", big_blob)

    assert :error == BlobCache.get("b1", "small")  # should be deleted
    assert {:ok, ^big_blob} = BlobCache.get("b1", "big")
  end

  test "check oldest blobs deletion" do
    b1 = make_bytes(2000)
    b2 = make_bytes(2000)
    b3 = make_bytes(2000)
    b4 = make_bytes(5000)
    last = make_bytes(3000)

    assert :ok == BlobCache.put("b", "b1", b1)
    assert :ok == BlobCache.put("b", "b2", b2)
    assert :ok == BlobCache.put("b", "b3", b3)

    assert {:ok, ^b1} = BlobCache.get("b", "b2")
    assert {:ok, ^b2} = BlobCache.get("b", "b2")
    assert {:ok, ^b3} = BlobCache.get("b", "b3")

    # push out b1
    assert :ok == BlobCache.put("b", "b4", b4)
    assert :error == BlobCache.get("b", "b1")
    assert {:ok, ^b2} = BlobCache.get("b", "b2")
    assert {:ok, ^b3} = BlobCache.get("b", "b3")
    assert {:ok, ^b4} = BlobCache.get("b", "b4")

    # touch b2, it should be became more "new" comparing b3
    assert {:ok, ^b2} = BlobCache.get("b", "b2")

    assert :ok == BlobCache.put("b", "last", last)
    assert {:ok, ^b2} = BlobCache.get("b", "b2")  # b2 was kept, touched later than b3
    assert :error == BlobCache.get("b", "b3")     # b3 was first used, deleted
    assert {:ok, ^b4} = BlobCache.get("b", "b4")
    assert {:ok, ^last} = BlobCache.get("b", "last")
  end

  test "too big blob" do
    large_blob = make_bytes(11000) # more than limit of 10000 bytes

    assert :error == BlobCache.put("apples", "huge", large_blob)
    assert :error == BlobCache.get("apples", "huge")
  end

  test "delete unknown blob" do
    assert :error == BlobCache.delete("star", "nonexistent")
  end

end
