defmodule Gossip.Actors do
	use GenServer

	def start_link(properties) do
		GenServer.start_link(__MODULE__, properties)
	end

	def init(properties) do
		{:ok, properties}
	end

	def handle_cast({:transition_and_get_state}, properties) do
		properties = Map.put(properties,"state",properties["next_state"])
		send(properties["boss"],{:state, properties["id"], properties["state"]})
		{:noreply, properties}
	end

	def handle_call({:send}, _from, properties) do
		if properties["state"] do
			properties = Gossip.Handler.send_rumor(properties)
			{:reply, :ok, properties}
		else
			send(properties["boss"],{:ok})
			{:reply, :ok, properties}
		end
	end

	def handle_call({:listen, rumor}, _from, properties) do
		if properties["state"] == :true or properties["state"] == :nil do
			{:reply, :nil, Gossip.Handler.process(rumor,properties)}
		else
			{:reply, rumor, properties}
		end
	end

	def handle_call({:set_state,value}, _from, properties) do
		properties = Map.put(properties,"next_state",value)
		send(properties["boss"],{:ok})
		{:reply, :ok, properties}
	end

	def handle_call({:initialize, initvar}, _from, properties) do
		{:reply, :ok, Gossip.Handler.initialize(initvar,properties)}
	end
end