defmodule Taifascraper do
  use GenServer
  require Logger
  @tafia_base_url "https://taifaleo.nation.co.ke/"
  def start_link() do
    GenServer.start_link(__MODULE__, {}, name: __MODULE__)
  end

  def init(args) do
    {:ok, args}
  end

  def run() do
    GenServer.cast(__MODULE__, :run)
  end

  def handle_cast(:run, state) do
    scrape(sehemu())
    {:noreply, state}
  end

  defp scrape(urls) do
    url = List.first(urls)

    case fetch_from_url(url) do
      {:ok, _} ->
        scrape(List.delete_at(urls, 0))

      {:error, _} ->
        Logger.error("Error fetching from #{url}")
    end
  end

  @doc """
  Fetches the page from the given URL
  Adds pagination and some recursion to fetch all the pages
  """

  def fetch_from_url(url, page \\ 1) do
    formatted_url = get_url(url, page)

    case HTTPoison.get(formatted_url, [],
           follow_redirect: true,
           timeout: 50_000,
           recv_timeout: 50_000
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Logger.info("Scraping #{url}")
        links = body |> Floki.parse_document() |> scrape_body()
        dump_links_to_file(links)
        fetch_from_url(url, page + 1)
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        Logger.error("404 Not Found")
        {:error, "404"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTPoison Error on page #{page}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Scrapes the body of the page
  Returns a list of links to the articles
  """
  def scrape_body({:ok, document}) do
    document
    |> Floki.find(".col-lg-8 .col-xl-12 a")
    |> Enum.map(&Floki.attribute(&1, "href"))
    |> Enum.flat_map(fn x -> x end)
    |> Enum.filter(&(!String.starts_with?(&1, "T L")))
    |> Enum.uniq()
  end

  defp sehemu() do
    [
      "habari-mseto",
      "michezo",
      "makala",
      "siasa",
      "maoni",
      # "bi-taifa",
      "dondoo",
      "Mashairi"
    ]
  end

  # defp get_url(sehemu) do
  #   @tafia_base_url <> "sehemu/#{sehemu}"
  # end

  defp get_url(sehemu, page) do
    if page == 1 do
      @tafia_base_url <> "sehemu/#{sehemu}"
    else
      @tafia_base_url <> "sehemu/#{sehemu}/page/#{page}"
    end
  end

  defp dump_links_to_file(links) do
    Logger.debug("Writing Links To file")
    File.write!("temp/links_taifa.txt", Enum.join(links, "\n"), [:append])
  end
end
