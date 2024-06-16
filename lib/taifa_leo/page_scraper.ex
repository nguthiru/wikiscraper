defmodule TaifaLeo.PageScraper do

  use GenServer
  require Logger
  defstruct [:file_path, :links, :output_dir]

  def start_link(file_path \\ "temp/links_taifa.txt", output_dir \\ "taifa") do
    # file path is the path to the links.txt
    GenServer.start_link(__MODULE__, %__MODULE__{file_path: file_path, output_dir: output_dir},
      name: __MODULE__
    )
  end

  def init(%__MODULE__{output_dir: output_dir} = args) do
    create_dir_if_not_exists("temp/#{output_dir}_processed")
    {:ok, args}
  end

  def run do
    GenServer.cast(__MODULE__, {:run})
  end

  def handle_cast({:run}, %__MODULE__{file_path: file_path} = state) do
    links =
      File.stream!(file_path)
      |> Enum.map(&String.trim/1)
      |> Enum.shuffle()

    links
    |> Enum.chunk_every(1000)
    |> Enum.map(fn x -> Task.async(fn -> scrape(MapSet.new(x), state) end) end)
    |> Enum.each(fn x -> Task.await(x, :infinity) end)

    {:noreply, state}
  end

  def scrape(%MapSet{} = urls, %__MODULE__{output_dir: output_dir} = state) do
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
            write_to_file("temp/#{output_dir}_processed/#{get_keyword(url)}.txt", body_content)
            append_to_file(url, "temp/links_#{output_dir}_processed.txt")

          {:error, :failed} ->
            Logger.error("Failed to scrape")
        end

        scrape(MapSet.delete(urls, url), state)
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
    Floki.find(document, ".news-details-layout1 p,h2")
    |> Enum.map(&Floki.text/1)
    |> Enum.join("\n")
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

  defp append_to_file(url, file_path) do
    File.write(file_path, url <> "\n", [:append])
  end

  defp create_dir_if_not_exists(output_dir) do
    if File.dir?(output_dir) do
      Logger.debug("Directory #{output_dir} already exists")
    else
      File.mkdir!(output_dir)
      Logger.debug("Directory #{output_dir} created")
    end
  end
end
