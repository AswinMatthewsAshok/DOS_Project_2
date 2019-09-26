defmodule Gossip.Proj2 do
	def main(args\\[]) do
		script_mode = true
		start = Time.utc_now()
		[numNodes, topology, algorithm] = args
		actors = Gossip.Topologies.build_topology(topology,String.to_integer(numNodes),algorithm)
		round_count = Gossip.Boss.manage(actors,1)
		Gossip.Topologies.terminate_actors(actors)
		time_taken = Time.diff(Time.utc_now(),start,:millisecond)
		if script_mode do
			IO.puts("#{round_count} #{time_taken}")
		else
			IO.puts("Convergence achieved withing #{round_count} rounds.\nTime taken to achieve convergence is #{time_taken} milliseconds")
		end
	end
end