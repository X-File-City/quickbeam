defmodule ContentPipelineTest do
  use ExUnit.Case

  setup do
    js_dir = Path.join(File.cwd!(), "priv/js")
    {:ok, sup} = ContentPipeline.start_link(collector: self(), js_dir: js_dir)
    Process.unlink(sup)
    on_exit(fn -> Supervisor.stop(sup) end)
    :ok
  end

  test "strips HTML tags" do
    ContentPipeline.submit(%{
      id: 1,
      title: "<b>Bold</b> and <i>italic</i>",
      body: "<p>A <a href='#'>link</a> here.</p>",
      author: "alice"
    })

    assert_receive {:done, result}, 2000
    assert result["title"] == "Bold and italic"
    assert result["body"] == "A link here."
  end

  test "detects spam" do
    ContentPipeline.submit(%{
      id: 2,
      title: "Buy Now! Free Money!!!",
      body: "Click here for $$$ — act now!",
      author: "spammer"
    })

    assert_receive {:done, result}, 2000
    assert result["is_spam"] == true
    assert result["spam_score"] >= 2
  end

  test "passes clean posts through" do
    ContentPipeline.submit(%{
      id: 3,
      title: "QuickBEAM Release",
      body: "JS runtimes as BEAM processes.",
      author: "bob"
    })

    assert_receive {:done, result}, 2000
    assert result["is_spam"] == false
    assert result["spam_score"] == 0
  end

  test "counts words" do
    ContentPipeline.submit(%{
      id: 4,
      title: "Test",
      body: "one two three four five",
      author: "alice"
    })

    assert_receive {:done, result}, 2000
    assert result["word_count"] == 5
  end

  test "adds processing timestamp" do
    ContentPipeline.submit(%{id: 5, title: "T", body: "B", author: "a"})

    assert_receive {:done, result}, 2000
    assert is_binary(result["processed_at"])
    assert {:ok, _, _} = DateTime.from_iso8601(result["processed_at"])
  end

  test "processes multiple posts" do
    for i <- 1..10 do
      ContentPipeline.submit(%{
        id: i,
        title: "Post #{i}",
        body: "Content of post #{i}",
        author: "user_#{i}"
      })
    end

    results =
      for _ <- 1..10 do
        assert_receive {:done, result}, 2000
        result
      end

    ids = results |> Enum.map(& &1["id"]) |> Enum.sort()
    assert ids == Enum.to_list(1..10)
  end

  test "classifier crash doesn't kill other stages" do
    ContentPipeline.submit(%{id: 0, title: "before", body: "test", author: "a"})
    assert_receive {:done, _}, 2000

    classifier_pid = Process.whereis(:classifier)
    Process.exit(classifier_pid, :kill)
    Process.sleep(100)

    assert Process.whereis(:classifier) != classifier_pid
    assert Process.whereis(:sanitizer) != nil
    assert Process.whereis(:enricher) != nil
  end
end
