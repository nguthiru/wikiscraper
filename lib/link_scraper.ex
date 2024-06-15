defmodule LinkScraper do
  use GenServer
  require Logger
  defstruct [:url, :links]
  @wiki_base_url "https://sw.wikipedia.org/wiki/"

  def start_link(keyword) do
    GenServer.start_link(__MODULE__, %{keyword: keyword}, name: String.to_atom(keyword))
  end

  def init(%{keyword: keyword}) do
    {:ok, %__MODULE__{links: MapSet.new(), url: @wiki_base_url <> keyword}}
  end

  def view_state(keyword) do
    GenServer.call(String.to_atom(keyword), {:view_state})
  end

  def scrape_page(keyword) do
    GenServer.call(String.to_atom(keyword), {:scrape}, 15000)
  end

  def stop(keyword) do
    GenServer.stop(String.to_atom(keyword))
  end

  def handle_call({:view_state}, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call({:scrape}, _from, state) do
    case scrape(state.url) do
      {:ok, %{links: links}} ->
        state = %{state | links: MapSet.put(state.links, links)}
        # dump_to_file(state.url, body_content)

        {:reply, {:ok, links}, state}

      {:error, :failed} ->
        IO.inspect("Failed to scrape")
        {:reply, {:error, :failed}, state}
    end
  end

  defp scrape(url) do
    Logger.debug("Scraping started on #{url}")

    case HTTPoison.get(url) do
      {:ok, response} ->
        {:ok, html} = Floki.parse_document(response.body)
        links = extract_links(html)
        links_formatted = Enum.map(links, fn x -> @wiki_base_url <> x end)
        add_links_to_file(links_formatted)
        # body_content = extract_body_content(html)
        {:ok, %{links: links, body_content: ""}}

      {:error, _item} ->
        IO.inspect("We have failed")
        {:error, :failed}
    end
  end

  defp extract_links(html) do
    Logger.debug("Extracting links")

    Floki.find(html, "#bodyContent a")
    |> Enum.map(fn x -> Floki.attribute(x, "href") end)
    |> Enum.flat_map(fn x -> x end)
    |> Enum.filter(fn x ->
      String.starts_with?(x, "/wiki/") &&
        !String.contains?(x, ":")
    end)
    |> Enum.map(fn x -> String.replace_prefix(x, "/wiki/", "") end)
  end

  defp add_links_to_file(links) do
    File.write("temp/links.txt", Enum.join(links, "\n"), [:append])
  end
end
