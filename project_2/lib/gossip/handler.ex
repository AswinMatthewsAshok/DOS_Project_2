defmodule Gossip.Handler do
	def process(rumor,properties) do
		cond do
			properties["algorithm"] == "gossip" ->
				properties = Map.put(properties,"count", properties["count"]+1)
				properties = Map.put(properties,"next_state", if(properties["count"] == 10,do: :false, else: :true))
				properties = Map.put(properties,"state",if(properties["next_state"] == :false, do: properties["next_state"], else: properties["state"]))
				properties
			properties["algorithm"] == "push-sum" ->
				properties = Map.put(properties,"s", properties["s"]+rumor["s"])
				properties = Map.put(properties,"w", properties["w"]+rumor["w"])
				next_ratio = Kernel.trunc((properties["s"]/properties["w"])*:math.pow(10,10))
				properties = Map.put(properties,"count", if(properties["ratio"] == next_ratio, do: properties["count"]+1, else: 1))
				properties = Map.put(properties,"ratio", next_ratio)
				properties = Map.put(properties,"next_state", if(properties["count"] == 3, do: :false, else: :true))
				properties = Map.put(properties,"state",if(properties["next_state"] == :false, do: properties["next_state"], else: properties["state"]))
				properties
		end
	end
	def send_rumor(properties) do
		cond do
			properties["algorithm"] == "gossip" ->
				rumor = :ok
				result = GenServer.call(elem(Enum.random(properties["neighbours"]),0),{:listen,rumor},:infinity)
				if result == rumor do
					Gossip.Handler.process(rumor,properties)
				else
					properties
				end 
			properties["algorithm"] == "push-sum" ->
				properties = Map.put(properties,"s", properties["s"]/2)
				properties = Map.put(properties,"w", properties["w"]/2)
				properties = Map.put(properties,"ratio", Kernel.trunc((properties["s"]/properties["w"])*:math.pow(10,10)))
				rumor = %{"s" => properties["s"], "w" => properties["w"]}
				result = GenServer.call(elem(Enum.random(properties["neighbours"]),0),{:listen,rumor},:infinity)
				if result == rumor do
					Gossip.Handler.process(rumor,properties)
				else
					properties
				end
		end
	end
	def initialize(initvar,properties) do
		cond do
			properties["algorithm"] == "gossip" ->
				properties = Map.put(properties,"neighbours", initvar["neighbours"])
				properties
			properties["algorithm"] == "push-sum" ->
				properties = Map.put(properties,"neighbours", initvar["neighbours"])
				properties = Map.put(properties,"s", initvar["s"])
				properties = Map.put(properties,"ratio", Kernel.trunc((properties["s"]/properties["w"])*:math.pow(10,10)))
				properties
		end
	end
end