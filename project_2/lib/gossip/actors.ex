defmodule Gossip.Actors do
	use GenServer

	def start_link(properties) do
		GenServer.start_link(__MODULE__, properties)
	end

	def init(properties) do
		{:ok, properties}
	end

	def handle_call({:listen, rumor}, _from, properties) do
		if properties["state"] == :true or properties["state"] == :nil do
			{:reply, :nil, Gossip.Handler.process(rumor,properties)}
		else
			{:reply, rumor, properties}
		end
	end

	def handle_call({:send}, _from, properties) do
		if properties["state"] do
			{:reply, :true, Gossip.Handler.send_rumor(properties)}
		else
			{:reply, :false, properties}
		end
	end

	def handle_call({:set_state,value}, _from, properties) do
		properties = Map.put(properties,"next_state",value)
		{:reply, :ok, properties}
	end

	def handle_call({:transition_and_get_state}, _from, properties) do
		properties = Map.put(properties,"state",properties["next_state"])
		{:reply, properties["state"], properties}
	end

	def handle_call({:initialize, initvar}, _from, properties) do
		{:reply, :ok, Gossip.Handler.initialize(initvar,properties)}
	end
end