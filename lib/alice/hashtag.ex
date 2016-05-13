defmodule Alice.Hashtag.Utils do
  alias Alice.Conn

  def user_data(%Conn{slack: %{users: u}, message: %{user: id}}), do: u[id]
  def user_data(%Conn{slack: %{users: u}}, id),                   do: u[id]

  def at_reply_user(%{id: id}), do: "<@#{id}>"
  def at_reply_user(id),        do: "<@#{id}>"

  defp user_state(conn), do: Conn.get_state_for(conn, :users, %{})

  defp freq_state(conn), do: Conn.get_state_for(conn, :frequencies, %{})

  def total_tags(conn), do: conn |> freq_state |> Map.keys |> length

  def most_popular_tag(conn, tag) do
    cond do
      hd(popular_tags(conn, 1)) == tag ->
        ["#HotStuff", "#mostpopular", "#💯"]
        |> Enum.random
      true -> ""
    end
  end

  def tag_frequency(conn, tag), do: conn |> freq_state |> Map.get(tag, 0)

  def users_for_tag(conn, tag) do
    conn
    |> Conn.get_state_for(:users, %{})
    |> Enum.reduce(0, fn
      ({user, %{^tag => _}}, acc) -> acc + 1
      (_, acc) -> acc
    end)
  end

  def top_user_of_tag(conn, tag) do
    id = conn
         |> Conn.get_state_for(:users, %{})
         |> Enum.max_by(fn
           ({_user, %{^tag => num}}) -> num
           (_) -> 0
         end)
         |> elem(0)
    user_data(conn, id)
  end

  @doc "returns tags sorted by decending popularity"
  def popular_tags(conn, number), do: conn |> popular_tags |> Enum.take(number)
  def popular_tags(conn) do
    conn
    |> freq_state
    |> Enum.sort_by(fn({_tag, num}) -> -num end)
    |> Enum.map(fn({tag, _num}) -> tag end)
  end

  def tags_for_user(conn, id) do
    conn
    |> user_state
    |> Map.get(id, %{})
    |> Enum.map(fn({tag, _}) -> tag end)
  end

  def most_used_tag_for_user(conn, id) do
    conn
    |> user_state
    |> Map.get(id, %{})
    |> Enum.max_by(fn({_, num}) -> num end)
    |> elem(0)
  end

  def user_with_most_tags(conn) do
    {id, _} = conn
              |> user_state
              |> Enum.max_by(fn({_id, tags}) -> tags |> Map.keys |> length end)
    user_data(conn, id)
  end

  def most_tags(conn, id) do
    cond do
      user_with_most_tags(conn).id == id ->
        ["#MostTags", "#TopDawg", "#winning"]
        |> Enum.random
      true -> ""
    end
  end

  def find_messages_for_tag(conn, tag) do
    conn
    |> Conn.get_state_for(:messages, %{})
    |> Map.get(tag, [])
  end

  def update_user_tags(conn, tags) do
    user_id = user_data(conn).id
    all_user_tags = user_state(conn)
    user_tags = all_user_tags
                |> Map.get(user_id, %{})
                |> increment_freqs_for_tags(tags)
    all_user_tags = Map.put(all_user_tags, user_id, user_tags)
    Conn.put_state_for(conn, :users, all_user_tags)
  end

  def update_frequencies(conn, tags) do
    frequencies = conn
                  |> freq_state
                  |> increment_freqs_for_tags(tags)
    Conn.put_state_for(conn, :frequencies, frequencies)
  end

  defp increment_freqs_for_tags(frequencies, tags) do
    Enum.reduce(tags, frequencies, fn(tag, freqs) ->
      current = Map.get(freqs, tag, 0)
      Map.put(freqs, tag, current + 1)
    end)
  end

  def save_message(conn = %Conn{message: %{text: text}}, tags) do
    message = %{text: text, user: user_data(conn)}
    messages = Conn.get_state_for(conn, :messages, %{})
    messages = Enum.reduce(tags, messages, fn(tag, tagged_messages) ->
      messages = Map.get(tagged_messages, tag, [])
      Map.put(tagged_messages, tag, [ message | messages ])
    end)
    Conn.put_state_for(conn, :messages, messages)
  end
end
