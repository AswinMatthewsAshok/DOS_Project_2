defmodule Gossip.Boss do
	def manage(actors,key\\0) do
		# Tracks network convergence
		if not Enum.any?(0..tuple_size(actors)-1, fn i -> elem(actors,i)["state"] == "alive" end) do
			unaware_nodes = Gossip.Topologies.get_unaware(actors)
			if not Enum.empty?(unaware_nodes) do
				chosen = Enum.random(unaware_nodes)
				GenServer.call(elem(actors,chosen)["pid"],{:seed})
			end
		end
		actors = Gossip.Topologies.update_actor_states(actors,key)
		Process.sleep(10)
		if Enum.any?(0..tuple_size(actors)-1, fn i -> elem(actors,i)["state"]!= "dead" end) do
			manage(actors,key+1)
		end
	end
end