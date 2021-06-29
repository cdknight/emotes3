defmodule Emotes4.DBValidator do
  defmacro __using__(require_attributes: req_opts, editable_attributes: edit_opts) do
    req_opts = Macro.expand(req_opts, __CALLER__)

    quote do
      def validate(data) do
        remaining =
          Enum.filter(unquote(req_opts), fn item -> Map.fetch(data, item) == {:ok, nil} end)

        case remaining do
          [] -> {:ok}
          _ -> {:missing_fields, remaining}
        end
      end

      def editable_attributes() do
        unquote(edit_opts)
      end
    end
  end
end

defmodule Emotes4.User do
  use Memento.Table,
    attributes: [:id, :username, :create_time, :update_time],
    type: :ordered_set,
    autoincrement: true

  use Emotes4.DBValidator, require_attributes: [:username], editable_attributes: []
end

defmodule Emotes4.UserKey do
  use Memento.Table,
    attributes: [:id, :user, :key, :description, :create_time, :update_time],
    type: :ordered_set,
    autoincrement: true

  use Emotes4.DBValidator,
    require_attributes: [:user, :key, :description],
    editable_attributes: []
end

defmodule Emotes4.Folder do
  # Emotes is a map of emote_slug: emote_filename
  use Memento.Table,
    attributes: [:id, :users, :name, :description, :emotes, :create_time, :update_time],
    type: :ordered_set,
    autoincrement: true

  use Emotes4.DBValidator,
    require_attributes: [:users, :name, :description],
    editable_attributes: [:users, :description]
end

defmodule Emotes4.DBCreate do
  def wipe_create_db() do
    nodes = [node()]

    Memento.stop()
    nodes |> Memento.Schema.create()
    Memento.start()

    tables = [Emotes4.User, Emotes4.UserKey, Emotes4.Folder]

    Enum.each(tables, &Memento.Table.delete(&1))
    Enum.each(tables, &Memento.Table.create!(&1, disc_copies: nodes))
  end
end
