defmodule Gossip.Topologies do
	def torus_3d_neighbours(node_count) do
		a = ceil(:math.pow(node_count,1/3))
		asquare = a*a
		acube = a*a*a
		Enum.reduce(0..node_count-1,%{},fn actor_id, map1 ->
			list = [
				if(rem(actor_id,a) >= a-1 or actor_id+1>=node_count,
					do: div(actor_id,a)*a,
					else: actor_id + 1),
				if(rem(actor_id,asquare) >= asquare-a or actor_id+a>=node_count,
					do: div(actor_id,asquare)*asquare+actor_id-div(actor_id,a)*a,
					else: actor_id + a),
				if(rem(actor_id,acube) >= acube-asquare or actor_id+asquare>=node_count,
					do: actor_id-div(actor_id,asquare)*asquare,
					else: actor_id + asquare)
			]
			Map.update(
				Enum.reduce(list,map1,fn id, map2 ->
					Map.update(map2,id,[actor_id],&([actor_id|&1]))
				end),
				actor_id,
				list,
				&(&1++list)
			)
		end)
	end

	def random_2d_neighbours(node_count) do
		random_list = 0..node_count
		coord_map = Enum.reduce(0..node_count-1, %{}, fn actor_id , map1 ->
			Map.put(map1,actor_id,{Enum.random(random_list)/node_count,Enum.random(random_list)/node_count})
		end)
		Enum.reduce(0..node_count-1, %{}, fn actor_id_1, map2 ->
			list = if(actor_id_1 != node_count-1,
				do:
				Enum.filter(actor_id_1+1..node_count-1, fn actor_id_2 ->
					{x1,y1} = coord_map[actor_id_1]
					{x2,y2} = coord_map[actor_id_2]
					distance = (x2-x1)*(x2-x1) + (y2-y1)*(y2-y1)
					distance <= 0.01
				end),
				else: []
			)
			Map.update(
				Enum.reduce(list,map2,fn id, map3 ->
					Map.update(map3,id,[actor_id_1],&([actor_id_1|&1]))
				end),
				actor_id_1,
				list,
				&(&1++list)
			)
		end)
	end

	def honeycomb_neighbours(node_count) do
		a = ceil(:math.pow(node_count,1/2))
		Enum.reduce(0..node_count-1,%{},fn actor_id, map1 ->
			toggle = if(rem(a,2)!=0,do: 0,else: if(rem(div(actor_id,a),2)==0,do: 0,else: 1))
			list = []
			list = if(rem(actor_id+1,a) != 0 and actor_id+1 < node_count,do: [actor_id+1|list],else: list)
			list = if(rem(actor_id+toggle,2) == 0 and actor_id+a < node_count,do: [actor_id+a|list],else: list)
			Map.update(
				Enum.reduce(list,map1,fn id, map2 ->
					Map.update(map2,id,[actor_id],&([actor_id|&1]))
				end),
				actor_id,
				list,
				&(&1++list)
			)
		end)
	end

	def honeycomb_rand_neighbours(node_count) do
		neighbour_map = honeycomb_neighbours(node_count)
		rand_unconnected = Enum.map(0..node_count-1,fn actor_id -> actor_id end)
		{neighbour_map,_} = Enum.reduce(0..node_count,{neighbour_map,rand_unconnected},fn actor_id,{map,list} ->
			if list == [] do
				{map,list}
			else
				len = length(list)
				list = list -- [actor_id]
				neighbour = if(len>length(list) and len > 1,do: Enum.random(list),else: :nil)
				if neighbour == :nil do
					{map,list}
				else
					{Map.update(
						Map.update(map,actor_id,[neighbour],&([neighbour|&1])),
						neighbour,[actor_id],&([actor_id|&1])
						),list--[neighbour]}
				end
			end
		end)
		neighbour_map
	end

	def build_topology(topology,node_count,algorithm) do
		properties = %{
			"id" => 0,
			"state" => :nil,
			"next_state" => :nil,
			"algorithm" => if(algorithm == "push-sum", do: "push-sum", else: "gossip"),
			"count" => 0,
			"s" => 0,
			"w" => 1,
			"ratio" => 0,
			"neighbours" => [],
			"boss" => self()
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
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = actors -- [actor]
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0)
					}},:infinity)
					Map.put(actor,"neighbours",Enum.map(neighbours,fn neighbour -> neighbour["id"] end))
				end))
			topology == "line" ->
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = if(i==0,
						do: [Enum.at(actors,i+1)], 
						else: if(i>0 and i<node_count-1,
							do: [Enum.at(actors,i-1), Enum.at(actors, i+1)],
							else: if(i == node_count-1,
								do: [Enum.at(actors,i-1)],
								else: []
								)
							)
						)
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0)
					}},:infinity)
					Map.put(actor,"neighbours",Enum.map(neighbours,fn neighbour -> neighbour["id"] end))
				end))
			topology == "rand2D" ->
				neighbour_map = random_2d_neighbours(node_count)
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = Enum.map(neighbour_map[actor["id"]],fn id -> Enum.at(actors,id) end)
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0)
					}},:infinity)
					Map.put(actor,"neighbours",neighbour_map[actor["id"]])
				end))
			topology == "3Dtorus" ->
				neighbour_map = torus_3d_neighbours(node_count)
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = Enum.map(neighbour_map[actor["id"]],fn id -> Enum.at(actors,id) end)
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0)
					}},:infinity)
					Map.put(actor,"neighbours",neighbour_map[actor["id"]])
				end))
			topology == "honeycomb" ->
				neighbour_map = honeycomb_neighbours(node_count)
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = Enum.map(neighbour_map[actor["id"]],fn id -> Enum.at(actors,id) end)
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0)
					}},:infinity)
					Map.put(actor,"neighbours",neighbour_map[actor["id"]])
				end))
			topology == "randhoneycomb" ->
				neighbour_map = honeycomb_rand_neighbours(node_count)
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = Enum.map(neighbour_map[actor["id"]],fn id -> Enum.at(actors,id) end)
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0)
					}},:infinity)
					Map.put(actor,"neighbours",neighbour_map[actor["id"]])
				end))
		end
	end

	def multi_call(actors,request) do
		Enum.each(0..tuple_size(actors)-1, fn i->
			actor = elem(actors,i)
			GenServer.call(actor["pid"],request)
		end)		
	end

	def multi_cast(actors,request) do
		Enum.map(0..tuple_size(actors)-1, fn i->
			actor = elem(actors,i)
			GenServer.cast(actor["pid"],request)
		end)		
	end

	def get_states(actors,count\\0)

	def get_states(actors,count) when count >= tuple_size(actors) do
		actors
	end

	def get_states(actors,count) when count < tuple_size(actors) do
		receive do
			{:state,id,state} ->
				actor = Map.put(elem(actors,id),"state",state)
				actors = put_elem(actors,id,actor)
				get_states(actors,count+1)
		end
	end

	def transition_and_get_state(actors) do
		multi_cast(actors,{:transition_and_get_state})
		actors = get_states(actors)
		Enum.each(0..tuple_size(actors)-1,fn i ->
			actor = elem(actors,i)
			if Enum.all?(actor["neighbours"],fn neighbour -> elem(actors,neighbour)["state"] == :false end) do
				GenServer.call(actor["pid"],{:set_state,:false},:infinity)
			end
		end)
		multi_cast(actors,{:transition_and_get_state})
		get_states(actors)
	end

	def get_unaware(actors) do
		Enum.filter(0..tuple_size(actors)-1,fn i ->
			elem(actors,i)["state"] == :nil end)
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