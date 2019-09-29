defmodule Gossip.Topologies do
	def full_neighbours(node_count,failure_rate,failure_type) do
		all_actors = Enum.map(0..node_count-1,fn id -> id end)
		{neighbour_map,_} = Enum.reduce(0..node_count-1,{%{},all_actors},fn actor_id, {map1,all} ->
			list = all -- [actor_id]
			list = if(failure_type == "connection",do: Enum.filter(list,fn _ -> Enum.random(1..100)>failure_rate end),else: list)
			{Map.update(
				Enum.reduce(list,map1,fn id, map2 ->
					Map.update(map2,id,[actor_id],&([actor_id|&1]))
				end),
				actor_id,
				list,
				&(&1++list)
			),list}
		end)
		neighbour_map
	end

	def line_neighbours(node_count,failure_rate,failure_type) do
		Enum.reduce(0..node_count-1,%{},fn actor_id, map1 ->
			list = if(actor_id+1 == node_count, do: [], else: [actor_id+1])
			list = if(failure_type == "connection",do: Enum.filter(list,fn _ -> Enum.random(1..100)>failure_rate end),else: list)
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

	def torus_3d_neighbours(node_count,failure_rate,failure_type) do
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
			list = if(failure_type == "connection",do: Enum.filter(list,fn _ -> Enum.random(1..100)>failure_rate end),else: list)
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

	def random_2d_neighbours(node_count,failure_rate,failure_type) do
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
			list = if(failure_type == "connection",do: Enum.filter(list,fn _ -> Enum.random(1..100)>failure_rate end),else: list)
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

	def honeycomb_neighbours(node_count,failure_rate,failure_type) do
		a = ceil(:math.pow(node_count,1/2))
		Enum.reduce(0..node_count-1,%{},fn actor_id, map1 ->
			toggle = if(rem(a,2)!=0,do: 0,else: if(rem(div(actor_id,a),2)==0,do: 0,else: 1))
			list = []
			list = if(rem(actor_id+1,a) != 0 and actor_id+1 < node_count,do: [actor_id+1|list],else: list)
			list = if(rem(actor_id+toggle,2) == 0 and actor_id+a < node_count,do: [actor_id+a|list],else: list)
			list = if(failure_type == "connection",do: Enum.filter(list,fn _ -> Enum.random(1..100)>failure_rate end),else: list)
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

	def honeycomb_rand_neighbours(node_count,failure_rate,failure_type) do
		neighbour_map = honeycomb_neighbours(node_count,failure_rate,failure_type)
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
					{
						if(failure_type == "connection" and Enum.random(1..100)>failure_rate, 
							do:
							Map.update(
								Map.update(map,actor_id,[neighbour],&([neighbour|&1])),
								neighbour,[actor_id],&([actor_id|&1])
								),
							else: map),
						list--[neighbour]
					}
				end
			end
		end)
		neighbour_map
	end

	def build_topology(topology,node_count,algorithm,failure_rate,failure_type) do
		properties = %{
			"id" => 0,
			"state" => "unaware",
			"algorithm" => if(algorithm == "push-sum", do: "push-sum", else: "gossip"),
			"count" => 0,
			"s" => 0,
			"w" => 1,
			"ratio" => 0,
			"neighbours" => [],
			"valid_neighbours" => [],
			"boss" => self(),
			"failure_rate" => failure_rate,
			"failure_type" => failure_type,
		}
		actors = Enum.map(0..node_count-1,fn count ->
			%{
				"id" => count,
				"pid" => elem(
					Supervisor.start_child({Gossip.Supervisor, Node.self()}, 
					Supervisor.child_spec({Gossip.Actors, properties}, id: count, shutdown: :infinity, restart: :transient)
					),1),
				"state" => "unaware",
				"neighbours" => []
			}
		end)
		cond do
			topology == "full" ->
				neighbour_map = full_neighbours(node_count,failure_rate,failure_type)
				IO.inspect(neighbour_map)
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = Enum.map(neighbour_map[actor["id"]],fn id -> Enum.at(actors,id) end)
					state = "unaware"
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0),
						"state"=>state
					}},:infinity)
					actor = Map.put(actor,"neighbours",neighbour_map[actor["id"]])
					Map.put(actor,"state",state)
				end))
			topology == "line" ->
				neighbour_map = line_neighbours(node_count,failure_rate,failure_type)
				IO.inspect(neighbour_map)
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = Enum.map(neighbour_map[actor["id"]],fn id -> Enum.at(actors,id) end)
					state = "unaware"
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0),
						"state"=>state
					}},:infinity)
					actor = Map.put(actor,"neighbours",neighbour_map[actor["id"]])
					Map.put(actor,"state",state)
				end))
			topology == "rand2D" ->
				neighbour_map = random_2d_neighbours(node_count,failure_rate,failure_type)
				IO.inspect(neighbour_map)
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = Enum.map(neighbour_map[actor["id"]],fn id -> Enum.at(actors,id) end)
					state = "unaware"
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0),
						"state"=>state
					}},:infinity)
					actor = Map.put(actor,"neighbours",neighbour_map[actor["id"]])
					Map.put(actor,"state",state)
				end))
			topology == "3Dtorus" ->
				neighbour_map = torus_3d_neighbours(node_count,failure_rate,failure_type)
				IO.inspect(neighbour_map)
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = Enum.map(neighbour_map[actor["id"]],fn id -> Enum.at(actors,id) end)
					state = "unaware"
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0),
						"state"=>state
					}},:infinity)
					actor = Map.put(actor,"neighbours",neighbour_map[actor["id"]])
					Map.put(actor,"state",state)
				end))
			topology == "honeycomb" ->
				neighbour_map = honeycomb_neighbours(node_count,failure_rate,failure_type)
				IO.inspect(neighbour_map)
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = Enum.map(neighbour_map[actor["id"]],fn id -> Enum.at(actors,id) end)
					state = "unaware"
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0),
						"state"=>state
					}},:infinity)
					actor = Map.put(actor,"neighbours",neighbour_map[actor["id"]])
					Map.put(actor,"state",state)
				end))
			topology == "randhoneycomb" ->
				neighbour_map = honeycomb_rand_neighbours(node_count,failure_rate,failure_type)
				IO.inspect(neighbour_map)
				List.to_tuple(Enum.map(0..node_count-1,fn i ->
					actor = Enum.at(actors,i)
					neighbours = Enum.map(neighbour_map[actor["id"]],fn id -> Enum.at(actors,id) end)
					state = "unaware"
					GenServer.call(actor["pid"],{:initialize,%{
						"id" => i,
						"neighbours" => neighbours,
						"s" => if(algorithm == "push-sum", do: actor["id"], else: 0),
						"state"=>state
					}},:infinity)
					actor = Map.put(actor,"neighbours",neighbour_map[actor["id"]])
					Map.put(actor,"state",state)
				end))
		end
	end

	def receive_state(actors,key) do
		receive do
			{:pong,state,id,reply_key} ->
				if reply_key == key do
					actors = put_elem(actors,id,Map.put(elem(actors,id),"state",state))
					{:cont,actors}
				else
					receive_state(actors,key)
				end
		after
			1_000 -> {:halt,actors}
		end
	end

	def update_actor_states(actors,key) do
		actors = Enum.reduce(0..tuple_size(actors)-1,actors,fn id,acc ->
			GenServer.cast(elem(acc,id)["pid"],{:ping,key})
			put_elem(acc,id,Map.put(elem(acc,id),"state","unknown"))
		end)
		actors = Enum.reduce_while(0..tuple_size(actors)-1, actors, fn _, acc ->
			receive_state(acc,key)
		end)
		Enum.each(0..tuple_size(actors)-1,fn id->
			actor = elem(actors,id)
			if actor["state"] == "unknown" do
				GenServer.cast(actor["pid"],{:restart})
			end
		end)
		# IO.inspect Enum.map(0..tuple_size(actors)-1,fn id->
		# 	actor = elem(actors,id)
		# 	"#{actor["id"]}=>#{actor["state"]}"
		# end)
		actors
	end

	def get_unaware(actors) do
		Enum.filter(0..tuple_size(actors)-1,fn i ->
			elem(actors,i)["state"] == "unaware" end)
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