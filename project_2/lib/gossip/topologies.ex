defmodule Gossip.Topologies do
	def build_topology(topology,node_count,algorithm) do
		properties = %{
			"state" => :nil,
			"next_state" => :nil,
			"algorithm" => if(algorithm == "push-sum", do: "push-sum", else: "gossip"),
			"count" => 0,
			"s" => 0,
			"w" => 1,
			"ratio" => 0,
			"neighbours" => []
		}
		actors = Enum.map(0..node_count-1,fn count ->
			%{
				"id" => count,
				"pid" => elem(
					Supervisor.start_child({Gossip.Supervisor, Node.self()}, 
					Supervisor.child_spec({Gossip.Actors, properties}, id: count, shutdown: :infinity, restart: :transient)
					),1),
				"state" => :nil,
				"neighbours" => []
			}
		end)
		cond do
			topology == "full" ->
				List.to_tuple(Enum.map(0..length(actors)-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = actors -- [actor]
					GenServer.call(actor["pid"],{:initialize,%{
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0)
					}},:infinity)
					Map.put(actor,"neighbours",Enum.map(neighbours,fn neighbour -> neighbour["id"] end))
				end))
		end
	end

	def multi_call(actors,request) do
		Enum.map(0..tuple_size(actors)-1, fn i->
			actor = elem(actors,i)
			GenServer.call(actor["pid"],request,:infinity)
		end)		
	end

	def transition_and_get_state(actors) do
		states = multi_call(actors,{:transition_and_get_state})
		List.to_tuple(Enum.map(0..tuple_size(actors)-1,fn i ->
			actor = elem(actors,i)
			Map.put(actor,"state",Enum.at(states,i))
		end))
	end

	def terminate_actors(actors) do
		supervisor = {Gossip.Supervisor, Node.self()}
		Enum.each(0..tuple_size(actors)-1,fn i->
			actor = elem(actors,i)
			Supervisor.terminate_child(supervisor,actor["id"])
			Supervisor.delete_child(supervisor,actor["id"])
		end)
	end
end