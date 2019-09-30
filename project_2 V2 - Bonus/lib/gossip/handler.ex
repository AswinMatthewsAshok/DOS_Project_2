defmodule Gossip.Handler do
	def process(rumor,properties) do
		cond do
			properties["algorithm"] == "gossip" ->
				properties = Map.put(properties,"count", properties["count"]+1)
				properties = Map.put(properties,"state", if(properties["count"] == 10,do: "dead", else: "alive"))
				properties
			properties["algorithm"] == "push-sum" ->
				properties = Map.put(properties,"s", properties["s"]+rumor["s"])
				properties = Map.put(properties,"w", properties["w"]+rumor["w"])
				next_ratio = Float.round(properties["s"]/properties["w"],10)
				properties = Map.put(properties,"count", if(properties["ratio"] == next_ratio, do: properties["count"]+1, else: 1))
				properties = Map.put(properties,"ratio", next_ratio)
				properties = Map.put(properties,"state", if(properties["count"] == 3, do: "dead", else: "alive"))
				properties
		end
	end

	def change_neighbour_state(properties,actor,state) do
		if(actor["state"] != state,
			do:
			Map.put(properties,"neighbours",Enum.map(properties["neighbours"],fn neighbour->
				if(neighbour["id"] == actor["id"],do: Map.put(neighbour,"state",state),else: neighbour) end)),
			else: properties)
	end

	def send_rumor(properties) do
		properties = Map.put(properties,"valid_neighbours",
			if(Enum.empty?(properties["valid_neighbours"]),
				do: properties["neighbours"],
				else: properties["valid_neighbours"]))
		if not Enum.empty?(properties["valid_neighbours"]) do
			{chosen_neighbour,valid_neighbours} = List.pop_at(properties["valid_neighbours"],Enum.random(0..length(properties["valid_neighbours"])-1))
			properties = Map.put(properties,"valid_neighbours",valid_neighbours)
			properties = change_neighbour_state(properties,chosen_neighbour,"alive")
			# IO.puts("S #{properties["id"]},#{properties["count"]},#{properties["state"]} #{chosen_neighbour["id"]}")
			cond do
				properties["algorithm"] == "gossip" ->
					rumor = :ok
					if chosen_neighbour["pid"] != self() do
						GenServer.cast(chosen_neighbour["pid"],{:listen,rumor,self()})
						properties
					else
						Gossip.Handler.process(rumor,properties)
					end
				properties["algorithm"] == "push-sum" ->
					if properties["w"]/2 != 0 do
						properties = Map.put(properties,"s", properties["s"]/2)
						properties = Map.put(properties,"w", properties["w"]/2)
						properties = Map.put(properties,"ratio", Float.round(properties["s"]/properties["w"],10))
						rumor = %{"s" => properties["s"], "w" => properties["w"]}
						if chosen_neighbour["pid"] != self() do
							GenServer.cast(chosen_neighbour["pid"],{:listen,rumor,self()})
							properties
						else
							Gossip.Handler.process(rumor,properties)
						end
					else
						properties
					end
			end
		else
			properties = Map.put(properties,"state", "dead")
			properties
		end
	end
	def initialize(initvar,properties) do
		cond do
			properties["algorithm"] == "gossip" ->
				properties = Map.put(properties,"id", initvar["id"])
				properties = Map.put(properties,"neighbours", initvar["neighbours"])
				properties = Map.put(properties,"state", initvar["state"])
				properties
			properties["algorithm"] == "push-sum" ->
				properties = Map.put(properties,"id", initvar["id"])
				properties = Map.put(properties,"neighbours", initvar["neighbours"])
				properties = Map.put(properties,"s", initvar["s"])
				properties = Map.put(properties,"ratio", Float.round(properties["s"]/properties["w"],10))
				properties = Map.put(properties,"state", initvar["state"])
				properties
		end
	end
end