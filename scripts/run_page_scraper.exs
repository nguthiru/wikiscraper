# alias Wikiscraper.Application
alias PageScraper

# Ensure all applications are started
Application.ensure_all_started(:logger)
Application.ensure_all_started(:httpoison)
Application.ensure_all_started(:floki)

# Start the supervision tree
{:ok, _pid} = Wikiscraper.Application.start(:normal, [])

# Start the PageScraper
{:ok, _scraper_pid} = PageScraper.start_link()

# Run the scraper with the path to your links.txt file
PageScraper.run()
