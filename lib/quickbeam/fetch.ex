defmodule QuickBEAM.Fetch do
  @moduledoc false

  def fetch([%{"url" => url, "method" => method, "headers" => headers} = opts]) do
    :ok = ensure_httpc_started()

    body = opts["body"]
    redirect = opts["redirect"] || "follow"

    uri = URI.parse(url)

    url_charlist =
      url
      |> String.to_charlist()

    req_headers =
      headers
      |> Enum.map(fn [k, v] -> {String.to_charlist(k), String.to_charlist(v)} end)

    http_opts = [
      ssl: ssl_opts(uri.host),
      autoredirect: redirect == "follow",
      relaxed: true
    ]

    request = build_request(url_charlist, req_headers, method, body)

    case :httpc.request(atomize_method(method), request, http_opts, body_format: :binary) do
      {:ok, {{_, status, reason}, resp_headers, resp_body}} ->
        %{
          "status" => status,
          "statusText" => List.to_string(reason),
          "headers" => Enum.map(resp_headers, fn {k, v} -> [to_string(k), to_string(v)] end),
          "body" => {:bytes, IO.iodata_to_binary(resp_body)},
          "url" => url,
          "redirected" => redirect == "follow" and status in 200..299
        }

      {:error, reason} ->
        raise "fetch failed: #{inspect(reason)}"
    end
  end

  defp build_request(url, headers, method, body)
       when method in ["GET", "HEAD", "OPTIONS", "DELETE"] or is_nil(body) do
    {url, headers}
  end

  defp build_request(url, headers, _method, body) do
    content_type =
      Enum.find_value(headers, ~c"application/octet-stream", fn
        {k, v} -> if :string.lowercase(k) == ~c"content-type", do: v
      end)

    body_binary = to_binary(body)
    {url, headers, content_type, body_binary}
  end

  defp atomize_method("GET"), do: :get
  defp atomize_method("POST"), do: :post
  defp atomize_method("PUT"), do: :put
  defp atomize_method("DELETE"), do: :delete
  defp atomize_method("PATCH"), do: :patch
  defp atomize_method("HEAD"), do: :head
  defp atomize_method("OPTIONS"), do: :options
  defp atomize_method(other), do: String.downcase(other) |> String.to_atom()

  defp to_binary(data) when is_binary(data), do: data
  defp to_binary(data) when is_list(data), do: :erlang.list_to_binary(data)
  defp to_binary(_), do: <<>>

  defp ssl_opts(host) do
    [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(host || ""),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  end

  defp ensure_httpc_started do
    case :inets.start(:httpc, profile: :quickbeam) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end
end
