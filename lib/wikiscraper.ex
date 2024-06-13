defmodule Wikiscraper do
  @moduledoc """
  Documentation for `Wikiscraper`.
  The module scrapes swahili wikipedia links and dumps the data.
  """
  use GenServer
  require Logger
  alias PageScraper
  # @wiki_base_url "https://sw.wikipedia.org/wiki/"

  defstruct [:urls, :unique_urls]

  def start_link(keyword \\ "Virusi") do
    GenServer.start_link(__MODULE__, %{keyword: keyword}, name: __MODULE__)
  end

  def init(%{keyword: keyword}) do
    {:ok, %__MODULE__{unique_urls: MapSet.new(), urls: [keyword]}}
  end

  def run(keyword \\ "Kiswahili") do
    GenServer.call(__MODULE__, {:run, keyword})
  end

  def handle_call({:run, keyword}, _from, %__MODULE__{urls: _urls} = state) do
    case recursive_scrape(keyword, state) do
      {:ok, _message, state} ->
        {:reply, {:ok, "Scraping completed"}, state}

      {:error, _reason, state} ->
        {:reply, {:error, :failed}, state}
    end
  end

  def handle_call(_, _from, state) do
    {:reply, {:error, :unknown_request}, state}
  end

  defp recursive_scrape(keyword, %__MODULE__{} = state) do
    # scrapes the links removing the first element and passing the first element to the same function until the list is empty
    try do
      case List.first(state.urls) do
        nil ->
          Logger.debug("Recursive Scraping of Page: #{keyword} completed")
          {:ok, "Scraping completed", state}

        keyword ->
          Logger.debug("Recursive Scraping of Page: #{keyword} started")

          Task.start(fn ->
            case scrape_page(keyword, state) do
              {:ok, _links, %__MODULE__{urls: urls} = state} ->
                Process.sleep(300)

                recursive_scrape(Enum.at(urls, 1), state)

              {:error, :failed, state} ->
                Logger.error("Failed to scrape")
                recursive_scrape(Enum.at(state.urls, 2), state)

                {:error, :failed, state}
            end
          end)
      end
    rescue
      _ -> {:error, :failed, state}
    end
  end

  defp scrape_page(keyword, %__MODULE__{} = state) do
    Logger.debug("Scraping of Page: #{keyword} started")

    if MapSet.member?(state.unique_urls, keyword) do
      state = %{state | urls: List.delete(state.urls, keyword)}

      Logger.warning("#{keyword} is already scraped")
      {:ok, state.urls, state}
    else
      case PageScraper.start_link(keyword) do
        {:ok, _pid} ->
          # remove keyword from urls
          state = %{state | urls: List.delete(state.urls, keyword)}

          case PageScraper.scrape_page(keyword) do
            {:ok, links} ->
              state = %{
                state
                | unique_urls: MapSet.put(state.unique_urls, keyword),
                  urls: Enum.concat(state.urls, links |> Enum.uniq())
              }

              PageScraper.stop(keyword)

              {:ok, links, state}

            {:error, :failed} ->
              PageScraper.stop(keyword)

              Logger.error("Failed to scrape")
              {:error, :failed, state}
          end

        {:error, reason} ->
          Logger.error("Failed to start scraping of #{keyword}")
          IO.inspect(reason)
          {:error, :failed, state}
      end
    end
  end
end
