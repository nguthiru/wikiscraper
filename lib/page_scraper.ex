defmodule PageScraper do
  use GenServer
  require Logger
  defstruct [:file_path, :links]

  def start_link(file_path \\ "temp/links.txt") do
    # file path is the path to the links.txt
    GenServer.start_link(__MODULE__, %{file_path: file_path}, name: __MODULE__)
  end

  def init(%{file_path: file_path}) do
    {:ok, %__MODULE__{file_path: file_path}}
  end

  def run do
    GenServer.cast(__MODULE__, {:run})
  end

  def handle_cast({:run}, %__MODULE__{file_path: file_path} = state) do
    links =
      File.stream!(file_path)
      |> Enum.map(&String.trim/1)

    links
    |> Enum.chunk_every(1000)
    |> Enum.map(fn x -> Task.async(fn -> scrape(MapSet.new(x)) end) end)
    |> Enum.each(fn x -> Task.await(x,:infinity) end)

    {:noreply, state}
  end

  def scrape(%MapSet{} = urls) do
    case MapSet.size(urls) do
      0 ->
        Logger.warning("No more links to scrape")
        {:noreply, %__MODULE__{}}

      _ ->
        Logger.debug("Remaining with #{MapSet.size(urls) |> inspect()} elements")
        url = urls |> MapSet.to_list() |> List.first()

        case get_document(url) do
          {:ok, html} ->
            body_content = extract_body_content(html)
            write_to_file("temp/processed/#{get_keyword(url)}.txt", body_content)
            append_to_file(url)

          {:error, :failed} ->
            Logger.error("Failed to scrape")
        end

        scrape(MapSet.delete(urls, url))
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

  defp extract_body_content(document) do
    Floki.find(document, "#mw-content-text")
    |> Floki.text()
  end

  defp get_keyword(url) do
    url
    |> String.split("/")
    |> Enum.at(-1)
  end

  defp write_to_file(file_path, content) do
    Logger.debug("Writing to file: #{file_path} - file content length: #{String.length(content)}")
    File.write(file_path, content, [:write])
  end

  defp append_to_file(url) do
    File.write("temp/links_processed.txt", url <> "\n", [:append])
  end
end
