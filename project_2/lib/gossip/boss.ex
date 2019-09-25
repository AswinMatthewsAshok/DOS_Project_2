defmodule Gossip.Boss do
	def manage(actors,round_count) do
		if Enum.any?(0..tuple_size(actors)-1, fn i -> elem(actors,i)["state"] end) do
			Gossip.Topologies.multi_call(actors,{:send})
		else
			GenServer.call(elem(actors,Enum.random(Gossip.Topologies.get_unaware(actors)))["pid"],{:set_state,:true},:infinity)
		end
		actors = Gossip.Topologies.transition_and_get_state(actors)
		if Enum.any?(0..tuple_size(actors)-1, fn i -> elem(actors,i)["state"]!= :false end) do
			manage(actors,round_count+1)
		else
			round_count
		end
	end
end