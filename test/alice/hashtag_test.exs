defmodule Alice.Conn do
  defstruct [:message, :slack, :state]
  alias Alice.Hashtag.Utils, as: H

  def user(conn), do: H.user_data(conn).name

  def get_state_for(%{state: state}, key, default) do
    Map.get(state, key, default)
  end

  def put_state_for(conn, key, value) do
    send(self, {:put, {key, value}})
    conn
  end
end

defmodule Alice.HashtagTest do
  use ExUnit.Case, async: true
  alias Alice.Hashtag.Utils, as: H

  @user %{id: "123", name: "username"}
  @conn %Alice.Conn{
    message: %{text: "some text #tag #another", user: @user.id},
    slack: %{
      users: %{
        @user.id => @user, "0" => %{name: "other", id: "0"},
        "another user" => "another user"
      }
    },
    state: %{
      users:       %{@user.id => %{ "tag" => 1 }},
      frequencies: %{"tag" => 1},
      messages:    %{"tag" => [%{text: "first #tag", user: @user}]}
    }
  }

  test "at_reply_user formats an at-reply given a user" do
    assert H.at_reply_user(@user) == "<@#{@user.id}>"
  end

  def conn_with_tags do
    state = @conn.state
            |> Map.put(:users, %{
              @user.id => %{ "tag1" => 4, "tag2" => 2 },
              "another user" => %{ "tag2" => 1, "tag3" => 1 }
            })
            |> Map.put(:frequencies, %{
              "tag2" => 3, "tag1" => 4, "tag3" => 1
            })
    %Alice.Conn{message: @conn.message, slack: @conn.slack, state: state}
  end

  test "most_popular_tag returns a random hashtag when this tag is the most popular" do
    assert "#" <> _rest = H.most_popular_tag(conn_with_tags, "tag1")
  end

  test "most_popular_tag returns an empty string when this tag is not the most popular" do
    assert H.most_popular_tag(conn_with_tags, "tag3") == ""
  end

  test "tag_frequency returns the frequency of the tag" do
    assert H.tag_frequency(conn_with_tags, "tag1") == 4
    assert H.tag_frequency(conn_with_tags, "tag2") == 3
    assert H.tag_frequency(conn_with_tags, "tag3") == 1
    assert H.tag_frequency(conn_with_tags, "nope") == 0
  end

  test "users_for_tag returns the number of users who have used the tag" do
    assert H.users_for_tag(conn_with_tags, "tag1") == 1
    assert H.users_for_tag(conn_with_tags, "tag2") == 2
    assert H.users_for_tag(conn_with_tags, "nope") == 0
  end

  test "top_user_of_tag returns the top user for the tag" do
    assert H.top_user_of_tag(conn_with_tags, "tag1") == @user
    assert H.top_user_of_tag(conn_with_tags, "tag2") == @user
    assert H.top_user_of_tag(conn_with_tags, "tag3") == "another user"
  end

  test "total_tags returns the number of unique tags recorded" do
    assert H.total_tags(conn_with_tags) == 3
  end

  test "popular_tags returns the tags ordered by frequency" do
    assert H.popular_tags(conn_with_tags) == ["tag1", "tag2", "tag3"]
  end

  test "popular_tags returns a subset when given a limit" do
    assert H.popular_tags(conn_with_tags, 2) == ["tag1", "tag2"]
  end

  test "tags_for_user returns all the tags for a user" do
    assert H.tags_for_user(conn_with_tags, @user.id) == ["tag1", "tag2"]
  end

  test "most_used_tag_for_user returns the most used tag for a user" do
    assert H.most_used_tag_for_user(conn_with_tags, @user.id) == "tag1"
  end

  test "user_with_most_tags returns the user with the most tags" do
    assert H.user_with_most_tags(conn_with_tags) == @user
  end

  test "most_tags returns a random hashtag when the user has the most tags" do
    assert "#" <> _rest = H.most_tags(conn_with_tags, @user.id)
  end

  test "most_tags returns an empty string when the user doesn't have the most" do
    assert H.most_tags(conn_with_tags, "0") == ""
  end

  test "find_messages_for_tag returns all the messages for a tag" do
    assert H.find_messages_for_tag(@conn, "tag") == [
      %{text: "first #tag", user: H.user_data(@conn)}
    ]
  end

  test "update_user_tags adds the tags to the user state" do
    @conn = H.update_user_tags(@conn, ["tag", "another"])
    assert_received {:put, {:users, user_tags}}
    assert user_tags == %{@user.id => %{"tag" => 2, "another" => 1}}
  end

  test "update_frequencies updates the frequencies for the tags" do
    @conn = H.update_frequencies(@conn, ["tag", "another"])
    assert_received {:put, {:frequencies, tags}}
    assert tags == %{"tag" => 2, "another" => 1}
  end

  test "save_message saves the message under all the tags" do
    msg = %{text: @conn.message.text, user: H.user_data(@conn)}
    @conn = H.save_message(@conn, ["tag", "another"])
    assert_received {:put, {:messages, messages}}
    assert messages == %{
      "tag" => [msg, %{text: "first #tag", user: H.user_data(@conn)}],
      "another" => [msg]
    }
  end
end
