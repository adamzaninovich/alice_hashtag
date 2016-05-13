defmodule Alice.Handlers.Hashtag do
  @moduledoc """
  Keep track of hashtags used in rooms where Alice is present
  """

  use Alice.Router
  alias Alice.Hashtag.Utils, as: H

  @hashtag_pattern "#([\w-]+)"

  route Regex.compile!(@hashtag_pattern, "u"),                          :record
  route Regex.compile!("\Ahashtag search #{@hashtag_pattern}\z", "iu"), :search
  route Regex.compile!("\Ahashtag random #{@hashtag_pattern}\z", "iu"), :random
  route Regex.compile!("\Ahashtag stats #{@hashtag_pattern}\z", "iu"),  :tag_stats
  route ~r/\Ahashtag <@(.*)>\z/i,                                       :user_stats
  route ~r/\Ahashtag stats\z/i,                                         :stats
  # route ~r/\Ahashtag cloud\z/i,                                         :cloud

  def stats(conn) do
    conn
    |> H.total_tags
    |> case do
      0     -> "No hashtags have been recorded"
      total ->
        """
        *Hashtag Stats*
        Number of unique tags: #{total}
        User with most tags: #{H.at_reply_user(H.user_with_most_tags(conn))}
        Most popular tags: #{conn |> H.popular_tags(5) |> Enum.join(", ")}
        """
        |> String.strip
    end
    |> reply(conn)
  end

  def tag_stats(conn) do
    tag = Alice.Conn.last_capture(conn)
    """
    *Stats for ##{tag}* #{H.most_popular_tag(conn, tag)}
    Used #{H.tag_frequency(conn, tag)} times by #{length(H.users_for_tag(conn, tag))} users
    Most popular with #{H.at_reply_user(H.top_user_of_tag(conn, tag))}
    """
    |> String.strip
    |> reply(conn)
  end

  def user_stats(conn) do
    user_id = Alice.Conn.last_capture(conn)
    """
    *Stats for #{H.at_reply_user(user_id)}* #{H.most_tags(conn, user_id)}
    Number of tags: #{length(H.tags_for_user(conn, user_id))}
    Most used tag: #{H.most_used_tag_for_user(conn, user_id)}
    """
    |> String.strip
    |> reply(conn)
  end

  def record(conn) do
    tags = @hashtag_pattern
           |> Regex.scan(conn.message)
           |> Enum.map(fn([_,tag]) -> tag end)
    conn
    |> H.update_user_tags(tags)
    |> H.update_frequencies(tags)
    |> H.save_message(tags)
  end

  def search(conn) do
    conn
    |> H.find_messages_for_tag(Alice.Conn.last_capture(conn))
    |> Enum.shuffle
    |> Enum.take(5)
    |> Enum.map(&format_search_response/1)
    |> Enum.join("\n\n")
    |> reply(conn)
  end

  def random(conn) do
    conn
    |> H.find_messages_for_tag(Alice.Conn.last_capture(conn))
    |> Enum.random
    |> format_search_response
    |> reply(conn)
  end

  defp format_search_response(%{text: text, user: user}) do
    """
    > #{text}
    - #{H.at_reply_user(user)}
    """
  end
end
