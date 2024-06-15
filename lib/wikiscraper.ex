defmodule Wikiscraper do
  require Logger

  use GenServer
  @wiki_base_url "https://sw.wikipedia.org"

  @initial_page @wiki_base_url <> "/w/index.php?title=Maalum:KurasaZote&from=Aaron+Ringera"
  defstruct [:url, :links]

  def start_link() do
    GenServer.start_link(__MODULE__, %__MODULE__{url: @wiki_base_url, links: []},
      name: __MODULE__
    )
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def scrape_links() do
    GenServer.cast(__MODULE__, {:scrape_links})
  end

  def handle_cast({:scrape_links}, state) do
    scrape(@initial_page, state)
    {:noreply, state}
  end

  def scrape(url \\ @initial_page, state) do
    case get_document(url) do
      {:ok, html} ->
        get_page_links(html) |> dump_page_links()

        case(get_navigation_links(html)) do
          {:ok, next_page} ->
            Logger.debug("Next Page Found: #{next_page}")
            scrape(@wiki_base_url <> next_page, state)
            {:noreply, state}

          {:error, _error} ->
            Logger.debug("No Next Page Found")
            {:noreply, state}
        end

      {:error, :failed} ->
        Logger.debug("Failed to scrape")
        {:noreply, state}
    end
  end

  defp get_document(url) do
    Logger.debug("Scraping on #{url} started")

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: _status_code, body: body}} ->
        Floki.parse_document(body)

      {:error, error} ->
        IO.inspect(error)
        Logger.error("Failed to scrape")
        {:error, :failed}
    end
  end

  defp get_navigation_links(html) do
    navigation_links = Floki.find(html, ".mw-allpages-nav a")

    nav_links =
      Enum.map(navigation_links, fn x -> Floki.attribute(x, "href") end) |> Enum.flat_map(fn x -> x end) |> Enum.uniq()
    case length(nav_links) do
      2 -> {:ok, nav_links |> List.last()}
      1 -> {:error, "No Next Page Found"}
    end
  end

  defp get_page_links(html) do
    Floki.find(html, ".mw-allpages-body a")
    |> Enum.map(fn x -> Floki.attribute(x, "href") end)
    |> Enum.flat_map(fn x -> x end)
    |> Enum.map(fn x -> @wiki_base_url <> x end)
  end

  defp dump_page_links(links) do
    File.write!("temp/links.txt", Enum.join(links, "\n"),[:append])
  end
end
