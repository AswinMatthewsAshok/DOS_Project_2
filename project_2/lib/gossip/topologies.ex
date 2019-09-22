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
			"neighbours" => {}
		}
		actors = List.to_tuple(Enum.map(1..node_count,fn count ->
			%{
				"id" => count,
				"pid" => elem(
					Supervisor.start_child({Gossip.Supervisor, Node.self()}, 
					Supervisor.child_spec({Gossip.Actors, properties}, id: count, shutdown: :infinity, restart: :transient)
					),1),
				"state" => :nil,
				"neighbours" => {}
			}
		end))
		cond do
			topology == "full" ->
				Enum.map(0..size(actors)-1,fn i ->
					actor = elem(actors,i)
					neighbours = Tuple.delete_at(actors,i)
					GenServer.call(actor["pid"],{:initialize,%{
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: elem(actor,0), else: 0)
					}},:infinity)
					actor["neighbours"] = neighbours
				end)
		end
		actors
	end

	def multi_call(actors,request) do
		Enum.map(actors, fn actor->
			GenServer.call(actor["pid"],request,:infinity)
		end)		
	end

	def transition_and_get_state(actors) do
		states = Gossip.Topologies.multi_call(actors,{:transition_and_get_state})

	end

	def terminate_actors(actors) do
		supervisor = {Gossip.Supervisor, Node.self()}
		Enum.each(actors,fn actor->
			Supervisor.terminate_child(supervisor,elem(actor,0))
			Supervisor.delete_child(supervisor,elem(actor,0))
		end)
	end
end