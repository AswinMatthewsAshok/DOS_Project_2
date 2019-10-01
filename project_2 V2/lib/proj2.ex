defmodule Proj2 do
	def check_args(args) do
		if length(args) == 3 do
			[numNodes, topology, algorithm] = args
			try do
				numNodes = String.to_integer(numNodes)
				if is_integer(numNodes) and numNodes > 0 do
					if Enum.member?(["full", "line", "rand2D", "3Dtorus", "honeycomb" , "randhoneycomb"], topology) do
						if Enum.member?(["gossip", "push-sum"], algorithm) do
							true
						else
							IO.puts("Invalid algorithm")
							false
						end
					else
						IO.puts("Invalid topology")
						false
					end
				else
					IO.puts("Invalid number of nodes")
					false
				end
			rescue
				ArgumentError -> 
					IO.puts("Invalid number of nodes")
					false
			end
		else
			IO.puts("Invalid number of arguments")
			false
		end
	end
	def main(args\\[]) do
		script_mode = true
		if check_args(args) do
			[numNodes, topology, algorithm] = args
			actors = Gossip.Topologies.build_topology(topology,String.to_integer(numNodes),algorithm)
			start = Time.utc_now()
			Gossip.Boss.manage(actors)
			stop = Time.utc_now()
			Gossip.Topologies.terminate_actors(actors)
			time_taken = Time.diff(stop,start,:millisecond)
			if script_mode do
				IO.puts("#{time_taken}")
			else
				IO.puts("Time taken to achieve convergence is #{time_taken} milliseconds")
			end
		end
	end
end