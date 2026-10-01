if Code.ensure_loaded?(SweetXml) do
  defmodule ExAws.S3.Parsers.ObjectVersions do
    @moduledoc false

    # A ListVersionsResult page holds up to 1000 entries. Building the xmerl DOM
    # for it and querying it with xpath keeps megabytes of charlists alive and
    # spends most of the time in garbage collection, so this parser builds the
    # result directly from SAX events.

    @root ~c"ListVersionsResult"

    @root_fields %{
      ~c"Name" => :name,
      ~c"Prefix" => :prefix,
      ~c"MaxKeys" => :max_keys,
      ~c"KeyMarker" => :key_marker,
      ~c"NextKeyMarker" => :next_key_marker,
      ~c"VersionIdMarker" => :version_id_marker,
      ~c"NextVersionIdMarker" => :next_version_id_marker,
      ~c"IsTruncated" => :is_truncated
    }

    @version_fields %{
      ~c"Key" => :key,
      ~c"VersionId" => :version_id,
      ~c"ETag" => :etag,
      ~c"IsLatest" => :is_latest,
      ~c"LastModified" => :last_modified,
      ~c"Size" => :size
    }

    @delete_marker_fields Map.drop(@version_fields, [~c"ETag", ~c"Size"])

    @entries %{
      ~c"Version" => {:versions, @version_fields},
      ~c"DeleteMarker" => {:delete_markers, @delete_marker_fields}
    }

    @empty_root Map.new(Map.values(@root_fields), &{&1, ""})

    @empty_entries %{
      versions: Map.new(Map.values(@version_fields), &{&1, ""}),
      delete_markers: Map.new(Map.values(@delete_marker_fields), &{&1, ""})
    }

    def parse(xml) do
      state = %{
        depth: 0,
        root?: false,
        field: nil,
        text: [],
        root: @empty_root,
        entry: nil,
        in_owner?: false,
        versions: [],
        delete_markers: []
      }

      options = [event_fun: &event/3, event_state: state]

      case :xmerl_sax_parser.stream(xml, options) do
        {:ok, %{root?: false}, _rest} ->
          exit({:fatal, {:expected_root, @root}})

        {:ok, state, _rest} ->
          Map.merge(state.root, %{
            versions: Enum.reverse(state.versions),
            delete_markers: Enum.reverse(state.delete_markers)
          })

        {:fatal_error, {_, _, line}, reason, _end_tags, _state} ->
          exit({:fatal, {reason, {:line, line}}})
      end
    end

    defp event({:startDTD, _name, public_id, system_id}, _location, _state)
         when public_id != [] or system_id != [],
         do: throw({:fatal_error, :external_dtd_not_allowed})

    defp event(event, _location, _state)
         when is_tuple(event) and
                elem(event, 0) in [:internalEntityDecl, :externalEntityDecl, :unparsedEntityDecl],
         do: throw({:fatal_error, :entities_not_allowed})

    defp event({:startElement, _uri, _name, {[], name}, _attrs}, _location, state) do
      start_element(%{state | depth: state.depth + 1}, name)
    end

    defp event({:startElement, _uri, _name, _qname, _attrs}, _location, state) do
      start_element(%{state | depth: state.depth + 1}, nil)
    end

    defp event({:endElement, _uri, _name, _qname}, _location, state) do
      state = end_element(state)
      %{state | depth: state.depth - 1}
    end

    defp event({type, chars}, _location, %{field: {_, depth}, depth: depth} = state)
         when type in [:characters, :ignorableWhitespace] do
      %{state | text: [state.text | chars]}
    end

    defp event(_event, _location, state), do: state

    defp start_element(%{depth: 1} = state, @root), do: %{state | root?: true}
    defp start_element(%{root?: false} = state, _name), do: state
    defp start_element(%{field: {_, _}} = state, _name), do: state

    defp start_element(%{depth: 2} = state, name) do
      case @entries do
        %{^name => {type, fields}} -> %{state | entry: {type, fields, @empty_entries[type], nil}}
        _ -> open_field(state, @root_fields[name])
      end
    end

    defp start_element(%{depth: 3, entry: {type, fields, entry, owner}} = state, name) do
      case name do
        ~c"Owner" when owner == nil ->
          %{state | entry: {type, fields, entry, %{id: ""}}, in_owner?: true}

        ~c"Owner" ->
          state

        _ ->
          open_field(state, fields[name])
      end
    end

    defp start_element(%{depth: 4, in_owner?: true} = state, ~c"ID"),
      do: open_field(state, :owner_id)

    defp start_element(state, _name), do: state

    defp end_element(%{field: {field, depth}, depth: depth} = state) do
      put_field(%{state | field: nil, text: []}, field, List.to_string(state.text))
    end

    defp end_element(%{depth: 3, in_owner?: true} = state), do: %{state | in_owner?: false}

    defp end_element(%{depth: 2, entry: {type, _fields, entry, owner}} = state) do
      Map.update!(%{state | entry: nil}, type, &[Map.put(entry, :owner, owner) | &1])
    end

    defp end_element(state), do: state

    defp open_field(state, nil), do: state
    defp open_field(state, field), do: %{state | field: {field, state.depth}, text: []}

    defp put_field(%{entry: nil} = state, field, value) do
      %{state | root: Map.update!(state.root, field, &(&1 <> value))}
    end

    defp put_field(%{entry: {type, fields, entry, owner}} = state, :owner_id, value) do
      %{state | entry: {type, fields, entry, %{owner | id: owner.id <> value}}}
    end

    defp put_field(%{entry: {type, fields, entry, owner}} = state, field, value) do
      %{state | entry: {type, fields, Map.update!(entry, field, &(&1 <> value)), owner}}
    end
  end
end
