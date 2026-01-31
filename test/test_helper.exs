ExUnit.start()

Path.join(__DIR__, "support/**/*.exs")
|> Path.wildcard()
|> Enum.each(&Code.require_file/1)
