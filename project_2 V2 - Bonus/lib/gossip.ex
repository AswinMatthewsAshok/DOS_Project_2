defmodule Gossip do
	use Application
	def start(_type, args) do
    	Gossip.Supervisor.start_link(args)
  	end
end
