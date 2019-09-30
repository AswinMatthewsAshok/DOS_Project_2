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

	def handle_cast({:listen, rumor, from}, properties) do
		if properties["state"] == "unaware" do
			send(self(),{:send})
		end
		cond do
			properties["state"] == "alive" or properties["state"] == "unaware" ->
				if properties["failure_type"] == "node" and properties["state"] == "unaware" do
					if Enum.random(1..100) > properties["failure_rate"] do
						properties = Gossip.Handler.process(rumor,properties)
						{:noreply, properties}
					else
						properties = Map.put(properties,"state","unknown")
						{:noreply, properties}
					end
				else
					properties = Gossip.Handler.process(rumor,properties)
					{:noreply, properties}
				end
			properties["state"] == "dead" ->
				GenServer.cast(from,{:bounced, rumor, self()})
				{:noreply, properties}
			true ->
				{:noreply, properties}
		end
	end

	def handle_cast({:bounced, rumor, from}, properties) do
		# IO.puts("B #{properties["id"]},#{properties["count"]},#{properties["state"]}")
		properties = Map.put(properties,"neighbours",Enum.filter(properties["neighbours"],fn neighbour -> from != neighbour["pid"] end))
		properties = Map.put(properties,"valid_neighbours",Enum.filter(properties["valid_neighbours"],fn neighbour -> from != neighbour["pid"] end))
		cond do
			properties["state"] == "alive" ->
				if not Enum.empty?(properties["valid_neighbours"]) do
					properties = Gossip.Handler.process(rumor,properties)
					{:noreply, properties}
				else
					properties = Map.put(properties,"state","dead")
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

	def handle_call({:seed},_from, properties) do
		properties = Map.put(properties,"state","alive")
		send(self(),{:send})
		{:reply, :ok, properties}
	end
end