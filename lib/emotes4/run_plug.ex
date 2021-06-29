defmodule Emotes4.WebApplication do
  use Plug.Router

  # Sources for everything
  # https://dev.to/jonlunsford/elixir-building-a-small-json-endpoint-with-plug-cowboy-and-poison-1826
  # https://elixirschool.com/en/lessons/specifics/plug/

  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(Plug.Parsers, parsers: [:json, :multipart], pass: ["*/*"], json_decoder: Poison)
  plug(:dispatch)

  get "/" do
    conn |> send_resp(200, json(%{hello: "world"}))
  end

  post "/api/emotes" do
    # special handler since resizing and all that good stuff

    # NOTE you can't update an emote. Just delete and re-upload. This is by design.

    # Get data

    # We have to do this since multipart is the only way to upload a file. Maybe I should use GraphQL next time.
    data = Poison.decode(conn.body_params["data"])
    # IO.puts(data)

    # Important pieces of data: folder (string), emote_file, emote_name

    {status, resp} =
      case Poison.decode(conn.body_params["data"]) do
        {:ok, data} ->
          case data do
            %{"folder" => folder, "emote_name" => emote_name} ->
              IO.puts("received all the important JSON data")
              IO.puts(inspect(conn.body_params["emote_file"]))

              emote_file = conn.body_params["emote_file"]

              case emote_file do
                %Plug.Upload{} ->
                  # TODO verify the mimetype
                  # TODO run the ffmpeg pipeline here and throw it in the db
                  {200, err("uploaded")}

                _ ->
                  {400, err("Missing 'emote_file'. Please upload a valid file.")}
              end

            _ ->
              # TODO be more specific
              {400, err("Missing fields of 'folder,' or 'emote_name'")}
          end

        {:error, _, _} ->
          {400, err("Malformed JSON data")}
      end

    conn |> send_resp(status, resp)
  end

  # Create or update
  post "/api/:resource" do
    module =
      case resource do
        "folder" -> Emotes4.Folder
        "user" -> Emotes4.User
        # Will require a bit of logic
        "user_key" -> Emotes4.UserKey
        _ -> nil
      end

    if module do
      {status, body} =
        case conn.body_params do
          %{"id" => i} when i == -1 ->
            # Create event
            IO.puts("creating object")

            {:ok, insert_item} =
              Poison.decode(Poison.encode!(conn.body_params), as: struct(module))

            insert_item = Map.delete(insert_item, :id)
            insert_item = %{insert_item | create_time: DateTime.utc_now(), update_time: nil}

            IO.puts(inspect(insert_item))

            case insert_item |> module.validate() do
              {:ok} ->
                {200,
                 json(
                   Memento.transaction!(fn ->
                     return = Memento.Query.write(insert_item)
                     IO.puts(inspect(return))
                     return
                   end)
                 )}

              {:missing_fields, missing_fields} ->
                IO.puts("failure")
                {400, missing(missing_fields)}
            end

          %{"id" => i} ->
            # Update event
            IO.puts("updating object")

            item = Memento.transaction!(fn -> Memento.Query.read(module, i) end)

            case item do
              nil ->
                {400, err("Object to update was not found")}

              # This seems a bit dangerous since there might be other outputs
              _ ->
                # Merge all the data from the params
                item =
                  struct(
                    module,
                    Enum.into(
                      Enum.map(item |> Map.from_struct(), fn {k, v} ->
                        if Enum.member?(module.editable_attributes, k) and
                             Map.has_key?(conn.body_params, to_string(k)) do
                          # Update the value
                          {k, conn.body_params[to_string(k)]}
                        else
                          {k, v}
                        end
                      end),
                      %{}
                    )
                  )

                item = %{item | update_time: DateTime.utc_now()}

                IO.puts(inspect(item))

                {200,
                 json(
                   Memento.transaction!(fn ->
                     Memento.Query.write(item)
                   end)
                 )}
            end

          _ ->
            {400, err("Bad request (missing parameters)")}
        end

      conn |> send_resp(status, body)
    else
      conn |> send_resp(404, err("That resource does not exist"))
    end
  end

  match _ do
    conn |> send_resp(404, "not found")
  end

  def json(map) do
    Poison.encode!(map)
  end

  def err(msg) do
    json(%{"msg" => msg})
  end

  def missing(list) do
    json(%{"msg" => "You are missing fields", "fields" => list})
  end
end
