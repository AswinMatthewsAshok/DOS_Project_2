defmodule Gossip.Proj2 do
	main(args \\[])
	args = System.argv()
	[numNodes, topology, algorithm] = args
	actors = Gossip.Topologies.build_topology(topology,String.to_integer(numNodes),algorithm)
	IO.puts(Gossip.Boss.manage(actors,1))
	Gossip.Topologies.terminate_actors(actors)