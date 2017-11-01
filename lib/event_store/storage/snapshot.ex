defmodule EventStore.Storage.Snapshot do
  @moduledoc """
  Record serialized snapshot data.
  """

  require Logger

  alias EventStore.Snapshots.SnapshotData
  alias EventStore.Sql.Statements
  alias EventStore.Storage.Snapshot

  def read_snapshot(conn, source_uuid) do
    Snapshot.QuerySnapshot.execute(conn, source_uuid)
  end

  def record_snapshot(conn, %SnapshotData{} = snapshot) do
    Snapshot.RecordSnapshot.execute(conn, snapshot)
  end

  def delete_snapshot(conn, source_uuid) do
    Snapshot.DeleteSnapshot.execute(conn, source_uuid)
  end

  defmodule QuerySnapshot do
    def execute(conn, source_uuid) do
      conn
      |> Postgrex.query(Statements.query_get_snapshot, [source_uuid], pool: DBConnection.Poolboy)
      |> handle_response
    end

    defp handle_response({:ok, %Postgrex.Result{num_rows: 0}}) do
      {:error, :snapshot_not_found}
    end

    defp handle_response({:ok, %Postgrex.Result{rows: [row]}}) do
      {:ok, to_snapshot_from_row(row)}
    end

    defp to_snapshot_from_row([source_uuid, source_version, source_type, data, metadata, created_at]) do
      %SnapshotData{
        source_uuid: source_uuid,
        source_version: source_version,
        source_type: source_type,
        data: data,
        metadata: metadata,
        created_at: created_at
      }
    end
  end

  defmodule RecordSnapshot do
    def execute(conn, %SnapshotData{source_uuid: source_uuid, source_version: source_version, source_type: source_type, data: data, metadata: metadata}) do
      conn
      |> Postgrex.query(Statements.record_snapshot, [source_uuid, source_version, source_type, data, metadata], pool: DBConnection.Poolboy)
      |> handle_response(source_uuid, source_version)
    end

    defp handle_response({:ok, _result}, _source_uuid, _source_version) do
      :ok
    end

    defp handle_response({:error, error}, source_uuid, source_version) do
      _ = Logger.warn(fn -> "Failed to record snapshot for source \"#{source_uuid}\" at version \"#{source_version}\" due to: #{inspect error}" end)
      {:error, error}
    end
  end

  defmodule DeleteSnapshot do
    def execute(conn, source_uuid) do
      conn
      |> Postgrex.query(Statements.delete_snapshot, [source_uuid], pool: DBConnection.Poolboy)
      |> handle_response(source_uuid)
    end

    defp handle_response({:ok, _result}, _source_uuid) do
      :ok
    end

    defp handle_response({:error, error}, source_uuid) do
      _ = Logger.warn(fn -> "Failed to delete snapshot for source \"#{source_uuid}\" due to: #{inspect error}" end)
      {:error, error}
    end
  end
end
