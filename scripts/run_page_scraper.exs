# alias Wikiscraper.Application
alias PageScraper
require Logger
# Ensure all applications are started
Application.ensure_all_started(:logger)
Application.ensure_all_started(:httpoison)
Application.ensure_all_started(:floki)

# Start the supervision tree
{:ok, _pid} = Wikiscraper.Application.start(:normal, [])

# Start the PageScraper
{:ok, scraper_pid} = PageScraper.start_link()
IO.inspect(scraper_pid)
# Run the scraper with the path to your links.txt file
Logger.debug("Running Page Scraper")
PageScraper.run
