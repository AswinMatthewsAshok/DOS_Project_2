defmodule Gossip.Boss do
	def manage(actors,states,round_count) do
		if Enum.any?(states, fn state -> state end) do
			Gossip.Topologies.multi_call(actors,{:send})
		else
			undisturbed_actors = Enum.filter(0..length(actors)-1,fn i ->
				Enum.at(states,i) == :nil
			end)
			GenServer.call(elem(Enum.random(),1),{:start},:infinity)
		end
		states = Gossip.Topologies.multi_call(actors,{:transition_and_get_state})
		states = Gossip.Topologies.handle_isolated_actors(actors,states)
		if Enum.any?(states, fn state -> state end) do
			manage(actors,states,round_count+1)
		else
			round_count
		end
	end
end