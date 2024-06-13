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

  def handle_call({:run}, _from, %__MODULE__{file_path: file_path} = state) do
    File.stream!(file_path)
    |> Enum.map(&String.trim/1)
    |> Stream.chunk_every(100)
    |> Stream.each(&process_links/1)
    |> Stream.run()

    {:reply, {:ok, "Scraping completed"}, state}
  end

  defp process_links(links) do
    Enum.map(links, fn link ->
      Task.async(fn -> scrape(link) end)
    end)
    |> Enum.map(&Task.await(&1, 60000))
  end

  defp scrape(url) do
    Logger.debug("Scraping started on #{url}")

    case HTTPoison.get(url) do
      {:ok, response} ->
        {:ok, html} = Floki.parse_document(response.body)
        body_content = extract_body_content(html)
        keyword = get_keyword(url)
        file_path = "temp/processed/#{keyword}.txt"

        Task.start(fn ->
          write_to_file(file_path, body_content)
          append_to_file(url)
        end)


        {:ok, body_content}

      {:error, _item} ->
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
    File.write(file_path, content, [:write])
  end

  defp append_to_file(url) do
    File.write("temp/links processed.txt", url <> "\n", [:append])
  end

end
