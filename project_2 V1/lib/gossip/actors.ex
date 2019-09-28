defmodule Gossip.Actors do
	use GenServer

	def start_link(properties) do
		GenServer.start_link(__MODULE__, properties)
	end

	def init(properties) do
		{:ok, properties}
	end

	def handle_info({:send}, properties) do
		cond do
			properties["state"] == "alive" ->
				properties = Gossip.Handler.send_rumor(properties)
				Process.send_after(self(),{:send},10)
				{:noreply, properties}
			true ->
				{:noreply, properties}
		end
	end

	def handle_cast({:seed}, properties) do
		properties = Map.put(properties,"state","alive")
		send(self(),{:send})
		{:noreply, properties}
	end

	def handle_cast({:listen, rumor, from}, properties) do
		if properties["state"] == "unaware" do
			send(self(),{:send})
		end
		cond do
			properties["state"] == "alive" or properties["state"] == "unaware" ->
				properties = Gossip.Handler.process(rumor,properties)
				{:noreply, properties}
			properties["state"] == "dead" ->
				GenServer.cast(from,{:bounced, rumor, self()})
				{:noreply, properties}
			true ->
				{:noreply, properties}
		end
	end

	def handle_cast({:bounced, rumor, from}, properties) do
		IO.puts("B #{properties["id"]},#{properties["count"]},#{properties["state"]}")
		dead_neighbour = Enum.find(properties["neighbours"],:nil,fn neighbour -> neighbour["pid"] == from end)
		properties = Gossip.Handler.change_neighbour_state(properties,dead_neighbour,"dead")
		properties = Map.put(properties,"valid_neighbours",
			if(Enum.empty?(properties["valid_neighbours"]),
				do: Enum.filter(properties["neighbours"], fn neighbour-> neighbour["state"]!="dead" end),
				else: properties["valid_neighbours"]))
		cond do
			properties["state"] == "alive" ->
				if not Enum.empty?(properties["valid_neighbours"]) do
					properties = Gossip.Handler.process(rumor,properties)
					{:noreply, properties}
				else
					properties = Map.put(properties,"state","dead")
					# IO.puts("#{properties["id"]}")
					{:noreply, properties}
				end
			properties["state"] == "dead" ->
				if not Enum.empty?(properties["valid_neighbours"]) do
					chosen_neighbour = Enum.random(properties["valid_neighbours"])
					properties = Map.put(properties,"valid_neighbours",properties["valid_neighbours"]--[chosen_neighbour])
					properties = Gossip.Handler.change_neighbour_state(properties,chosen_neighbour,"alive")
					if chosen_neighbour["pid"] != self() do
						GenServer.cast(chosen_neighbour["pid"],{:listen,rumor,self()})
						{:noreply, properties}
					else
						{:noreply, properties}
					end
				else
					{:noreply, properties}
				end
			true -> {:noreply, properties}
		end
	end

	def handle_cast({:ping,key}, properties) do
		cond do
			properties["state"] == "unknown" ->
				{:noreply,properties}
			true ->
				send(properties["boss"],{:pong,properties["state"],properties["id"],key})
				{:noreply, properties}
		end
	end

	def handle_cast({:restart},properties) do
		cond do
			properties["state"] == "unknown" ->
				properties = Map.put(properties,"state","unaware")
				{:noreply,properties}
			true->
				{:noreply,properties}
		end
	end

	def handle_call({:initialize, initvar}, _from, properties) do
		{:reply, :ok, Gossip.Handler.initialize(initvar,properties)}
	end
end